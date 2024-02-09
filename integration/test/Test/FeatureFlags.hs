-- This file is part of the Wire Server implementation.
--
-- Copyright (C) 2023 Wire Swiss GmbH <opensource@wire.com>
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

module Test.FeatureFlags where

import API.Galley
import API.GalleyInternal (FeatureStatus (..))
import qualified API.GalleyInternal as I
import qualified Data.Aeson as Aeson
import SetupHelpers
import Testlib.HTTP
import Testlib.Prelude

--------------------------------------------------------------------------------
-- Helpers

expectedStatus :: HasCallStack => FeatureStatus -> Aeson.Value
expectedStatus fs =
  Aeson.object ["lockStatus" .= "unlocked", "status" .= show fs, "ttl" .= "unlimited"]

assertFeature ::
  (HasCallStack, MakesValue user, MakesValue team) =>
  String ->
  user ->
  team ->
  FeatureStatus ->
  App ()
assertFeature featureName user team expected = do
  tf <- getTeamFeature featureName user team
  assertSuccessMatchBody (expectedStatus expected) tf

assertFeatureFromAll ::
  (HasCallStack, MakesValue user) =>
  String ->
  user ->
  FeatureStatus ->
  App ()
assertFeatureFromAll featureName user expected = do
  actual <- extractTeamFeatureFromAll featureName user
  actual %. "status" `shouldMatch` show expected

assertFeatureInternal ::
  (HasCallStack, MakesValue domain) =>
  String ->
  domain ->
  String ->
  FeatureStatus ->
  App ()
assertFeatureInternal featureName dom team expected = do
  tf <- I.getTeamFeature dom featureName team
  assertSuccessMatchBody (expectedStatus expected) tf

--------------------------------------------------------------------------------

testLimitedEventFanout :: HasCallStack => App ()
testLimitedEventFanout = do
  let featureName = "limitedEventFanout"
  (_alice, team, _) <- createTeam OwnDomain 1
  assertFeatureInternal featureName OwnDomain team Disabled
  I.setTeamFeatureStatus OwnDomain team featureName Enabled
  assertFeatureInternal featureName OwnDomain team Enabled

testSSOPut :: HasCallStack => FeatureStatus -> App ()
testSSOPut = genericTestSSO putInternal
  where
    putInternal domain team status = do
      let st = I.WithStatusNoLock status 0
      I.putTeamFeatureStatus domain team "sso" st

testSSOPatch :: HasCallStack => FeatureStatus -> App ()
testSSOPatch = genericTestSSO patchInternal
  where
    patchInternal domain team status =
      I.patchTeamFeatureStatus domain team "sso" status

genericTestSSO ::
  HasCallStack =>
  (String -> String -> FeatureStatus -> App ()) ->
  FeatureStatus ->
  App ()
genericTestSSO setter status = withModifiedBackend cnf $ \domain -> do
  (_alice, team, alex : _) <- createTeam domain 2
  nonMember <- randomUser domain def

  getTeamFeature featureName nonMember team `bindResponse` \resp -> do
    resp.status `shouldMatchInt` 403
    resp.json %. "label" `shouldMatch` "no-team-member"

  assertFeature featureName alex team status
  assertFeatureInternal featureName domain team status
  assertFeatureFromAll featureName alex status

  when (status == Disabled) $ do
    let opposite = Enabled
    setter domain team opposite
    assertFeature featureName alex team opposite
    assertFeatureInternal featureName domain team opposite
    assertFeatureFromAll featureName alex opposite
  where
    featureName = "sso"
    setting = "settings.featureFlags." <> featureName
    cnf =
      def
        { galleyCfg = \conf ->
            conf
              & setField setting (show status <> "-by-default")
        }

legalholdAssertions ::
  (HasCallStack, MakesValue user) =>
  String ->
  String ->
  user ->
  App ()
legalholdAssertions domain team mem = do
  assertFeature featureName mem team Disabled
  assertFeatureInternal featureName domain team Disabled
  assertFeatureFromAll featureName mem Disabled
  nonMem <- randomUser domain def
  getTeamFeature featureName nonMem team `bindResponse` \resp -> do
    resp.status `shouldMatchInt` 403
    resp.json %. "label" `shouldMatch` "no-team-member"
  where
    featureName = "legalhold"

legalholdDisabledByDefault ::
  HasCallStack =>
  (String -> String -> FeatureStatus -> App ()) ->
  App ()
legalholdDisabledByDefault setter = withModifiedBackend cnf $ \domain -> do
  (_alice, team, alex : _) <- createTeam domain 2
  legalholdAssertions domain team alex
  setter domain team Enabled
  assertFeature featureName alex team Enabled
  assertFeatureInternal featureName domain team Enabled
  assertFeatureFromAll featureName alex Enabled
  where
    cnf =
      def
        { galleyCfg = \conf ->
            conf
              -- & setField setting ("whitelist-teams-and-implicit-consent")
              & setField setting ("disabled-by-default")
        }
    setting = "settings.featureFlags." <> featureName
    featureName = "legalhold"

testLegalholdDisabledByDefaultPut :: HasCallStack => App ()
testLegalholdDisabledByDefaultPut = legalholdDisabledByDefault putInternal
  where
    putInternal domain team status = do
      let st = I.WithStatusNoLock status 0
      I.putTeamFeatureStatus domain team "legalhold" st

testLegalholdDisabledByDefaultPatch :: HasCallStack => App ()
testLegalholdDisabledByDefaultPatch = legalholdDisabledByDefault patchInternal
  where
    patchInternal domain team status =
      I.patchTeamFeatureStatus domain team "legalhold" status

legalholdFailToEnable ::
  HasCallStack =>
  (String -> String -> FeatureStatus -> App ()) ->
  String ->
  App ()
legalholdFailToEnable setter confValue = withModifiedBackend cnf $ \domain -> do
  (_alice, team, alex : _) <- createTeam domain 2
  legalholdAssertions domain team alex
  setter domain team Enabled
  where
    cnf =
      def
        { galleyCfg = \conf ->
            conf
              & setField setting confValue
        }
    setting = "settings.featureFlags." <> featureName
    featureName = "legalhold"

testLegalholdDisabledPermanentlyPatch :: HasCallStack => App ()
testLegalholdDisabledPermanentlyPatch =
  legalholdFailToEnable patchInternal "disabled-permanently"
  where
    patchInternal domain team status =
      I.failToPatchTeamFeatureStatus domain team "legalhold" status

testLegalholdDisabledPermanentlyPut :: HasCallStack => App ()
testLegalholdDisabledPermanentlyPut =
  legalholdFailToEnable putInternal "disabled-permanently"
  where
    putInternal domain team status = do
      let st = I.WithStatusNoLock status 0
      I.failToPutTeamFeatureStatus domain team "legalhold" st

testLegalholdWhitelistImplicitConsentPatch :: HasCallStack => App ()
testLegalholdWhitelistImplicitConsentPatch =
  legalholdFailToEnable patchInternal "whitelist-teams-and-implicit-consent"
  where
    patchInternal domain team status =
      I.failToPatchTeamFeatureStatus domain team "legalhold" status

testLegalholdWhitelistImplicitConsentPut :: HasCallStack => App ()
testLegalholdWhitelistImplicitConsentPut =
  legalholdFailToEnable putInternal "whitelist-teams-and-implicit-consent"
  where
    putInternal domain team status = do
      let st = I.WithStatusNoLock status 0
      I.failToPutTeamFeatureStatus domain team "legalhold" st
