#ifndef PR_ADAPTER_MQH
#define PR_ADAPTER_MQH

#include "..\Contract\PR_Types.mqh"

bool PR_IsReservedObjectName(string objectName, string &reservedPrefixes[])
  {
   for(int i = 0; i < ArraySize(reservedPrefixes); i++)
      if(StringLen(reservedPrefixes[i]) > 0 &&
         StringFind(objectName, reservedPrefixes[i]) == 0)
         return true;
   return false;
  }

int PR_ObjectAnchorCount(ENUM_OBJECT objectType)
  {
   if(objectType == OBJ_VLINE) return 1;
   if(objectType == OBJ_TREND) return 2;
   return 0;
  }

bool PR_AppendObject(PR_DraftSnapshot &snapshot, PR_ObjectSnapshot &objectSnapshot)
  {
   int index = ArraySize(snapshot.objects);
   if(ArrayResize(snapshot.objects, index + 1) != index + 1) return false;
   snapshot.objects[index] = objectSnapshot;
   return true;
  }

bool PR_AppendBoundary(PR_DraftSnapshot &snapshot, PR_BoundarySnapshot &boundary)
  {
   int index = ArraySize(snapshot.boundaries);
   if(ArrayResize(snapshot.boundaries, index + 1) != index + 1) return false;
   snapshot.boundaries[index] = boundary;
   return true;
  }

bool PR_AppendReleasePath(PR_DraftSnapshot &snapshot, PR_ReleasePathSnapshot &path)
  {
   int index = ArraySize(snapshot.releasePaths);
   if(ArrayResize(snapshot.releasePaths, index + 1) != index + 1) return false;
   snapshot.releasePaths[index] = path;
   return true;
  }

bool PR_ObjectNameExists(PR_DraftSnapshot &snapshot, string objectName)
  {
   for(int i = 0; i < ArraySize(snapshot.objects); i++)
      if(snapshot.objects[i].objectName == objectName) return true;
   return false;
  }

bool PR_ObjectComesBefore(PR_ObjectSnapshot &left, PR_ObjectSnapshot &right)
  {
   int nameCompare = StringCompare(left.objectName, right.objectName);
   if(nameCompare != 0) return (nameCompare < 0);
   if((int)left.objectType != (int)right.objectType)
      return ((int)left.objectType < (int)right.objectType);
   if(left.time1 != right.time1) return (left.time1 < right.time1);
   if(left.time2 != right.time2) return (left.time2 < right.time2);
   if(left.price1 != right.price1) return (left.price1 < right.price1);
   return (left.price2 < right.price2);
  }

void PR_SortObjects(PR_ObjectSnapshot &objects[])
  {
   for(int i = 1; i < ArraySize(objects); i++)
     {
      PR_ObjectSnapshot current = objects[i];
      int j = i - 1;
      while(j >= 0 && PR_ObjectComesBefore(current, objects[j]))
        {
         objects[j + 1] = objects[j];
         j--;
        }
      objects[j + 1] = current;
     }
  }

bool PR_PathComesBefore(PR_ReleasePathSnapshot &left,
                        PR_ReleasePathSnapshot &right)
  {
   int nameCompare = StringCompare(left.objectName, right.objectName);
   if(nameCompare != 0) return (nameCompare < 0);
   if(left.time1 != right.time1) return (left.time1 < right.time1);
   return (left.time2 < right.time2);
  }

void PR_SortReleasePaths(PR_ReleasePathSnapshot &paths[])
  {
   for(int i = 1; i < ArraySize(paths); i++)
     {
      PR_ReleasePathSnapshot current = paths[i];
      int j = i - 1;
      while(j >= 0 && PR_PathComesBefore(current, paths[j]))
        {
         paths[j + 1] = paths[j];
         j--;
        }
      paths[j + 1] = current;
     }
  }

string PR_EscapeFingerprintField(string value)
  {
   StringReplace(value, "%", "%25");
   StringReplace(value, "\\", "%5C");
   StringReplace(value, "|", "%7C");
   StringReplace(value, "=", "%3D");
   StringReplace(value, ":", "%3A");
   StringReplace(value, "\r", "%0D");
   StringReplace(value, "\n", "%0A");
   return value;
  }

string PR_CapFingerprint(string value)
  {
   int length = StringLen(value);
   if(length <= PR_FINGERPRINT_MAX_LENGTH) return value;
   string suffix = "|TRUNCATED=1|FULL_LEN=" + IntegerToString(length);
   int prefixLength = PR_FINGERPRINT_MAX_LENGTH - StringLen(suffix);
   if(prefixLength < 0) return StringSubstr(suffix, 0, PR_FINGERPRINT_MAX_LENGTH);
   return StringSubstr(value, 0, prefixLength) + suffix;
  }

void PR_SortBoundaries(PR_BoundarySnapshot &boundaries[])
  {
   for(int i = 1; i < ArraySize(boundaries); i++)
     {
      PR_BoundarySnapshot current = boundaries[i];
      int j = i - 1;
      while(j >= 0 &&
            (boundaries[j].time > current.time ||
             (boundaries[j].time == current.time &&
              StringCompare(boundaries[j].objectName, current.objectName) > 0)))
        {
         boundaries[j + 1] = boundaries[j];
         j--;
        }
      boundaries[j + 1] = current;
     }
  }

string PR_BuildDraftFingerprint(PR_DraftSnapshot &snapshot)
  {
   string fingerprint = "PRFP|" + PR_EscapeFingerprintField(snapshot.representationID) +
                        "|contract=" + PR_EscapeFingerprintField(snapshot.contractVersion) +
                        "|case=" + PR_EscapeFingerprintField(snapshot.caseID) +
                        "|type=" + PR_EscapeFingerprintField(snapshot.caseType) +
                        "|symbol=" + PR_EscapeFingerprintField(snapshot.symbol) +
                        "|tf=" + IntegerToString((int)snapshot.timeframe);
   for(int i = 0; i < ArraySize(snapshot.boundaries); i++)
      fingerprint += "|B=" + PR_EscapeFingerprintField(snapshot.boundaries[i].objectName) +
                     ":" + IntegerToString((long)snapshot.boundaries[i].time);
   for(int i = 0; i < ArraySize(snapshot.releasePaths); i++)
      fingerprint += "|L=" + PR_EscapeFingerprintField(snapshot.releasePaths[i].objectName) +
                     ":" + IntegerToString((long)snapshot.releasePaths[i].time1) +
                     ":" + IntegerToString((long)snapshot.releasePaths[i].time2) +
                     ":" + DoubleToString(snapshot.releasePaths[i].price1, 16) +
                     ":" + DoubleToString(snapshot.releasePaths[i].price2, 16);
   for(int i = 0; i < ArraySize(snapshot.objects); i++)
     {
      datetime objectTime1 = snapshot.objects[i].time1;
      datetime objectTime2 = snapshot.objects[i].time2;
      double objectPrice1 = snapshot.objects[i].price1;
      double objectPrice2 = snapshot.objects[i].price2;
      if(snapshot.objects[i].objectType == OBJ_TREND && objectTime2 < objectTime1)
        {
         datetime swapTime = objectTime1;
         double swapPrice = objectPrice1;
         objectTime1 = objectTime2;
         objectPrice1 = objectPrice2;
         objectTime2 = swapTime;
         objectPrice2 = swapPrice;
        }
      fingerprint += "|O=" + PR_EscapeFingerprintField(snapshot.objects[i].objectName) +
                     ":" + IntegerToString((int)snapshot.objects[i].objectType) +
                     ":" + IntegerToString((long)objectTime1) +
                     ":" + IntegerToString((long)objectTime2) +
                     ":" + DoubleToString(objectPrice1, 16) +
                     ":" + DoubleToString(objectPrice2, 16);
     }
   fingerprint += "|objects=" + IntegerToString(snapshot.objectCount) +
                  "|unsupported=" + IntegerToString(snapshot.unsupportedCount) +
                  "|subwindow=" + IntegerToString(snapshot.invalidSubwindowCount) +
                  "|price=" + IntegerToString(snapshot.invalidPriceCount) +
                  "|identity=" + IntegerToString(snapshot.invalidObjectIdentityCount) +
                  "|duplicate=" + IntegerToString(snapshot.duplicateObjectCount) +
                  "|structures=" + IntegerToString(snapshot.structureCount) +
                  "|key_bar=" + IntegerToString((int)snapshot.keyBarActive) +
                  "|structure_applicability=" +
                  PR_EscapeFingerprintField(snapshot.structureApplicability) +
                  "|key_bar_applicability=" +
                  PR_EscapeFingerprintField(snapshot.keyBarApplicability);
   return PR_CapFingerprint(fingerprint);
  }

bool PR_CaptureDraft(long chartID,
                     string caseID,
                     string caseType,
                     string symbol,
                     ENUM_TIMEFRAMES timeframe,
                     string &reservedPrefixes[],
                     PR_DraftSnapshot &snapshot)
  {
   PR_ResetDraftSnapshot(snapshot);
   snapshot.chartID = chartID;
   snapshot.caseID = caseID;
   snapshot.caseType = caseType;
   snapshot.symbol = symbol;
   snapshot.timeframe = timeframe;
   if(chartID == 0)
     {
      snapshot.captureErrorCode = PR_REASON_CAPTURE_FAILED;
      return false;
     }

   int total = ObjectsTotal(chartID, -1, -1);
   if(total < 0)
     {
      snapshot.captureErrorCode = PR_REASON_CAPTURE_FAILED;
      return false;
     }
   for(int i = 0; i < total; i++)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      if(StringLen(objectName) == 0)
        {
         snapshot.objectCount++;
         snapshot.invalidObjectIdentityCount++;
         continue;
        }
      if(PR_IsReservedObjectName(objectName, reservedPrefixes))
         continue;
      ENUM_OBJECT objectType = (ENUM_OBJECT)ObjectGetInteger(chartID, objectName, OBJPROP_TYPE);
      int anchorCount = PR_ObjectAnchorCount(objectType);
      bool duplicateObject = PR_ObjectNameExists(snapshot, objectName);

      PR_ObjectSnapshot objectSnapshot;
      objectSnapshot.objectName = objectName;
      objectSnapshot.objectType = objectType;
      objectSnapshot.subwindow = ObjectFind(chartID, objectName);
      objectSnapshot.anchorCount = anchorCount;
      objectSnapshot.time1 = 0;
      objectSnapshot.time2 = 0;
      objectSnapshot.price1 = 0.0;
      objectSnapshot.price2 = 0.0;
      if(anchorCount > 0)
        {
         objectSnapshot.time1 = (datetime)ObjectGetInteger(chartID, objectName, OBJPROP_TIME, 0);
         objectSnapshot.price1 = ObjectGetDouble(chartID, objectName, OBJPROP_PRICE, 0);
        }
      if(anchorCount > 1)
        {
         objectSnapshot.time2 = (datetime)ObjectGetInteger(chartID, objectName, OBJPROP_TIME, 1);
         objectSnapshot.price2 = ObjectGetDouble(chartID, objectName, OBJPROP_PRICE, 1);
        }
      if(!PR_AppendObject(snapshot, objectSnapshot))
        {
         snapshot.captureErrorCode = PR_REASON_CAPTURE_FAILED;
         return false;
        }
      snapshot.objectCount++;
      if(duplicateObject)
        {
         snapshot.duplicateObjectCount++;
         snapshot.invalidObjectIdentityCount++;
        }
      if(anchorCount <= 0)
        {
         snapshot.unsupportedCount++;
         continue;
        }
      if(objectSnapshot.subwindow != 0)
         snapshot.invalidSubwindowCount++;
      if(objectType == OBJ_VLINE)
        {
         PR_BoundarySnapshot boundary;
         boundary.objectName = objectName;
         boundary.subwindow = objectSnapshot.subwindow;
         boundary.time = objectSnapshot.time1;
         if(!PR_AppendBoundary(snapshot, boundary))
           {
            snapshot.captureErrorCode = PR_REASON_CAPTURE_FAILED;
            return false;
           }
        }
      else if(objectType == OBJ_TREND)
        {
         PR_ReleasePathSnapshot path;
         path.objectName = objectName;
         path.subwindow = objectSnapshot.subwindow;
         path.time1 = objectSnapshot.time1;
         path.time2 = objectSnapshot.time2;
         path.price1 = objectSnapshot.price1;
         path.price2 = objectSnapshot.price2;
         path.sourceAnchorOrder = 0;
         if(path.time2 < path.time1)
           {
            datetime originalTime1 = path.time1;
            double originalPrice1 = path.price1;
            path.time1 = path.time2;
            path.price1 = path.price2;
            path.time2 = originalTime1;
            path.price2 = originalPrice1;
            path.sourceAnchorOrder = 1;
           }
         if(!MathIsValidNumber(path.price1) || !MathIsValidNumber(path.price2))
            snapshot.invalidPriceCount++;
         if(!PR_AppendReleasePath(snapshot, path))
           {
            snapshot.captureErrorCode = PR_REASON_CAPTURE_FAILED;
            return false;
           }
        }
     }
   PR_SortBoundaries(snapshot.boundaries);
   PR_SortObjects(snapshot.objects);
   PR_SortReleasePaths(snapshot.releasePaths);
   snapshot.boundaryCount = ArraySize(snapshot.boundaries);
   snapshot.releasePathCount = ArraySize(snapshot.releasePaths);
   snapshot.captureOK = true;
   snapshot.fingerprint = PR_BuildDraftFingerprint(snapshot);
   return true;
  }

#endif
