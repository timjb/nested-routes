{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE DeriveTraversable          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE StandaloneDeriving         #-}


module Web.Routes.Nested.FileExtListener.Types where

import qualified Data.Text            as T

import           Control.Applicative
import           Control.Monad.Trans
import           Control.Monad.Writer
import           Data.Foldable        hiding (elem)
import           Data.Map
import           Data.Monoid
import           Data.Traversable


data FileExt = Html
             | Json
             | Text
  deriving (Show, Eq, Ord)


toExt :: T.Text -> Maybe FileExt
toExt x | x `elem` htmls = Just Html
        | x `elem` jsons = Just Json
        | x `elem` texts = Just Text
        | otherwise      = Nothing
  where
    htmls = ["", ".htm", ".html"]
    jsons = [".json"]
    texts = [".txt"]

newtype FileExts a = FileExts { unFileExts :: Map FileExt a }
  deriving (Show, Eq, Functor, Traversable)

deriving instance Monoid      (FileExts a)
deriving instance Foldable     FileExts


newtype FileExtListenerT r m a =
  FileExtListenerT { runFileExtListenerT :: WriterT (FileExts r) m a }
    deriving (Functor)

deriving instance Applicative m => Applicative (FileExtListenerT r m)
deriving instance Monad m =>       Monad       (FileExtListenerT r m)
deriving instance MonadIO m =>     MonadIO     (FileExtListenerT r m)
deriving instance                  MonadTrans  (FileExtListenerT r)
