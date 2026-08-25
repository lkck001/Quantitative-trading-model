#ifndef CD_CONTRACT_MQH
#define CD_CONTRACT_MQH

#include "CD_Types.mqh"

bool CD_HasUnsafeCsvText(string value)
  {
   return (StringFind(value, ",") >= 0 ||
           StringFind(value, "\r") >= 0 ||
           StringFind(value, "\n") >= 0);
  }

bool CD_ParseCanonicalNonNegativeInt(string value, int &parsed)
  {
   parsed = 0;
   if(StringLen(value) == 0) return false;
   if(StringLen(value) > 1 && StringSubstr(value, 0, 1) == "0") return false;
   for(int index = 0; index < StringLen(value); index++)
     {
      ushort character = StringGetCharacter(value, index);
      if(character < StringGetCharacter("0", 0) ||
         character > StringGetCharacter("9", 0))
         return false;
     }
   long parsedLong = StringToInteger(value);
   if(parsedLong < 0 || parsedLong > 2147483647) return false;
   if(IntegerToString(parsedLong) != value) return false;
   parsed = (int)parsedLong;
   return true;
  }

bool CD_ParsePositiveDigitText(string value, int &parsed)
  {
   parsed = 0;
   if(StringLen(value) == 0) return false;
   for(int index = 0; index < StringLen(value); index++)
     {
      ushort character = StringGetCharacter(value, index);
      if(character < StringGetCharacter("0", 0) ||
         character > StringGetCharacter("9", 0))
         return false;
     }
   long parsedLong = StringToInteger(value);
   if(parsedLong <= 0 || parsedLong > 2147483647) return false;
   parsed = (int)parsedLong;
   return true;
  }

bool CD_ParseCaseIdentity(string caseID, int &year, int &sequence)
  {
   year = 0;
   sequence = 0;
   string fields[];
   if(StringSplit(caseID, '-', fields) < 2) return false;
   if(!CD_ParseCanonicalNonNegativeInt(fields[1], year) ||
      year < 1900 || year > 2100)
      return false;

   string caseToken = "-CASE-";
   int tokenPosition = StringFind(caseID, caseToken);
   if(tokenPosition >= 0)
     {
      string sequenceText = StringSubstr(
         caseID, tokenPosition + StringLen(caseToken));
      return CD_ParsePositiveDigitText(sequenceText, sequence);
     }
   else
     {
      int separatorPosition = -1;
      for(int characterIndex = StringLen(caseID) - 1;
          characterIndex >= 0; characterIndex--)
         if(StringSubstr(caseID, characterIndex, 1) == "-")
           {
            separatorPosition = characterIndex;
            break;
           }
      if(separatorPosition >= 0)
        {
         string sequenceText = StringSubstr(caseID, separatorPosition + 1);
         return CD_ParsePositiveDigitText(sequenceText, sequence);
        }
     }
   return false;
  }

bool CD_ArePathsDistinct(CD_Request &request)
  {
   string paths[];
   ArrayResize(paths, CD_RESOURCE_COUNT + 1);
   for(int index = 0; index < CD_RESOURCE_COUNT; index++)
      paths[index] = CD_ResourcePath(request, index);
   paths[CD_RESOURCE_COUNT] = request.journalPath;
   for(int left = 0; left < ArraySize(paths); left++)
     {
      if(StringLen(paths[left]) == 0) return false;
      for(int right = left + 1; right < ArraySize(paths); right++)
         if(paths[left] == paths[right]) return false;
     }
   return true;
  }

bool CD_ValidateRequest(CD_Request &request,
                        bool requireIdentity,
                        bool requireAuthorization,
                        CD_Result &result)
  {
   if(!CD_ArePathsDistinct(request))
     {
      result.statusCode = CD_STATUS_IDENTITY_CONFLICT;
      result.reasonCode = CD_REASON_REQUEST_INVALID;
      return false;
     }
   if(requireIdentity)
     {
      int year = 0;
      int sequence = 0;
      if(StringLen(request.caseID) == 0 ||
         StringLen(request.caseType) == 0 ||
         StringLen(request.symbol) == 0 ||
         StringLen(request.timeframe) == 0 ||
         CD_HasUnsafeCsvText(request.caseID) ||
         CD_HasUnsafeCsvText(request.caseType) ||
         CD_HasUnsafeCsvText(request.symbol) ||
         CD_HasUnsafeCsvText(request.timeframe) ||
         !CD_ParseCaseIdentity(request.caseID, year, sequence))
        {
         result.statusCode = CD_STATUS_IDENTITY_CONFLICT;
         result.reasonCode = CD_REASON_REQUEST_INVALID;
         return false;
        }
     }
   if(requireAuthorization && !request.formalDeleteAuthorized)
     {
      result.statusCode = CD_STATUS_CANCELLED;
      result.reasonCode = CD_REASON_NOT_AUTHORIZED;
      return false;
     }
   return true;
  }

bool CD_PreviewMatchesRequest(CD_Request &request, CD_Preview &preview)
  {
   int caseYear = 0;
   int caseSequence = 0;
   if(!CD_ParseCaseIdentity(request.caseID, caseYear, caseSequence))
      return false;
   return (preview.ready &&
           preview.contractVersion == CD_CONTRACT_VERSION &&
           preview.caseID == request.caseID &&
           preview.caseType == request.caseType &&
           preview.symbol == request.symbol &&
           preview.timeframe == request.timeframe &&
           preview.caseYear == caseYear &&
           preview.caseSequence == caseSequence &&
           ArraySize(preview.targetRows) == CD_ARCHIVE_COUNT &&
           ArraySize(preview.totalRows) == CD_ARCHIVE_COUNT &&
           ArraySize(preview.archiveFingerprints) == CD_ARCHIVE_COUNT &&
           ArraySize(preview.retainedFingerprints) == CD_ARCHIVE_COUNT &&
           StringLen(preview.manifestFingerprint) > 0 &&
           StringLen(preview.transactionToken) > 0);
  }

bool CD_PreviewsEquivalent(CD_Preview &left, CD_Preview &right)
  {
   if(!left.ready || !right.ready ||
      left.contractVersion != right.contractVersion ||
      left.caseID != right.caseID ||
      left.caseType != right.caseType ||
      left.symbol != right.symbol ||
      left.timeframe != right.timeframe ||
      left.caseYear != right.caseYear ||
      left.caseSequence != right.caseSequence ||
      left.sequenceExists != right.sequenceExists ||
      left.sequenceHighWater != right.sequenceHighWater ||
      left.sequenceFingerprint != right.sequenceFingerprint ||
      left.manifestFingerprint != right.manifestFingerprint ||
      ArraySize(left.targetRows) != CD_ARCHIVE_COUNT ||
      ArraySize(right.targetRows) != CD_ARCHIVE_COUNT ||
      ArraySize(left.totalRows) != CD_ARCHIVE_COUNT ||
      ArraySize(right.totalRows) != CD_ARCHIVE_COUNT ||
      ArraySize(left.archiveFingerprints) != CD_ARCHIVE_COUNT ||
      ArraySize(right.archiveFingerprints) != CD_ARCHIVE_COUNT ||
      ArraySize(left.retainedFingerprints) != CD_ARCHIVE_COUNT ||
      ArraySize(right.retainedFingerprints) != CD_ARCHIVE_COUNT)
      return false;
   for(int index = 0; index < CD_ARCHIVE_COUNT; index++)
      if(left.targetRows[index] != right.targetRows[index] ||
         left.totalRows[index] != right.totalRows[index] ||
         left.archiveFingerprints[index] != right.archiveFingerprints[index] ||
         left.retainedFingerprints[index] != right.retainedFingerprints[index])
         return false;
   return true;
  }

#endif
