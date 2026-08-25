#ifndef CD_TYPES_MQH
#define CD_TYPES_MQH

#define CD_CONTRACT_VERSION "CASE_DELETION_CONTRACT_V1"
#define CD_TRANSACTION_VERSION "CASE_DELETION_TRANSACTION_V1"
#define CD_SEQUENCE_HEADER "year,last_sequence,updated_at"

#define CD_ARCHIVE_COUNT 7
#define CD_RESOURCE_COUNT 8

#define CD_ARCHIVE_CASES 0
#define CD_ARCHIVE_ANCHORS 1
#define CD_ARCHIVE_KEY_BARS 2
#define CD_ARCHIVE_DRAWINGS 3
#define CD_ARCHIVE_REGIONS 4
#define CD_ARCHIVE_SEMANTICS 5
#define CD_ARCHIVE_CHANNEL_BOUNDARIES 6
#define CD_RESOURCE_SEQUENCE 7

#define CD_STATUS_READY "READY"
#define CD_STATUS_CANCELLED "CANCELLED"
#define CD_STATUS_NOT_FORMAL_CASE "NOT_FORMAL_CASE"
#define CD_STATUS_IDENTITY_CONFLICT "IDENTITY_CONFLICT"
#define CD_STATUS_STALE_PREVIEW "STALE_PREVIEW"
#define CD_STATUS_ARCHIVE_MISSING "ARCHIVE_MISSING"
#define CD_STATUS_STAGE_FAILED "STAGE_FAILED"
#define CD_STATUS_COMMIT_FAILED "COMMIT_FAILED"
#define CD_STATUS_ROLLED_BACK "ROLLED_BACK"
#define CD_STATUS_RECOVERY_REQUIRED "RECOVERY_REQUIRED"
#define CD_STATUS_TRANSACTION_BUSY "TRANSACTION_BUSY"
#define CD_STATUS_DELETED "DELETED"

#define CD_REASON_READY "DELETE_PREVIEW_READY"
#define CD_REASON_CANCELLED "DELETE_NOT_CONFIRMED"
#define CD_REASON_REQUEST_INVALID "DELETE_REQUEST_INVALID"
#define CD_REASON_NOT_AUTHORIZED "FORMAL_DELETE_NOT_AUTHORIZED"
#define CD_REASON_CASE_MISSING "FORMAL_CASE_RECORD_MISSING"
#define CD_REASON_CASE_DUPLICATE "FORMAL_CASE_RECORD_NOT_UNIQUE"
#define CD_REASON_IDENTITY_MISMATCH "FORMAL_CASE_IDENTITY_MISMATCH"
#define CD_REASON_CHILD_IDENTITY_MISMATCH "CHILD_ARCHIVE_IDENTITY_MISMATCH"
#define CD_REASON_ARCHIVE_UNAVAILABLE "FORMAL_ARCHIVE_UNAVAILABLE"
#define CD_REASON_ARCHIVE_INVALID "FORMAL_ARCHIVE_INVALID"
#define CD_REASON_SEQUENCE_INVALID "CASE_SEQUENCE_ARCHIVE_INVALID"
#define CD_REASON_PREVIEW_CHANGED "DELETE_PREVIEW_CHANGED"
#define CD_REASON_STAGE_WRITE_FAILED "DELETE_STAGE_WRITE_FAILED"
#define CD_REASON_STAGE_VERIFY_FAILED "DELETE_STAGE_VERIFY_FAILED"
#define CD_REASON_BACKUP_FAILED "DELETE_BACKUP_FAILED"
#define CD_REASON_JOURNAL_FAILED "DELETE_JOURNAL_FAILED"
#define CD_REASON_COMMIT_COPY_FAILED "DELETE_COMMIT_COPY_FAILED"
#define CD_REASON_COMMIT_VERIFY_FAILED "DELETE_COMMIT_VERIFY_FAILED"
#define CD_REASON_ROLLBACK_COMPLETE "DELETE_ROLLBACK_COMPLETE"
#define CD_REASON_ROLLBACK_FAILED "DELETE_ROLLBACK_FAILED"
#define CD_REASON_RECOVERY_PENDING "DELETE_RECOVERY_PENDING"
#define CD_REASON_RECOVERY_JOURNAL_INVALID "DELETE_RECOVERY_JOURNAL_INVALID"
#define CD_REASON_TRANSACTION_BUSY "DELETE_TRANSACTION_BUSY"
#define CD_REASON_DELETED "FORMAL_CASE_DELETED"
#define CD_REASON_DELETED_CLEANUP_WARNING "FORMAL_CASE_DELETED_TEMP_CLEANUP_WARNING"

struct CD_Request
  {
   string caseID;
   string caseType;
   string symbol;
   string timeframe;
   string casesPath;
   string anchorsPath;
   string keyBarsPath;
   string drawingsPath;
   string regionsPath;
   string semanticsPath;
   string channelBoundariesPath;
   string sequencePath;
   string journalPath;
   bool formalDeleteAuthorized;
  };

struct CD_ArchiveInventory
  {
   bool valid;
   bool exists;
   string path;
   string header;
   int logicalLineCount;
   int dataRowCount;
   int targetRowCount;
   string contentFingerprint;
   string retainedFingerprint;
   string targetFingerprint;
   string targetCaseType;
   string targetSymbol;
   string targetTimeframe;
   int lastError;
   string reasonCode;
  };

struct CD_SequenceInventory
  {
   bool valid;
   bool exists;
   string path;
   int targetYear;
   int highWater;
   int logicalLineCount;
   int dataRowCount;
   int targetRowCount;
   string contentFingerprint;
   string retainedFingerprint;
   int lastError;
   string reasonCode;
  };

struct CD_Preview
  {
   bool ready;
   string contractVersion;
   string caseID;
   string caseType;
   string symbol;
   string timeframe;
   int caseYear;
   int caseSequence;
   int targetRows[];
   int totalRows[];
   string archiveFingerprints[];
   string retainedFingerprints[];
   bool sequenceExists;
   int sequenceHighWater;
   string sequenceFingerprint;
   string manifestFingerprint;
   string transactionToken;
  };

struct CD_Result
  {
   bool success;
   bool archiveTouched;
   bool restored;
   bool recoveryPending;
   bool cleanupComplete;
   string statusCode;
   string reasonCode;
   string caseID;
   string manifestFingerprint;
   int targetRows[];
   int lastError;
  };

struct CD_RecoveryInfo
  {
   bool pending;
   bool valid;
   string transactionVersion;
   string state;
   string token;
   string caseID;
   string caseType;
   string symbol;
   string timeframe;
   string beforeManifest;
   int existedMask;
   int targetRows[];
   int lastError;
   string reasonCode;
  };

void CD_ResetRequest(CD_Request &request)
  {
   request.caseID = "";
   request.caseType = "";
   request.symbol = "";
   request.timeframe = "";
   request.casesPath = "";
   request.anchorsPath = "";
   request.keyBarsPath = "";
   request.drawingsPath = "";
   request.regionsPath = "";
   request.semanticsPath = "";
   request.channelBoundariesPath = "";
   request.sequencePath = "";
   request.journalPath = "";
   request.formalDeleteAuthorized = false;
  }

void CD_ResetArchiveInventory(CD_ArchiveInventory &inventory)
  {
   inventory.valid = false;
   inventory.exists = false;
   inventory.path = "";
   inventory.header = "";
   inventory.logicalLineCount = 0;
   inventory.dataRowCount = 0;
   inventory.targetRowCount = 0;
   inventory.contentFingerprint = "";
   inventory.retainedFingerprint = "";
   inventory.targetFingerprint = "";
   inventory.targetCaseType = "";
   inventory.targetSymbol = "";
   inventory.targetTimeframe = "";
   inventory.lastError = 0;
   inventory.reasonCode = "";
  }

void CD_ResetSequenceInventory(CD_SequenceInventory &inventory)
  {
   inventory.valid = false;
   inventory.exists = false;
   inventory.path = "";
   inventory.targetYear = 0;
   inventory.highWater = 0;
   inventory.logicalLineCount = 0;
   inventory.dataRowCount = 0;
   inventory.targetRowCount = 0;
   inventory.contentFingerprint = "";
   inventory.retainedFingerprint = "";
   inventory.lastError = 0;
   inventory.reasonCode = "";
  }

void CD_ResetPreview(CD_Preview &preview)
  {
   preview.ready = false;
   preview.contractVersion = CD_CONTRACT_VERSION;
   preview.caseID = "";
   preview.caseType = "";
   preview.symbol = "";
   preview.timeframe = "";
   preview.caseYear = 0;
   preview.caseSequence = 0;
   ArrayResize(preview.targetRows, CD_ARCHIVE_COUNT);
   ArrayResize(preview.totalRows, CD_ARCHIVE_COUNT);
   ArrayResize(preview.archiveFingerprints, CD_ARCHIVE_COUNT);
   ArrayResize(preview.retainedFingerprints, CD_ARCHIVE_COUNT);
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
     {
      preview.targetRows[index] = 0;
      preview.totalRows[index] = 0;
      preview.archiveFingerprints[index] = "";
      preview.retainedFingerprints[index] = "";
     }
   preview.sequenceExists = false;
   preview.sequenceHighWater = 0;
   preview.sequenceFingerprint = "";
   preview.manifestFingerprint = "";
   preview.transactionToken = "";
  }

void CD_ResetResult(CD_Result &result)
  {
   result.success = false;
   result.archiveTouched = false;
   result.restored = false;
   result.recoveryPending = false;
   result.cleanupComplete = true;
   result.statusCode = CD_STATUS_READY;
   result.reasonCode = CD_REASON_READY;
   result.caseID = "";
   result.manifestFingerprint = "";
   ArrayResize(result.targetRows, CD_ARCHIVE_COUNT);
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
      result.targetRows[index] = 0;
   result.lastError = 0;
  }

void CD_ResetRecoveryInfo(CD_RecoveryInfo &info)
  {
   info.pending = false;
   info.valid = false;
   info.transactionVersion = "";
   info.state = "";
   info.token = "";
   info.caseID = "";
   info.caseType = "";
   info.symbol = "";
   info.timeframe = "";
   info.beforeManifest = "";
   info.existedMask = 0;
   ArrayResize(info.targetRows, CD_ARCHIVE_COUNT);
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
      info.targetRows[index] = 0;
   info.lastError = 0;
   info.reasonCode = "";
  }

string CD_ArchivePath(CD_Request &request, int archiveIndex)
  {
   if(archiveIndex == CD_ARCHIVE_CASES) return request.casesPath;
   if(archiveIndex == CD_ARCHIVE_ANCHORS) return request.anchorsPath;
   if(archiveIndex == CD_ARCHIVE_KEY_BARS) return request.keyBarsPath;
   if(archiveIndex == CD_ARCHIVE_DRAWINGS) return request.drawingsPath;
   if(archiveIndex == CD_ARCHIVE_REGIONS) return request.regionsPath;
   if(archiveIndex == CD_ARCHIVE_SEMANTICS) return request.semanticsPath;
   if(archiveIndex == CD_ARCHIVE_CHANNEL_BOUNDARIES)
      return request.channelBoundariesPath;
   return "";
  }

string CD_ArchiveName(int archiveIndex)
  {
   if(archiveIndex == CD_ARCHIVE_CASES) return "CASES";
   if(archiveIndex == CD_ARCHIVE_ANCHORS) return "ANCHORS";
   if(archiveIndex == CD_ARCHIVE_KEY_BARS) return "KEY_BARS";
   if(archiveIndex == CD_ARCHIVE_DRAWINGS) return "DRAWINGS";
   if(archiveIndex == CD_ARCHIVE_REGIONS) return "REGIONS";
   if(archiveIndex == CD_ARCHIVE_SEMANTICS) return "SEMANTICS";
   if(archiveIndex == CD_ARCHIVE_CHANNEL_BOUNDARIES)
      return "CHANNEL_BOUNDARIES";
   return "UNKNOWN";
  }

string CD_ResourcePath(CD_Request &request, int resourceIndex)
  {
   if(resourceIndex < CD_ARCHIVE_COUNT)
      return CD_ArchivePath(request, resourceIndex);
   if(resourceIndex == CD_RESOURCE_SEQUENCE) return request.sequencePath;
   return "";
  }

#endif
