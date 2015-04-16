{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE DeriveFunctor #-}

module Data.Trie.Pred where

import Data.List.NonEmpty
import Data.Bifunctor
import Control.Applicative


data PredTrie (t :: *) (p :: *) (c :: * -> *) a where
  -- ^ Literal lookups
  More :: t
       -> Maybe (c a)
       -> NonEmpty (PredTrie t p c a) -- should sort Pred lower than More
       -> PredTrie t p c a
  -- ^ Exhausively Unique
  Rest :: NonEmpty t
       -> c a
       -> PredTrie t p c a
  -- ^ Predicative
  Pred :: (p, t -> Maybe r)
       -> Maybe (r -> a)
       -> [PredTrie t p c (r -> a)]
       -> PredTrie t p c a
  Nil  :: PredTrie t p c a
  -- deriving (Functor)

-- | Rightward bias in that results are overwritten
merge :: Eq t => PredTrie t p c a -> PredTrie t p c a -> PredTrie t p c a
merge Nil y = y
merge x Nil = x
merge x@(More t mx xs) (More p my ys) =
  let
    xs' = toList xs
    ys' = toList ys
  in
  if t == p then More t mx $ fromList $ xs' `sortedUnion` ys'
            else x
merge xss@(Rest (t:|ts) x) yss@(More p my ys) =
  if t == p then case ts of
                   [] -> case my of
                           Nothing -> More p (Just x) ys
                           _       -> yss
                   _  -> More p my $ fmap (merge $ Rest (fromList ts) x) ys
            else xss
merge xss@(More t mx xs) yss@(Rest (p:|ps) y) =
  if t == p then case ps of
                   [] -> case mx of
                           Nothing -> More t (Just y) xs
                           _       -> yss
                   _  -> More t mx $ fmap (merge $ Rest (fromList ps) y) xs
            else xss
merge (Rest tss@(t:|ts) x) (Rest pss@(p:|ps) y)
  | tss == pss = Rest pss y
  | t == p = case (ts,ps) of
               ([],_) -> More t (Just x) $ fromList [Rest (fromList ps) y]
               (_,[]) -> More p (Just y) $ fromList [Rest (fromList ts) x]
merge (Rest (t:|ts) x) yss@(Pred (w,w') my ys) = yss
merge (Pred (q,q') mx xs) yss@(Rest (p:|ps) y) = yss
merge (Pred (q,q') mx xs) yss@(Pred (w,w') my ys) = yss
  -- | q == w = Pred (w,w') $ xs `sortedUnion` ys -- FACK unifying existentialzurp?


sortedUnion :: [PredTrie t p c a] -> [PredTrie t p c a] -> [PredTrie t p c a]
sortedUnion [] y = y
sortedUnion x [] = x
sortedUnion (x:xs) (y:ys) = case (x,y) of
  (Nil,Nil)               ->         xs `sortedUnion` ys -- aint need dem shitty Nils anywayzzzzirp
  (Rest _ _,Rest _ _)     -> x : y : xs `sortedUnion` ys
  (More _ _ _,More _ _ _) -> x : y : xs `sortedUnion` ys
  (Pred _ _ _,Pred _ _ _) -> xs `sortedUnion` ys ++ [x,y]
  (Pred _ _ _,_)          -> y : xs `sortedUnion` ys ++ [x]
  (_,Pred _ _ _)          -> x : xs `sortedUnion` ys ++ [y]



lookupLR :: (Eq t, Functor c) => [t] -> PredTrie t p c a -> Maybe (Either (c a) a)
lookupLR [] _ = Nothing
lookupLR (t:ts) x = case x of
  Nil -> Nothing
  (More t' mx xs) -> if t == t'
                       then
                         case ts of
                           [] -> Left <$> mx
                           _  -> (getFirst $ fmap (lookupLR ts) $ toList xs)
                       else Nothing
  (Rest ts' x) -> if (fromList (t:ts)) == ts'
                    then Just $ Left x
                    else Nothing
  (Pred (_,p) mx xs) -> case p t of
                          Nothing  -> Nothing
                          (Just r) -> case ts of
                            [] -> Right <$> ($ r) <$> mx
                            _  -> (bimap (($ r) <$>) ($ r)) <$> (getFirst $ fmap (lookupLR ts) xs)

  where
    getFirst :: [Maybe a] -> Maybe a
    getFirst []           = Nothing
    getFirst (Nothing:xs) = getFirst xs
    getFirst (Just x:_)   = Just x


areDisjoint :: (Eq t) =>
               PredTrie t p c a
            -> PredTrie t p c a
            -> Bool
areDisjoint (More t _ _) (More p _ _)
  | t == p = False
  | otherwise = True
areDisjoint (Rest (t:|_) _) (Rest (p:|_) _)
  | t == p = False
  | otherwise = True
areDisjoint _ _ = True
