#ifndef PR_DECISION_MQH
#define PR_DECISION_MQH

#include "..\Contract\PR_Types.mqh"

#define PR_DIRECTION_MIN_NET_ATR 0.25
#define PR_DIRECTION_MIN_SLOPE_SPAN_ATR 0.15

#define PR_QUALITY_PASS_NET_ATR 1.00
#define PR_QUALITY_FAIL_NET_ATR 0.50
#define PR_QUALITY_PASS_EFFICIENCY 0.60
#define PR_QUALITY_FAIL_EFFICIENCY 0.35
#define PR_QUALITY_PASS_BODY_ALIGNMENT 0.60
#define PR_QUALITY_FAIL_BODY_ALIGNMENT 0.45
#define PR_QUALITY_PASS_PULLBACK_RATIO 0.50
#define PR_QUALITY_FAIL_PULLBACK_RATIO 0.80

string PR_DetermineMarketDirection(PR_FeatureVector &features)
  {
   if(!features.valid ||
      features.netMoveAtr < PR_DIRECTION_MIN_NET_ATR ||
      features.slopeSpanAtr < PR_DIRECTION_MIN_SLOPE_SPAN_ATR)
      return PR_DIRECTION_UNKNOWN;
   if(features.signedNetMove > 0.0 && features.regressionSlope > 0.0)
      return PR_DIRECTION_UP;
   if(features.signedNetMove < 0.0 && features.regressionSlope < 0.0)
      return PR_DIRECTION_DOWN;
   return PR_DIRECTION_UNKNOWN;
  }

bool PR_EvaluateDirectionAgreement(string caseType,
                                   string lineDirection,
                                   PR_FeatureVector &features,
                                   PR_AnalysisResult &result)
  {
   result.declaredDirection = PR_CaseTypeDirection(caseType);
   result.lineDirection = lineDirection;
   result.marketDirection = PR_DetermineMarketDirection(features);
   if(!PR_IsDirectionalValue(result.lineDirection))
     {
      result.directionAgreement = PR_AGREEMENT_LINE_AMBIGUOUS;
      result.statusCode = PR_ANALYSIS_STATUS_DIRECTION_REJECTED;
      result.reasonCode = PR_ANALYSIS_REASON_LINE_AMBIGUOUS;
      return false;
     }
   if(result.declaredDirection != result.lineDirection)
     {
      result.directionAgreement = PR_AGREEMENT_TYPE_LINE_MISMATCH;
      result.statusCode = PR_ANALYSIS_STATUS_DIRECTION_REJECTED;
      result.reasonCode = PR_ANALYSIS_REASON_TYPE_LINE_MISMATCH;
      return false;
     }
   if(!PR_IsDirectionalValue(result.marketDirection))
     {
      result.directionAgreement = PR_AGREEMENT_MARKET_AMBIGUOUS;
      result.statusCode = PR_ANALYSIS_STATUS_DIRECTION_REJECTED;
      result.reasonCode = PR_ANALYSIS_REASON_MARKET_AMBIGUOUS;
      return false;
     }
   if(result.declaredDirection != result.marketDirection)
     {
      result.directionAgreement = PR_AGREEMENT_TYPE_MARKET_MISMATCH;
      result.statusCode = PR_ANALYSIS_STATUS_DIRECTION_REJECTED;
      result.reasonCode = PR_ANALYSIS_REASON_TYPE_MARKET_MISMATCH;
      return false;
     }
   result.directionAgreement = PR_AGREEMENT_PASS;
   return true;
  }

void PR_AddQualityGateResult(bool passesStrict,
                             bool failsClearly,
                             int gate,
                             PR_AnalysisResult &result)
  {
   if(!passesStrict) result.qualityReviewMask |= gate;
   if(failsClearly) result.qualityFailureMask |= gate;
  }

string PR_PrimaryQualityFailureReason(int failureMask)
  {
   if((failureMask & PR_QUALITY_GATE_NET_MOVE) != 0)
      return PR_ANALYSIS_REASON_MOVE_TOO_SMALL;
   if((failureMask & PR_QUALITY_GATE_EFFICIENCY) != 0)
      return PR_ANALYSIS_REASON_LOW_EFFICIENCY;
   if((failureMask & PR_QUALITY_GATE_BODY_ALIGNMENT) != 0)
      return PR_ANALYSIS_REASON_BODY_MISALIGNED;
   if((failureMask & PR_QUALITY_GATE_PULLBACK) != 0)
      return PR_ANALYSIS_REASON_PULLBACK_EXCESSIVE;
   return PR_ANALYSIS_REASON_QUALITY_REVIEW;
  }

bool PR_EvaluateReleaseQuality(PR_FeatureVector &features,
                               PR_AnalysisResult &result)
  {
   result.qualityReviewMask = 0;
   result.qualityFailureMask = 0;
   if(result.marketDirection == PR_DIRECTION_UP)
     {
      result.selectedBodyAlignment = features.bodyAlignmentUp;
      result.selectedPullbackRatio = features.pullbackRatioUp;
     }
   else
     {
      result.selectedBodyAlignment = features.bodyAlignmentDown;
      result.selectedPullbackRatio = features.pullbackRatioDown;
     }

   PR_AddQualityGateResult(features.netMoveAtr >= PR_QUALITY_PASS_NET_ATR,
                           features.netMoveAtr < PR_QUALITY_FAIL_NET_ATR,
                           PR_QUALITY_GATE_NET_MOVE, result);
   PR_AddQualityGateResult(features.efficiency >= PR_QUALITY_PASS_EFFICIENCY,
                           features.efficiency < PR_QUALITY_FAIL_EFFICIENCY,
                           PR_QUALITY_GATE_EFFICIENCY, result);
   PR_AddQualityGateResult(
      result.selectedBodyAlignment >= PR_QUALITY_PASS_BODY_ALIGNMENT,
      result.selectedBodyAlignment < PR_QUALITY_FAIL_BODY_ALIGNMENT,
      PR_QUALITY_GATE_BODY_ALIGNMENT, result);
   PR_AddQualityGateResult(
      result.selectedPullbackRatio <= PR_QUALITY_PASS_PULLBACK_RATIO,
      result.selectedPullbackRatio > PR_QUALITY_FAIL_PULLBACK_RATIO,
      PR_QUALITY_GATE_PULLBACK, result);

   if(result.qualityFailureMask != 0)
     {
      result.qualityStatus = PR_QUALITY_FAIL;
      result.statusCode = PR_ANALYSIS_STATUS_QUALITY_REJECTED;
      result.reasonCode = PR_PrimaryQualityFailureReason(result.qualityFailureMask);
      return false;
     }
   if(result.qualityReviewMask != 0)
     {
      result.qualityStatus = PR_QUALITY_REVIEW;
      result.statusCode = PR_ANALYSIS_STATUS_REVIEW;
      result.reasonCode = PR_ANALYSIS_REASON_QUALITY_REVIEW;
      return false;
     }
   result.qualityStatus = PR_QUALITY_PASS;
   result.statusCode = PR_ANALYSIS_STATUS_QUALIFIED;
   result.reasonCode = PR_ANALYSIS_REASON_QUALIFIED;
   result.qualified = true;
   return true;
  }

bool PR_EvaluatePureRelease(string caseType,
                            string lineDirection,
                            PR_FeatureVector &features,
                            PR_AnalysisResult &result)
  {
   result.qualified = false;
   result.qualityStatus = PR_QUALITY_NOT_EVALUATED;
   if(!PR_EvaluateDirectionAgreement(caseType, lineDirection, features, result))
      return false;
   return PR_EvaluateReleaseQuality(features, result);
  }

#endif
