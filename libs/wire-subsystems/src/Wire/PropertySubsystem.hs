module Wire.PropertySubsystem where

import Data.Id
import Imports
import Wire.API.Properties

data PropertiesDataError
  = TooManyProperties

data PropertySubsystem m a where
  SetProperty :: UserId -> ConnId -> PropertyKey -> PropertyValue -> PropertySubsystem m ()
  DeleteProperty :: UserId -> ConnId -> PropertyKey -> PropertySubsystem m ()
  ClearProperties :: UserId -> ConnId -> PropertySubsystem m ()
  LookupProperty :: UserId -> PropertyKey -> PropertySubsystem m (Maybe RawPropertyValue)
  LookupPropertyKeys :: UserId -> PropertySubsystem m [PropertyKey]
  GetAllProperties :: UserId -> PropertySubsystem m [(PropertyKey, RawPropertyValue)]
