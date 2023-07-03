module Testlib.Types where

import Control.Exception as E
import Control.Monad.Base
import Control.Monad.Catch
import Control.Monad.Reader
import Control.Monad.Trans.Control
import Data.Aeson (Value)
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Encode.Pretty as Aeson
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import qualified Data.ByteString.Lazy as L
import qualified Data.CaseInsensitive as CI
import Data.Default
import Data.Function ((&))
import Data.Functor
import Data.Hex
import Data.IORef
import Data.List
import qualified Data.Map as Map
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import GHC.Records
import GHC.Stack
import qualified Network.HTTP.Client as HTTP
import qualified Network.HTTP.Types as HTTP
import Network.URI
import Testlib.Env
import Testlib.Printing
import Prelude

data Response = Response
  { jsonBody :: Maybe Aeson.Value,
    body :: ByteString,
    status :: Int,
    headers :: [HTTP.Header],
    request :: HTTP.Request
  }
  deriving (Show)

instance HasField "json" Response (App Aeson.Value) where
  getField response = maybe (assertFailure "Response has no json body") pure response.jsonBody

showRequest :: HTTP.Request -> String
showRequest r =
  T.unpack (T.decodeUtf8 (HTTP.method r))
    <> " "
    <> uriToString id (HTTP.getUri r) ""

showHeaders :: [HTTP.Header] -> String
showHeaders r =
  intercalate "\n" $
    r <&> \(name, value) ->
      C8.unpack (CI.original name) <> ": " <> C8.unpack value

getRequestBody :: HTTP.Request -> Maybe BS.ByteString
getRequestBody req = case HTTP.requestBody req of
  HTTP.RequestBodyLBS lbs -> pure (L.toStrict lbs)
  HTTP.RequestBodyBS bs -> pure bs
  _ -> Nothing

prettyResponse :: Response -> String
prettyResponse r =
  unlines $
    concat
      [ pure $ colored yellow "request: \n" <> showRequest r.request,
        pure $ colored yellow "request headers: \n" <> showHeaders (HTTP.requestHeaders r.request),
        case getRequestBody r.request of
          Nothing -> []
          Just b ->
            [ colored yellow "request body:",
              T.unpack . T.decodeUtf8 $ case Aeson.decode (L.fromStrict b) of
                Just v -> L.toStrict (Aeson.encodePretty (v :: Aeson.Value))
                Nothing -> hex b
            ],
        pure $ colored blue "response status: " <> show r.status,
        pure $ colored blue "response body:",
        pure $
          ( T.unpack . T.decodeUtf8 $
              case r.jsonBody of
                Just b -> L.toStrict (Aeson.encodePretty b)
                Nothing -> r.body
          )
      ]

data AssertionFailure = AssertionFailure
  { callstack :: CallStack,
    response :: Maybe Response,
    msg :: String
  }

instance Show AssertionFailure where
  show (AssertionFailure _ _ msg) = "AssertionFailure _ _ " <> show msg

instance Exception AssertionFailure where
  displayException (AssertionFailure _ _ msg) = msg

newtype App a = App {unApp :: ReaderT Env IO a}
  deriving
    ( Functor,
      Applicative,
      Monad,
      MonadIO,
      MonadMask,
      MonadCatch,
      MonadThrow,
      MonadReader Env,
      MonadBase IO
    )

instance MonadBaseControl IO App where
  type StM App a = StM (ReaderT Env IO) a
  liftBaseWith f = App (liftBaseWith (\g -> f (g . unApp)))
  restoreM = App . restoreM

runAppWithEnv :: Env -> App a -> IO a
runAppWithEnv e m = runReaderT (unApp m) e

-- | Convert an action in the 'App' monad to an 'IO' action.
appToIO :: App a -> App (IO a)
appToIO action = do
  env <- ask
  pure $ runAppWithEnv env action

getServiceMap :: String -> App ServiceMap
getServiceMap fedDomain = do
  env <- ask
  assertJust ("Could not find service map for federation domain: " <> fedDomain) (Map.lookup fedDomain (env.serviceMap))

getMLSState :: App MLSState
getMLSState = do
  ref <- asks (.mls)
  liftIO $ readIORef ref

setMLSState :: MLSState -> App ()
setMLSState s = do
  ref <- asks (.mls)
  liftIO $ writeIORef ref s

modifyMLSState :: (MLSState -> MLSState) -> App ()
modifyMLSState f = do
  ref <- asks (.mls)
  liftIO $ modifyIORef ref f

getBaseDir :: App FilePath
getBaseDir = fmap (.baseDir) getMLSState

data AppFailure = AppFailure String

instance Show AppFailure where
  show (AppFailure msg) = msg

instance Exception AppFailure where
  displayException (AppFailure msg) = msg

instance MonadFail App where
  fail msg = assertFailure ("Pattern matching failure: " <> msg)

assertFailure :: HasCallStack => String -> App a
assertFailure msg =
  forceList msg $
    liftIO $
      E.throw (AssertionFailure callStack Nothing msg)
  where
    forceList [] y = y
    forceList (x : xs) y = seq x (forceList xs y)

assertJust :: HasCallStack => String -> Maybe a -> App a
assertJust _ (Just x) = pure x
assertJust msg Nothing = assertFailure msg

addFailureContext :: String -> App a -> App a
addFailureContext msg = modifyFailureMsg (\m -> m <> "\nThis failure happened in this context:\n" <> msg)

modifyFailureMsg :: (String -> String) -> App a -> App a
modifyFailureMsg modMessage = modifyFailure (\e -> e {msg = modMessage e.msg})

modifyFailure :: (AssertionFailure -> AssertionFailure) -> App a -> App a
modifyFailure modifyAssertion action = do
  env <- ask
  liftIO
    ( E.catch
        (runAppWithEnv env action)
        ( \(e :: AssertionFailure) ->
            E.throw (modifyAssertion e)
        )
    )

data ServiceOverrides = ServiceOverrides
  { dbBrig :: Value -> App Value,
    dbCannon :: Value -> App Value,
    dbCargohold :: Value -> App Value,
    dbGalley :: Value -> App Value,
    dbGundeck :: Value -> App Value,
    dbNginz :: Value -> App Value,
    dbSpar :: Value -> App Value,
    dbBackgroundWorker :: Value -> App Value
  }

instance Default ServiceOverrides where
  def = defaultServiceOverrides

defaultServiceOverrides :: ServiceOverrides
defaultServiceOverrides =
  ServiceOverrides
    { dbBrig = pure,
      dbCannon = pure,
      dbCargohold = pure,
      dbGalley = pure,
      dbGundeck = pure,
      dbNginz = pure,
      dbSpar = pure,
      dbBackgroundWorker = pure
    }

defaultServiceOverridesToMap :: Map.Map Service (Value -> App Value)
defaultServiceOverridesToMap = ([minBound .. maxBound] <&> (,pure)) & Map.fromList

-- | Overrides the service configurations with the given overrides.
-- e.g.
-- `let overrides =
--    def
--      { dbBrig =
--          setField "optSettings.setFederationStrategy" "allowDynamic"
--            >=> removeField "optSettings.setFederationDomainConfigs"
--      }
--  withOverrides overrides defaultServiceOverridesToMap`
withOverrides :: ServiceOverrides -> Map.Map Service (Value -> App Value) -> Map.Map Service (Value -> App Value)
withOverrides overrides =
  Map.mapWithKey
    ( \svr f ->
        case svr of
          Brig -> f >=> overrides.dbBrig
          Cannon -> f >=> overrides.dbCannon
          Cargohold -> f >=> overrides.dbCargohold
          Galley -> f >=> overrides.dbGalley
          Gundeck -> f >=> overrides.dbGundeck
          Nginz -> f >=> overrides.dbNginz
          Spar -> f >=> overrides.dbSpar
          BackgroundWorker -> f >=> overrides.dbBackgroundWorker
    )
