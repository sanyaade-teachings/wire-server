{-# LANGUAGE RecordWildCards #-}
{-# HLINT ignore "Use $>" #-}
-- Disabling to stop warnings on HasCallStack
{-# OPTIONS_GHC -Wno-redundant-constraints #-}
{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}
{-# OPTIONS_GHC -fplugin=Polysemy.Plugin #-}

-- This file is part of the Wire Server implementation.
--
-- Copyright (C) 2022 Wire Swiss GmbH <opensource@wire.com>
--
-- This program is free software: you can redistribute it and/or modify it under
-- the terms of the GNU Affero General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option) any
-- later version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
-- details.
--
-- You should have received a copy of the GNU Affero General Public License along
-- with this program. If not, see <https://www.gnu.org/licenses/>.

-- | The API types, handlers, and WAI 'Application' for whole Spar.
--
-- Note: handlers are defined here, but API types are reexported from "Spar.API.Types". The
-- SCIM branch of the API is fully defined in "Spar.Scim".
module Spar.API
  ( -- * Server
    app,
    api,

    -- * API types
    SparAPI,

    -- ** Individual API pieces
    APIAuthReqPrecheck,
    APIAuthReq,
    APIAuthResp,
    IdpGet,
    IdpGetAll,
    IdpCreate,
    IdpDelete,
  )
where

import Brig.Types.Intra
import Cassandra as Cas
import Control.Lens
import Control.Monad.Except
import qualified Data.ByteString as SBS
import Data.ByteString.Builder (toLazyByteString)
import Data.Id
import Data.Proxy
import Data.Range
import qualified Data.Set as Set
import Data.Time
import Galley.Types.Teams (HiddenPerm (CreateUpdateDeleteIdp, ReadIdp))
import Imports
import Polysemy
import Polysemy.Error
import Polysemy.Input
import qualified SAML2.WebSSO as SAML
import Servant
import qualified Servant.Multipart as Multipart
import Spar.App
import Spar.CanonicalInterpreter
import Spar.Error
import qualified Spar.Intra.BrigApp as Brig
import Spar.Options
import Spar.Orphans ()
import Spar.Scim
import Spar.Sem.AReqIDStore (AReqIDStore)
import Spar.Sem.AssIDStore (AssIDStore)
import Spar.Sem.BrigAccess (BrigAccess)
import qualified Spar.Sem.BrigAccess as BrigAccess
import Spar.Sem.DefaultSsoCode (DefaultSsoCode)
import qualified Spar.Sem.DefaultSsoCode as DefaultSsoCode
import Spar.Sem.GalleyAccess (GalleyAccess)
import qualified Spar.Sem.GalleyAccess as GalleyAccess
import Spar.Sem.IdPConfigStore (IdPConfigStore, Replaced (..), Replacing (..))
import qualified Spar.Sem.IdPConfigStore as IdPConfigStore
import Spar.Sem.IdPRawMetadataStore (IdPRawMetadataStore)
import qualified Spar.Sem.IdPRawMetadataStore as IdPRawMetadataStore
import Spar.Sem.Reporter (Reporter)
import Spar.Sem.SAML2 (SAML2)
import qualified Spar.Sem.SAML2 as SAML2
import Spar.Sem.SAMLUserStore (SAMLUserStore)
import qualified Spar.Sem.SAMLUserStore as SAMLUserStore
import Spar.Sem.SamlProtocolSettings (SamlProtocolSettings)
import qualified Spar.Sem.SamlProtocolSettings as SamlProtocolSettings
import Spar.Sem.ScimExternalIdStore (ScimExternalIdStore)
import Spar.Sem.ScimTokenStore (ScimTokenStore)
import qualified Spar.Sem.ScimTokenStore as ScimTokenStore
import Spar.Sem.ScimUserTimesStore (ScimUserTimesStore)
import qualified Spar.Sem.ScimUserTimesStore as ScimUserTimesStore
import Spar.Sem.VerdictFormatStore (VerdictFormatStore)
import qualified Spar.Sem.VerdictFormatStore as VerdictFormatStore
import System.Logger (Msg)
import qualified URI.ByteString as URI
import Wire.API.Routes.Internal.Spar
import Wire.API.Routes.Public.Spar
import Wire.API.User
import Wire.API.User.IdentityProvider
import Wire.API.User.Saml
import Wire.Sem.Logger (Logger)
import qualified Wire.Sem.Logger as Logger
import Wire.Sem.Now (Now)
import Wire.Sem.Random (Random)
import qualified Wire.Sem.Random as Random

app :: Env -> Application
app ctx =
  SAML.setHttpCachePolicy $
    serve (Proxy @SparAPI) (hoistServer (Proxy @SparAPI) (runSparToHandler ctx) (api $ sparCtxOpts ctx) :: Server SparAPI)

api ::
  ( Member GalleyAccess r,
    Member BrigAccess r,
    Member (Input Opts) r,
    Member AssIDStore r,
    Member AReqIDStore r,
    Member VerdictFormatStore r,
    Member ScimExternalIdStore r,
    Member ScimUserTimesStore r,
    Member ScimTokenStore r,
    Member DefaultSsoCode r,
    Member IdPConfigStore r,
    Member IdPRawMetadataStore r,
    Member SAMLUserStore r,
    Member Random r,
    Member (Error SparError) r,
    Member SAML2 r,
    Member Now r,
    Member SamlProtocolSettings r,
    Member (Logger String) r,
    Member Reporter r,
    Member
      ( -- TODO(sandy): Only necessary for 'fromExceptionSem' in 'apiScim'
        Final IO
      )
      r,
    Member (Logger (Msg -> Msg)) r
  ) =>
  Opts ->
  ServerT SparAPI (Sem r)
api opts =
  apiSSO opts
    :<|> apiIDP
    :<|> apiScim
    :<|> apiINTERNAL

apiSSO ::
  ( Member GalleyAccess r,
    Member (Logger String) r,
    Member (Input Opts) r,
    Member BrigAccess r,
    Member AssIDStore r,
    Member VerdictFormatStore r,
    Member AReqIDStore r,
    Member ScimTokenStore r,
    Member DefaultSsoCode r,
    Member IdPConfigStore r,
    Member Random r,
    Member (Error SparError) r,
    Member SAML2 r,
    Member SamlProtocolSettings r,
    Member Reporter r,
    Member SAMLUserStore r
  ) =>
  Opts ->
  ServerT APISSO (Sem r)
apiSSO opts =
  SAML2.meta appName (SamlProtocolSettings.spIssuer Nothing) (SamlProtocolSettings.responseURI Nothing)
    :<|> (\tid -> SAML2.meta appName (SamlProtocolSettings.spIssuer (Just tid)) (SamlProtocolSettings.responseURI (Just tid)))
    :<|> authreqPrecheck
    :<|> authreq (maxttlAuthreqDiffTime opts)
    :<|> authresp Nothing
    :<|> authresp . Just
    :<|> ssoSettings

apiIDP ::
  ( Member Random r,
    Member (Logger String) r,
    Member GalleyAccess r,
    Member BrigAccess r,
    Member ScimTokenStore r,
    Member IdPConfigStore r,
    Member IdPRawMetadataStore r,
    Member SAMLUserStore r,
    Member (Error SparError) r
  ) =>
  ServerT APIIDP (Sem r)
apiIDP =
  idpGet
    :<|> idpGetRaw
    :<|> idpGetAll
    :<|> idpCreate
    :<|> idpUpdate
    :<|> idpDelete

apiINTERNAL ::
  ( Member ScimTokenStore r,
    Member DefaultSsoCode r,
    Member IdPConfigStore r,
    Member (Error SparError) r,
    Member SAMLUserStore r,
    Member ScimUserTimesStore r
  ) =>
  ServerT InternalAPI (Sem r)
apiINTERNAL =
  internalStatus
    :<|> internalDeleteTeam
    :<|> internalPutSsoSettings
    :<|> internalGetScimUserInfo

appName :: Text
appName = "spar"

----------------------------------------------------------------------------
-- SSO API

authreqPrecheck ::
  ( Member IdPConfigStore r,
    Member (Error SparError) r
  ) =>
  Maybe URI.URI ->
  Maybe URI.URI ->
  SAML.IdPId ->
  Sem r NoContent
authreqPrecheck msucc merr idpid =
  validateAuthreqParams msucc merr
    *> IdPConfigStore.getConfig idpid
    $> NoContent

authreq ::
  ( Member Random r,
    Member (Input Opts) r,
    Member (Logger String) r,
    Member AssIDStore r,
    Member VerdictFormatStore r,
    Member AReqIDStore r,
    Member SAML2 r,
    Member SamlProtocolSettings r,
    Member (Error SparError) r,
    Member IdPConfigStore r
  ) =>
  NominalDiffTime ->
  Maybe URI.URI ->
  Maybe URI.URI ->
  SAML.IdPId ->
  Sem r (SAML.FormRedirect SAML.AuthnRequest)
authreq authreqttl msucc merr idpid = do
  vformat <- validateAuthreqParams msucc merr
  form@(SAML.FormRedirect _ ((^. SAML.rqID) -> reqid)) <- do
    idp :: IdP <- IdPConfigStore.getConfig idpid
    let mbtid :: Maybe TeamId
        mbtid = case fromMaybe defWireIdPAPIVersion (idp ^. SAML.idpExtraInfo . apiVersion) of
          WireIdPAPIV1 -> Nothing
          WireIdPAPIV2 -> Just $ idp ^. SAML.idpExtraInfo . team
    SAML2.authReq authreqttl (SamlProtocolSettings.spIssuer mbtid) idpid
  VerdictFormatStore.store authreqttl reqid vformat
  pure form

redirectURLMaxLength :: Int
redirectURLMaxLength = 140

validateAuthreqParams :: Member (Error SparError) r => Maybe URI.URI -> Maybe URI.URI -> Sem r VerdictFormat
validateAuthreqParams msucc merr = case (msucc, merr) of
  (Nothing, Nothing) -> pure VerdictFormatWeb
  (Just ok, Just err) -> do
    validateRedirectURL `mapM_` [ok, err]
    pure $ VerdictFormatMobile ok err
  _ -> throwSparSem $ SparBadInitiateLoginQueryParams "need-both-redirect-urls"

validateRedirectURL :: Member (Error SparError) r => URI.URI -> Sem r ()
validateRedirectURL uri = do
  unless ((SBS.take 4 . URI.schemeBS . URI.uriScheme $ uri) == "wire") $ do
    throwSparSem $ SparBadInitiateLoginQueryParams "invalid-schema"
  unless (SBS.length (URI.serializeURIRef' uri) <= redirectURLMaxLength) $ do
    throwSparSem $ SparBadInitiateLoginQueryParams "url-too-long"

authresp ::
  forall r.
  ( Member Random r,
    Member (Logger String) r,
    Member (Input Opts) r,
    Member GalleyAccess r,
    Member BrigAccess r,
    Member AssIDStore r,
    Member VerdictFormatStore r,
    Member AReqIDStore r,
    Member ScimTokenStore r,
    Member IdPConfigStore r,
    Member SAML2 r,
    Member SamlProtocolSettings r,
    Member (Error SparError) r,
    Member Reporter r,
    Member SAMLUserStore r
  ) =>
  Maybe TeamId ->
  SAML.AuthnResponseBody ->
  Sem r Void
authresp mbtid arbody = logErrors $ SAML2.authResp mbtid (SamlProtocolSettings.spIssuer mbtid) (SamlProtocolSettings.responseURI mbtid) go arbody
  where
    go :: SAML.AuthnResponse -> IdP -> SAML.AccessVerdict -> Sem r Void
    go resp verdict idp = do
      result :: SAML.ResponseVerdict <- verdictHandler resp idp verdict
      throw @SparError $ SAML.CustomServant result

    logErrors :: Sem r Void -> Sem r Void
    logErrors action = catch @SparError action $ \case
      e@(SAML.CustomServant _) -> throw e
      e -> do
        throw @SparError . SAML.CustomServant $
          errorPage
            e
            (Multipart.inputs (SAML.authnResponseBodyRaw arbody))

ssoSettings :: Member DefaultSsoCode r => Sem r SsoSettings
ssoSettings =
  SsoSettings <$> DefaultSsoCode.get

----------------------------------------------------------------------------
-- IdPConfigStore API

idpGet ::
  ( Member Random r,
    Member (Logger String) r,
    Member GalleyAccess r,
    Member BrigAccess r,
    Member IdPConfigStore r,
    Member (Error SparError) r
  ) =>
  Maybe UserId ->
  SAML.IdPId ->
  Sem r IdP
idpGet zusr idpid = withDebugLog "idpGet" (Just . show . (^. SAML.idpId)) $ do
  idp <- IdPConfigStore.getConfig idpid
  _ <- authorizeIdP zusr idp
  pure idp

idpGetRaw ::
  ( Member GalleyAccess r,
    Member BrigAccess r,
    Member IdPConfigStore r,
    Member IdPRawMetadataStore r,
    Member (Error SparError) r
  ) =>
  Maybe UserId ->
  SAML.IdPId ->
  Sem r RawIdPMetadata
idpGetRaw zusr idpid = do
  idp <- IdPConfigStore.getConfig idpid
  _ <- authorizeIdP zusr idp
  IdPRawMetadataStore.get idpid >>= \case
    Just txt -> pure $ RawIdPMetadata txt
    Nothing -> throwSparSem $ SparIdPNotFound (cs $ show idpid)

idpGetAll ::
  ( Member Random r,
    Member (Logger String) r,
    Member GalleyAccess r,
    Member BrigAccess r,
    Member IdPConfigStore r,
    Member (Error SparError) r
  ) =>
  Maybe UserId ->
  Sem r IdPList
idpGetAll zusr = withDebugLog "idpGetAll" (const Nothing) $ do
  teamid <- Brig.getZUsrCheckPerm zusr ReadIdp
  _providers <- IdPConfigStore.getConfigsByTeam teamid
  pure IdPList {..}

-- | Delete empty IdPs, or if @"purge=true"@ in the HTTP query, delete all users
-- *synchronously* on brig and spar, and the IdP once it's empty.
--
-- The @"purge"@ query parameter is as a quick work-around until we have something better.  It
-- may very well time out, but it processes the users under the 'IdP' in chunks of 2000, so no
-- matter what the team size, it shouldn't choke any servers, just the client (which is
-- probably curl running locally on one of the spar instances).
-- https://github.com/zinfra/backend-issues/issues/1314
--
-- FUTUREWORK: discontinue POST with `replaced_by` query param.  we have PUT now to update
-- existing IdPs in-place, no need to post replacing new idps..
idpDelete ::
  forall r.
  ( Member Random r,
    Member (Logger String) r,
    Member GalleyAccess r,
    Member BrigAccess r,
    Member ScimTokenStore r,
    Member SAMLUserStore r,
    Member IdPConfigStore r,
    Member IdPRawMetadataStore r,
    Member (Error SparError) r
  ) =>
  Maybe UserId ->
  SAML.IdPId ->
  Maybe Bool ->
  Sem r NoContent
idpDelete mbzusr idpid (fromMaybe False -> purge) = withDebugLog "idpDelete" (const Nothing) $ do
  idp <- IdPConfigStore.getConfig idpid
  (zusr, teamId) <- authorizeIdP mbzusr idp
  whenM (idpDoesAuthSelf idp zusr) $ throwSparSem SparIdPCannotDeleteOwnIdp
  assertEmptyOrPurge idp
  actuallyDelete idp teamId
  pure NoContent
  where
    allIssuers :: IdP -> [SAML.Issuer]
    allIssuers idp = (idp ^. SAML.idpMetadata . SAML.edIssuer) : (idp ^. SAML.idpExtraInfo . oldIssuers)

    assertEmptyOrPurge :: IdP -> Sem r ()
    assertEmptyOrPurge idp = do
      forM_ (allIssuers idp) $ \issuer -> do
        page <- SAMLUserStore.getAllByIssuerPaginated issuer
        cont page
      where
        cont :: Cas.Page (SAML.UserRef, UserId) -> Sem r ()
        cont page = do
          forM_ (Cas.result page) $ \(uref, uid) -> do
            mbAccount <- BrigAccess.getAccount NoPendingInvitations uid
            let mUserTeam = userTeam . accountUser =<< mbAccount
            -- See comment on 'getAllSAMLUsersByIssuerPaginated' for why we need to filter for team here.
            when (mUserTeam == Just (idp ^. SAML.idpExtraInfo . team)) $ do
              if purge
                then void $ BrigAccess.deleteUser uid >> SAMLUserStore.delete uid uref
                else throwSparSem (SparIdPHasBoundUsers (cs $ show $ idp ^. SAML.idpId))
          when (Cas.hasMore page) $
            SAMLUserStore.nextPage page >>= cont

    actuallyDelete :: IdP -> TeamId -> Sem r ()
    actuallyDelete idp teamId = do
      -- Delete tokens associated with given IdP (we rely on the fact that
      -- each IdP has exactly one team so we can look up all tokens
      -- associated with the team and then filter them)
      tokens <- ScimTokenStore.lookupByTeam teamId
      for_ tokens $ \ScimTokenInfo {..} ->
        when (stiIdP == Just idpid) $ ScimTokenStore.delete teamId stiId
      -- Delete IdP config
      IdPConfigStore.deleteConfig idp
      IdPRawMetadataStore.delete idpid
      -- old issuers
      forM_ (allIssuers idp) $ \iss -> IdPConfigStore.deleteIssuer iss (Just $ idp ^. SAML.idpExtraInfo . team)

    idpDoesAuthSelf :: IdP -> UserId -> Sem r Bool
    idpDoesAuthSelf idp uid = do
      let idpIssuer = idp ^. SAML.idpMetadata . SAML.edIssuer
      mUserIssuer <- (>>= userIssuer) <$> Brig.getBrigUser NoPendingInvitations uid
      pure $ mUserIssuer == Just idpIssuer

-- | This handler only does the json parsing, and leaves all authorization checks and
-- application logic to 'idpCreateXML'.
idpCreate ::
  ( Member Random r,
    Member (Logger String) r,
    Member GalleyAccess r,
    Member BrigAccess r,
    Member ScimTokenStore r,
    Member IdPRawMetadataStore r,
    Member IdPConfigStore r,
    Member (Error SparError) r
  ) =>
  Maybe UserId ->
  IdPMetadataInfo ->
  Maybe SAML.IdPId ->
  Maybe WireIdPAPIVersion ->
  Maybe (Range 1 32 Text) ->
  Sem r IdP
idpCreate zusr (IdPMetadataValue raw xml) = idpCreateXML zusr raw xml

-- | We generate a new UUID for each IdP used as IdPConfig's path, thereby ensuring uniqueness.
idpCreateXML ::
  ( Member Random r,
    Member (Logger String) r,
    Member GalleyAccess r,
    Member BrigAccess r,
    Member ScimTokenStore r,
    Member IdPConfigStore r,
    Member IdPRawMetadataStore r,
    Member (Error SparError) r
  ) =>
  Maybe UserId ->
  Text ->
  SAML.IdPMetadata ->
  Maybe SAML.IdPId ->
  Maybe WireIdPAPIVersion ->
  Maybe (Range 1 32 Text) ->
  Sem r IdP
idpCreateXML zusr raw idpmeta mReplaces (fromMaybe defWireIdPAPIVersion -> apiversion) mHandle = withDebugLog "idpCreateXML" (Just . show . (^. SAML.idpId)) $ do
  teamid <- Brig.getZUsrCheckPerm zusr CreateUpdateDeleteIdp
  GalleyAccess.assertSSOEnabled teamid
  assertNoScimOrNoIdP teamid
  idp <-
    maybe (IdPConfigStore.newHandle teamid) (pure . IdPHandle . fromRange) mHandle
      >>= validateNewIdP apiversion idpmeta teamid mReplaces
  IdPRawMetadataStore.store (idp ^. SAML.idpId) raw
  IdPConfigStore.insertConfig idp
  forM_ mReplaces $ \replaces ->
    IdPConfigStore.setReplacedBy (Replaced replaces) (Replacing (idp ^. SAML.idpId))
  pure idp

-- | In teams with a scim access token, only one IdP is allowed.  The reason is that scim user
-- data contains no information about the idp issuer, only the user name, so no valid saml
-- credentials can be created.  To fix this, we need to implement a way to associate scim
-- tokens with IdPs.  https://wearezeta.atlassian.net/browse/SQSERVICES-165
assertNoScimOrNoIdP ::
  ( Member ScimTokenStore r,
    Member (Error SparError) r,
    Member IdPConfigStore r
  ) =>
  TeamId ->
  Sem r ()
assertNoScimOrNoIdP teamid = do
  numTokens <- length <$> ScimTokenStore.lookupByTeam teamid
  numIdps <- length <$> IdPConfigStore.getConfigsByTeam teamid
  when (numTokens > 0 && numIdps > 0) $
    throwSparSem $
      SparProvisioningMoreThanOneIdP
        "Teams with SCIM tokens can only have at most one IdP"

-- | Does a number of things:
--
-- * Create IdPId (uuidv4)
-- * Check that request URI is https;
-- * Check that issuer is not used anywhere in the system ('WireIdPAPIV1', here it is a
--   database key for finding IdPs), or anywhere in this team ('WireIdPAPIV2');
-- * Check that all replaced IdPIds, if present, point to our team.
-- * ...  (read source code to make sure this comment is up to date!)
--
-- About the @mReplaces@ argument: the information whether the idp is replacing an old one is
-- in query parameter, because the body can be both XML and JSON.  The JSON body could carry
-- the replaced idp id fine, but the XML is defined in the SAML standard and cannot be
-- changed.  NB: if you want to replace an IdP by one with the same issuer, you probably
-- want to use `PUT` instead of `POST`.
--
-- FUTUREWORK: deprecate XML body type.
validateNewIdP ::
  forall m r.
  (HasCallStack, m ~ Sem r) =>
  ( Member Random r,
    Member (Logger String) r,
    Member IdPConfigStore r,
    Member (Error SparError) r
  ) =>
  WireIdPAPIVersion ->
  SAML.IdPMetadata ->
  TeamId ->
  Maybe SAML.IdPId ->
  IdPHandle ->
  m IdP
validateNewIdP apiversion _idpMetadata teamId mReplaces idHandle = withDebugLog "validateNewIdP" (Just . show . (^. SAML.idpId)) $ do
  _idpId <- SAML.IdPId <$> Random.uuid
  let requri = _idpMetadata ^. SAML.edRequestURI
      _idpExtraInfo = WireIdP teamId (Just apiversion) oldIssuersList Nothing idHandle

  enforceHttps requri
  checkNotInUse

  mOldIdP <- IdPConfigStore.getConfig `mapM` mReplaces
  let oldIssuersList :: [SAML.Issuer]
      oldIssuersList = case mOldIdP of
        Nothing -> []
        Just oldIdP -> (oldIdP ^. SAML.idpMetadata . SAML.edIssuer) : (oldIdP ^. SAML.idpExtraInfo . oldIssuers)

  pure SAML.IdPConfig {..}
  where
    checkNotInUse :: m IdP
    checkNotInUse = do
      mbPreviousIdP <- case apiversion of
        WireIdPAPIV1 -> IdPConfigStore.getIdPByIssuerV1Maybe (_idpMetadata ^. SAML.edIssuer)
        WireIdPAPIV2 -> IdPConfigStore.getIdPByIssuerV2Maybe (_idpMetadata ^. SAML.edIssuer) teamId
      Logger.log Logger.Debug $ show (apiversion, _idpMetadata, teamId, mReplaces)
      Logger.log Logger.Debug $ show (_idpId, oldIssuersList, mbPreviousIdP)
      let idpIssuerInUse = case (mbPreviousIdP, mReplaces) of
            (Nothing, Nothing) -> False
            (Nothing, Just _) -> False -- this is unexpected, though: caller is referencing a replacee that doesn't exist.
            (Just _, Nothing) -> True
            (Just previousIdP, Just previousId) -> previousIdP ^. SAML.idpId /= previousId
      when idpIssuerInUse $ failWithIdPClash apiversion "create" _idpId (_idpMetadata ^. SAML.edIssuer)

failWithIdPClash :: (Member (Error SparError) r) => WireIdPAPIVersion -> LText -> SAML.IdPId -> SAML.Issuer -> Sem r ()
failWithIdPClash apiversion operation iid iissuer = throwSparSem . SparIdPIssuerInUse $ msg <> ctx
  where
    ctx = " idp id: " <> (cs . SAML.idPIdToST $ iid) <> "; issuer: " <> (cs . SAML.renderURI . view SAML.fromIssuer $ iissuer) <> "."
    msg = case apiversion of
      WireIdPAPIV1 ->
        "You can't " <> operation <> " an IdP with api_version v1 if the issuer is already in use on your wire instance."
      WireIdPAPIV2 ->
        -- idp was found by lookup with teamid, so it's in the same team.
        "You can't " <> operation <> " an IdP with api_version v2 if the issuer is already in use in your team."

-- | FUTUREWORK: 'idpUpdateXML' is only factored out of this function for symmetry with
-- 'idpCreate', which is not a good reason.  make this one function and pass around
-- 'IdPMetadataInfo' directly where convenient.
idpUpdate ::
  ( Member Random r,
    Member (Logger String) r,
    Member GalleyAccess r,
    Member BrigAccess r,
    Member IdPConfigStore r,
    Member IdPRawMetadataStore r,
    Member (Error SparError) r
  ) =>
  Maybe UserId ->
  IdPMetadataInfo ->
  SAML.IdPId ->
  Maybe (Range 1 32 Text) ->
  Sem r IdP
idpUpdate zusr (IdPMetadataValue raw xml) = idpUpdateXML zusr raw xml

idpUpdateXML ::
  ( Member Random r,
    Member (Logger String) r,
    Member GalleyAccess r,
    Member BrigAccess r,
    Member IdPConfigStore r,
    Member IdPRawMetadataStore r,
    Member (Error SparError) r
  ) =>
  Maybe UserId ->
  Text ->
  SAML.IdPMetadata ->
  SAML.IdPId ->
  Maybe (Range 1 32 Text) ->
  Sem r IdP
idpUpdateXML zusr raw idpmeta idpid mHandle = withDebugLog "idpUpdateXML" (Just . show . (^. SAML.idpId)) $ do
  (teamid, idp) <- validateIdPUpdate zusr idpmeta idpid
  GalleyAccess.assertSSOEnabled teamid
  IdPRawMetadataStore.store (idp ^. SAML.idpId) raw
  let idp' :: IdP = case mHandle of
        Just idpHandle -> idp & (SAML.idpExtraInfo . handle) .~ IdPHandle (fromRange idpHandle)
        Nothing -> idp
  -- (if raw metadata is stored and then spar goes out, raw metadata won't match the
  -- structured idp config.  since this will lead to a 5xx response, the client is expected to
  -- try again, which would clean up cassandra state.)
  IdPConfigStore.insertConfig idp'
  pure idp'

-- Construct a validated `IdP` from `IdPMetadata`.
validateIdPUpdate ::
  forall m r.
  (HasCallStack, m ~ Sem r) =>
  ( Member Random r,
    Member (Logger String) r,
    Member GalleyAccess r,
    Member BrigAccess r,
    Member IdPConfigStore r,
    Member (Error SparError) r
  ) =>
  Maybe UserId ->
  SAML.IdPMetadata ->
  SAML.IdPId ->
  m (TeamId, IdP)
validateIdPUpdate zusr _idpMetadata _idpId = withDebugLog "validateIdPUpdate" (Just . show . (_2 %~ (^. SAML.idpId))) $ do
  previousIdP <- IdPConfigStore.getConfig _idpId
  let apiversion = fromMaybe defWireIdPAPIVersion $ previousIdP ^. SAML.idpExtraInfo . apiVersion
      newIssuer = _idpMetadata ^. SAML.edIssuer
  (_, teamId) <- authorizeIdP zusr previousIdP
  unless (previousIdP ^. SAML.idpExtraInfo . team == teamId) $
    throw errUnknownIdP
  let previousIssuer = previousIdP ^. SAML.idpMetadata . SAML.edIssuer
      allPreviousIssuers = nub $ previousIssuer : previousIdP ^. SAML.idpExtraInfo . oldIssuers
  _idpExtraInfo <- do
    if previousIssuer == newIssuer
      then do
        -- idempotency
        pure $ previousIdP ^. SAML.idpExtraInfo
      else do
        idpIssuerInUse <-
          ( case apiversion of
              WireIdPAPIV1 -> IdPConfigStore.getIdPByIssuerV1Maybe newIssuer
              WireIdPAPIV2 -> IdPConfigStore.getIdPByIssuerV2Maybe newIssuer teamId
            )
            <&> ( \case
                    Just idpFound ->
                      let notIt = idpFound ^. SAML.idpId /= _idpId
                          notReplacedByIt = idpFound ^. SAML.idpExtraInfo . replacedBy /= Just _idpId
                       in notIt && notReplacedByIt
                    Nothing -> False
                )
        when idpIssuerInUse $ failWithIdPClash apiversion "update" _idpId newIssuer
        pure $ previousIdP ^. SAML.idpExtraInfo & oldIssuers .~ allPreviousIssuers

  let requri = _idpMetadata ^. SAML.edRequestURI
  enforceHttps requri
  pure (teamId, SAML.IdPConfig {..})
  where
    errUnknownIdP = SAML.UnknownIdP $ enc uri
      where
        enc = cs . toLazyByteString . URI.serializeURIRef
        uri = _idpMetadata ^. SAML.edIssuer . SAML.fromIssuer

withDebugLog :: Member (Logger String) r => String -> (a -> Maybe String) -> Sem r a -> Sem r a
withDebugLog msg showval action = do
  Logger.log Logger.Debug $ "entering " ++ msg
  val <- action
  let mshowedval = showval val
  Logger.log Logger.Debug $ "leaving " ++ msg ++ mconcat [": " ++ fromJust mshowedval | isJust mshowedval]
  pure val

authorizeIdP ::
  ( HasCallStack,
    ( Member GalleyAccess r,
      Member BrigAccess r,
      Member (Error SparError) r
    )
  ) =>
  Maybe UserId ->
  IdP ->
  Sem r (UserId, TeamId)
authorizeIdP Nothing _ = throw (SAML.CustomError $ SparNoPermission (cs $ show CreateUpdateDeleteIdp))
authorizeIdP (Just zusr) idp = do
  let teamid = idp ^. SAML.idpExtraInfo . team
  GalleyAccess.assertHasPermission teamid CreateUpdateDeleteIdp zusr
  pure (zusr, teamid)

enforceHttps :: Member (Error SparError) r => URI.URI -> Sem r ()
enforceHttps uri =
  unless ((uri ^. URI.uriSchemeL . URI.schemeBSL) == "https") $ do
    throwSparSem . SparNewIdPWantHttps . cs . SAML.renderURI $ uri

----------------------------------------------------------------------------
-- Internal API

internalStatus :: Sem r NoContent
internalStatus = pure NoContent

-- | Cleanup handler that is called by Galley whenever a team is about to
-- get deleted.
internalDeleteTeam ::
  ( Member ScimTokenStore r,
    Member IdPConfigStore r,
    Member SAMLUserStore r
  ) =>
  TeamId ->
  Sem r NoContent
internalDeleteTeam teamId = do
  deleteTeam teamId
  pure NoContent

internalPutSsoSettings ::
  ( Member DefaultSsoCode r,
    Member (Error SparError) r,
    Member IdPConfigStore r
  ) =>
  SsoSettings ->
  Sem r NoContent
internalPutSsoSettings SsoSettings {defaultSsoCode = Nothing} = do
  DefaultSsoCode.delete
  pure NoContent
internalPutSsoSettings SsoSettings {defaultSsoCode = Just code} =
  -- this can throw a 404, which is not quite right,
  -- but it's an internal endpoint and the message clearly says
  -- "Could not find IdP".
  IdPConfigStore.getConfig code
    *> DefaultSsoCode.store code
    $> NoContent

internalGetScimUserInfo :: Member ScimUserTimesStore r => UserSet -> Sem r ScimUserInfos
internalGetScimUserInfo (UserSet uids) = do
  results <- ScimUserTimesStore.readMulti (Set.toList uids)
  let scimUserInfos = results <&> (\(uid, t, _) -> ScimUserInfo uid (Just t))
  pure $ ScimUserInfos scimUserInfos
