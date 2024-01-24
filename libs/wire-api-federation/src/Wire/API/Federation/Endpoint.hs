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

module Wire.API.Federation.Endpoint
  ( ApplyMods,
    module Wire.API.Federation.Endpoint,
  )
where

import Data.Kind
import GHC.TypeLits
import Servant.API
import Wire.API.ApplyMods
import Wire.API.Federation.API.Common
import Wire.API.Federation.Domain
import Wire.API.Federation.HasNotificationEndpoint
import Wire.API.Routes.Named

data Versioned v name

instance {-# OVERLAPPING #-} RenderableSymbol a => RenderableSymbol (Versioned v a) where
  renderSymbol = renderSymbol @a

type family FedPath (name :: k) :: Symbol

type instance FedPath (name :: Symbol) = name

type instance FedPath (Versioned v name) = name

type FedEndpointWithMods (mods :: [Type]) name input output =
  Named
    name
    ( ApplyMods
        mods
        (FedPath name :> OriginDomainHeader :> ReqBody '[JSON] input :> Post '[JSON] output)
    )

type NotificationFedEndpointWithMods (mods :: [Type]) name input =
  FedEndpointWithMods mods name input EmptyResponse

type FedEndpoint name input output = FedEndpointWithMods '[] name input output

type NotificationFedEndpoint tag =
  FedEndpoint (NotificationPath tag) (Payload tag) EmptyResponse

type StreamingFedEndpoint name input output =
  Named
    name
    ( name
        :> OriginDomainHeader
        :> ReqBody '[JSON] input
        :> StreamPost NoFraming OctetStream output
    )
