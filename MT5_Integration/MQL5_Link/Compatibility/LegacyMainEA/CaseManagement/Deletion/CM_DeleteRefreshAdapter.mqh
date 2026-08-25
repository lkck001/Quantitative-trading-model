#ifndef CM_DELETE_REFRESH_ADAPTER_MQH
#define CM_DELETE_REFRESH_ADAPTER_MQH

void CM_DeleteRefreshPresentFeedback(int feedbackCode, string detail)
  {
   UI_CM_DeleteFeedback feedback;
   UI_CM_GetDeleteFeedback(feedbackCode, detail, feedback);
   SetOpportunityCaseFeedback(feedback.text, feedback.durationMs);
  }

bool CM_DeleteRefreshEnterSafeState(long chartID, bool recoveryPending)
  {
   HideOpportunityDetailsPanel(chartID);
   CloseOpportunityCaseMenu(chartID);
   CloseOpportunityTypeMenu(chartID);
   DeleteAllOpportunityDisplayObjects(chartID,
                                      recoveryPending ?
                                      "delete_recovery_pending" :
                                      "delete_completed");
   ResetOpportunityAnnotationState();
   ResetPureReleaseShadowState(recoveryPending ?
                               "delete_recovery_pending" :
                               "delete_completed");
   ArrayResize(opportunityCaseCatalog, 0);
   opportunityCaseCatalogReady = false;
   opportunityActiveCaseId = "";
   opportunityActiveCaseType = "UNSELECTED";
   opportunityArchivedCaseType = "";
   opportunityCaseTypeDirty = false;
   opportunityCaseTypeCommitInProgress = false;
   opportunityActiveStandardity = "UNREVIEWED";
   opportunityArchivedStandardity = "UNREVIEWED";
   opportunityStandardityDirty = false;
   opportunityStandardityCommitInProgress = false;
   opportunityAnnotationReadOnly = recoveryPending;
   opportunitySessionStateRestored = false;
   opportunitySessionWorkYear = fullWorkYear;
   opportunityCaseSearchCaseId = "";
   opportunityExplicitNoSelection = true;
   bool sessionStateReady = true;
   if(!recoveryPending)
      sessionStateReady = PersistOpportunityExplicitNoSelection(chartID);
   opportunitySessionStateRestored = (!recoveryPending && sessionStateReady);
   UpdateOpportunityCaseSelectorButton();
   UpdateOpportunityCaseSearchButtons();
   UpdateOpportunityAnnotationPanel();
   return sessionStateReady;
  }

bool CM_DeleteRefreshReloadCatalog(long chartID)
  {
   return LoadOpportunityCaseCatalog(chartID);
  }

#endif
