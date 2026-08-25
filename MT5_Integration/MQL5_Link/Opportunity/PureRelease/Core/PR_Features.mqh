#ifndef PR_FEATURES_MQH
#define PR_FEATURES_MQH

#include "..\Contract\PR_Types.mqh"

#define PR_FEATURE_EPSILON 0.000000000001

double PR_TrueRange(MqlRates &bar, double previousClose)
  {
   double highLow = bar.high - bar.low;
   double highPrevious = MathAbs(bar.high - previousClose);
   double lowPrevious = MathAbs(bar.low - previousClose);
   return MathMax(highLow, MathMax(highPrevious, lowPrevious));
  }

double PR_ComputePreReleaseATR(PR_MarketSnapshot &snapshot)
  {
   if(snapshot.contextBarCount != PR_ATR_CONTEXT_BAR_COUNT) return 0.0;
   double total = 0.0;
   for(int i = 1; i < snapshot.contextBarCount; i++)
      total += PR_TrueRange(snapshot.contextBars[i],
                            snapshot.contextBars[i - 1].close);
   return total / (snapshot.contextBarCount - 1);
  }

void PR_SortDoubles(double &values[])
  {
   for(int i = 1; i < ArraySize(values); i++)
     {
      double current = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > current)
        {
         values[j + 1] = values[j];
         j--;
        }
      values[j + 1] = current;
     }
  }

double PR_Median(double &values[])
  {
   int count = ArraySize(values);
   if(count <= 0) return 0.0;
   PR_SortDoubles(values);
   int middle = count / 2;
   if((count % 2) == 1) return values[middle];
   return (values[middle - 1] + values[middle]) * 0.5;
  }

bool PR_AreFeatureValuesValid(PR_FeatureVector &features)
  {
   return MathIsValidNumber(features.atrReference) &&
          MathIsValidNumber(features.signedNetMove) &&
          MathIsValidNumber(features.netMoveAtr) &&
          MathIsValidNumber(features.regressionSlope) &&
          MathIsValidNumber(features.slopeSpanAtr) &&
          MathIsValidNumber(features.efficiency) &&
          MathIsValidNumber(features.bodyAlignmentUp) &&
          MathIsValidNumber(features.bodyAlignmentDown) &&
          MathIsValidNumber(features.pullbackRatioUp) &&
          MathIsValidNumber(features.pullbackRatioDown) &&
          MathIsValidNumber(features.rangeExpansion) &&
          MathIsValidNumber(features.regressionR2);
  }

bool PR_ExtractFeatures(PR_MarketSnapshot &snapshot,
                        PR_FeatureVector &features)
  {
   PR_ResetFeatureVector(features);
   if(!snapshot.captureOK || snapshot.releaseBarCount < PR_MIN_RELEASE_BAR_COUNT)
     {
      features.reasonCode = PR_FEATURE_REASON_INVALID_VALUE;
      return false;
     }
   features.releaseBarCount = snapshot.releaseBarCount;
   features.atrReference = PR_ComputePreReleaseATR(snapshot);
   if(!MathIsValidNumber(features.atrReference) ||
      features.atrReference <= PR_FEATURE_EPSILON)
     {
      features.reasonCode = PR_FEATURE_REASON_INVALID_ATR;
      return false;
     }

   int count = snapshot.releaseBarCount;
   double startPrice = snapshot.releaseBars[0].open;
   double finalPrice = snapshot.releaseBars[count - 1].close;
   features.signedNetMove = finalPrice - startPrice;
   features.netMoveAtr = MathAbs(features.signedNetMove) / features.atrReference;

   features.pathLength = MathAbs(snapshot.releaseBars[0].close - startPrice);
   features.totalBody = 0.0;
   double upBody = 0.0;
   double downBody = 0.0;
   for(int i = 0; i < count; i++)
     {
      double body = snapshot.releaseBars[i].close - snapshot.releaseBars[i].open;
      features.totalBody += MathAbs(body);
      if(body > 0.0) upBody += body;
      else if(body < 0.0) downBody += -body;
      if(i > 0)
         features.pathLength += MathAbs(snapshot.releaseBars[i].close -
                                        snapshot.releaseBars[i - 1].close);
     }
   if(features.pathLength > PR_FEATURE_EPSILON)
      features.efficiency = MathAbs(features.signedNetMove) / features.pathLength;
   if(features.totalBody > PR_FEATURE_EPSILON)
     {
      features.bodyAlignmentUp = upBody / features.totalBody;
      features.bodyAlignmentDown = downBody / features.totalBody;
     }

   double runningHigh = startPrice;
   double runningLow = startPrice;
   for(int i = 0; i < count; i++)
     {
      double closePrice = snapshot.releaseBars[i].close;
      if(closePrice > runningHigh) runningHigh = closePrice;
      if(closePrice < runningLow) runningLow = closePrice;
      features.maxFavorableUp = MathMax(features.maxFavorableUp,
                                       runningHigh - startPrice);
      features.maxFavorableDown = MathMax(features.maxFavorableDown,
                                         startPrice - runningLow);
      features.maxPullbackUp = MathMax(features.maxPullbackUp,
                                      runningHigh - closePrice);
      features.maxPullbackDown = MathMax(features.maxPullbackDown,
                                        closePrice - runningLow);
     }
   if(features.maxFavorableUp > PR_FEATURE_EPSILON)
      features.pullbackRatioUp = features.maxPullbackUp / features.maxFavorableUp;
   if(features.maxFavorableDown > PR_FEATURE_EPSILON)
      features.pullbackRatioDown = features.maxPullbackDown / features.maxFavorableDown;

   double sumX = 0.0;
   double sumY = 0.0;
   for(int i = 0; i < count; i++)
     {
      double typicalPrice = (snapshot.releaseBars[i].high +
                             snapshot.releaseBars[i].low +
                             snapshot.releaseBars[i].close) / 3.0;
      sumX += i;
      sumY += typicalPrice;
     }
   double meanX = sumX / count;
   double meanY = sumY / count;
   double covariance = 0.0;
   double varianceX = 0.0;
   double varianceY = 0.0;
   for(int i = 0; i < count; i++)
     {
      double typicalPrice = (snapshot.releaseBars[i].high +
                             snapshot.releaseBars[i].low +
                             snapshot.releaseBars[i].close) / 3.0;
      double centeredX = i - meanX;
      double centeredY = typicalPrice - meanY;
      covariance += centeredX * centeredY;
      varianceX += centeredX * centeredX;
      varianceY += centeredY * centeredY;
     }
   if(varianceX > PR_FEATURE_EPSILON)
      features.regressionSlope = covariance / varianceX;
   features.slopeSpanAtr = MathAbs(features.regressionSlope) * (count - 1) /
                           features.atrReference;
   if(varianceX > PR_FEATURE_EPSILON && varianceY > PR_FEATURE_EPSILON)
      features.regressionR2 = covariance * covariance / (varianceX * varianceY);

   double releaseRanges[];
   if(ArrayResize(releaseRanges, count) != count)
     {
      features.reasonCode = PR_FEATURE_REASON_INVALID_VALUE;
      return false;
     }
   double previousClose = snapshot.contextBars[snapshot.contextBarCount - 1].close;
   for(int i = 0; i < count; i++)
     {
      releaseRanges[i] = PR_TrueRange(snapshot.releaseBars[i], previousClose);
      previousClose = snapshot.releaseBars[i].close;
     }
   features.rangeExpansion = PR_Median(releaseRanges) / features.atrReference;

   if(!PR_AreFeatureValuesValid(features))
     {
      features.reasonCode = PR_FEATURE_REASON_INVALID_VALUE;
      return false;
     }
   features.valid = true;
   features.reasonCode = PR_FEATURE_REASON_VALID;
   return true;
  }

#endif
