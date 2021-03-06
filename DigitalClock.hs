{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE QuasiQuotes                #-}
{-# LANGUAGE ScopedTypeVariables        #-}
-- | This module implements a simple digital stopwatch.
module Main where

import           Prelude                 () -- no implicit Prelude!
import           Control.Applicative
import           Control.Arrow
import qualified Data.List as List
import           Data.Traversable

import           Language.Literals.Binary
import           CLaSH.Prelude
import           CLaSH.Sized.Vector
import           CLaSH.Signal
import           CLaSH.Signal.Explicit
import           CLaSH.Signal.Bundle

type Word17 = Unsigned 17

-- | Gives a signal once every second, for the duration of a single System Clock cycle.
everySecond :: Signal Bool -- ^ trigger every one second
everySecond  = counter' fpgaFrequency
-- $ (2 :: Word17) ^ (15 :: Word17) * (1000 :: Word17) -- or Signed 16?

-- | FPGA frequency for my Papillio 250K is 32.768MHz.
-- 
-- Here, I am using 32 bit arithmetic to count second,
-- instead of splitting it into smaller counters and connecting them.
fpgaFrequency :: Unsigned 27
fpgaFrequency  = 32768000 -- real 32MHz

-- | Counter that cycles every time it gets a given @True@ signal at the input,
-- and itself gives the current count, and also the @True@ signal only
-- when the limit is reached.
counter      :: (Num s, Eq s) =>
                 s            -> -- ^ number of clock cycles before overflow and reset
                 Signal Bool  -> -- ^ input trigger for the clock cycle (not the clock domain!)
                 Unbundled (s, Bool)
counter limit = fsm <^> 0
  where
    fsm st False                = (st,   (st,   False))
    fsm st True | limit == st+1 = (0,    (0,    True ))
    fsm st True                 = (st+1, (st+1, False))

-- | Simple counter without any inputs.
-- Gives true signal only when the given limit is reached.
counter'      :: (Num s, Eq s) =>
                  s            -> -- ^ number of clock cycles before overflow and reset
                  Signal Bool
counter' limit = (fsm <^> 0) $ signal ()
  where
    fsm st () | limit == st = (0,    True)
              | otherwise   = (st+1, False)

-- | Given an input clock, this clock gives four digits of the clock
-- for minutes and seconds.
hourClock :: (Num a, Eq a) =>
              Signal (Vec 4 a)
hourClock = bundle (  secondsCounter
                   :> tenSecondsCounter
                   :> minutesCounter
                   :> tenMinutesCounter
                   :> Nil )
  where
    secondPulse                         = counter'   fpgaFrequency
    (secondsCounter,    tenSecondPulse) = counter 10 secondPulse
    (tenSecondsCounter, minutePulse   ) = counter 6  tenSecondPulse
    (minutesCounter,    tenMinutePulse) = counter 10 minutePulse
    (tenMinutesCounter, _hourPulse    ) = counter 6  tenMinutePulse
    -- (hoursCounter,      _             ) = counter 24 (hourPulse,      rst)

newtype BCDDigit = BCDDigit { bcdDigit :: Unsigned 4 }
  deriving (Eq, Ord, Enum, Bounded, Show, Num)

newtype SevenSegDigit = SevenSegDigit { ssDigit :: Unsigned 7 }
  deriving (Eq, Ord, Enum, Bounded, Show, Num)

-- | Encoding a BCD digit to seven segment display with active-low.
sevenSegmentDigit   :: BCDDigit -> SevenSegDigit
sevenSegmentDigit  0 = [b| 1000000 |]
sevenSegmentDigit  1 = [b| 1111001 |]
sevenSegmentDigit  2 = [b| 0100100 |]
sevenSegmentDigit  3 = [b| 0110000 |]
sevenSegmentDigit  4 = [b| 0011001 |]
sevenSegmentDigit  5 = [b| 0010010 |]
sevenSegmentDigit  6 = [b| 0000010 |]
sevenSegmentDigit  7 = [b| 1111000 |]
sevenSegmentDigit  8 = [b| 0000000 |]
sevenSegmentDigit  9 = [b| 0010000 |]
sevenSegmentDigit 10 = [b| 0001000 |] -- empty
sevenSegmentDigit 11 = [b| 0000011 |] -- empty
sevenSegmentDigit 12 = [b| 1000110 |] -- empty
sevenSegmentDigit 13 = [b| 1001110 |] -- empty
sevenSegmentDigit 14 = [b| 0000110 |] -- empty
sevenSegmentDigit 15 = [b| 0001110 |] -- empty

-- | 1kHz clock for changing seven segment anode without flicker
hz1000 :: Signal Bool
hz1000 = counter' 32768
-- ((2^15) :: Word17)

-- | Interface to seven segment display.
data SevenSegmentDisplay n = SevenSegmentDisplay {
                               anodeIndex   :: Unsigned n    -- ^ Anode index
                             , currentDigit :: SevenSegDigit -- ^ Seven segment signal for th current anode
                             }
 deriving (Show)

instance (KnownNat n) => Bundle (SevenSegmentDisplay n) where
  type Unbundled' t (SevenSegmentDisplay n) = (Signal' t (Unsigned n),
                                               Signal' t  SevenSegDigit)
  unbundle' _  s                                = (anodeIndex <$> s, currentDigit <$> s)
  bundle'   _ (anode,                    digit) = SevenSegmentDisplay <$> anode <*> digit


-- | Anode states for a given digit to display.
-- NOTE: Generic version seems to make compiler loop as of 0.5/0.5.2.
-- digitAnode i = 2^i
digitAnode  :: (KnownNat n) => Unsigned n -> Unsigned n
digitAnode 0 = [b|0111|]
digitAnode 1 = [b|1011|]
digitAnode 2 = [b|1101|]
digitAnode 3 = [b|1110|]

-- | Given an array of numbers and clock for changing anode state,
-- drives @SevenSegmentDisplay@ interface.
sevenSegmentDisplay :: KnownNat n              =>
                       Signal (Vec n BCDDigit) ->
                       Signal (SevenSegmentDisplay n)
sevenSegmentDisplay digits = bundle (digitAnode        <$> whichDigit  ,
                                     sevenSegmentDigit <$> currentDigit)
  where
    (whichDigit, _) = counter (myMaxIndex $ unbundle digits) hz1000
    rst             = signal False -- no resetting for now...
    currentDigit   :: Signal BCDDigit
    currentDigit    = (!!) <$> digits <*> whichDigit --(!!) <$> digits <*> whichDigit
    myMaxIndex     :: (KnownNat n) => Unbundled (Vec n a) -> Unsigned n
    myMaxIndex      = fromIntegral . (+1) . maxIndex

-- | Top entity to implement
topEntity ::  Signal (SevenSegmentDisplay 4)
topEntity  = sevenSegmentDisplay hourClock 

-- * Here are helpers for simulation.
-- | Takes every nth step of simulated signal.
takeEvery :: Int -> [a] -> [a]
takeEvery n = go
  where
    go []     = []
    go (b:bs) = b:go (List.drop (fromIntegral n) bs)

main :: IO ()
main = print $ takeEvery ((fromIntegral fpgaFrequency `div` 10)) $ sampleN (10*fromIntegral fpgaFrequency) topEntity 
