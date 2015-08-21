{-# LANGUAGE CPP                       #-}
{-# LANGUAGE DeriveDataTypeable        #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE FlexibleInstances         #-}
{-# LANGUAGE FunctionalDependencies    #-}
{-# LANGUAGE MultiParamTypeClasses     #-}
{-# LANGUAGE RankNTypes                #-}
{-# LANGUAGE RecordWildCards           #-}
{-# LANGUAGE TypeFamilies              #-}
{-# LANGUAGE AllowAmbiguousTypes       #-}

{-# OPTIONS_GHC -fno-warn-duplicate-exports #-}

module Plots.Types.Ribbon
  (  -- * GRibbonPlot plot
     GRibbonPlot
  , _RibbonPlot

    -- * Ribbon plot
  , RibbonPlot
  , mkRibbonPlotOf
  , mkRibbonPlot

    -- * Helper functions
  , createBarData
  , zeroY

    -- * Lenses
  , strokeEdge

  --  , BarPlot
  --  , mkBarPlotOf
  --  , mkBarPlot
  --  , createbardata

    -- * Ribbon plot
  , ribbonPlot
  , ribbonPlot'
  , ribbonPlotL
  
    -- * Fold variation ribbon plot
  , ribbonPlotOf
  , ribbonPlotOf'
  , ribbonPlotLOf

    -- * Area plot
  , makeribbon
  , makearea
  , makearea'
  , makeareagroup'

    -- * Single barplot
  , barPlot
  , barPlot'
  , barPlotL

    -- * Barplot normal
  , barPlotNormal
  , barPlotNormalC
  , barPlotNormalCL
  , barPlotNormalMulti
  , barPlotNormalMultiC

    -- * Barplot stacked
  , barPlotStacked
  , barPlotStackedC
  , barPlotStackedCL
  , barPlotStackedMultiC

    -- * Barplot split
  , barPlotSplit
  , barPlotSplitC
  , barPlotSplitCL
  , barPlotSplitMultiC

    -- * Barplot ratio
  , barPlotRatio
  , barPlotRatioC
  , barPlotRatioCL
  , barPlotRatioMultiC
  ) where

import           Control.Lens                    hiding (lmap, none, transform,
                                                  ( # ))
import           Control.Monad.State.Lazy

import qualified Data.Foldable                   as F
import           Data.Typeable
import           Data.List
import           Data.Function

import           Diagrams.Prelude
import           Diagrams.Coordinates.Isomorphic

import           Plots.Themes
import           Plots.Types
import           Plots.API
import           Plots.Axis

------------------------------------------------------------------------
-- GPoints plot
------------------------------------------------------------------------

data GRibbonPlot v n a = forall s. GRibbonPlot
  { sData :: s
  , sFold :: Fold s a
  , sPos  :: a -> Point v n
  , sLine :: Bool
  } deriving Typeable

type instance V (GRibbonPlot v n a) = v
type instance N (GRibbonPlot v n a) = n

instance (Metric v, OrderedField n) => Enveloped (GRibbonPlot v n a) where
  getEnvelope GRibbonPlot {..} = foldMapOf (sFold . to sPos) getEnvelope sData

instance (Typeable a, Typeable b, TypeableFloat n, Renderable (Path V2 n) b)
    => Plotable (GRibbonPlot V2 n a) b where
  renderPlotable s GRibbonPlot {..} pp =
      fromVertices ps
        # mapLoc closeLine
        # stroke
        # lw none
        # applyBarStyle pp
        # transform t

   <> if sLine
        then fromVertices ps
               # mapLoc closeLine
               # stroke
               # transform t
               # applyLineStyle pp
        else mempty
    where
      ps = toListOf (sFold . to sPos . to (logPoint ls)) sData
      t  = s ^. specTrans
      ls = s ^. specScale

  defLegendPic GRibbonPlot {..} pp
      = square 5 # applyBarStyle pp

_RibbonPlot :: (Plotable (RibbonPlot v n) b, Typeable b)
             => Prism' (Plot b v n) (RibbonPlot v n)
_RibbonPlot = _Plot

------------------------------------------------------------------------
-- Ribbon Plot
------------------------------------------------------------------------

type RibbonPlot v n = GRibbonPlot v n (Point v n)

-- | Make a line plot.
mkRibbonPlot :: (PointLike v n p, F.Foldable f, Num n)
              => f p -> RibbonPlot v n
mkRibbonPlot = mkRibbonPlotOf folded

-- | Make a line plot using the given fold.
mkRibbonPlotOf :: (PointLike v n p, Num n)
                => Fold s p -> s -> RibbonPlot v n
mkRibbonPlotOf f a = GRibbonPlot
  { sData = a
  , sFold = f . unpointLike
  , sPos  = id
  , sLine = True
  }

------------------------------------------------------------------------
-- Helper functions 
------------------------------------------------------------------------

zeroY :: [(Double, Double)] -> [(Double, Double)]
zeroY xs = [(a,0) | (a,_) <- xs]

createBarData (x, y) w = [(xmax, y),(xmin, y),(xmin, 0),(xmax, 0)]
        where xmax =  x + (w/2)
              xmin =  x - (w/2)

------------------------------------------------------------------------
-- Ribbon lenses
------------------------------------------------------------------------

class HasRibbon a v n d | a -> v n, a -> d where
  ribbon :: Lens' a (GRibbonPlot v n d)

  strokeEdge :: Lens' a Bool
  strokeEdge = ribbon . lens sLine (\s b -> (s {sLine = b}))

instance HasRibbon (GRibbonPlot v n d) v n d where
  ribbon = id

instance HasRibbon (PropertiedPlot (GRibbonPlot v n d) b) v n d where
  ribbon = _pp


-- type BarPlot v n = GRibbonPlot v n (Point v n)

-- mkBarPlot = mkBarPlotOf folded

-- mkBarPlotOf :: (PointLike v n p, Num n)
--                => Fold [(Double, Double)] p -> (Double, Double) -> Double -> BarPlot v n
-- mkBarPlotOf f bdata width = GRibbonPlot
--  { sData = a
--  , sFold = f . unpointLike
--  , sPos  = id
--  , sLine = True
--  }  where a = createbardata bdata width

-- createbardata (x, y) w = [(xmax, y),(xmin, y),(xmin, 0),(xmax, 0)]
--        where xmax =  x + (w/2)
--              xmin =  x - (w/2)

------------------------------------------------------------------------
-- Ribbon
------------------------------------------------------------------------

ribbonPlot
  :: (v ~ BaseSpace c,
      PointLike v n p,
      MonadState (Axis b c n) m,
      Plotable (RibbonPlot v n) b,
      F.Foldable f)
  => f p -> m ()
ribbonPlot a = addPlotable (mkRibbonPlot a)

ribbonPlot'
  :: (v ~ BaseSpace c,
      PointLike v n p,
      MonadState (Axis b c n) m,
      Plotable (RibbonPlot v n) b,
      F.Foldable f)
  => f p -> PlotState (RibbonPlot v n) b -> m ()
ribbonPlot' d = addPlotable' (mkRibbonPlot d)

ribbonPlotL
  :: (v ~ BaseSpace c,
      PointLike v n p,
      MonadState (Axis b c n) m,
      Plotable (RibbonPlot v n) b,
      F.Foldable f)
  => String -> f p -> m ()
ribbonPlotL l d = addPlotableL l (mkRibbonPlot d)

-- Fold variants

ribbonPlotOf
  :: (v ~ BaseSpace c,
      PointLike v n p,
      MonadState (Axis b c n) m,
      Plotable (RibbonPlot v n) b)
  => Fold s p -> s -> m ()
ribbonPlotOf f s = addPlotable (mkRibbonPlotOf f s)

ribbonPlotOf'
  :: (v ~ BaseSpace c,
      PointLike v n p,
      MonadState (Axis b c n) m,
      Plotable (RibbonPlot v n) b)
  => Fold s p -> s -> PlotState (RibbonPlot v n) b -> m ()
ribbonPlotOf' f s = addPlotable' (mkRibbonPlotOf f s)

ribbonPlotLOf
  :: (v ~ BaseSpace c,
      PointLike v n p,
      MonadState (Axis b c n) m,
      Plotable (RibbonPlot v n) b)
  => String -> Fold s p -> s -> m ()
ribbonPlotLOf l f s = addPlotableL l (mkRibbonPlotOf f s)

------------------------------------------------------------------------
-- Area
------------------------------------------------------------------------

makeribbon :: (RealFloat b, Typeable b, Typeable b1, Renderable (Path V2 b) b1,
               MonadState (Axis b1 c b) m, BaseSpace c ~ V2) =>
              [b] -> [b] -> [b] -> Colour Double -> m ()
makeribbon x1s x2s ys colour = ribbonPlot' ((zip x1s ys) ++ reverse (zip x2s ys)) $ do
                                 addLegendEntry "ribbon test"
                                 plotColor .= colour

makearea :: (Typeable b, Renderable (Path V2 Double) b,
             MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
            [Double] -> [Double] -> Colour Double -> m ()
makearea xs ys colour = ribbonPlot' ((zip xs ys) ++ reverse (zeroY (zip xs ys))) $ do
                                 addLegendEntry "ribbon test"
                                 plotColor .= colour

makearea' :: (Typeable b, Renderable (Path V2 Double) b,
              MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
             [(Double, Double)] -> String -> m ()
makearea' sd string = ribbonPlot' (sd ++ reverse (zeroY sd)) $ do
                                 addLegendEntry string

makeareagroup' :: (Typeable b, Renderable (Path V2 Double) b,
                   MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                  m ([(Double, Double)], String) -> m ()
makeareagroup' xs  = do x <- xs
                        makearea' (fst x) (snd x)

------------------------------------------------------------------------
-- Bar
------------------------------------------------------------------------

barPlot :: (Typeable b, Renderable (Path V2 Double) b,
             MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
            (Double,Double) -> Double -> m ()
barPlot x w = ribbonPlot (createBarData x w)

barPlot' :: (Typeable b, Renderable (Path V2 Double) b,
             MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
            (Double,Double) -> Double -> PlotState (RibbonPlot V2 Double) b -> m ()
barPlot' x w = ribbonPlot' (createBarData x w)

barPlotC :: (Typeable b, Renderable (Path V2 Double) b,
             MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
            (Double,Double) -> Double -> Colour Double -> m ()
barPlotC x w colour = ribbonPlot' (createBarData x w) $ do
                                plotColor .= colour

barPlotL :: (Typeable b, Renderable (Path V2 Double) b,
             MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
            (Double,Double) -> Double -> String -> Colour Double -> m ()
barPlotL x w string colour = ribbonPlot' (createBarData x w) $ do
                                plotColor .= colour
                                addLegendEntry string

------------------------------------------------------------------------
-- Normal Bar
------------------------------------------------------------------------
barPlotNormal :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                 Int -> [Double] -> Double -> m ()
barPlotNormal y xs w = F.for_ xs $ \x -> barPlot ((fromIntegral y), x) w


barPlotNormalC :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                 Int -> [Double] -> [Colour Double]-> Double -> m ()
barPlotNormalC y xs cs w = F.for_ (sortBy (compare `on` fst)(zip xs cs)) $ \x -> barPlotC ((fromIntegral y), fst x) w (snd x)


barPlotNormalCL :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                 Int -> [Double] -> [Colour Double] -> [String]-> Double -> m ()
barPlotNormalCL y xs cs ls w = F.for_ (sortBy (compare `on` fstof3)(zip3 xs cs ls)) $ \x -> barPlotL ((fromIntegral y), fstof3 x) w (trdof3 x) (sndof3 x)

fstof3 (a, _, _) = a
sndof3 (_, a, _) = a
trdof3 (_, _, a) = a

barPlotNormalMulti :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                  [[Double]] -> Double -> m ()
barPlotNormalMulti xs w = F.for_ [1 .. length xs] $ \x -> barPlotNormal x (xs!!(x-1)) w

barPlotNormalMultiC :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                  [[Double]] -> [Colour Double] -> [String] -> Double -> m ()
barPlotNormalMultiC xs colormap names w = do
                                          barPlotNormalCL 1 (xs!!0) colormap names w
                                          F.for_ [2 .. length xs] $ \x -> barPlotNormalC x (xs!!(x-1)) colormap w

------------------------------------------------------------------------
-- Stacked Bar
------------------------------------------------------------------------
barPlotStacked :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                 Int -> [Double] -> Double -> m ()
barPlotStacked y xs w = F.for_ (additive xs) $ \x -> barPlot ((fromIntegral y), x) w

additive :: [Double] -> [Double]
additive [] = []
additive (x:[]) = [x]
additive (x:xs) = x:(additive (addtofst x xs))

addtofst :: Double -> [Double] -> [Double]
addtofst a (x:xs) = (a+x):xs

barPlotStackedC :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                 Int -> [Double] -> [Colour Double]-> Double -> m ()
barPlotStackedC y xs cs w = F.for_ (sortBy (compare `on` fst)(zip (additive xs) cs)) $ \x -> barPlotC ((fromIntegral y), fst x) w (snd x)

barPlotStackedCL :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                 Int -> [Double] -> [Colour Double]
                     -> [String] -> Double -> m ()
barPlotStackedCL y xs cs ls w = F.for_ (sortBy (compare `on` fstof3)(zip3 (additive xs) cs ls)) $ \x -> barPlotL ((fromIntegral y), fstof3 x) w (trdof3 x) (sndof3 x)

barPlotStackedMultiC :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                  [[Double]] -> [Colour Double]-> [String] -> Double -> m ()
barPlotStackedMultiC xs colormap names w = do
                                          barPlotStackedCL 1 (xs!!0) colormap names w
                                          F.for_ [2 .. length xs] $ \x -> barPlotStackedC x (xs!!(x-1)) colormap w

------------------------------------------------------------------------
-- Split Bar
------------------------------------------------------------------------
barPlotSplit :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                 Int -> [Double] -> Double -> m ()
barPlotSplit y xs w = F.for_ (zip (createsplitdata y len w) xs) $ \x -> barPlot x w1
                      where w1 = w/fromIntegral len
                            len = length xs

createsplitdata :: Int -> Int -> Double -> [Double]
createsplitdata y len w =  [b, b+w1 .. (a-w1)]
                           where y1 = fromIntegral y
                                 w1 = w/fromIntegral len
                                 a  = y1+(w/2)+ (w1/2)
                                 b  = y1-(w/2)+ (w1/2)

barPlotSplitC :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                 Int -> [Double] -> [Colour Double]-> Double -> m ()
barPlotSplitC y xs cs w = F.for_ (zip (zip (createsplitdata y len w) xs) cs) $ \x -> barPlotC (fst x) w1 (snd x)
                         where w1  = w/fromIntegral len
                               len = length xs

barPlotSplitCL :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                 Int -> [Double] -> [Colour Double]
                     -> [String] -> Double -> m ()
barPlotSplitCL y xs cs ls w = F.for_ (zip3 (zip (createsplitdata y len w) xs) cs ls) $ \x -> barPlotL (fstof3 x) w1 (trdof3 x) (sndof3 x)
                             where w1  = w/fromIntegral len
                                   len = length xs

barPlotSplitMultiC :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                  [[Double]] -> [Colour Double]-> [String] -> Double -> m ()
barPlotSplitMultiC xs colormap names w = do
                                         barPlotSplitCL 1 (xs!!0) colormap names w
                                         F.for_ [2 .. length xs] $ \x -> barPlotSplitC x (xs!!(x-1)) colormap w
------------------------------------------------------------------------
-- Ratio Bar
------------------------------------------------------------------------
barPlotRatio :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                 Int -> [Double] -> Double -> m ()
barPlotRatio t xs w = do
                      barPlotStacked t [ x/tot | x <- xs] w
                      where tot = sum xs

barPlotRatioC :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                 Int -> [Double] -> [Colour Double] -> Double -> m ()
barPlotRatioC t xs colormap w = do
                                barPlotStackedC t [x/tot | x <- xs] colormap w
                                where tot = sum xs

barPlotRatioCL :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                 Int -> [Double] -> [Colour Double]
                     -> [String]-> Double -> m ()
barPlotRatioCL t xs colormap names w = do
                                       barPlotStackedCL t [x/tot | x <- xs] colormap names w
                                       where tot = sum xs

barPlotRatioMultiC :: (Typeable b, Renderable (Path V2 Double) b,
                  MonadState (Axis b c Double) m, BaseSpace c ~ V2) =>
                  [[Double]] -> [Colour Double] -> [String] -> Double -> m ()
barPlotRatioMultiC xs colormap names w = do
                                         barPlotRatioCL 1 (xs!!0) colormap names w
                                         F.for_ [2 .. length xs] $ \x -> barPlotRatioC x (xs!!(x-1)) colormap w
