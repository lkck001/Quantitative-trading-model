#ifndef CM_DELETE_CONTEXT_ADAPTER_MQH
#define CM_DELETE_CONTEXT_ADAPTER_MQH

#define CM_DELETE_CONTEXT_READY 0
#define CM_DELETE_CONTEXT_NOT_READY 1
#define CM_DELETE_CONTEXT_IDENTITY_CONFLICT 2

struct CM_DeleteContextSnapshot
  {
   int catalogIndex;
   bool catalogReady;
   bool caseTypeDirty;
   bool standardityDirty;
   string activeCaseID;
   string activeCaseType;
   string archivedCaseType;
   string nativeSymbol;
   string nativeTimeframe;
   string caseID;
   string caseType;
   string symbol;
   string timeframe;
  };

void CM_DeleteContextResetSnapshot(CM_DeleteContextSnapshot &snapshot)
  {
   snapshot.catalogIndex = -1;
   snapshot.catalogReady = false;
   snapshot.caseTypeDirty = false;
   snapshot.standardityDirty = false;
   snapshot.activeCaseID = "";
   snapshot.activeCaseType = "";
   snapshot.archivedCaseType = "";
   snapshot.nativeSymbol = "";
   snapshot.nativeTimeframe = "";
   snapshot.caseID = "";
   snapshot.caseType = "";
   snapshot.symbol = "";
   snapshot.timeframe = "";
  }

int CM_DeleteContextCaptureSnapshot(CM_DeleteContextSnapshot &snapshot)
  {
   CM_DeleteContextResetSnapshot(snapshot);
   snapshot.catalogReady = opportunityCaseCatalogReady;
   snapshot.caseTypeDirty = opportunityCaseTypeDirty;
   snapshot.standardityDirty = opportunityStandardityDirty;
   snapshot.activeCaseID = OpportunityCaseId();
   snapshot.activeCaseType = OpportunityCaseType();
   snapshot.archivedCaseType = opportunityArchivedCaseType;
   snapshot.nativeSymbol = opportunityAnnotationNativeSymbol;
   snapshot.nativeTimeframe = opportunityAnnotationNativeTimeframe;
   snapshot.catalogIndex = FindOpportunityCaseCatalogIndex(snapshot.activeCaseID);
   if(!snapshot.catalogReady || snapshot.catalogIndex < 0 ||
      snapshot.caseTypeDirty || snapshot.standardityDirty)
      return CM_DELETE_CONTEXT_NOT_READY;

   OpportunityCaseCatalogEntry entry =
      opportunityCaseCatalog[snapshot.catalogIndex];
   snapshot.caseID = entry.caseId;
   snapshot.caseType = entry.caseType;
   snapshot.symbol = entry.symbol;
   snapshot.timeframe = entry.timeframe;
   if(snapshot.caseID != snapshot.activeCaseID ||
      snapshot.caseType != snapshot.activeCaseType ||
      snapshot.caseType != snapshot.archivedCaseType ||
      snapshot.symbol != snapshot.nativeSymbol ||
      snapshot.timeframe != snapshot.nativeTimeframe)
      return CM_DELETE_CONTEXT_IDENTITY_CONFLICT;
   return CM_DELETE_CONTEXT_READY;
  }

void CM_DeleteContextBuildBaseRequest(CD_Request &request, bool authorized)
  {
   CD_ResetRequest(request);
   request.casesPath = InpOpportunityCasesCsvPath;
   request.anchorsPath = InpOpportunityAnchorsCsvPath;
   request.keyBarsPath = InpOpportunityKeyBarsCsvPath;
   request.drawingsPath = InpOpportunityDrawingsCsvPath;
   request.regionsPath = InpOpportunityRegionsCsvPath;
   request.semanticsPath = InpOpportunityDrawingSemanticsCsvPath;
   request.channelBoundariesPath = InpOpportunityChannelBoundariesCsvPath;
   request.sequencePath = InpOpportunityCaseSequencesCsvPath;
   request.journalPath = InpOpportunityCaseDeleteJournalPath;
   request.formalDeleteAuthorized = authorized;
  }

void CM_DeleteContextBuildRequest(CM_DeleteContextSnapshot &snapshot,
                                  bool authorized,
                                  CD_Request &request)
  {
   CM_DeleteContextBuildBaseRequest(request, authorized);
   request.caseID = snapshot.caseID;
   request.caseType = snapshot.caseType;
   request.symbol = snapshot.symbol;
   request.timeframe = snapshot.timeframe;
  }

string CM_DeleteContextEligibilityKey(CM_DeleteContextSnapshot &snapshot)
  {
   return snapshot.caseID + "|" + snapshot.caseType + "|" +
          snapshot.symbol + "|" + snapshot.timeframe;
  }

#endif
