{-# LANGUAGE DeriveGeneric #-}
module Servant.Subscriber.Response where


import qualified Blaze.ByteString.Builder        as B
import           Control.Concurrent.STM          (STM, atomically, retry)
import           Control.Concurrent.STM.TVar
import           Control.Monad                   (void)
import           Data.Aeson
import           Data.Aeson.Parser               (value)
import           Data.Aeson.Types                (unsafeToEncoding)
import qualified Data.ByteString                 as BS
import qualified Data.CaseInsensitive            as Case
import           Data.IntMap                     (IntMap)
import qualified Data.IntMap                     as IntMap
import           Data.Map                        (Map)
import           Data.Text                       (Text)
import qualified Data.Text.Encoding              as T
import           Data.Time
import           GHC.Generics
import qualified Network.HTTP.Types              as H
import qualified Network.Wai                     as Wai
import qualified Network.Wai.Internal            as Wai
import           Network.WebSockets.Connection   as WS
import           Servant.Server

import           Data.Attoparsec.ByteString      (parseOnly)
import           Data.Bifunctor
import           Servant.Subscriber
import           Servant.Subscriber.Request
import           Servant.Subscriber.Subscribable

type ResponseHeader = RequestHeader
type ResponseHeaders = RequestHeaders

-- | Any message from the server is a Response.
data Response =
    Response !Path !EventName !HttpResponse
  | ServerError !Path !ServantErr
  | RequestError !Path !SubscribeAction !RequestError
  deriving Generic

instance ToJSON Response

data HttpResponse = HttpResponse {
  httpStatus  :: !Status
, httpHeaders :: !ResponseHeaders
, httpBody    :: ResponseBody
} deriving Generic

instance ToJSON HttpResponse


data Status = Status {
  statusCode    :: !Int
, statusMessage :: !Text
} deriving Generic

instance ToJSON Status

data ResponseBody = ResponseBody B.Builder

instance ToJSON ResponseBody where
  toJSON (ResponseBody b) = getValue $ parseOnly value (B.toByteString b)
    where
      getValue r = case r of
        Left e -> error e
        Right r -> r
  toEncoding (ResponseBody b) = unsafeToEncoding b -- A no-op - like it should be :-)

fromHTTPHeader :: H.Header -> ResponseHeader
fromHTTPHeader = bimap (T.decodeUtf8 . Case.original) T.decodeUtf8

fromHTTPHeaders :: H.ResponseHeaders -> ResponseHeaders
fromHTTPHeaders = map fromHTTPHeader

fromHTTPStatus :: H.Status -> Status
fromHTTPStatus s = Status {
  statusCode = H.statusCode s
, statusMessage = T.decodeUtf8 . H.statusMessage $ s
}
