#ifndef PR_CONTRACT_MQH
#define PR_CONTRACT_MQH

#include "PR_Types.mqh"

#define PR_DIRECTION_FLAT_EPSILON 0.0000000001

bool PR_IsTimeInsideWindow(datetime value, datetime windowStart, datetime windowEnd)
  {
   return (value >= windowStart && value < windowEnd);
  }

void PR_SetResultFailure(PR_PreflightResult &result, string statusCode, string reasonCode)
  {
   result.contractValid = false;
   result.statusCode = statusCode;
   result.reasonCode = reasonCode;
   result.direction = PR_DIRECTION_UNKNOWN;
  }

void PR_SetGeometricDirection(PR_PreflightResult &result,
                              datetime firstTime,
                              double firstPrice,
                              datetime secondTime,
                              double secondPrice)
  {
   result.signedPriceDelta = secondPrice - firstPrice;
   if(secondTime <= firstTime)
     {
      result.direction = PR_DIRECTION_UNKNOWN;
      return;
     }
   if(MathAbs(result.signedPriceDelta) <= PR_DIRECTION_FLAT_EPSILON)
      result.direction = PR_DIRECTION_FLAT;
   else if(result.signedPriceDelta > 0.0)
      result.direction = PR_DIRECTION_UP;
   else
      result.direction = PR_DIRECTION_DOWN;
  }

bool PR_ValidateContract(PR_DraftSnapshot &snapshot,
                         PR_PreflightResult &result)
  {
   PR_ResetPreflightResult(result);
   result.fingerprint = snapshot.fingerprint;
   result.objectCount = snapshot.objectCount;
   result.boundaryCount = snapshot.boundaryCount;
   result.releasePathCount = snapshot.releasePathCount;
   result.unsupportedCount = snapshot.unsupportedCount;
   result.invalidSubwindowCount = snapshot.invalidSubwindowCount;
   result.invalidPriceCount = snapshot.invalidPriceCount;
   result.invalidObjectIdentityCount = snapshot.invalidObjectIdentityCount;
   result.duplicateObjectCount = snapshot.duplicateObjectCount;
   result.structureCount = snapshot.structureCount;
   result.keyBarActive = snapshot.keyBarActive;
   result.structureApplicability = snapshot.structureApplicability;
   result.keyBarApplicability = snapshot.keyBarApplicability;
   if(!snapshot.captureOK)
     {
      PR_SetResultFailure(result, PR_STATUS_CAPTURE_FAILED, PR_REASON_CAPTURE_FAILED);
      return false;
     }
   if(!PR_IsPureReleaseCaseType(snapshot.caseType) ||
      snapshot.representationID != PR_REPRESENTATION_ID)
     {
      PR_SetResultFailure(result, PR_STATUS_REPRESENTATION_MISMATCH,
                          PR_REASON_REPRESENTATION);
      return false;
     }
   if(snapshot.boundaryCount != 2)
     {
      PR_SetResultFailure(result, PR_STATUS_INVALID_BOUNDARY_COUNT,
                          PR_REASON_BOUNDARY_COUNT);
      return false;
     }
   if(snapshot.releasePathCount != 1)
     {
      PR_SetResultFailure(result, PR_STATUS_INVALID_RELEASE_PATH_COUNT,
                          PR_REASON_RELEASE_PATH_COUNT);
      return false;
     }
   if(snapshot.unsupportedCount > 0)
     {
      PR_SetResultFailure(result, PR_STATUS_UNSUPPORTED_OBJECT,
                          PR_REASON_UNSUPPORTED_OBJECT);
      return false;
     }
   if(snapshot.invalidObjectIdentityCount > 0 || snapshot.duplicateObjectCount > 0)
     {
      PR_SetResultFailure(result, PR_STATUS_INVALID_OBJECT_IDENTITY,
                          PR_REASON_OBJECT_IDENTITY);
      return false;
     }
   if(snapshot.invalidSubwindowCount > 0)
     {
      PR_SetResultFailure(result, PR_STATUS_INVALID_SUBWINDOW,
                          PR_REASON_SUBWINDOW);
      return false;
     }
   if(snapshot.invalidPriceCount > 0)
     {
      PR_SetResultFailure(result, PR_STATUS_INVALID_PRICE,
                          PR_REASON_PRICE);
      return false;
     }
   if(snapshot.structureCount != 0 || snapshot.keyBarActive ||
      snapshot.structureApplicability != PR_APPLICABILITY_NOT_APPLICABLE ||
      snapshot.keyBarApplicability != PR_APPLICABILITY_NOT_APPLICABLE)
     {
      PR_SetResultFailure(result, PR_STATUS_NOT_APPLICABLE_VIOLATION,
                          PR_REASON_NOT_APPLICABLE);
      return false;
     }
   datetime windowStart = snapshot.boundaries[0].time;
   datetime windowEnd = snapshot.boundaries[1].time;
   if(windowStart <= 0 || windowEnd <= windowStart)
     {
      PR_SetResultFailure(result, PR_STATUS_INVALID_BOUNDARY_ORDER,
                          PR_REASON_BOUNDARY_ORDER);
      return false;
     }
   if(snapshot.boundaries[0].time >= snapshot.boundaries[1].time)
     {
      PR_SetResultFailure(result, PR_STATUS_INVALID_BOUNDARY_ORDER,
                          PR_REASON_BOUNDARY_ORDER);
      return false;
     }
   PR_ReleasePathSnapshot path = snapshot.releasePaths[0];
   if(path.time1 <= 0 || path.time2 <= 0 || path.time1 == path.time2)
     {
      PR_SetResultFailure(result, PR_STATUS_INVALID_RELEASE_PATH_TIME,
                          PR_REASON_RELEASE_PATH_TIME);
      return false;
     }
   datetime firstTime = path.time1;
   datetime secondTime = path.time2;
   double firstPrice = path.price1;
   double secondPrice = path.price2;
   if(secondTime < firstTime)
     {
      firstTime = path.time2;
      secondTime = path.time1;
      firstPrice = path.price2;
      secondPrice = path.price1;
     }
   if(!PR_IsTimeInsideWindow(firstTime, windowStart, windowEnd) ||
      !PR_IsTimeInsideWindow(secondTime, windowStart, windowEnd))
     {
      PR_SetResultFailure(result, PR_STATUS_RELEASE_PATH_OUTSIDE_WINDOW,
                          PR_REASON_RELEASE_PATH_OUTSIDE);
      result.windowStart = windowStart;
      result.windowEnd = windowEnd;
      PR_SetGeometricDirection(result, firstTime, firstPrice, secondTime, secondPrice);
      return false;
     }
   result.windowStart = windowStart;
   result.windowEnd = windowEnd;
   PR_SetGeometricDirection(result, firstTime, firstPrice, secondTime, secondPrice);
   result.contractValid = true;
   result.statusCode = PR_STATUS_VALID;
   result.reasonCode = PR_REASON_VALID;
   result.archiveTouched = false;
   return true;
  }

#endif
