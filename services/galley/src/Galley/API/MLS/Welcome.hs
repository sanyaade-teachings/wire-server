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

module Galley.API.MLS.Welcome
  ( sendWelcomes,
    sendLocalWelcomes,
  )
where

import Data.Domain
import Data.Id
import Data.Json.Util
import Data.Qualified
import Data.Time
import Galley.API.Push
import Galley.Effects.ExternalAccess
import Galley.Effects.FederatorAccess
import Galley.Effects.GundeckAccess
import Imports
import qualified Network.Wai.Utilities.Error as Wai
import Network.Wai.Utilities.Server
import Polysemy
import Polysemy.Input
import qualified Polysemy.TinyLog as P
import qualified System.Logger.Class as Logger
import Wire.API.Error
import Wire.API.Error.Galley
import Wire.API.Event.Conversation
import Wire.API.Federation.API
import Wire.API.Federation.API.Galley
import Wire.API.Federation.Error
import Wire.API.MLS.Credential
import Wire.API.MLS.Message
import Wire.API.MLS.Serialisation
import Wire.API.MLS.SubConversation
import Wire.API.MLS.Welcome
import Wire.API.Message

sendWelcomes ::
  ( Member FederatorAccess r,
    Member GundeckAccess r,
    Member ExternalAccess r,
    Member P.TinyLog r,
    Member (Input UTCTime) r
  ) =>
  Local ConvOrSubConvId ->
  Qualified UserId ->
  Maybe ConnId ->
  [ClientIdentity] ->
  RawMLS Welcome ->
  Sem r ()
sendWelcomes loc qusr con cids welcome = do
  now <- input
  let qcnv = convFrom <$> tUntagged loc
      (locals, remotes) = partitionQualified loc (map cidQualifiedClient cids)
      msg = mkRawMLS $ mkMessage (MessageWelcome welcome)
  sendLocalWelcomes qcnv qusr con now msg (qualifyAs loc locals)
  sendRemoteWelcomes qcnv qusr msg remotes
  where
    convFrom (Conv c) = c
    convFrom (SubConv c _) = c

sendLocalWelcomes ::
  ( Member GundeckAccess r,
    Member P.TinyLog r,
    Member ExternalAccess r
  ) =>
  Qualified ConvId ->
  Qualified UserId ->
  Maybe ConnId ->
  UTCTime ->
  RawMLS Message ->
  Local [(UserId, ClientId)] ->
  Sem r ()
sendLocalWelcomes qcnv qusr con now welcome lclients = do
  let e = Event qcnv Nothing qusr now $ EdMLSWelcome welcome.raw
  runMessagePush lclients (Just qcnv) $
    newMessagePush mempty con defMessageMetadata (tUnqualified lclients) e

sendRemoteWelcomes ::
  ( Member FederatorAccess r,
    Member P.TinyLog r
  ) =>
  Qualified ConvId ->
  Qualified UserId ->
  RawMLS Message ->
  [Remote (UserId, ClientId)] ->
  Sem r ()
sendRemoteWelcomes qcnv qusr welcome clients = do
  let msg = Base64ByteString welcome.raw
  traverse_ handleError <=< runFederatedConcurrentlyEither clients $ \rcpts ->
    fedClient @'Galley @"mls-welcome"
      MLSWelcomeRequest
        { originatingUser = qUnqualified qusr,
          welcomeMessage = msg,
          recipients = tUnqualified rcpts,
          qualifiedConvId = qcnv
        }
  where
    handleError ::
      Member P.TinyLog r =>
      Either (Remote [a], FederationError) (Remote MLSWelcomeResponse) ->
      Sem r ()
    handleError (Right x) = case tUnqualified x of
      MLSWelcomeSent -> pure ()
      MLSWelcomeMLSNotEnabled -> logFedError x (errorToWai @'MLSNotEnabled)
    handleError (Left (r, e)) = logFedError r (toWai e)

    logFedError :: Member P.TinyLog r => Remote x -> Wai.Error -> Sem r ()
    logFedError r e =
      P.warn $
        Logger.msg ("A welcome message could not be delivered to a remote backend" :: ByteString)
          . Logger.field "remote_domain" (domainText (tDomain r))
          . logErrorMsg e
