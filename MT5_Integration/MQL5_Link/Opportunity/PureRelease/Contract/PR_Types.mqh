#ifndef PR_TYPES_MQH
#define PR_TYPES_MQH

#define PR_STRATEGY_ID "PURE_RELEASE_V1"
#define PR_CONTRACT_VERSION "PURE_RELEASE_CONTRACT_V1"
#define PR_REPRESENTATION_ID "PURE_RELEASE_DRAFT_V1"
#define PR_FEATURE_VERSION "PURE_RELEASE_FEATURES_V1"
#define PR_DIRECTION_VERSION "PURE_RELEASE_DIRECTION_V1"
#define PR_POLICY_VERSION "PURE_RELEASE_QUALITY_SHADOW_V1"
#define PR_SESSION_POLICY_VERSION "PURE_RELEASE_SESSION_POLICY_V2"

#define PR_CASE_TYPE_UPWARD "UPWARD_RELEASE"
#define PR_CASE_TYPE_DOWNWARD "DOWNWARD_RELEASE"

#define PR_DIRECTION_UP "UP"
#define PR_DIRECTION_DOWN "DOWN"
#define PR_DIRECTION_FLAT "FLAT"
#define PR_DIRECTION_UNKNOWN "UNKNOWN"

#define PR_STATUS_VALID "VALID"
#define PR_STATUS_CAPTURE_FAILED "CAPTURE_FAILED"
#define PR_STATUS_INVALID_BOUNDARY_COUNT "INVALID_BOUNDARY_COUNT"
#define PR_STATUS_INVALID_RELEASE_PATH_COUNT "INVALID_RELEASE_PATH_COUNT"
#define PR_STATUS_INVALID_BOUNDARY_ORDER "INVALID_BOUNDARY_ORDER"
#define PR_STATUS_INVALID_RELEASE_PATH_TIME "INVALID_RELEASE_PATH_TIME"
#define PR_STATUS_RELEASE_PATH_OUTSIDE_WINDOW "RELEASE_PATH_OUTSIDE_WINDOW"
#define PR_STATUS_UNSUPPORTED_OBJECT "UNSUPPORTED_OBJECT"
#define PR_STATUS_REPRESENTATION_MISMATCH "REPRESENTATION_MISMATCH"
#define PR_STATUS_INVALID_SUBWINDOW "INVALID_SUBWINDOW"
#define PR_STATUS_INVALID_PRICE "INVALID_PRICE"
#define PR_STATUS_INVALID_OBJECT_IDENTITY "INVALID_OBJECT_IDENTITY"
#define PR_STATUS_NOT_APPLICABLE_VIOLATION "NOT_APPLICABLE_VIOLATION"

#define PR_REASON_VALID "VALID_CONTRACT"
#define PR_REASON_CAPTURE_FAILED "CHART_SNAPSHOT_FAILED"
#define PR_REASON_BOUNDARY_COUNT "EXPECTED_TWO_BOUNDARIES"
#define PR_REASON_RELEASE_PATH_COUNT "EXPECTED_ONE_RELEASE_PATH"
#define PR_REASON_BOUNDARY_ORDER "BOUNDARIES_NOT_STRICTLY_ORDERED"
#define PR_REASON_RELEASE_PATH_TIME "RELEASE_PATH_ENDPOINT_TIMES_INVALID"
#define PR_REASON_RELEASE_PATH_OUTSIDE "RELEASE_PATH_ENDPOINT_OUTSIDE_WINDOW"
#define PR_REASON_UNSUPPORTED_OBJECT "UNSUPPORTED_OBJECT_PRESENT"
#define PR_REASON_REPRESENTATION "CASE_TYPE_NOT_PURE_RELEASE"
#define PR_REASON_SUBWINDOW "OBJECT_NOT_ON_MAIN_SUBWINDOW"
#define PR_REASON_PRICE "NON_FINITE_PRICE"
#define PR_REASON_OBJECT_IDENTITY "EMPTY_OR_DUPLICATE_OBJECT_ID"
#define PR_REASON_NOT_APPLICABLE "STRUCTURE_OR_KEY_BAR_MUST_BE_NOT_APPLICABLE"

#define PR_APPLICABILITY_NOT_APPLICABLE "NOT_APPLICABLE"
#define PR_FINGERPRINT_MAX_LENGTH 8192

#define PR_DATA_STATUS_NOT_RUN "NOT_RUN"
#define PR_DATA_STATUS_VALID "VALID"
#define PR_DATA_STATUS_INVALID_WINDOW "INVALID_WINDOW"
#define PR_DATA_STATUS_UNSUPPORTED_TIMEFRAME "UNSUPPORTED_TIMEFRAME"
#define PR_DATA_STATUS_BOUNDARY_NOT_ALIGNED "BOUNDARY_NOT_ALIGNED"
#define PR_DATA_STATUS_COPY_FAILED "COPY_FAILED"
#define PR_DATA_STATUS_INSUFFICIENT_RELEASE_BARS "INSUFFICIENT_RELEASE_BARS"
#define PR_DATA_STATUS_INSUFFICIENT_ATR_CONTEXT "INSUFFICIENT_ATR_CONTEXT"
#define PR_DATA_STATUS_INVALID_BAR "INVALID_BAR"
#define PR_DATA_STATUS_DISCONTIGUOUS_WINDOW "DISCONTIGUOUS_WINDOW"

#define PR_DATA_REASON_NOT_RUN "MARKET_DATA_NOT_REQUESTED"
#define PR_DATA_REASON_VALID "VALID_H1_MARKET_SNAPSHOT"
#define PR_DATA_REASON_INVALID_WINDOW "ANALYSIS_WINDOW_INVALID"
#define PR_DATA_REASON_UNSUPPORTED_TIMEFRAME "PURE_RELEASE_REQUIRES_H1"
#define PR_DATA_REASON_BOUNDARY_NOT_ALIGNED "BOUNDARIES_MUST_MATCH_H1_OPEN_TIMES"
#define PR_DATA_REASON_COPY_FAILED "H1_RATES_COPY_FAILED"
#define PR_DATA_REASON_INSUFFICIENT_RELEASE_BARS "EXPECTED_AT_LEAST_THREE_RELEASE_BARS"
#define PR_DATA_REASON_INSUFFICIENT_ATR_CONTEXT "EXPECTED_FIFTEEN_PRE_RELEASE_BARS"
#define PR_DATA_REASON_INVALID_BAR "INVALID_H1_OHLC_BAR"
#define PR_DATA_REASON_DISCONTIGUOUS_WINDOW "RELEASE_WINDOW_CONTAINS_TIME_GAP"
#define PR_DATA_REASON_VALID_EXPECTED_CLOSURES "VALID_H1_SNAPSHOT_WITH_EXPECTED_CLOSURES"
#define PR_DATA_REASON_UNEXPECTED_RELEASE_GAP "RELEASE_WINDOW_CONTAINS_UNEXPECTED_GAP"
#define PR_DATA_REASON_UNEXPECTED_CONTEXT_GAP "ATR_CONTEXT_CONTAINS_UNEXPECTED_GAP"

#define PR_FEATURE_REASON_NOT_RUN "FEATURES_NOT_COMPUTED"
#define PR_FEATURE_REASON_VALID "VALID_FEATURE_VECTOR"
#define PR_FEATURE_REASON_INVALID_ATR "ATR_REFERENCE_INVALID"
#define PR_FEATURE_REASON_INVALID_VALUE "NON_FINITE_FEATURE_VALUE"

#define PR_AGREEMENT_NOT_EVALUATED "NOT_EVALUATED"
#define PR_AGREEMENT_PASS "PASS"
#define PR_AGREEMENT_LINE_AMBIGUOUS "LINE_AMBIGUOUS"
#define PR_AGREEMENT_TYPE_LINE_MISMATCH "TYPE_LINE_MISMATCH"
#define PR_AGREEMENT_MARKET_AMBIGUOUS "MARKET_AMBIGUOUS"
#define PR_AGREEMENT_TYPE_MARKET_MISMATCH "TYPE_MARKET_MISMATCH"

#define PR_QUALITY_NOT_EVALUATED "NOT_EVALUATED"
#define PR_QUALITY_PASS "PASS"
#define PR_QUALITY_REVIEW "REVIEW"
#define PR_QUALITY_FAIL "FAIL"

#define PR_ANALYSIS_STATUS_NOT_RUN "NOT_RUN"
#define PR_ANALYSIS_STATUS_CONTRACT_INVALID "CONTRACT_INVALID"
#define PR_ANALYSIS_STATUS_DATA_INVALID "DATA_INVALID"
#define PR_ANALYSIS_STATUS_FEATURE_INVALID "FEATURE_INVALID"
#define PR_ANALYSIS_STATUS_DIRECTION_REJECTED "DIRECTION_REJECTED"
#define PR_ANALYSIS_STATUS_QUALITY_REJECTED "QUALITY_REJECTED"
#define PR_ANALYSIS_STATUS_REVIEW "REVIEW"
#define PR_ANALYSIS_STATUS_QUALIFIED "QUALIFIED"

#define PR_ANALYSIS_REASON_NOT_RUN "ANALYSIS_NOT_RUN"
#define PR_ANALYSIS_REASON_CONTRACT_INVALID "PHASE1_CONTRACT_INVALID"
#define PR_ANALYSIS_REASON_DATA_INVALID "MARKET_DATA_INVALID"
#define PR_ANALYSIS_REASON_FEATURE_INVALID "FEATURE_VECTOR_INVALID"
#define PR_ANALYSIS_REASON_LINE_AMBIGUOUS "RELEASE_LINE_DIRECTION_AMBIGUOUS"
#define PR_ANALYSIS_REASON_TYPE_LINE_MISMATCH "CASE_TYPE_AND_RELEASE_LINE_DISAGREE"
#define PR_ANALYSIS_REASON_MARKET_AMBIGUOUS "MARKET_DIRECTION_AMBIGUOUS"
#define PR_ANALYSIS_REASON_TYPE_MARKET_MISMATCH "CASE_TYPE_AND_MARKET_DISAGREE"
#define PR_ANALYSIS_REASON_MOVE_TOO_SMALL "NET_MOVE_TOO_SMALL"
#define PR_ANALYSIS_REASON_LOW_EFFICIENCY "PATH_EFFICIENCY_TOO_LOW"
#define PR_ANALYSIS_REASON_BODY_MISALIGNED "BAR_BODIES_NOT_DIRECTIONAL"
#define PR_ANALYSIS_REASON_PULLBACK_EXCESSIVE "PULLBACK_TOO_LARGE"
#define PR_ANALYSIS_REASON_QUALITY_REVIEW "QUALITY_REQUIRES_REVIEW"
#define PR_ANALYSIS_REASON_QUALIFIED "QUALIFIED_PURE_RELEASE"

#define PR_QUALITY_GATE_NET_MOVE 1
#define PR_QUALITY_GATE_EFFICIENCY 2
#define PR_QUALITY_GATE_BODY_ALIGNMENT 4
#define PR_QUALITY_GATE_PULLBACK 8

#define PR_ATR_CONTEXT_BAR_COUNT 15
#define PR_MIN_RELEASE_BAR_COUNT 3

struct PR_ObjectSnapshot
  {
   string objectName;
   ENUM_OBJECT objectType;
   int subwindow;
   int anchorCount;
   datetime time1;
   datetime time2;
   double price1;
   double price2;
  };

struct PR_BoundarySnapshot
  {
   string objectName;
   int subwindow;
   datetime time;
  };

struct PR_ReleasePathSnapshot
  {
   string objectName;
   int subwindow;
   datetime time1;
   datetime time2;
   double price1;
   double price2;
   int sourceAnchorOrder;
  };

struct PR_DraftSnapshot
  {
   bool captureOK;
   string captureErrorCode;
   long chartID;
   string caseID;
   string caseType;
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   string representationID;
   string contractVersion;
   int objectCount;
   int boundaryCount;
   int releasePathCount;
   int unsupportedCount;
   int invalidSubwindowCount;
   int invalidPriceCount;
   int invalidObjectIdentityCount;
   int duplicateObjectCount;
   int structureCount;
   bool keyBarActive;
   string structureApplicability;
   string keyBarApplicability;
   PR_ObjectSnapshot objects[];
   PR_BoundarySnapshot boundaries[];
   PR_ReleasePathSnapshot releasePaths[];
   string fingerprint;
  };

struct PR_PreflightResult
  {
   bool contractValid;
   bool archiveTouched;
   string statusCode;
   string reasonCode;
   string direction;
   string fingerprint;
   datetime windowStart;
   datetime windowEnd;
   double signedPriceDelta;
   int objectCount;
   int boundaryCount;
   int releasePathCount;
   int unsupportedCount;
   int invalidSubwindowCount;
   int invalidPriceCount;
   int invalidObjectIdentityCount;
   int duplicateObjectCount;
   int structureCount;
   bool keyBarActive;
   string structureApplicability;
   string keyBarApplicability;
  };

struct PR_MarketSnapshot
  {
   bool captureOK;
   string statusCode;
   string reasonCode;
   int lastError;
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   datetime windowStart;
   datetime windowEnd;
   int expectedReleaseBarCount;
   int calendarSpanHours;
   int contextBarCount;
   int releaseBarCount;
   string gapStatus;
   string gapReason;
   string sessionPolicyVersion;
   int expectedClosureGapCount;
   int expectedClosureHours;
   int unexpectedGapCount;
   datetime firstUnexpectedGapPrevious;
   datetime firstUnexpectedGapNext;
   int firstUnexpectedGapHours;
   MqlRates contextBars[];
   MqlRates releaseBars[];
   string fingerprint;
  };

struct PR_FeatureVector
  {
   bool valid;
   string reasonCode;
   int releaseBarCount;
   double atrReference;
   double signedNetMove;
   double netMoveAtr;
   double regressionSlope;
   double slopeSpanAtr;
   double efficiency;
   double pathLength;
   double totalBody;
   double bodyAlignmentUp;
   double bodyAlignmentDown;
   double maxFavorableUp;
   double maxFavorableDown;
   double maxPullbackUp;
   double maxPullbackDown;
   double pullbackRatioUp;
   double pullbackRatioDown;
   double rangeExpansion;
   double regressionR2;
  };

struct PR_AnalysisResult
  {
   bool qualified;
   bool analysisCompleted;
   bool archiveTouched;
   string statusCode;
   string reasonCode;
   string dataStatusCode;
   string dataReasonCode;
   int dataLastError;
   string dataGapStatus;
   string dataGapReason;
   string sessionPolicyVersion;
   int calendarSpanHours;
   int calendarExpectedBars;
   int actualBars;
   int expectedClosureGapCount;
   int expectedClosureHours;
   int unexpectedGapCount;
   datetime firstUnexpectedGapPrevious;
   datetime firstUnexpectedGapNext;
   int firstUnexpectedGapHours;
   string declaredDirection;
   string lineDirection;
   string marketDirection;
   string directionAgreement;
   string qualityStatus;
   int qualityReviewMask;
   int qualityFailureMask;
   double selectedBodyAlignment;
   double selectedPullbackRatio;
   string featureVersion;
   string directionVersion;
   string policyVersion;
   string marketFingerprint;
   string analysisFingerprint;
   PR_FeatureVector features;
  };

void PR_ResetPreflightResult(PR_PreflightResult &result)
  {
   result.contractValid = false;
   result.archiveTouched = false;
   result.statusCode = PR_STATUS_CAPTURE_FAILED;
   result.reasonCode = PR_REASON_CAPTURE_FAILED;
   result.direction = PR_DIRECTION_UNKNOWN;
   result.fingerprint = "";
   result.windowStart = 0;
   result.windowEnd = 0;
   result.signedPriceDelta = 0.0;
   result.objectCount = 0;
   result.boundaryCount = 0;
   result.releasePathCount = 0;
   result.unsupportedCount = 0;
   result.invalidSubwindowCount = 0;
   result.invalidPriceCount = 0;
   result.invalidObjectIdentityCount = 0;
   result.duplicateObjectCount = 0;
   result.structureCount = 0;
   result.keyBarActive = false;
   result.structureApplicability = PR_APPLICABILITY_NOT_APPLICABLE;
   result.keyBarApplicability = PR_APPLICABILITY_NOT_APPLICABLE;
  }

void PR_ResetDraftSnapshot(PR_DraftSnapshot &snapshot)
  {
   snapshot.captureOK = false;
   snapshot.captureErrorCode = "";
   snapshot.chartID = 0;
   snapshot.caseID = "";
   snapshot.caseType = "";
   snapshot.symbol = "";
   snapshot.timeframe = PERIOD_CURRENT;
   snapshot.representationID = PR_REPRESENTATION_ID;
   snapshot.contractVersion = PR_CONTRACT_VERSION;
   snapshot.objectCount = 0;
   snapshot.boundaryCount = 0;
   snapshot.releasePathCount = 0;
   snapshot.unsupportedCount = 0;
   snapshot.invalidSubwindowCount = 0;
   snapshot.invalidPriceCount = 0;
   snapshot.invalidObjectIdentityCount = 0;
   snapshot.duplicateObjectCount = 0;
   snapshot.structureCount = 0;
   snapshot.keyBarActive = false;
   snapshot.structureApplicability = PR_APPLICABILITY_NOT_APPLICABLE;
   snapshot.keyBarApplicability = PR_APPLICABILITY_NOT_APPLICABLE;
   ArrayResize(snapshot.objects, 0);
   ArrayResize(snapshot.boundaries, 0);
   ArrayResize(snapshot.releasePaths, 0);
   snapshot.fingerprint = "";
  }

void PR_ResetMarketSnapshot(PR_MarketSnapshot &snapshot)
  {
   snapshot.captureOK = false;
   snapshot.statusCode = PR_DATA_STATUS_NOT_RUN;
   snapshot.reasonCode = PR_DATA_REASON_NOT_RUN;
   snapshot.lastError = 0;
   snapshot.symbol = "";
   snapshot.timeframe = PERIOD_H1;
   snapshot.windowStart = 0;
   snapshot.windowEnd = 0;
   snapshot.expectedReleaseBarCount = 0;
   snapshot.calendarSpanHours = 0;
   snapshot.contextBarCount = 0;
   snapshot.releaseBarCount = 0;
   snapshot.gapStatus = "NOT_EVALUATED";
   snapshot.gapReason = "SESSION_GAP_NOT_EVALUATED";
   snapshot.sessionPolicyVersion = PR_SESSION_POLICY_VERSION;
   snapshot.expectedClosureGapCount = 0;
   snapshot.expectedClosureHours = 0;
   snapshot.unexpectedGapCount = 0;
   snapshot.firstUnexpectedGapPrevious = 0;
   snapshot.firstUnexpectedGapNext = 0;
   snapshot.firstUnexpectedGapHours = 0;
   ArrayResize(snapshot.contextBars, 0);
   ArrayResize(snapshot.releaseBars, 0);
   snapshot.fingerprint = "";
  }

void PR_ResetFeatureVector(PR_FeatureVector &features)
  {
   features.valid = false;
   features.reasonCode = PR_FEATURE_REASON_NOT_RUN;
   features.releaseBarCount = 0;
   features.atrReference = 0.0;
   features.signedNetMove = 0.0;
   features.netMoveAtr = 0.0;
   features.regressionSlope = 0.0;
   features.slopeSpanAtr = 0.0;
   features.efficiency = 0.0;
   features.pathLength = 0.0;
   features.totalBody = 0.0;
   features.bodyAlignmentUp = 0.0;
   features.bodyAlignmentDown = 0.0;
   features.maxFavorableUp = 0.0;
   features.maxFavorableDown = 0.0;
   features.maxPullbackUp = 0.0;
   features.maxPullbackDown = 0.0;
   features.pullbackRatioUp = 0.0;
   features.pullbackRatioDown = 0.0;
   features.rangeExpansion = 0.0;
   features.regressionR2 = 0.0;
  }

void PR_ResetAnalysisResult(PR_AnalysisResult &result)
  {
   result.qualified = false;
   result.analysisCompleted = false;
   result.archiveTouched = false;
   result.statusCode = PR_ANALYSIS_STATUS_NOT_RUN;
   result.reasonCode = PR_ANALYSIS_REASON_NOT_RUN;
   result.dataStatusCode = PR_DATA_STATUS_NOT_RUN;
   result.dataReasonCode = PR_DATA_REASON_NOT_RUN;
   result.dataLastError = 0;
   result.dataGapStatus = "NOT_EVALUATED";
   result.dataGapReason = "SESSION_GAP_NOT_EVALUATED";
   result.sessionPolicyVersion = PR_SESSION_POLICY_VERSION;
   result.calendarSpanHours = 0;
   result.calendarExpectedBars = 0;
   result.actualBars = 0;
   result.expectedClosureGapCount = 0;
   result.expectedClosureHours = 0;
   result.unexpectedGapCount = 0;
   result.firstUnexpectedGapPrevious = 0;
   result.firstUnexpectedGapNext = 0;
   result.firstUnexpectedGapHours = 0;
   result.declaredDirection = PR_DIRECTION_UNKNOWN;
   result.lineDirection = PR_DIRECTION_UNKNOWN;
   result.marketDirection = PR_DIRECTION_UNKNOWN;
   result.directionAgreement = PR_AGREEMENT_NOT_EVALUATED;
   result.qualityStatus = PR_QUALITY_NOT_EVALUATED;
   result.qualityReviewMask = 0;
   result.qualityFailureMask = 0;
   result.selectedBodyAlignment = 0.0;
   result.selectedPullbackRatio = 0.0;
   result.featureVersion = PR_FEATURE_VERSION;
   result.directionVersion = PR_DIRECTION_VERSION;
   result.policyVersion = PR_POLICY_VERSION;
   result.marketFingerprint = "";
   result.analysisFingerprint = "";
   PR_ResetFeatureVector(result.features);
  }

bool PR_IsPureReleaseCaseType(string caseType)
  {
   return (caseType == PR_CASE_TYPE_UPWARD || caseType == PR_CASE_TYPE_DOWNWARD);
  }

string PR_CaseTypeDirection(string caseType)
  {
   if(caseType == PR_CASE_TYPE_UPWARD) return PR_DIRECTION_UP;
   if(caseType == PR_CASE_TYPE_DOWNWARD) return PR_DIRECTION_DOWN;
   return PR_DIRECTION_UNKNOWN;
  }

bool PR_IsDirectionalValue(string direction)
  {
   return (direction == PR_DIRECTION_UP || direction == PR_DIRECTION_DOWN);
  }

#endif
