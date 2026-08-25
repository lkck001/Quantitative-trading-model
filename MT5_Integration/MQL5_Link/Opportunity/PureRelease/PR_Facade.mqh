#ifndef PR_FACADE_MQH
#define PR_FACADE_MQH

#include "Contract\PR_Types.mqh"
#include "Integration\PR_Adapter.mqh"
#include "Contract\PR_Contract.mqh"
#include "Integration\PR_MarketData.mqh"
#include "Core\PR_Features.mqh"
#include "Core\PR_Decision.mqh"

bool PR_PreflightChartWithState(long chartID,
                                string caseID,
                                string caseType,
                                string symbol,
                                ENUM_TIMEFRAMES timeframe,
                                string &reservedPrefixes[],
                                string representationID,
                                int structureCount,
                                bool keyBarActive,
                                string structureApplicability,
                                string keyBarApplicability,
                                PR_DraftSnapshot &snapshot,
                                PR_PreflightResult &result)
  {
   PR_ResetPreflightResult(result);
   PR_ResetDraftSnapshot(snapshot);
   if(!PR_IsPureReleaseCaseType(caseType))
     {
      result.statusCode = PR_STATUS_REPRESENTATION_MISMATCH;
      result.reasonCode = PR_REASON_REPRESENTATION;
      return false;
     }
   if(!PR_CaptureDraft(chartID, caseID, caseType, symbol, timeframe,
                       reservedPrefixes, snapshot))
     {
      result.statusCode = PR_STATUS_CAPTURE_FAILED;
      result.reasonCode = (StringLen(snapshot.captureErrorCode) > 0) ?
                          snapshot.captureErrorCode : PR_REASON_CAPTURE_FAILED;
      result.fingerprint = snapshot.fingerprint;
      return false;
     }
   snapshot.representationID = representationID;
   snapshot.structureCount = structureCount;
   snapshot.keyBarActive = keyBarActive;
   snapshot.structureApplicability = structureApplicability;
   snapshot.keyBarApplicability = keyBarApplicability;
   snapshot.fingerprint = PR_BuildDraftFingerprint(snapshot);
   return PR_ValidateContract(snapshot, result);
  }

bool PR_PreflightChart(long chartID,
                       string caseID,
                       string caseType,
                       string symbol,
                       ENUM_TIMEFRAMES timeframe,
                       string &reservedPrefixes[],
                       PR_DraftSnapshot &snapshot,
                       PR_PreflightResult &result)
  {
   return PR_PreflightChartWithState(chartID, caseID, caseType, symbol,
                                     timeframe, reservedPrefixes,
                                     PR_REPRESENTATION_ID, 0, false,
                                     PR_APPLICABILITY_NOT_APPLICABLE,
                                     PR_APPLICABILITY_NOT_APPLICABLE,
                                     snapshot, result);
  }

string PR_BuildAnalysisFingerprint(PR_PreflightResult &preflight,
                                   PR_AnalysisResult &analysis)
  {
   string fingerprint = "PRAF1|contract=" + preflight.statusCode +
                        "|data=" + analysis.dataStatusCode +
                        "|data_reason=" + analysis.dataReasonCode +
                        "|gap_status=" + analysis.dataGapStatus +
                        "|gap_reason=" + analysis.dataGapReason +
                        "|session_policy=" + analysis.sessionPolicyVersion +
                        "|calendar_hours=" + IntegerToString(analysis.calendarSpanHours) +
                        "|calendar_bars=" + IntegerToString(analysis.calendarExpectedBars) +
                        "|actual_bars=" + IntegerToString(analysis.actualBars) +
                        "|expected_closure_hours=" + IntegerToString(analysis.expectedClosureHours) +
                        "|unexpected_gaps=" + IntegerToString(analysis.unexpectedGapCount) +
                        "|first_gap_previous=" + IntegerToString((long)analysis.firstUnexpectedGapPrevious) +
                        "|first_gap_next=" + IntegerToString((long)analysis.firstUnexpectedGapNext) +
                        "|analysis_completed=" + IntegerToString((int)analysis.analysisCompleted) +
                        "|market=" + analysis.marketFingerprint +
                        "|feature=" + analysis.featureVersion +
                        "|direction=" + analysis.directionVersion +
                        "|policy=" + analysis.policyVersion +
                        "|analysis=" + analysis.statusCode +
                        "|reason=" + analysis.reasonCode +
                        "|draft_length=" + IntegerToString(StringLen(preflight.fingerprint)) +
                        "|draft=" + preflight.fingerprint;
   return PR_CapFingerprint(fingerprint);
  }

bool PR_AnalyzeChartWithState(long chartID,
                              string caseID,
                              string caseType,
                              string symbol,
                              ENUM_TIMEFRAMES timeframe,
                              string &reservedPrefixes[],
                              string representationID,
                              int structureCount,
                              bool keyBarActive,
                              string structureApplicability,
                              string keyBarApplicability,
                              PR_DraftSnapshot &snapshot,
                              PR_PreflightResult &preflight,
                              PR_AnalysisResult &analysis)
  {
   PR_ResetAnalysisResult(analysis);
   bool contractValid = PR_PreflightChartWithState(
      chartID, caseID, caseType, symbol, timeframe, reservedPrefixes,
      representationID, structureCount, keyBarActive,
      structureApplicability, keyBarApplicability, snapshot, preflight);
   analysis.declaredDirection = PR_CaseTypeDirection(caseType);
   analysis.lineDirection = preflight.direction;
   if(!contractValid)
     {
      analysis.statusCode = PR_ANALYSIS_STATUS_CONTRACT_INVALID;
      analysis.reasonCode = preflight.reasonCode;
      analysis.analysisFingerprint = PR_BuildAnalysisFingerprint(preflight, analysis);
      return false;
     }

   PR_MarketSnapshot market;
   bool marketValid = PR_CaptureH1MarketSnapshot(
      symbol, timeframe, preflight.windowStart, preflight.windowEnd, market);
   analysis.dataStatusCode = market.statusCode;
   analysis.dataReasonCode = market.reasonCode;
   analysis.dataLastError = market.lastError;
   analysis.dataGapStatus = market.gapStatus;
   analysis.dataGapReason = market.gapReason;
   analysis.sessionPolicyVersion = market.sessionPolicyVersion;
   analysis.calendarSpanHours = market.calendarSpanHours;
   analysis.calendarExpectedBars = market.expectedReleaseBarCount;
   analysis.actualBars = market.releaseBarCount;
   analysis.expectedClosureGapCount = market.expectedClosureGapCount;
   analysis.expectedClosureHours = market.expectedClosureHours;
   analysis.unexpectedGapCount = market.unexpectedGapCount;
   analysis.firstUnexpectedGapPrevious = market.firstUnexpectedGapPrevious;
   analysis.firstUnexpectedGapNext = market.firstUnexpectedGapNext;
   analysis.firstUnexpectedGapHours = market.firstUnexpectedGapHours;
   analysis.marketFingerprint = market.fingerprint;
   if(!marketValid)
     {
      analysis.statusCode = PR_ANALYSIS_STATUS_DATA_INVALID;
      analysis.reasonCode = market.reasonCode;
      analysis.analysisFingerprint = PR_BuildAnalysisFingerprint(preflight, analysis);
      return false;
     }

   PR_FeatureVector features;
   bool featuresValid = PR_ExtractFeatures(market, features);
   analysis.features = features;
   if(!featuresValid)
     {
      analysis.statusCode = PR_ANALYSIS_STATUS_FEATURE_INVALID;
      analysis.reasonCode = features.reasonCode;
      analysis.analysisFingerprint = PR_BuildAnalysisFingerprint(preflight, analysis);
      return false;
     }

   bool qualified = PR_EvaluatePureRelease(caseType, preflight.direction,
                                           features, analysis);
   analysis.features = features;
   analysis.analysisCompleted = true;
   analysis.archiveTouched = false;
   analysis.analysisFingerprint = PR_BuildAnalysisFingerprint(preflight, analysis);
   return qualified;
  }

string PR_PreflightSummary(PR_DraftSnapshot &snapshot,
                           PR_PreflightResult &result)
  {
   return "strategy=" + PR_STRATEGY_ID +
          "|contract=" + result.statusCode +
          "|reason=" + result.reasonCode +
          "|direction=" + result.direction +
          "|boundaries=" + IntegerToString(result.boundaryCount) +
          "|release_paths=" + IntegerToString(result.releasePathCount) +
          "|objects=" + IntegerToString(result.objectCount) +
          "|unsupported=" + IntegerToString(result.unsupportedCount) +
          "|invalid_subwindow=" + IntegerToString(result.invalidSubwindowCount) +
          "|invalid_price=" + IntegerToString(result.invalidPriceCount) +
          "|invalid_identity=" + IntegerToString(result.invalidObjectIdentityCount) +
          "|duplicate_identity=" + IntegerToString(result.duplicateObjectCount) +
          "|structures=" + IntegerToString(result.structureCount) +
          "|key_bar_active=" + IntegerToString((int)result.keyBarActive) +
          "|structure_applicability=" + result.structureApplicability +
          "|key_bar_applicability=" + result.keyBarApplicability +
          "|window=" + IntegerToString((long)result.windowStart) +
          ".." + IntegerToString((long)result.windowEnd) +
          "|fingerprint=" + result.fingerprint +
          "|archive_touched=" + IntegerToString((int)result.archiveTouched);
  }

string PR_AnalysisSummary(PR_AnalysisResult &result)
  {
   return "analysis=" + result.statusCode +
          "|reason=" + result.reasonCode +
          "|data=" + result.dataStatusCode +
          "|data_reason=" + result.dataReasonCode +
          "|gap_status=" + result.dataGapStatus +
          "|gap_reason=" + result.dataGapReason +
          "|session_policy=" + result.sessionPolicyVersion +
          "|analysis_completed=" + IntegerToString((int)result.analysisCompleted) +
          "|calendar_hours=" + IntegerToString(result.calendarSpanHours) +
          "|calendar_bars=" + IntegerToString(result.calendarExpectedBars) +
          "|actual_bars=" + IntegerToString(result.actualBars) +
          "|expected_closure_gaps=" + IntegerToString(result.expectedClosureGapCount) +
          "|expected_closure_hours=" + IntegerToString(result.expectedClosureHours) +
          "|unexpected_gaps=" + IntegerToString(result.unexpectedGapCount) +
          "|first_gap_previous=" + IntegerToString((long)result.firstUnexpectedGapPrevious) +
          "|first_gap_next=" + IntegerToString((long)result.firstUnexpectedGapNext) +
          "|first_gap_hours=" + IntegerToString(result.firstUnexpectedGapHours) +
          "|declared_direction=" + result.declaredDirection +
          "|line_direction=" + result.lineDirection +
          "|market_direction=" + result.marketDirection +
          "|direction_agreement=" + result.directionAgreement +
          "|quality=" + result.qualityStatus +
          "|review_mask=" + IntegerToString(result.qualityReviewMask) +
          "|failure_mask=" + IntegerToString(result.qualityFailureMask) +
          "|bars=" + IntegerToString(result.features.releaseBarCount) +
          "|atr=" + DoubleToString(result.features.atrReference, 8) +
          "|net_atr=" + DoubleToString(result.features.netMoveAtr, 6) +
          "|slope_span_atr=" + DoubleToString(result.features.slopeSpanAtr, 6) +
          "|efficiency=" + DoubleToString(result.features.efficiency, 6) +
          "|body_alignment=" + DoubleToString(result.selectedBodyAlignment, 6) +
          "|pullback_ratio=" + DoubleToString(result.selectedPullbackRatio, 6) +
          "|range_expansion=" + DoubleToString(result.features.rangeExpansion, 6) +
          "|regression_r2=" + DoubleToString(result.features.regressionR2, 6) +
          "|feature_version=" + result.featureVersion +
          "|direction_version=" + result.directionVersion +
          "|policy_version=" + result.policyVersion +
          "|archive_touched=" + IntegerToString((int)result.archiveTouched);
  }

#endif
