{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE DeriveTraversable          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE StandaloneDeriving         #-}

module Web.Routes.Nested.FileExtListener where

import qualified Data.Aeson              as A
import qualified Data.Text.Lazy          as LT
import qualified Data.Text.Lazy.Encoding as LT
import           Network.HTTP.Types      (status200)
import           Network.Wai

import           Control.Applicative
import           Control.Monad.Trans
import           Control.Monad.Writer
import           Data.Monoid
import           Data.Map.Lazy
import           Data.Traversable
import           Data.Foldable


data FileExt = Html
             | Json
             | Text
  deriving (Show, Eq, Ord)

possibleExts :: FileExt -> [String]
possibleExts Html = ["", ".htm", ".html"]
possibleExts Json = [".json"]
possibleExts Text = [".txt"]

newtype FileExts a = FileExts { unFileExts :: Map FileExt a }
  deriving (Show, Eq, Functor, Traversable)

deriving instance Monoid      (FileExts a)
deriving instance Foldable     FileExts

-- | Sorting instance
-- instance Monoid (FileExts a) where
--   mempty = FileExts []
--   (FileExts []) `mappend` ys = ys
--   xs `mappend` (FileExts []) = xs
--   (FileExts (x'@(x,a):xs)) `mappend` (FileExts (y'@(y,b):ys))
--     | x < y = FileExts $ x' : xs `mappend` (y':ys)
--     | x > y = FileExts $ y' : (x':xs) `mappend` ys
--     | x == y = FileExts $ y' : xs `mappend` ys
--     | otherwise = error "unordered merge?"

newtype FileExtListenerT r m a =
  FileExtListenerT { runFileExtListenerT :: WriterT (FileExts r) m a }
    deriving (Functor)

deriving instance Applicative m => Applicative (FileExtListenerT r m)
deriving instance Monad m =>       Monad       (FileExtListenerT r m)
deriving instance MonadIO m =>     MonadIO     (FileExtListenerT r m)
deriving instance                  MonadTrans  (FileExtListenerT r)


-- TODO: Propogate constraints to bottom-level of dual-written expression
-- TODO: Overload sub-expressions to be bottom-level if contextually inside
-- a wrapper, or mid-level if itself is wrapper
-- TODO: key (1,2) is ordered (and organized) by outer/inner expression -
-- optimization for content-type vs. verb is up to end user.
json :: (A.ToJSON j, Monad m) =>
        j
     -> FileExtListenerT Response m ()
json i =
  let r = responseLBS status200 [("Content-Type", "application/json")] $
            A.encode i
  in
  FileExtListenerT $ tell $
    FileExts $ singleton Json r

jsonp :: (A.ToJSON j, Monad m) =>
         j
      -> FileExtListenerT Response m ()
jsonp i =
  let r = responseLBS status200 [("Content-Type", "application/javascript")] $
            A.encode i
  in
  FileExtListenerT $ tell $
    FileExts $ singleton Json r

text :: (Monad m) =>
        LT.Text
     -> FileExtListenerT Response m ()
text i =
  let r = responseLBS status200 [("Content-Type", "text/plain")] $
            LT.encodeUtf8 i
  in
  FileExtListenerT $ tell $
    FileExts $ singleton Text r
--
-- blaze :: Html -> Response
-- blaze = HR.renderHtml
--
-- lucid :: Monad m => HtmlT m () -> Response
-- lucid = L.renderTextT

-- json :: ToJSON a => a -> Response
-- json = lazy-bytestring . encode

-- text :: T.Text -> Response
-- text = bytestring . TR.encodeUtf8

-- lazy-text :: LT.Text -> Response
-- lazy-text = lazy-bytestring . LTR.encodeUtf8
--
-- builder :: Builder -> Response
-- builder = responseBuilder
--
-- bytestring :: B.ByteString -> Response
-- bytestring = lazy-bytestring . LB.fromStrict
--
-- lazy-bytestring :: LB.ByteString -> Response
-- lazy-bytestring = responseLBS