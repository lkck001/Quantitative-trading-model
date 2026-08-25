#ifndef CM_DELETE_MODULE_MQH
#define CM_DELETE_MODULE_MQH

#include "CM_DeleteContextAdapter.mqh"
#include "CM_DeleteRefreshAdapter.mqh"

int CM_DeleteModuleFailureFeedbackCode(CD_Result &result)
  {
   if(result.statusCode == CD_STATUS_NOT_FORMAL_CASE)
      return UI_CM_DELETE_FEEDBACK_DOMAIN_NOT_FORMAL;
   if(result.statusCode == CD_STATUS_IDENTITY_CONFLICT)
      return UI_CM_DELETE_FEEDBACK_DOMAIN_IDENTITY_CONFLICT;
   if(result.statusCode == CD_STATUS_STALE_PREVIEW)
      return UI_CM_DELETE_FEEDBACK_DOMAIN_STALE;
   if(result.statusCode == CD_STATUS_ARCHIVE_MISSING)
      return UI_CM_DELETE_FEEDBACK_DOMAIN_ARCHIVE_MISSING;
   if(result.statusCode == CD_STATUS_ROLLED_BACK)
      return UI_CM_DELETE_FEEDBACK_DOMAIN_ROLLED_BACK;
   if(result.statusCode == CD_STATUS_RECOVERY_REQUIRED)
      return UI_CM_DELETE_FEEDBACK_DOMAIN_RECOVERY_REQUIRED;
   if(result.statusCode == CD_STATUS_TRANSACTION_BUSY)
      return UI_CM_DELETE_FEEDBACK_DOMAIN_TRANSACTION_BUSY;
   return UI_CM_DELETE_FEEDBACK_DOMAIN_OTHER;
  }

void CM_DeleteModulePresentFeedback(int feedbackCode, string detail)
  {
   CM_DeleteRefreshPresentFeedback(feedbackCode, detail);
  }

bool CM_DeleteModuleEnterSafeState(long chartID, bool recoveryPending)
  {
   bool sessionStateReady =
      CM_DeleteRefreshEnterSafeState(chartID, recoveryPending);
   CD_InvalidateDeleteEligibility();
   return sessionStateReady;
  }

bool CM_DeleteModuleRefreshRecoveryState()
  {
   CD_Request request;
   CM_DeleteContextBuildBaseRequest(request, false);
   bool readable = CD_RefreshDeleteRecoveryState(request);
   CD_RecoveryInfo recoveryInfo;
   CD_GetDeleteRecoveryInfo(recoveryInfo);
   if(recoveryInfo.pending)
      Print("[EA|FULL|DELETE] WARN recovery journal detected",
            " | valid=", (int)recoveryInfo.valid,
            " | case=", recoveryInfo.caseID,
            " | reason=", recoveryInfo.reasonCode,
            " | err=", recoveryInfo.lastError,
            " | archive_touched=0");
   return readable;
  }

bool CM_DeleteModuleIsRecoveryPending()
  {
   return CD_DeleteRecoveryPending();
  }

bool CM_DeleteModulePrepareStartup(long chartID)
  {
   CM_DeleteModuleRefreshRecoveryState();
   if(!CM_DeleteModuleIsRecoveryPending()) return false;
   CD_RecoveryInfo recoveryInfo;
   CD_GetDeleteRecoveryInfo(recoveryInfo);
   CM_DeleteModuleEnterSafeState(chartID, true);
   CD_Request request;
   CM_DeleteContextBuildBaseRequest(request, false);
   Print("[EA|FULL|DELETE] WARN startup recovery pending",
         " | case=", recoveryInfo.caseID,
         " | journal=", request.journalPath,
         " | journal_valid=", (int)recoveryInfo.valid,
         " | archive_touched=0");
   return true;
  }

void CM_DeleteModuleInvalidateEligibility()
  {
   CD_InvalidateDeleteEligibility();
  }

void CM_DeleteModuleUpdateButton(long chartID)
  {
   bool enabled = false;
   if(!CM_DeleteModuleIsRecoveryPending())
     {
      CM_DeleteContextSnapshot snapshot;
      if(CM_DeleteContextCaptureSnapshot(snapshot) == CM_DELETE_CONTEXT_READY)
        {
         CD_Request request;
         CM_DeleteContextBuildRequest(snapshot, false, request);
         bool recoveryDetected = false;
         enabled = CD_QueryDeleteEligibility(
            request, CM_DeleteContextEligibilityKey(snapshot), recoveryDetected);
         if(recoveryDetected)
            CM_DeleteModuleRefreshRecoveryState();
        }
     }
   UI_CM_UpdateDeleteButton(chartID, enabled,
                            CM_DeleteModuleIsRecoveryPending());
  }

bool CM_DeleteModuleHandleIntent(long chartID)
  {
   if(CM_DeleteModuleIsRecoveryPending())
     {
      CD_RecoveryInfo recoveryInfo;
      CD_GetDeleteRecoveryInfo(recoveryInfo);
      if(!recoveryInfo.valid)
        {
         CM_DeleteModulePresentFeedback(
            UI_CM_DELETE_FEEDBACK_RECOVERY_INVALID, "");
         Print("[EA|FULL|DELETE] ERROR recovery unavailable",
               " | reason=", recoveryInfo.reasonCode,
               " | err=", recoveryInfo.lastError,
               " | archive_touched=0");
         return true;
        }
      if(!UI_CM_ConfirmRecoveryAction(recoveryInfo.caseID,
                                      recoveryInfo.targetRows))
        {
         CM_DeleteModulePresentFeedback(
            UI_CM_DELETE_FEEDBACK_RECOVERY_CANCELLED, "");
         Print("[EA|FULL|DELETE] INFO recovery cancelled",
               " | case=", recoveryInfo.caseID,
               " | archive_touched=0");
         return true;
        }

      CD_Request recoveryRequest;
      CM_DeleteContextBuildBaseRequest(recoveryRequest, true);
      CD_Result recoveryResult;
      bool recovered = CD_RecoverDelete(recoveryRequest, recoveryResult);
      CM_DeleteModuleRefreshRecoveryState();
      if(recovered)
        {
         bool emptyStateReady = CM_DeleteModuleEnterSafeState(chartID, false);
         bool catalogReloaded = CM_DeleteRefreshReloadCatalog(chartID);
         CM_DeleteModulePresentFeedback(
            (catalogReloaded && emptyStateReady) ?
            UI_CM_DELETE_FEEDBACK_RECOVERY_SUCCEEDED :
            UI_CM_DELETE_FEEDBACK_RECOVERY_WARNING, "");
        }
      else
        {
         if(CM_DeleteModuleIsRecoveryPending())
            CM_DeleteModuleEnterSafeState(chartID, true);
         CM_DeleteModulePresentFeedback(
            CM_DeleteModuleFailureFeedbackCode(recoveryResult),
            recoveryResult.statusCode);
        }
      Print("[EA|FULL|DELETE] ", recovered ? "INFO" : "ERROR",
            " recovery result | case=", recoveryResult.caseID,
            " | status=", recoveryResult.statusCode,
            " | reason=", recoveryResult.reasonCode,
            " | restored=", (int)recoveryResult.restored,
            " | recovery_pending=", (int)recoveryResult.recoveryPending,
            " | err=", recoveryResult.lastError,
            " | archive_touched=", (int)recoveryResult.archiveTouched);
      return true;
     }

   CM_DeleteContextSnapshot snapshot;
   int hostStatus = CM_DeleteContextCaptureSnapshot(snapshot);
   if(hostStatus == CM_DELETE_CONTEXT_NOT_READY)
     {
      CM_DeleteModulePresentFeedback(
         UI_CM_DELETE_FEEDBACK_NOT_DISPLAYED, "");
      Print("[EA|FULL|DELETE] WARN delete intent rejected",
            " | case=", snapshot.activeCaseID,
            " | catalog_ready=", (int)snapshot.catalogReady,
            " | catalog_index=", snapshot.catalogIndex,
            " | type_dirty=", (int)snapshot.caseTypeDirty,
            " | standardity_dirty=", (int)snapshot.standardityDirty,
            " | archive_touched=0");
      return true;
     }
   if(hostStatus == CM_DELETE_CONTEXT_IDENTITY_CONFLICT)
     {
      CM_DeleteModulePresentFeedback(
         UI_CM_DELETE_FEEDBACK_HOST_IDENTITY_CONFLICT, "");
      Print("[EA|FULL|DELETE] ERROR host identity conflict",
            " | case=", snapshot.caseID,
            " | catalog=", snapshot.caseType, "/", snapshot.symbol, "/",
            snapshot.timeframe,
            " | active=", snapshot.activeCaseType, "/",
            snapshot.nativeSymbol, "/", snapshot.nativeTimeframe,
            " | archive_touched=0");
      return true;
     }

   CD_Request request;
   CM_DeleteContextBuildRequest(snapshot, false, request);
   CD_Preview preview;
   CD_Result prepareResult;
   if(!CD_PrepareDelete(request, preview, prepareResult))
     {
      if(prepareResult.recoveryPending)
        {
         CM_DeleteModuleRefreshRecoveryState();
         CM_DeleteModuleEnterSafeState(chartID, true);
        }
      CM_DeleteModulePresentFeedback(
         CM_DeleteModuleFailureFeedbackCode(prepareResult),
         prepareResult.statusCode);
      Print("[EA|FULL|DELETE] ERROR preview rejected | case=",
            snapshot.caseID,
            " | status=", prepareResult.statusCode,
            " | reason=", prepareResult.reasonCode,
            " | err=", prepareResult.lastError,
            " | archive_touched=0");
      return true;
     }

   Print("[EA|FULL|DELETE] INFO preview ready | case=", snapshot.caseID,
         " | cases=", preview.targetRows[0],
         " | anchors=", preview.targetRows[1],
         " | key_bars=", preview.targetRows[2],
         " | drawings=", preview.targetRows[3],
         " | regions=", preview.targetRows[4],
         " | semantics=", preview.targetRows[5],
         " | channel_boundaries=", preview.targetRows[6],
         " | manifest=", preview.manifestFingerprint,
         " | archive_touched=0");
   if(!UI_CM_ConfirmDeleteAction(preview.caseID, preview.caseType,
                                 preview.symbol, preview.timeframe,
                                 preview.targetRows))
     {
      CD_Result cancelled;
      CD_CancelDelete(request, preview, cancelled);
      CM_DeleteModulePresentFeedback(
         UI_CM_DELETE_FEEDBACK_DELETE_CANCELLED, "");
      Print("[EA|FULL|DELETE] INFO delete cancelled | case=",
            snapshot.caseID,
            " | status=", cancelled.statusCode,
            " | archive_touched=0");
      return true;
     }

   request.formalDeleteAuthorized = true;
   CD_Result commitResult;
   bool deleted = CD_CommitDelete(request, preview, commitResult);
   CM_DeleteModuleRefreshRecoveryState();
   if(deleted)
     {
      bool emptyStateReady = CM_DeleteModuleEnterSafeState(chartID, false);
      bool catalogReloaded = CM_DeleteRefreshReloadCatalog(chartID);
      CM_DeleteModulePresentFeedback(
         (catalogReloaded && emptyStateReady) ?
         UI_CM_DELETE_FEEDBACK_DELETE_SUCCEEDED :
         UI_CM_DELETE_FEEDBACK_DELETE_WARNING, "");
     }
   else
     {
      if(CM_DeleteModuleIsRecoveryPending())
         CM_DeleteModuleEnterSafeState(chartID, true);
      CM_DeleteModulePresentFeedback(
         CM_DeleteModuleFailureFeedbackCode(commitResult),
         commitResult.statusCode);
     }
   Print("[EA|FULL|DELETE] ", deleted ? "INFO" : "ERROR",
         " commit result | case=", snapshot.caseID,
         " | status=", commitResult.statusCode,
         " | reason=", commitResult.reasonCode,
         " | restored=", (int)commitResult.restored,
         " | recovery_pending=", (int)commitResult.recoveryPending,
         " | cleanup_complete=", (int)commitResult.cleanupComplete,
         " | err=", commitResult.lastError,
         " | archive_touched=", (int)commitResult.archiveTouched);
   return true;
  }

bool CM_DeleteModuleHandleRecoveryGate(long chartID,
                                       int eventID,
                                       string objectName)
  {
   if(!CM_DeleteModuleIsRecoveryPending()) return false;
   int actionCode = UI_CM_DELETE_ACTION_NONE;
   if(eventID == CHARTEVENT_OBJECT_CLICK &&
      UI_CM_RouteDeleteAction(objectName, actionCode) &&
      actionCode == UI_CM_DELETE_ACTION_REQUEST)
     {
      CM_DeleteModuleHandleIntent(chartID);
      ChartRedraw(0);
      return true;
     }
   if(eventID == CHARTEVENT_OBJECT_CLICK ||
      eventID == CHARTEVENT_OBJECT_ENDEDIT ||
      eventID == CHARTEVENT_CLICK || eventID == CHARTEVENT_KEYDOWN)
      CM_DeleteModulePresentFeedback(
         UI_CM_DELETE_FEEDBACK_RECOVERY_BLOCKED, "");
   return true;
  }

bool CM_DeleteModuleTryHandleAction(long chartID, string objectName)
  {
   int actionCode = UI_CM_DELETE_ACTION_NONE;
   if(!UI_CM_RouteDeleteAction(objectName, actionCode) ||
      actionCode != UI_CM_DELETE_ACTION_REQUEST)
      return false;
   CM_DeleteModuleHandleIntent(chartID);
   return true;
  }

#endif
