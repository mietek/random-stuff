{-# LANGUAGE GADTs, DataKinds, TypeFamilies, TemplateHaskell, TypeOperators #-}

import Data.Functor
import Data.Singletons.TH
import Data.Singletons.Prelude

$(singletons [d| data Nat = Z | S Nat |])

data HomoFree n f a where
    Pure :: a -> HomoFree Z f a
    Free :: f (HomoFree n f a) -> HomoFree (S n) f a

mapFree :: Functor f => (a -> b) -> HomoFree n f a -> HomoFree n f b
mapFree f (Pure  x) = Pure $ f x
mapFree f (Free fx) = Free $ mapFree f <$> fx

type family IterN n f a where
  IterN  Z    f a = a
  IterN (S n) f a = f (IterN n f a)

toFree :: (Functor f, SingI n) => IterN n f a -> HomoFree n f a
toFree = go sing where
    go :: Functor f => Sing n -> IterN n f a -> HomoFree n f a
    go  SZ    x  = Pure x
    go (SS n) fx = Free $ go n <$> fx

fromFree :: Functor f => HomoFree n f a -> IterN n f a
fromFree (Pure  x) = x
fromFree (Free fx) = fromFree <$> fx

lowerFree :: (Functor f, SingI n) => HomoFree (S n) f a -> HomoFree n f (f a)
lowerFree = go sing where
    go :: Functor f => Sing n -> HomoFree (S n) f a -> HomoFree n f (f a)
    go  SZ    (Free fx) = Pure $ fromFree <$> fx
    go (SS n) (Free fx) = Free $ go n <$> fx

type family n :+ m :: Nat where
  Z     :+ m = m
  (S n) :+ m = S (n :+ m)

nmapFree :: Functor f
         => Sing n
         -> (HomoFree m f a -> HomoFree p f b)
         -> HomoFree (n :+ m) f a
         -> HomoFree (n :+ p) f b
nmapFree  SZ    f  h        = f h
nmapFree (SS n) f (Free fx) = Free $ nmapFree n f <$> fx

sumFree :: SingI n => HomoFree (S n) [] Int -> HomoFree n [] Int
sumFree = mapFree sum . lowerFree

xs = [[[1, 2, 3], [4, 5, 6]], [[7, 8, 9]]]

main = do
    print $ fromFree . mapFree (+ 1)                  $ (toFree xs :: HomoFree (S (S (S Z))) []  Int ) -- [[[2,3,4],[5,6,7]],[[8,9,10]]]
    print $ fromFree . mapFree  sum                   $ (toFree xs :: HomoFree (S (S  Z   )) [] [Int]) -- [[6,15],[24]]
    print $ fromFree . sumFree                        $ (toFree xs :: HomoFree (S (S (S Z))) []  Int ) -- [[6,15],[24]]
    print $ fromFree . nmapFree (SS (SS SZ)) sumFree  $ (toFree xs :: HomoFree (S (S (S Z))) []  Int ) -- [[6,15],[24]]