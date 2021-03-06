{-|
Module      : Control.Monad.Bayes.Weighted
Description : Probability monad accumulating the likelihood
Copyright   : (c) Adam Scibior, 2016
License     : MIT
Maintainer  : ams240@cam.ac.uk
Stability   : experimental
Portability : GHC

-}

module Control.Monad.Bayes.Weighted (
    Weighted,
    withWeight,
    runWeighted,
    extractWeight,
    prior,
    flatten,
    applyWeight,
    hoist,
                  ) where

import Control.Monad.Trans
import Control.Monad.Trans.State
import Control.Monad.Fix

import Numeric.Log
import Control.Monad.Bayes.Class

-- | Executes the program using the prior distribution, while accumulating likelihood.
newtype Weighted m a = Weighted (StateT (Log Double) m a)
    --StateT is more efficient than WriterT
    deriving(Functor, Applicative, Monad, MonadIO, MonadTrans, MonadSample, MonadFix)

instance Monad m => MonadCond (Weighted m) where
  score w = Weighted (modify (* w))

instance MonadSample m => MonadInfer (Weighted m)

-- | Obtain an explicit value of the likelihood for a given value.
runWeighted :: (Functor m) => Weighted m a -> m (a, Log Double)
runWeighted (Weighted m) = runStateT m 1

-- | Compute the weight and discard the sample.
extractWeight :: Functor m => Weighted m a -> m (Log Double)
extractWeight m = snd <$> runWeighted m

-- | Embed a random variable with explicitly given likelihood.
--
-- > runWeighted . withWeight = id
withWeight :: (Monad m) => m (a, Log Double) -> Weighted m a
withWeight m = Weighted $ do
  (x,w) <- lift m
  modify (* w)
  return x

-- | Discard the weight.
-- This operation introduces bias.
prior :: (Functor m) => Weighted m a -> m a
prior = fmap fst . runWeighted

-- | Combine weights from two different levels.
flatten :: Monad m => Weighted (Weighted m) a -> Weighted m a
flatten m = withWeight $ (\((x,p),q) -> (x, p*q)) <$> runWeighted (runWeighted m)

-- | Use the weight as a factor in the transformed monad.
applyWeight :: MonadCond m => Weighted m a -> m a
applyWeight m = do
  (x, w) <- runWeighted m
  factor w
  return x

-- | Apply a transformation to the transformed monad.
hoist :: (forall x. m x -> n x) -> Weighted m a -> Weighted n a
hoist t (Weighted m) = Weighted $ mapStateT t m
