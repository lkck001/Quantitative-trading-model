#ifndef CD_ARCHIVE_STORE_MQH
#define CD_ARCHIVE_STORE_MQH

#include "..\Contract\CD_Contract.mqh"

void CD_HashInitialize(uint &primary, uint &secondary)
  {
   primary = 2166136261;
   secondary = 2246822519;
  }

void CD_HashAppendText(string value, uint &primary, uint &secondary)
  {
   string framed = IntegerToString(StringLen(value)) + ":" + value + "|";
   for(int index = 0; index < StringLen(framed); index++)
     {
      uint character = (uint)StringGetCharacter(framed, index);
      primary = (primary ^ character) * 16777619;
      secondary ^= character + 0x9e3779b9 + (secondary << 6) +
                   (secondary >> 2);
     }
  }

string CD_HashFinish(uint primary, uint secondary)
  {
   return StringFormat("%08X%08X", primary, secondary);
  }

string CD_FirstCsvField(string line)
  {
   int separator = StringFind(line, ",");
   if(separator < 0) return line;
   return StringSubstr(line, 0, separator);
  }

int CD_FindCsvColumn(string header, string columnName)
  {
   string columns[];
   ushort separator = StringGetCharacter(",", 0);
   int count = StringSplit(header, separator, columns);
   for(int index = 0; index < count; index++)
      if(columns[index] == columnName) return index;
   return -1;
  }

bool CD_DeleteFileIfPresent(string path, int &lastError)
  {
   lastError = 0;
   if(!FileIsExist(path, 0)) return true;
   ResetLastError();
   if(FileDelete(path, 0)) return true;
   lastError = GetLastError();
   return false;
  }

bool CD_WriteTextLine(int handle, string line, int &lastError)
  {
   ResetLastError();
   uint written = FileWriteString(handle, line + "\r\n");
   if(written > 0) return true;
   lastError = GetLastError();
   return false;
  }

bool CD_ReadArchiveInventory(string path,
                             string caseID,
                             CD_ArchiveInventory &inventory)
  {
   CD_ResetArchiveInventory(inventory);
   inventory.path = path;
   inventory.exists = FileIsExist(path, 0);
   if(!inventory.exists)
     {
      inventory.reasonCode = CD_REASON_ARCHIVE_UNAVAILABLE;
      return false;
     }

   ResetLastError();
   int handle = FileOpen(path,
                         FILE_READ|FILE_TXT|FILE_ANSI|
                         FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE)
     {
      inventory.lastError = GetLastError();
      inventory.reasonCode = CD_REASON_ARCHIVE_UNAVAILABLE;
      return false;
     }
   if(FileIsEnding(handle))
     {
      FileClose(handle);
      inventory.reasonCode = CD_REASON_ARCHIVE_INVALID;
      return false;
     }

   uint contentPrimary = 0;
   uint contentSecondary = 0;
   uint retainedPrimary = 0;
   uint retainedSecondary = 0;
   uint targetPrimary = 0;
   uint targetSecondary = 0;
   CD_HashInitialize(contentPrimary, contentSecondary);
   CD_HashInitialize(retainedPrimary, retainedSecondary);
   CD_HashInitialize(targetPrimary, targetSecondary);

   inventory.header = FileReadString(handle);
   inventory.logicalLineCount = 1;
   if(StringFind(inventory.header, "case_id,") != 0)
     {
      FileClose(handle);
      inventory.reasonCode = CD_REASON_ARCHIVE_INVALID;
      return false;
     }
   int caseTypeColumn = CD_FindCsvColumn(inventory.header, "case_type");
   int symbolColumn = CD_FindCsvColumn(inventory.header, "symbol");
   int timeframeColumn = CD_FindCsvColumn(inventory.header, "timeframe");
   if(caseTypeColumn < 0 || symbolColumn < 0 || timeframeColumn < 0)
     {
      FileClose(handle);
      inventory.reasonCode = CD_REASON_ARCHIVE_INVALID;
      return false;
     }
   CD_HashAppendText(inventory.header, contentPrimary, contentSecondary);
   CD_HashAppendText(inventory.header, retainedPrimary, retainedSecondary);
   CD_HashAppendText(caseID, targetPrimary, targetSecondary);

   ushort separator = StringGetCharacter(",", 0);
   bool targetIdentityValid = true;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      inventory.logicalLineCount++;
      CD_HashAppendText(line, contentPrimary, contentSecondary);
      if(StringLen(line) == 0)
        {
         CD_HashAppendText(line, retainedPrimary, retainedSecondary);
         continue;
        }

      inventory.dataRowCount++;
      if(CD_FirstCsvField(line) != caseID)
        {
         CD_HashAppendText(line, retainedPrimary, retainedSecondary);
         continue;
        }

      string fields[];
      int fieldCount = StringSplit(line, separator, fields);
      int requiredColumn = MathMax(caseTypeColumn,
                           MathMax(symbolColumn, timeframeColumn));
      if(fieldCount <= requiredColumn ||
         StringLen(fields[caseTypeColumn]) == 0 ||
         StringLen(fields[symbolColumn]) == 0 ||
         StringLen(fields[timeframeColumn]) == 0)
         targetIdentityValid = false;
      inventory.targetRowCount++;
      CD_HashAppendText(line, targetPrimary, targetSecondary);
      if(inventory.targetRowCount == 1 && fieldCount > requiredColumn)
        {
         inventory.targetCaseType = fields[caseTypeColumn];
         inventory.targetSymbol = fields[symbolColumn];
         inventory.targetTimeframe = fields[timeframeColumn];
        }
      else if(fieldCount > requiredColumn &&
              (inventory.targetCaseType != fields[caseTypeColumn] ||
               inventory.targetSymbol != fields[symbolColumn] ||
               inventory.targetTimeframe != fields[timeframeColumn]))
         targetIdentityValid = false;
     }
   FileClose(handle);

   inventory.contentFingerprint = CD_HashFinish(contentPrimary,
                                                 contentSecondary);
   inventory.retainedFingerprint = CD_HashFinish(retainedPrimary,
                                                  retainedSecondary);
   inventory.targetFingerprint = CD_HashFinish(targetPrimary,
                                                targetSecondary);
   if(!targetIdentityValid)
     {
      inventory.reasonCode = CD_REASON_CHILD_IDENTITY_MISMATCH;
      return false;
     }
   inventory.valid = true;
   return true;
  }

bool CD_ReadSequenceInventory(string path,
                              int targetYear,
                              CD_SequenceInventory &inventory)
  {
   CD_ResetSequenceInventory(inventory);
   inventory.path = path;
   inventory.targetYear = targetYear;
   inventory.exists = FileIsExist(path, 0);
   if(!inventory.exists)
     {
      inventory.contentFingerprint = "MISSING";
      inventory.retainedFingerprint = "MISSING";
      inventory.valid = true;
      return true;
     }

   ResetLastError();
   int handle = FileOpen(path,
                         FILE_READ|FILE_TXT|FILE_ANSI|
                         FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE)
     {
      inventory.lastError = GetLastError();
      inventory.reasonCode = CD_REASON_SEQUENCE_INVALID;
      return false;
     }
   if(FileIsEnding(handle))
     {
      FileClose(handle);
      inventory.reasonCode = CD_REASON_SEQUENCE_INVALID;
      return false;
     }

   uint primary = 0;
   uint secondary = 0;
   uint retainedPrimary = 0;
   uint retainedSecondary = 0;
   CD_HashInitialize(primary, secondary);
   CD_HashInitialize(retainedPrimary, retainedSecondary);
   string header = FileReadString(handle);
   inventory.logicalLineCount = 1;
   CD_HashAppendText(header, primary, secondary);
   CD_HashAppendText(header, retainedPrimary, retainedSecondary);
   if(header != CD_SEQUENCE_HEADER)
     {
      FileClose(handle);
      inventory.reasonCode = CD_REASON_SEQUENCE_INVALID;
      return false;
     }

   int seenYears[];
   ushort separator = StringGetCharacter(",", 0);
   bool rowsValid = true;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      inventory.logicalLineCount++;
      CD_HashAppendText(line, primary, secondary);
      if(StringLen(line) == 0)
        {
         CD_HashAppendText(line, retainedPrimary, retainedSecondary);
         continue;
        }

      string fields[];
      int fieldCount = StringSplit(line, separator, fields);
      if(fieldCount != 3)
        {
         rowsValid = false;
         CD_HashAppendText(line, retainedPrimary, retainedSecondary);
         continue;
        }
      inventory.dataRowCount++;
      int year = 0;
      int sequence = 0;
      if(!CD_ParseCanonicalNonNegativeInt(fields[0], year) ||
         !CD_ParseCanonicalNonNegativeInt(fields[1], sequence) ||
         year < 1900 || year > 2100 || StringLen(fields[2]) == 0)
        {
         rowsValid = false;
         CD_HashAppendText(line, retainedPrimary, retainedSecondary);
         continue;
        }
      for(int index = 0; index < ArraySize(seenYears); index++)
         if(seenYears[index] == year) rowsValid = false;
      int seenIndex = ArraySize(seenYears);
      ArrayResize(seenYears, seenIndex + 1);
      seenYears[seenIndex] = year;
      if(year == targetYear)
        {
         inventory.targetRowCount++;
         inventory.highWater = sequence;
        }
      else
         CD_HashAppendText(line, retainedPrimary, retainedSecondary);
     }
   FileClose(handle);
   inventory.contentFingerprint = CD_HashFinish(primary, secondary);
   inventory.retainedFingerprint = CD_HashFinish(retainedPrimary,
                                                  retainedSecondary);
   if(!rowsValid)
     {
      inventory.reasonCode = CD_REASON_SEQUENCE_INVALID;
      return false;
     }
   inventory.valid = true;
   return true;
  }

string CD_BuildManifestFingerprint(CD_Request &request,
                                   CD_ArchiveInventory &archives[],
                                   CD_SequenceInventory &sequence)
  {
   uint primary = 0;
   uint secondary = 0;
   CD_HashInitialize(primary, secondary);
   CD_HashAppendText(CD_CONTRACT_VERSION, primary, secondary);
   CD_HashAppendText(request.caseID, primary, secondary);
   CD_HashAppendText(request.caseType, primary, secondary);
   CD_HashAppendText(request.symbol, primary, secondary);
   CD_HashAppendText(request.timeframe, primary, secondary);
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
     {
      CD_HashAppendText(CD_ArchiveName(index), primary, secondary);
      CD_HashAppendText(archives[index].path, primary, secondary);
      CD_HashAppendText(archives[index].header, primary, secondary);
      CD_HashAppendText(IntegerToString(archives[index].dataRowCount),
                        primary, secondary);
      CD_HashAppendText(IntegerToString(archives[index].targetRowCount),
                        primary, secondary);
      CD_HashAppendText(archives[index].contentFingerprint,
                        primary, secondary);
      CD_HashAppendText(archives[index].retainedFingerprint,
                        primary, secondary);
      CD_HashAppendText(archives[index].targetFingerprint,
                        primary, secondary);
     }
   CD_HashAppendText(sequence.path, primary, secondary);
   CD_HashAppendText(IntegerToString((int)sequence.exists),
                     primary, secondary);
   CD_HashAppendText(IntegerToString(sequence.highWater),
                     primary, secondary);
   CD_HashAppendText(IntegerToString(sequence.logicalLineCount),
                     primary, secondary);
   CD_HashAppendText(IntegerToString(sequence.dataRowCount),
                     primary, secondary);
   CD_HashAppendText(IntegerToString(sequence.targetRowCount),
                     primary, secondary);
   CD_HashAppendText(sequence.contentFingerprint, primary, secondary);
   CD_HashAppendText(sequence.retainedFingerprint, primary, secondary);
   return CD_HashFinish(primary, secondary);
  }

bool CD_BuildArchiveSet(CD_Request &request,
                        CD_ArchiveInventory &archives[],
                        CD_SequenceInventory &sequence,
                        CD_Result &result)
  {
   ArrayResize(archives, CD_ARCHIVE_COUNT);
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
     {
      string path = CD_ArchivePath(request, index);
      if(CD_ReadArchiveInventory(path, request.caseID, archives[index]))
         continue;
      result.lastError = archives[index].lastError;
      result.statusCode = archives[index].exists ?
                          CD_STATUS_IDENTITY_CONFLICT :
                          CD_STATUS_ARCHIVE_MISSING;
      result.reasonCode = archives[index].reasonCode;
      return false;
     }

   if(archives[CD_ARCHIVE_CASES].targetRowCount == 0)
     {
      result.statusCode = CD_STATUS_NOT_FORMAL_CASE;
      result.reasonCode = CD_REASON_CASE_MISSING;
      return false;
     }
   if(archives[CD_ARCHIVE_CASES].targetRowCount != 1)
     {
      result.statusCode = CD_STATUS_IDENTITY_CONFLICT;
      result.reasonCode = CD_REASON_CASE_DUPLICATE;
      return false;
     }
   if(archives[CD_ARCHIVE_CASES].targetCaseType != request.caseType ||
      archives[CD_ARCHIVE_CASES].targetSymbol != request.symbol ||
      archives[CD_ARCHIVE_CASES].targetTimeframe != request.timeframe)
     {
      result.statusCode = CD_STATUS_IDENTITY_CONFLICT;
      result.reasonCode = CD_REASON_IDENTITY_MISMATCH;
      return false;
     }
   for(int index = 1; index < CD_ARCHIVE_COUNT; index++)
      if(archives[index].targetRowCount > 0 &&
         (archives[index].targetCaseType != request.caseType ||
          archives[index].targetSymbol != request.symbol ||
          archives[index].targetTimeframe != request.timeframe))
        {
         result.statusCode = CD_STATUS_IDENTITY_CONFLICT;
         result.reasonCode = CD_REASON_CHILD_IDENTITY_MISMATCH;
         return false;
        }

   int caseYear = 0;
   int caseSequence = 0;
   if(!CD_ParseCaseIdentity(request.caseID, caseYear, caseSequence) ||
      !CD_ReadSequenceInventory(request.sequencePath, caseYear, sequence))
     {
      result.statusCode = CD_STATUS_IDENTITY_CONFLICT;
      result.reasonCode = CD_REASON_SEQUENCE_INVALID;
      result.lastError = sequence.lastError;
      return false;
     }
   return true;
  }

string CD_CreateTransactionToken(string manifestFingerprint)
  {
   return IntegerToString((long)TimeLocal()) + "-" +
          IntegerToString((long)GetTickCount()) + "-" +
          manifestFingerprint;
  }

bool CD_BuildPreview(CD_Request &request,
                     CD_Preview &preview,
                     CD_Result &result)
  {
   CD_ResetPreview(preview);
   CD_ArchiveInventory archives[];
   CD_SequenceInventory sequence;
   if(!CD_BuildArchiveSet(request, archives, sequence, result)) return false;

   int caseYear = 0;
   int caseSequence = 0;
   CD_ParseCaseIdentity(request.caseID, caseYear, caseSequence);
   preview.caseID = request.caseID;
   preview.caseType = request.caseType;
   preview.symbol = request.symbol;
   preview.timeframe = request.timeframe;
   preview.caseYear = caseYear;
   preview.caseSequence = caseSequence;
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
     {
      preview.targetRows[index] = archives[index].targetRowCount;
      preview.totalRows[index] = archives[index].dataRowCount;
      preview.archiveFingerprints[index] = archives[index].contentFingerprint;
      preview.retainedFingerprints[index] = archives[index].retainedFingerprint;
      result.targetRows[index] = archives[index].targetRowCount;
     }
   preview.sequenceExists = sequence.exists;
   preview.sequenceHighWater = sequence.highWater;
   preview.sequenceFingerprint = sequence.contentFingerprint;
   preview.manifestFingerprint = CD_BuildManifestFingerprint(request,
                                                              archives,
                                                              sequence);
   preview.transactionToken = CD_CreateTransactionToken(
                                 preview.manifestFingerprint);
   preview.ready = true;
   result.statusCode = CD_STATUS_READY;
   result.reasonCode = CD_REASON_READY;
   result.caseID = request.caseID;
   result.manifestFingerprint = preview.manifestFingerprint;
   return true;
  }

bool CD_WriteArchiveStage(string sourcePath,
                          string stagePath,
                          string caseID,
                          int &lastError)
  {
   lastError = 0;
   if(!CD_DeleteFileIfPresent(stagePath, lastError)) return false;
   ResetLastError();
   int sourceHandle = FileOpen(sourcePath,
                               FILE_READ|FILE_TXT|FILE_ANSI|
                               FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(sourceHandle == INVALID_HANDLE)
     {
      lastError = GetLastError();
      return false;
     }
   ResetLastError();
   int stageHandle = FileOpen(stagePath,
                              FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(stageHandle == INVALID_HANDLE)
     {
      lastError = GetLastError();
      FileClose(sourceHandle);
      return false;
     }

   bool written = false;
   if(!FileIsEnding(sourceHandle))
      written = CD_WriteTextLine(stageHandle,
                                 FileReadString(sourceHandle), lastError);
   while(written && !FileIsEnding(sourceHandle))
     {
      string line = FileReadString(sourceHandle);
      if(StringLen(line) > 0 && CD_FirstCsvField(line) == caseID)
         continue;
      written = CD_WriteTextLine(stageHandle, line, lastError);
     }
   FileFlush(stageHandle);
   FileClose(stageHandle);
   FileClose(sourceHandle);
   if(written) return true;
   int cleanupError = 0;
   CD_DeleteFileIfPresent(stagePath, cleanupError);
   return false;
  }

bool CD_VerifyArchiveStage(string stagePath,
                           string caseID,
                           CD_ArchiveInventory &source,
                           CD_ArchiveInventory &stage,
                           int &lastError)
  {
   lastError = 0;
   if(!CD_ReadArchiveInventory(stagePath, caseID, stage))
     {
      lastError = stage.lastError;
      return false;
     }
   return (stage.header == source.header &&
           stage.targetRowCount == 0 &&
           stage.dataRowCount == source.dataRowCount - source.targetRowCount &&
           stage.contentFingerprint == source.retainedFingerprint);
  }

bool CD_WriteSequenceStage(string sourcePath,
                           string stagePath,
                           int targetYear,
                           int targetHighWater,
                           string updatedAt,
                           int &lastError)
  {
   lastError = 0;
   if(!CD_DeleteFileIfPresent(stagePath, lastError)) return false;
   ResetLastError();
   int stageHandle = FileOpen(stagePath,
                              FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(stageHandle == INVALID_HANDLE)
     {
      lastError = GetLastError();
      return false;
     }
   bool written = CD_WriteTextLine(stageHandle, CD_SEQUENCE_HEADER, lastError);
   bool targetWritten = false;
   if(written && FileIsExist(sourcePath, 0))
     {
      ResetLastError();
      int sourceHandle = FileOpen(sourcePath,
                                  FILE_READ|FILE_TXT|FILE_ANSI|
                                  FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(sourceHandle == INVALID_HANDLE)
        {
         lastError = GetLastError();
         written = false;
        }
      else
        {
         if(!FileIsEnding(sourceHandle)) FileReadString(sourceHandle);
         ushort separator = StringGetCharacter(",", 0);
         while(written && !FileIsEnding(sourceHandle))
           {
            string line = FileReadString(sourceHandle);
            if(StringLen(line) == 0)
              {
               written = CD_WriteTextLine(stageHandle, line, lastError);
               continue;
              }
            string fields[];
            int fieldCount = StringSplit(line, separator, fields);
            int year = 0;
            int sequence = 0;
            bool rowValid = (fieldCount == 3 &&
                             CD_ParseCanonicalNonNegativeInt(fields[0], year) &&
                             CD_ParseCanonicalNonNegativeInt(fields[1], sequence) &&
                             year >= 1900 && year <= 2100 &&
                             StringLen(fields[2]) > 0);
            if(!rowValid)
              {
               written = false;
               continue;
              }
            if(year == targetYear)
              {
               string replacement = IntegerToString(targetYear) + "," +
                                    IntegerToString(targetHighWater) + "," +
                                    updatedAt;
               written = CD_WriteTextLine(stageHandle, replacement,
                                          lastError);
               targetWritten = written;
              }
            else
               written = CD_WriteTextLine(stageHandle, line, lastError);
           }
         FileClose(sourceHandle);
        }
     }
   if(written && !targetWritten)
     {
      string newLine = IntegerToString(targetYear) + "," +
                       IntegerToString(targetHighWater) + "," + updatedAt;
      written = CD_WriteTextLine(stageHandle, newLine, lastError);
     }
   FileFlush(stageHandle);
   FileClose(stageHandle);
   if(written) return true;
   int cleanupError = 0;
   CD_DeleteFileIfPresent(stagePath, cleanupError);
   return false;
  }

bool CD_VerifySequenceStage(string stagePath,
                            int targetYear,
                            int targetHighWater,
                            CD_SequenceInventory &source,
                            CD_SequenceInventory &stage,
                            int &lastError)
  {
   lastError = 0;
   if(!CD_ReadSequenceInventory(stagePath, targetYear, stage))
     {
      lastError = stage.lastError;
      return false;
     }
   int expectedDataRows = source.exists ? source.dataRowCount : 0;
   int expectedLogicalLines = source.exists ? source.logicalLineCount : 1;
   if(source.targetRowCount == 0)
     {
      expectedDataRows++;
      expectedLogicalLines++;
     }
   string expectedRetained = source.retainedFingerprint;
   if(!source.exists)
     {
      uint primary = 0;
      uint secondary = 0;
      CD_HashInitialize(primary, secondary);
      CD_HashAppendText(CD_SEQUENCE_HEADER, primary, secondary);
      expectedRetained = CD_HashFinish(primary, secondary);
     }
   return (stage.exists && stage.valid &&
           stage.targetRowCount == 1 &&
           stage.highWater == targetHighWater &&
           stage.dataRowCount == expectedDataRows &&
           stage.logicalLineCount == expectedLogicalLines &&
           stage.retainedFingerprint == expectedRetained);
  }

bool CD_CopyFileReplace(string sourcePath,
                        string destinationPath,
                        int &lastError)
  {
   ResetLastError();
   if(FileCopy(sourcePath, 0, destinationPath, FILE_REWRITE))
     {
      lastError = 0;
      return true;
     }
   lastError = GetLastError();
   return false;
  }

string CD_StagePath(string resourcePath)
  {
   return resourcePath + ".cd_stage";
  }

string CD_BackupPath(string resourcePath)
  {
   return resourcePath + ".cd_backup";
  }

string CD_JournalStagePath(string journalPath)
  {
   return journalPath + ".cd_stage";
  }

string CD_TargetRowsText(int &targetRows[])
  {
   string value = "";
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
     {
      if(index > 0) value += ",";
      value += IntegerToString(targetRows[index]);
     }
   return value;
  }

bool CD_ReadJournalFile(string path, CD_RecoveryInfo &info)
  {
   CD_ResetRecoveryInfo(info);
   info.pending = FileIsExist(path, 0);
   if(!info.pending) return false;
   ResetLastError();
   int handle = FileOpen(path,
                         FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(handle == INVALID_HANDLE)
     {
      info.lastError = GetLastError();
      info.reasonCode = CD_REASON_RECOVERY_JOURNAL_INVALID;
      return false;
     }
   string existedMaskText = "";
   string targetRowsText = "";
   int seenFormat = 0;
   int seenState = 0;
   int seenToken = 0;
   int seenCaseID = 0;
   int seenCaseType = 0;
   int seenSymbol = 0;
   int seenTimeframe = 0;
   int seenManifest = 0;
   int seenMask = 0;
   int seenTargetRows = 0;
   bool syntaxValid = true;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      int separatorPosition = StringFind(line, "=");
      if(separatorPosition <= 0)
        {
         syntaxValid = false;
         continue;
        }
      string key = StringSubstr(line, 0, separatorPosition);
      string value = StringSubstr(line, separatorPosition + 1);
      if(key == "format")
        {
         seenFormat++;
         info.transactionVersion = value;
        }
      else if(key == "state")
        {
         seenState++;
         info.state = value;
        }
      else if(key == "token")
        {
         seenToken++;
         info.token = value;
        }
      else if(key == "case_id")
        {
         seenCaseID++;
         info.caseID = value;
        }
      else if(key == "case_type")
        {
         seenCaseType++;
         info.caseType = value;
        }
      else if(key == "symbol")
        {
         seenSymbol++;
         info.symbol = value;
        }
      else if(key == "timeframe")
        {
         seenTimeframe++;
         info.timeframe = value;
        }
      else if(key == "before_manifest")
        {
         seenManifest++;
         info.beforeManifest = value;
        }
      else if(key == "existed_mask")
        {
         seenMask++;
         existedMaskText = value;
        }
      else if(key == "target_rows")
        {
         seenTargetRows++;
         targetRowsText = value;
        }
      else
         syntaxValid = false;
     }
   FileClose(handle);

   int parsedMask = 0;
   bool maskValid = (seenMask == 1 &&
                     CD_ParseCanonicalNonNegativeInt(existedMaskText,
                                                     parsedMask));
   if(maskValid) info.existedMask = parsedMask;
   string countFields[];
   ushort comma = StringGetCharacter(",", 0);
   int count = StringSplit(targetRowsText, comma, countFields);
   bool countsValid = (seenTargetRows == 1 && count == CD_ARCHIVE_COUNT);
   if(countsValid)
      for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
        {
         int parsedCount = 0;
         if(!CD_ParseCanonicalNonNegativeInt(countFields[index],
                                             parsedCount))
            countsValid = false;
         info.targetRows[index] = parsedCount;
        }
   int requiredArchiveMask = (1 << CD_ARCHIVE_COUNT) - 1;
   int parsedYear = 0;
   int parsedSequence = 0;
   info.valid = (syntaxValid &&
                 seenFormat == 1 && seenState == 1 && seenToken == 1 &&
                 seenCaseID == 1 && seenCaseType == 1 && seenSymbol == 1 &&
                 seenTimeframe == 1 && seenManifest == 1 &&
                 info.transactionVersion == CD_TRANSACTION_VERSION &&
                 info.state == "PREPARED" &&
                 StringLen(info.token) > 0 &&
                 StringLen(info.caseID) > 0 &&
                 StringLen(info.caseType) > 0 &&
                 StringLen(info.symbol) > 0 &&
                 StringLen(info.timeframe) > 0 &&
                 StringLen(info.beforeManifest) > 0 &&
                 CD_ParseCaseIdentity(info.caseID, parsedYear,
                                      parsedSequence) &&
                 maskValid &&
                 info.existedMask < (1 << CD_RESOURCE_COUNT) &&
                 (info.existedMask & requiredArchiveMask) ==
                 requiredArchiveMask &&
                 countsValid && info.targetRows[CD_ARCHIVE_CASES] == 1);
   info.reasonCode = info.valid ? CD_REASON_RECOVERY_PENDING :
                                  CD_REASON_RECOVERY_JOURNAL_INVALID;
   return info.valid;
  }

bool CD_JournalMatchesPreview(CD_RecoveryInfo &info,
                              CD_Preview &preview,
                              int existedMask)
  {
   if(!info.valid || info.transactionVersion != CD_TRANSACTION_VERSION ||
      info.state != "PREPARED" ||
      info.token != preview.transactionToken ||
      info.caseID != preview.caseID ||
      info.caseType != preview.caseType ||
      info.symbol != preview.symbol ||
      info.timeframe != preview.timeframe ||
      info.beforeManifest != preview.manifestFingerprint ||
      info.existedMask != existedMask ||
      ArraySize(info.targetRows) != CD_ARCHIVE_COUNT ||
      ArraySize(preview.targetRows) != CD_ARCHIVE_COUNT)
      return false;
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
      if(info.targetRows[index] != preview.targetRows[index]) return false;
   return true;
  }

bool CD_WriteJournalFile(string path,
                         CD_Preview &preview,
                         int existedMask,
                         int &lastError)
  {
   lastError = 0;
   ResetLastError();
   int handle = FileOpen(path,
                         FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(handle == INVALID_HANDLE)
     {
      lastError = GetLastError();
      return false;
     }
   bool written = CD_WriteTextLine(handle,
                                   "format=" + CD_TRANSACTION_VERSION,
                                   lastError);
   written = written && CD_WriteTextLine(handle, "state=PREPARED", lastError);
   written = written && CD_WriteTextLine(handle,
                                          "token=" + preview.transactionToken,
                                          lastError);
   written = written && CD_WriteTextLine(handle,
                                          "case_id=" + preview.caseID,
                                          lastError);
   written = written && CD_WriteTextLine(handle,
                                          "case_type=" + preview.caseType,
                                          lastError);
   written = written && CD_WriteTextLine(handle,
                                          "symbol=" + preview.symbol,
                                          lastError);
   written = written && CD_WriteTextLine(handle,
                                          "timeframe=" + preview.timeframe,
                                          lastError);
   written = written && CD_WriteTextLine(handle,
                                          "before_manifest=" +
                                          preview.manifestFingerprint,
                                          lastError);
   written = written && CD_WriteTextLine(handle,
                                          "existed_mask=" +
                                          IntegerToString(existedMask),
                                          lastError);
   written = written && CD_WriteTextLine(handle,
                                          "target_rows=" +
                                          CD_TargetRowsText(preview.targetRows),
                                          lastError);
   FileFlush(handle);
   FileClose(handle);
   return written;
  }

bool CD_WriteJournal(CD_Request &request,
                     CD_Preview &preview,
                     int existedMask,
                     int &lastError)
  {
   lastError = 0;
   string stagePath = CD_JournalStagePath(request.journalPath);
   if(FileIsExist(request.journalPath, 0) || FileIsExist(stagePath, 0))
      return false;
   if(!CD_WriteJournalFile(stagePath, preview, existedMask, lastError))
      return false;
   CD_RecoveryInfo stageInfo;
   if(!CD_ReadJournalFile(stagePath, stageInfo) ||
      !CD_JournalMatchesPreview(stageInfo, preview, existedMask))
      return false;
   if(!CD_CopyFileReplace(stagePath, request.journalPath, lastError))
      return false;
   CD_RecoveryInfo publishedInfo;
   if(!CD_ReadJournalFile(request.journalPath, publishedInfo) ||
      !CD_JournalMatchesPreview(publishedInfo, preview, existedMask))
      return false;
   return true;
  }

bool CD_ReadJournal(CD_Request &request, CD_RecoveryInfo &info)
  {
   string stagePath = CD_JournalStagePath(request.journalPath);
   bool journalExists = FileIsExist(request.journalPath, 0);
   bool stageExists = FileIsExist(stagePath, 0);
   if(!journalExists && !stageExists)
     {
      CD_ResetRecoveryInfo(info);
      return true;
     }
   if(journalExists && CD_ReadJournalFile(request.journalPath, info))
      return true;
   if(stageExists && CD_ReadJournalFile(stagePath, info))
      return true;
   if(journalExists) CD_ReadJournalFile(request.journalPath, info);
   else CD_ReadJournalFile(stagePath, info);
   info.pending = true;
   return false;
  }

#endif
