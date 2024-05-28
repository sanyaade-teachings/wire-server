-- Disabling to stop warnings on HasCallStack
{-# OPTIONS_GHC -Wno-redundant-constraints #-}

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

module Gundeck.Push.Native.Serialise
  ( serialise,
    maxPayloadSize,
  )
where

import Data.Aeson (Value, object, (.=))
import Data.Aeson.Text (encodeToTextBuilder)
import Data.ByteString qualified as BS
import Data.Id
import Data.Text.Encoding (encodeUtf8)
import Data.Text.Lazy qualified as LT
import Data.Text.Lazy.Builder qualified as LTB
import Gundeck.Push.Native.Types
import Gundeck.Types
import Imports

serialise :: HasCallStack => NativePush -> UserId -> Transport -> Either Failure LT.Text
serialise (NativePush nid prio _aps) uid transport = do
  case renderText transport prio o of
    Nothing -> Left PayloadTooLarge
    Just txt -> Right txt
  where
    o =
      object
        [ "type" .= ("notice" :: Text),
          "data" .= object ["id" .= nid],
          "user" .= uid
        ]

-- | Assemble a final SNS JSON string for transmission.
renderText :: Transport -> Priority -> Value -> Maybe LT.Text
renderText t _prio x = case t of
  GCM -> trim "GCM" (jsonString gcmJson)
  APNS -> trim "APNS" (jsonString stdApnsJson)
  APNSSandbox -> trim "APNS_SANDBOX" (jsonString stdApnsJson)
  where
    gcmJson =
      -- NOTE: Here is the object that is nested after GCM
      -- object
      --   [ "data" .= x,
      --     "priority" .= gcmPriority prio
      --   ]
      object
        [ "fcmV1Message"
            .= object
              [ "message"
                  .= object
                    [ "data" .= x
                    ]
              ]
        ]
    stdApnsJson =
      object
        [ "aps" .= apsDict,
          "data" .= x
        ]
    -- https://developer.apple.com/documentation/usernotifications/modifying_content_in_newly_delivered_notifications
    -- Must contain `mutable-content: 1` and include an alert dictionary with title, subtitle, or body information.
    -- Since we have no useful data here, we send a default payload that gets overridden by the client
    apsDict =
      object
        [ "alert" .= object ["title" .= ("New message" :: Text)],
          "mutable-content" .= '1'
        ]

    maxLen = maxPayloadSize t
    -- see <https://github.com/wireapp/wire-server/issues/341>.
    trim k j =
      let j' = LT.toStrict (LT.take (maxLen + 1) j)
       in if BS.length (encodeUtf8 j') > fromIntegral maxLen
            then Nothing
            else Just $! jsonString $! object [k .= j']

-- | APNS: Check size at https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/generating_a_remote_notification
maxPayloadSize :: Transport -> Int64
maxPayloadSize GCM = 4096
maxPayloadSize APNS = 4096
maxPayloadSize APNSSandbox = 4096

-- gcmPriority :: Priority -> Text
-- gcmPriority LowPriority = "normal"
-- gcmPriority HighPriority = "high"

jsonString :: Value -> LT.Text
jsonString = LTB.toLazyTextWith 512 . encodeToTextBuilder
