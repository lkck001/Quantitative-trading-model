#ifndef CD_FACADE_MQH
#define CD_FACADE_MQH

#include "Contract\CD_Types.mqh"
#include "Contract\CD_Contract.mqh"
#include "Persistence\CD_ArchiveStore.mqh"
#include "Persistence\CD_Transaction.mqh"

struct CD_RuntimeState
  {
   bool eligibilityKnown;
   bool eligibilityReady;
   bool eligibilityRecoveryPending;
   string eligibilityKey;
   CD_RecoveryInfo recoveryInfo;
  };

CD_RuntimeState cdRuntimeState;

void CD_InvalidateDeleteEligibility()
  {
   cdRuntimeState.eligibilityKnown = false;
   cdRuntimeState.eligibilityReady = false;
   cdRuntimeState.eligibilityRecoveryPending = false;
   cdRuntimeState.eligibilityKey = "";
  }

bool CD_PrepareDelete(CD_Request &request,
                      CD_Preview &preview,
                      CD_Result &result)
  {
   return CD_PrepareDeleteInternal(request, preview, result);
  }

bool CD_QueryDeleteEligibility(CD_Request &request,
                               string eligibilityKey,
                               bool &recoveryPending)
  {
   if(!cdRuntimeState.eligibilityKnown ||
      cdRuntimeState.eligibilityKey != eligibilityKey)
     {
      CD_Preview preview;
      CD_Result result;
      cdRuntimeState.eligibilityReady =
         CD_PrepareDelete(request, preview, result);
      cdRuntimeState.eligibilityRecoveryPending = result.recoveryPending;
      cdRuntimeState.eligibilityKnown = true;
      cdRuntimeState.eligibilityKey = eligibilityKey;
     }
   recoveryPending = cdRuntimeState.eligibilityRecoveryPending;
   return cdRuntimeState.eligibilityReady;
  }

bool CD_CommitDelete(CD_Request &request,
                     CD_Preview &preview,
                     CD_Result &result)
  {
   return CD_CommitDeleteInternal(request, preview, result);
  }

void CD_CancelDelete(CD_Request &request,
                     CD_Preview &preview,
                     CD_Result &result)
  {
   CD_ResetResult(result);
   result.statusCode = CD_STATUS_CANCELLED;
   result.reasonCode = CD_REASON_CANCELLED;
   result.caseID = request.caseID;
   result.manifestFingerprint = preview.manifestFingerprint;
   CD_CopyPreviewRowsToResult(preview, result);
  }

bool CD_DetectRecovery(CD_Request &request, CD_RecoveryInfo &info)
  {
   return CD_DetectRecoveryInternal(request, info);
  }

bool CD_RefreshDeleteRecoveryState(CD_Request &request)
  {
   bool readable = CD_DetectRecovery(request, cdRuntimeState.recoveryInfo);
   if(cdRuntimeState.recoveryInfo.pending)
      CD_InvalidateDeleteEligibility();
   return readable;
  }

bool CD_DeleteRecoveryPending()
  {
   return cdRuntimeState.recoveryInfo.pending;
  }

void CD_GetDeleteRecoveryInfo(CD_RecoveryInfo &info)
  {
   CD_ResetRecoveryInfo(info);
   info.pending = cdRuntimeState.recoveryInfo.pending;
   info.valid = cdRuntimeState.recoveryInfo.valid;
   info.transactionVersion = cdRuntimeState.recoveryInfo.transactionVersion;
   info.state = cdRuntimeState.recoveryInfo.state;
   info.token = cdRuntimeState.recoveryInfo.token;
   info.caseID = cdRuntimeState.recoveryInfo.caseID;
   info.caseType = cdRuntimeState.recoveryInfo.caseType;
   info.symbol = cdRuntimeState.recoveryInfo.symbol;
   info.timeframe = cdRuntimeState.recoveryInfo.timeframe;
   info.beforeManifest = cdRuntimeState.recoveryInfo.beforeManifest;
   info.existedMask = cdRuntimeState.recoveryInfo.existedMask;
   int count = ArraySize(cdRuntimeState.recoveryInfo.targetRows);
   ArrayResize(info.targetRows, count);
   for(int index = 0; index < count; index++)
      info.targetRows[index] = cdRuntimeState.recoveryInfo.targetRows[index];
   info.lastError = cdRuntimeState.recoveryInfo.lastError;
   info.reasonCode = cdRuntimeState.recoveryInfo.reasonCode;
  }

bool CD_RecoverDelete(CD_Request &request, CD_Result &result)
  {
   return CD_RecoverDeleteInternal(request, result);
  }

bool CD_GetSequenceHighWater(string sequencePath,
                             int year,
                             int &highWater,
                             string &reasonCode,
                             int &lastError)
  {
   return CD_GetSequenceHighWaterInternal(sequencePath, year, highWater,
                                          reasonCode, lastError);
  }

#endif
