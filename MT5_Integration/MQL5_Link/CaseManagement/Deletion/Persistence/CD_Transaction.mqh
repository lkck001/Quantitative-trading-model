#ifndef CD_TRANSACTION_MQH
#define CD_TRANSACTION_MQH

#include "CD_ArchiveStore.mqh"

void CD_CopyPreviewRowsToResult(CD_Preview &preview, CD_Result &result)
  {
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
      result.targetRows[index] = preview.targetRows[index];
  }

bool CD_CleanupArtifacts(CD_Request &request,
                         bool includeStages,
                         bool includeBackups,
                         int &lastError)
  {
   lastError = 0;
   bool cleaned = true;
   for(int index = 0; index < CD_RESOURCE_COUNT; index++)
     {
      string resourcePath = CD_ResourcePath(request, index);
      int currentError = 0;
      if(includeStages &&
         !CD_DeleteFileIfPresent(CD_StagePath(resourcePath), currentError))
        {
         cleaned = false;
         if(lastError == 0) lastError = currentError;
        }
      currentError = 0;
      if(includeBackups &&
         !CD_DeleteFileIfPresent(CD_BackupPath(resourcePath), currentError))
        {
         cleaned = false;
         if(lastError == 0) lastError = currentError;
        }
     }
   if(includeStages)
     {
      int journalStageError = 0;
      if(!CD_DeleteFileIfPresent(CD_JournalStagePath(request.journalPath),
                                 journalStageError))
        {
         cleaned = false;
         if(lastError == 0) lastError = journalStageError;
        }
     }
   return cleaned;
  }

bool CD_DeleteJournalFiles(CD_Request &request, int &lastError)
  {
   lastError = 0;
   int currentError = 0;
   if(!CD_DeleteFileIfPresent(request.journalPath, currentError))
     {
      lastError = currentError;
      return false;
     }
   if(!CD_DeleteFileIfPresent(CD_JournalStagePath(request.journalPath),
                              currentError))
     {
      lastError = currentError;
      return false;
     }
   return true;
  }

string CD_TransactionLockPath(CD_Request &request)
  {
   return request.journalPath + ".cd_lock";
  }

bool CD_AcquireTransactionLock(CD_Request &request,
                               int &lockHandle,
                               int &lastError)
  {
   lockHandle = INVALID_HANDLE;
   lastError = 0;
   ResetLastError();
   lockHandle = FileOpen(CD_TransactionLockPath(request),
                         FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(lockHandle != INVALID_HANDLE) return true;
   lastError = GetLastError();
   return false;
  }

bool CD_ReleaseTransactionLock(CD_Request &request,
                               int &lockHandle,
                               int &lastError)
  {
   lastError = 0;
   if(lockHandle != INVALID_HANDLE)
     {
      FileClose(lockHandle);
      lockHandle = INVALID_HANDLE;
     }
   return CD_DeleteFileIfPresent(CD_TransactionLockPath(request), lastError);
  }

bool CD_SourceMatchesPreview(CD_Request &request,
                             CD_Preview &preview,
                             CD_Result &result)
  {
   CD_Preview current;
   CD_Result currentResult;
   CD_ResetResult(currentResult);
   if(!CD_BuildPreview(request, current, currentResult))
     {
      result.statusCode = CD_STATUS_STALE_PREVIEW;
      result.reasonCode = CD_REASON_PREVIEW_CHANGED;
      result.lastError = currentResult.lastError;
      return false;
     }
   if(CD_PreviewsEquivalent(current, preview)) return true;
   result.statusCode = CD_STATUS_STALE_PREVIEW;
   result.reasonCode = CD_REASON_PREVIEW_CHANGED;
   result.manifestFingerprint = current.manifestFingerprint;
   return false;
  }

bool CD_StageDeleteWriteSet(CD_Request &request,
                            CD_Preview &preview,
                            CD_ArchiveInventory &sourceArchives[],
                            CD_SequenceInventory &sourceSequence,
                            string &stageFingerprints[],
                            string &sequenceStageFingerprint,
                            CD_Result &result)
  {
   if(!CD_BuildArchiveSet(request, sourceArchives, sourceSequence, result))
     {
      result.statusCode = CD_STATUS_STALE_PREVIEW;
      result.reasonCode = CD_REASON_PREVIEW_CHANGED;
      return false;
     }
   string manifest = CD_BuildManifestFingerprint(request, sourceArchives,
                                                  sourceSequence);
   if(manifest != preview.manifestFingerprint)
     {
      result.statusCode = CD_STATUS_STALE_PREVIEW;
      result.reasonCode = CD_REASON_PREVIEW_CHANGED;
      result.manifestFingerprint = manifest;
      return false;
     }

   ArrayResize(stageFingerprints, CD_ARCHIVE_COUNT);
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
     {
      string stagePath = CD_StagePath(CD_ArchivePath(request, index));
      int stageError = 0;
      if(!CD_WriteArchiveStage(CD_ArchivePath(request, index), stagePath,
                               request.caseID, stageError))
        {
         result.statusCode = CD_STATUS_STAGE_FAILED;
         result.reasonCode = CD_REASON_STAGE_WRITE_FAILED;
         result.lastError = stageError;
         return false;
        }
      CD_ArchiveInventory stageInventory;
      if(!CD_VerifyArchiveStage(stagePath, request.caseID,
                                sourceArchives[index], stageInventory,
                                stageError))
        {
         result.statusCode = CD_STATUS_STAGE_FAILED;
         result.reasonCode = CD_REASON_STAGE_VERIFY_FAILED;
         result.lastError = stageError;
         return false;
        }
      stageFingerprints[index] = stageInventory.contentFingerprint;
     }

   int caseYear = 0;
   int caseSequence = 0;
   if(!CD_ParseCaseIdentity(request.caseID, caseYear, caseSequence))
     {
      result.statusCode = CD_STATUS_STALE_PREVIEW;
      result.reasonCode = CD_REASON_PREVIEW_CHANGED;
      return false;
     }
   int sequenceHighWater = sourceSequence.highWater;
   if(caseSequence > sequenceHighWater)
      sequenceHighWater = caseSequence;
   string updatedAt = TimeToString(TimeLocal(),
                                   TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   int sequenceError = 0;
   string sequenceStagePath = CD_StagePath(request.sequencePath);
   if(!CD_WriteSequenceStage(request.sequencePath, sequenceStagePath,
                             caseYear, sequenceHighWater,
                             updatedAt, sequenceError))
     {
      result.statusCode = CD_STATUS_STAGE_FAILED;
      result.reasonCode = CD_REASON_STAGE_WRITE_FAILED;
      result.lastError = sequenceError;
      return false;
     }
   CD_SequenceInventory stageSequence;
   if(!CD_VerifySequenceStage(sequenceStagePath, caseYear,
                              sequenceHighWater, sourceSequence,
                              stageSequence, sequenceError))
     {
      result.statusCode = CD_STATUS_STAGE_FAILED;
      result.reasonCode = CD_REASON_STAGE_VERIFY_FAILED;
      result.lastError = sequenceError;
      return false;
     }
   sequenceStageFingerprint = stageSequence.contentFingerprint;
   return true;
  }

bool CD_PrepareBackups(CD_Request &request,
                       CD_ArchiveInventory &sourceArchives[],
                       CD_SequenceInventory &sourceSequence,
                       int &existedMask,
                       CD_Result &result)
  {
   existedMask = 0;
   int caseYear = 0;
   int caseSequence = 0;
   if(!CD_ParseCaseIdentity(request.caseID, caseYear, caseSequence))
     {
      result.statusCode = CD_STATUS_STALE_PREVIEW;
      result.reasonCode = CD_REASON_PREVIEW_CHANGED;
      return false;
     }
   for(int index = 0; index < CD_RESOURCE_COUNT; index++)
     {
      string resourcePath = CD_ResourcePath(request, index);
      string backupPath = CD_BackupPath(resourcePath);
      int backupError = 0;
      if(!CD_DeleteFileIfPresent(backupPath, backupError))
        {
         result.statusCode = CD_STATUS_STAGE_FAILED;
         result.reasonCode = CD_REASON_BACKUP_FAILED;
         result.lastError = backupError;
         return false;
        }
      bool existed = index < CD_ARCHIVE_COUNT ?
                     sourceArchives[index].exists : sourceSequence.exists;
      if(!existed) continue;
      existedMask |= (1 << index);
      if(!CD_CopyFileReplace(resourcePath, backupPath, backupError))
        {
         result.statusCode = CD_STATUS_STAGE_FAILED;
         result.reasonCode = CD_REASON_BACKUP_FAILED;
         result.lastError = backupError;
         return false;
        }
      if(index < CD_ARCHIVE_COUNT)
        {
         CD_ArchiveInventory backupInventory;
         if(!CD_ReadArchiveInventory(backupPath, request.caseID,
                                     backupInventory) ||
            backupInventory.contentFingerprint !=
            sourceArchives[index].contentFingerprint)
           {
            result.statusCode = CD_STATUS_STAGE_FAILED;
            result.reasonCode = CD_REASON_BACKUP_FAILED;
            result.lastError = backupInventory.lastError;
            return false;
           }
        }
      else
        {
         CD_SequenceInventory backupSequence;
         if(!CD_ReadSequenceInventory(backupPath, caseYear,
                                      backupSequence) ||
            backupSequence.contentFingerprint !=
            sourceSequence.contentFingerprint)
           {
            result.statusCode = CD_STATUS_STAGE_FAILED;
            result.reasonCode = CD_REASON_BACKUP_FAILED;
            result.lastError = backupSequence.lastError;
            return false;
           }
        }
     }
   return true;
  }

bool CD_ValidateRecoveryBackups(CD_Request &request,
                                CD_RecoveryInfo &recovery,
                                CD_Result &result)
  {
   CD_Request backupRequest = request;
   backupRequest.casesPath = CD_BackupPath(request.casesPath);
   backupRequest.anchorsPath = CD_BackupPath(request.anchorsPath);
   backupRequest.keyBarsPath = CD_BackupPath(request.keyBarsPath);
   backupRequest.drawingsPath = CD_BackupPath(request.drawingsPath);
   backupRequest.regionsPath = CD_BackupPath(request.regionsPath);
   backupRequest.semanticsPath = CD_BackupPath(request.semanticsPath);
   backupRequest.channelBoundariesPath =
      CD_BackupPath(request.channelBoundariesPath);
   backupRequest.sequencePath = CD_BackupPath(request.sequencePath);

   CD_ArchiveInventory archives[];
   CD_SequenceInventory sequence;
   CD_Result validation;
   CD_ResetResult(validation);
   if(!CD_BuildArchiveSet(backupRequest, archives, sequence, validation))
     {
      result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
      result.reasonCode = CD_REASON_ROLLBACK_FAILED;
      result.recoveryPending = true;
      result.lastError = validation.lastError;
      return false;
     }

   bool sequenceExisted =
      ((recovery.existedMask & (1 << CD_RESOURCE_SEQUENCE)) != 0);
   if(sequence.exists != sequenceExisted)
     {
      result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
      result.reasonCode = CD_REASON_ROLLBACK_FAILED;
      result.recoveryPending = true;
      return false;
     }
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
     {
      if(archives[index].targetRowCount != recovery.targetRows[index])
        {
         result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
         result.reasonCode = CD_REASON_ROLLBACK_FAILED;
         result.recoveryPending = true;
         return false;
        }
      archives[index].path = CD_ArchivePath(request, index);
     }
   sequence.path = request.sequencePath;
   string backupManifest = CD_BuildManifestFingerprint(request, archives,
                                                        sequence);
   if(backupManifest != recovery.beforeManifest)
     {
      result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
      result.reasonCode = CD_REASON_ROLLBACK_FAILED;
      result.recoveryPending = true;
      result.manifestFingerprint = backupManifest;
      return false;
     }
   return true;
  }

bool CD_RestoreWriteSet(CD_Request &request,
                        CD_RecoveryInfo &recovery,
                        CD_Result &result)
  {
   if(!CD_ValidateRecoveryBackups(request, recovery, result)) return false;
   bool restored = true;
   for(int index = 0; index < CD_RESOURCE_COUNT; index++)
     {
      string resourcePath = CD_ResourcePath(request, index);
      int restoreError = 0;
      bool existed = ((recovery.existedMask & (1 << index)) != 0);
      if(existed)
        {
         string backupPath = CD_BackupPath(resourcePath);
         if(!FileIsExist(backupPath, 0) ||
            !CD_CopyFileReplace(backupPath, resourcePath, restoreError))
            restored = false;
        }
      else if(!CD_DeleteFileIfPresent(resourcePath, restoreError))
         restored = false;
      if(!restored && result.lastError == 0)
         result.lastError = restoreError;
     }
   if(!restored)
     {
      result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
      result.reasonCode = CD_REASON_ROLLBACK_FAILED;
      result.recoveryPending = true;
      return false;
     }

   CD_Preview restoredPreview;
   CD_Result restoredResult;
   CD_ResetResult(restoredResult);
   if(!CD_BuildPreview(request, restoredPreview, restoredResult) ||
      restoredPreview.manifestFingerprint != recovery.beforeManifest)
     {
      result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
      result.reasonCode = CD_REASON_ROLLBACK_FAILED;
      result.lastError = restoredResult.lastError;
      result.recoveryPending = true;
      return false;
     }

   int journalError = 0;
   if(!CD_DeleteJournalFiles(request, journalError))
     {
      result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
      result.reasonCode = CD_REASON_ROLLBACK_FAILED;
      result.lastError = journalError;
      result.recoveryPending = true;
      return false;
     }
   int cleanupError = 0;
   bool cleanupComplete = CD_CleanupArtifacts(request, true, true,
                                               cleanupError);
   result.success = true;
   result.restored = true;
   result.archiveTouched = true;
   result.recoveryPending = false;
   result.cleanupComplete = cleanupComplete;
   result.statusCode = CD_STATUS_ROLLED_BACK;
   result.reasonCode = CD_REASON_ROLLBACK_COMPLETE;
   result.lastError = cleanupComplete ? 0 : cleanupError;
   return true;
  }

bool CD_VerifyCommittedWriteSet(CD_Request &request,
                                CD_Preview &preview,
                                string &stageFingerprints[],
                                string sequenceStageFingerprint,
                                CD_Result &result)
  {
   int caseYear = 0;
   int caseSequence = 0;
   if(!CD_ParseCaseIdentity(request.caseID, caseYear, caseSequence))
     {
      result.statusCode = CD_STATUS_COMMIT_FAILED;
      result.reasonCode = CD_REASON_COMMIT_VERIFY_FAILED;
      return false;
     }
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
     {
      CD_ArchiveInventory committed;
      if(!CD_ReadArchiveInventory(CD_ArchivePath(request, index),
                                  request.caseID, committed) ||
         committed.targetRowCount != 0 ||
         committed.dataRowCount != preview.totalRows[index] -
                                   preview.targetRows[index] ||
         committed.contentFingerprint != stageFingerprints[index])
        {
         result.statusCode = CD_STATUS_COMMIT_FAILED;
         result.reasonCode = CD_REASON_COMMIT_VERIFY_FAILED;
         result.lastError = committed.lastError;
         return false;
        }
     }
   CD_SequenceInventory committedSequence;
   if(!CD_ReadSequenceInventory(request.sequencePath, caseYear,
                                committedSequence) ||
      committedSequence.highWater < caseSequence ||
      committedSequence.contentFingerprint != sequenceStageFingerprint)
     {
      result.statusCode = CD_STATUS_COMMIT_FAILED;
      result.reasonCode = CD_REASON_COMMIT_VERIFY_FAILED;
      result.lastError = committedSequence.lastError;
      return false;
     }
   return true;
  }

bool CD_PrepareDeleteInternal(CD_Request &request,
                              CD_Preview &preview,
                              CD_Result &result)
  {
   CD_ResetResult(result);
   CD_ResetPreview(preview);
   if(!CD_ValidateRequest(request, true, false, result)) return false;
   CD_RecoveryInfo recovery;
   bool journalValid = CD_ReadJournal(request, recovery);
   if(recovery.pending)
     {
      result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
      result.reasonCode = journalValid ? CD_REASON_RECOVERY_PENDING :
                                         CD_REASON_RECOVERY_JOURNAL_INVALID;
      result.recoveryPending = true;
      result.lastError = recovery.lastError;
      return false;
     }
   return CD_BuildPreview(request, preview, result);
  }

bool CD_CommitDeleteLocked(CD_Request &request,
                           CD_Preview &preview,
                           CD_Result &result)
  {
   CD_RecoveryInfo existingRecovery;
   if(!CD_ReadJournal(request, existingRecovery) || existingRecovery.pending)
     {
      result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
      result.reasonCode = existingRecovery.valid ? CD_REASON_RECOVERY_PENDING :
                                                   CD_REASON_RECOVERY_JOURNAL_INVALID;
      result.recoveryPending = true;
      result.lastError = existingRecovery.lastError;
      return false;
     }
   if(!CD_SourceMatchesPreview(request, preview, result)) return false;

   CD_ArchiveInventory sourceArchives[];
   CD_SequenceInventory sourceSequence;
   string stageFingerprints[];
   string sequenceStageFingerprint = "";
   if(!CD_StageDeleteWriteSet(request, preview, sourceArchives,
                              sourceSequence, stageFingerprints,
                              sequenceStageFingerprint, result))
     {
      CD_SourceMatchesPreview(request, preview, result);
      int cleanupError = 0;
      CD_CleanupArtifacts(request, true, false, cleanupError);
      return false;
     }
   if(!CD_SourceMatchesPreview(request, preview, result))
     {
      int cleanupError = 0;
      CD_CleanupArtifacts(request, true, false, cleanupError);
      return false;
     }

   int existedMask = 0;
   if(!CD_PrepareBackups(request, sourceArchives, sourceSequence,
                         existedMask, result))
     {
      CD_SourceMatchesPreview(request, preview, result);
      int cleanupError = 0;
      CD_CleanupArtifacts(request, true, true, cleanupError);
      return false;
     }
   if(!CD_SourceMatchesPreview(request, preview, result))
     {
      int cleanupError = 0;
      CD_CleanupArtifacts(request, true, true, cleanupError);
      return false;
     }

   int journalError = 0;
   if(!CD_WriteJournal(request, preview, existedMask, journalError))
     {
      result.statusCode = CD_STATUS_STAGE_FAILED;
      result.reasonCode = CD_REASON_JOURNAL_FAILED;
      result.lastError = journalError;
      int journalCleanupError = 0;
      if(CD_DeleteJournalFiles(request, journalCleanupError))
        {
         int cleanupError = 0;
         CD_CleanupArtifacts(request, true, true, cleanupError);
        }
      else
        {
         result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
         result.reasonCode = CD_REASON_RECOVERY_PENDING;
         result.lastError = journalCleanupError;
         result.recoveryPending = true;
        }
      return false;
     }

   CD_RecoveryInfo recovery;
   if(!CD_ReadJournal(request, recovery) ||
      !CD_JournalMatchesPreview(recovery, preview, existedMask))
     {
      result.statusCode = CD_STATUS_STAGE_FAILED;
      result.reasonCode = CD_REASON_JOURNAL_FAILED;
      result.lastError = recovery.lastError;
      int journalCleanupError = 0;
      if(CD_DeleteJournalFiles(request, journalCleanupError))
        {
         int cleanupError = 0;
         CD_CleanupArtifacts(request, true, true, cleanupError);
        }
      else
        {
         result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
         result.reasonCode = CD_REASON_RECOVERY_PENDING;
         result.lastError = journalCleanupError;
         result.recoveryPending = true;
        }
      return false;
     }
   if(!CD_SourceMatchesPreview(request, preview, result))
     {
      int journalCleanupError = 0;
      if(CD_DeleteJournalFiles(request, journalCleanupError))
        {
         int cleanupError = 0;
         CD_CleanupArtifacts(request, true, true, cleanupError);
        }
      else
        {
         result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
         result.reasonCode = CD_REASON_RECOVERY_PENDING;
         result.lastError = journalCleanupError;
         result.recoveryPending = true;
        }
      return false;
     }
   bool copied = true;
   for(int index = 0; index < CD_RESOURCE_COUNT; index++)
     {
      int copyError = 0;
      if(!CD_CopyFileReplace(CD_StagePath(CD_ResourcePath(request, index)),
                             CD_ResourcePath(request, index), copyError))
        {
         copied = false;
         result.lastError = copyError;
         break;
        }
      result.archiveTouched = true;
     }
   if(!copied)
     {
      result.statusCode = CD_STATUS_COMMIT_FAILED;
      result.reasonCode = CD_REASON_COMMIT_COPY_FAILED;
      CD_RestoreWriteSet(request, recovery, result);
      if(result.restored) result.success = false;
      return false;
     }
   if(!CD_VerifyCommittedWriteSet(request, preview, stageFingerprints,
                                  sequenceStageFingerprint, result))
     {
      CD_RestoreWriteSet(request, recovery, result);
      if(result.restored) result.success = false;
      return false;
     }

   if(!CD_DeleteJournalFiles(request, journalError))
     {
      result.statusCode = CD_STATUS_COMMIT_FAILED;
      result.reasonCode = CD_REASON_JOURNAL_FAILED;
      result.lastError = journalError;
      CD_RestoreWriteSet(request, recovery, result);
      if(result.restored) result.success = false;
      return false;
     }

   int cleanupError = 0;
   bool cleanupComplete = CD_CleanupArtifacts(request, true, true,
                                               cleanupError);
   result.success = true;
   result.archiveTouched = true;
   result.restored = false;
   result.recoveryPending = false;
   result.cleanupComplete = cleanupComplete;
   result.statusCode = CD_STATUS_DELETED;
   result.reasonCode = cleanupComplete ? CD_REASON_DELETED :
                                         CD_REASON_DELETED_CLEANUP_WARNING;
   result.lastError = cleanupComplete ? 0 : cleanupError;
   return true;
  }

bool CD_CommitDeleteInternal(CD_Request &request,
                             CD_Preview &preview,
                             CD_Result &result)
  {
   CD_ResetResult(result);
   result.caseID = request.caseID;
   result.manifestFingerprint = preview.manifestFingerprint;
   CD_CopyPreviewRowsToResult(preview, result);
   if(!CD_ValidateRequest(request, true, true, result) ||
      !CD_PreviewMatchesRequest(request, preview))
     {
      if(result.statusCode == CD_STATUS_READY)
        {
         result.statusCode = CD_STATUS_STALE_PREVIEW;
         result.reasonCode = CD_REASON_PREVIEW_CHANGED;
        }
      return false;
     }

   int lockHandle = INVALID_HANDLE;
   int lockError = 0;
   if(!CD_AcquireTransactionLock(request, lockHandle, lockError))
     {
      result.statusCode = CD_STATUS_TRANSACTION_BUSY;
      result.reasonCode = CD_REASON_TRANSACTION_BUSY;
      result.lastError = lockError;
      return false;
     }
   bool deleted = CD_CommitDeleteLocked(request, preview, result);
   int releaseError = 0;
   bool lockReleased = CD_ReleaseTransactionLock(request, lockHandle,
                                                  releaseError);
   if(!lockReleased)
     {
      if(deleted)
        {
         result.cleanupComplete = false;
         result.reasonCode = CD_REASON_DELETED_CLEANUP_WARNING;
        }
      if(result.lastError == 0) result.lastError = releaseError;
     }
   return deleted;
  }

bool CD_DetectRecoveryInternal(CD_Request &request,
                               CD_RecoveryInfo &info)
  {
   CD_Result validation;
   CD_ResetResult(validation);
   CD_ResetRecoveryInfo(info);
   if(!CD_ValidateRequest(request, false, false, validation))
     {
      info.reasonCode = validation.reasonCode;
      return false;
     }
   return CD_ReadJournal(request, info);
  }

bool CD_RecoverDeleteLocked(CD_Request &request,
                            CD_Result &result)
  {
   CD_RecoveryInfo recovery;
   if(!CD_ReadJournal(request, recovery) || !recovery.pending ||
      !recovery.valid)
     {
      result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
      result.reasonCode = CD_REASON_RECOVERY_JOURNAL_INVALID;
      result.recoveryPending = recovery.pending;
      result.lastError = recovery.lastError;
      return false;
     }

   request.caseID = recovery.caseID;
   request.caseType = recovery.caseType;
   request.symbol = recovery.symbol;
   request.timeframe = recovery.timeframe;
   if(!CD_ValidateRequest(request, true, false, result))
     {
      result.statusCode = CD_STATUS_RECOVERY_REQUIRED;
      result.reasonCode = CD_REASON_RECOVERY_JOURNAL_INVALID;
      result.recoveryPending = true;
      return false;
     }
   result.caseID = recovery.caseID;
   result.manifestFingerprint = recovery.beforeManifest;
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
      result.targetRows[index] = recovery.targetRows[index];
   return CD_RestoreWriteSet(request, recovery, result);
  }

bool CD_RecoverDeleteInternal(CD_Request &request,
                              CD_Result &result)
  {
   CD_ResetResult(result);
   if(!CD_ValidateRequest(request, false, true, result)) return false;
   int lockHandle = INVALID_HANDLE;
   int lockError = 0;
   if(!CD_AcquireTransactionLock(request, lockHandle, lockError))
     {
      result.statusCode = CD_STATUS_TRANSACTION_BUSY;
      result.reasonCode = CD_REASON_TRANSACTION_BUSY;
      result.lastError = lockError;
      return false;
     }
   bool restored = CD_RecoverDeleteLocked(request, result);
   int releaseError = 0;
   bool lockReleased = CD_ReleaseTransactionLock(request, lockHandle,
                                                  releaseError);
   if(!lockReleased)
     {
      if(restored) result.cleanupComplete = false;
      if(result.lastError == 0) result.lastError = releaseError;
     }
   return restored;
  }

bool CD_GetSequenceHighWaterInternal(string sequencePath,
                                     int year,
                                     int &highWater,
                                     string &reasonCode,
                                     int &lastError)
  {
   highWater = 0;
   reasonCode = "";
   lastError = 0;
   CD_SequenceInventory inventory;
   if(!CD_ReadSequenceInventory(sequencePath, year, inventory))
     {
      reasonCode = inventory.reasonCode;
      lastError = inventory.lastError;
      return false;
     }
   highWater = inventory.highWater;
   return true;
  }

#endif
