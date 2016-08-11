{-# LANGUAGE
  GADTs,
  StandaloneDeriving
 #-}

module Control.Monad.Bayes.Primitive where

import Data.Typeable
import Numeric.SpecFunctions
import Data.Number.LogFloat (LogFloat, logFloat, logToLogFloat)

-- | Primitive distributions for which we can compute density.
-- Here the weights of Categorical must be normalized.
data Primitive a where
    Discrete :: (Typeable a, Integral a)         => [LogFloat] -> Primitive a
    Normal   :: (Typeable a, Real a, Floating a) => a -> a -> Primitive a
    Gamma    :: (Typeable a, Real a, Floating a) => a -> a -> Primitive a
    Beta     :: (Typeable a, Real a, Floating a) => a -> a -> Primitive a
    Uniform  :: (Typeable a, Real a, Floating a) => a -> a -> Primitive a

deriving instance Eq   (Primitive a)
instance Show (Primitive a) where
  show (Discrete xs) = "Discrete " ++ show xs
  show (Normal  m s) =
    "Normal "  ++ show (toRational m) ++ " " ++ show (toRational s)
  show (Gamma   a b) =
    "Gamma "   ++ show (toRational a) ++ " " ++ show (toRational b)
  show (Beta    a b) =
    "Beta "    ++ show (toRational a) ++ " " ++ show (toRational b)
  show (Uniform a b) =
    "Uniform " ++ show (toRational a) ++ " " ++ show (toRational b)

-- | The probability density function.
pdf :: Primitive a -> a -> LogFloat
pdf (Discrete d) = \i -> case lookup i (zip [0..] d) of
                              Just p -> p
                              Nothing -> logFloat 0
pdf (Normal  m s) = normalPdf m s
pdf (Gamma   a b) = gammaPdf a b
pdf (Beta    a b) = betaPdf a b
pdf (Uniform a b) = uniformPdf a b

-- | PDF of a continuous uniform distribution on an interval
uniformPdf :: (Real a) => a -> a -> a -> LogFloat
uniformPdf a b x =
  if a <= x && x <= b then
    logFloat $ 1 / (realToFrac b - realToFrac a)
  else
    0

-- | PDF of normal distribution parameterized by mean and stddev.
normalPdf :: (Real a) => a -> a -> a -> LogFloat
normalPdf mu sigma x =
  logToLogFloat $ (-0.5 * log (2 * pi * sigma2)) +
  ((-((realToFrac x) - (realToFrac mu))^2) / (2 * sigma2))
  where
    sigma2 = realToFrac sigma^2

-- | PDF of gamma distribution parameterized by shape and rate.
gammaPdf :: (Real a) => a -> a -> a -> LogFloat
gammaPdf a b x
  | x > 0     = let (a',b',x') = (realToFrac a, realToFrac b, realToFrac x) in
    logToLogFloat $ a' * log b' - logGamma a' + (a'-1) * log x' - b' * x'
  | otherwise = logFloat 0

-- | PDF of beta distribution.
betaPdf :: (Real a) => a -> a -> a -> LogFloat
betaPdf a b x
   | a <= 0 || b <= 0 = error "Negative parameter to Beta"
   | x <= 0 = logFloat 0
   | x >= 1 = logFloat 0
   | otherwise = let (a',b',x') = (realToFrac a, realToFrac b, realToFrac x) in
     logToLogFloat $ (a'-1)*log x' + (b'-1)*log (1-x') - logBeta a' b'
