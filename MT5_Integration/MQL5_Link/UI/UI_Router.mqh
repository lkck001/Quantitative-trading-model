#ifndef UI_ROUTER_MQH
#define UI_ROUTER_MQH

#include "CaseManagement\Deletion\UI_CM_DeletePanel.mqh"
#include "CaseManagement\Deletion\UI_CM_DeleteActions.mqh"
#include "CaseManagement\Deletion\UI_CM_DeletePresenter.mqh"

bool UI_CM_CreateDeleteButton(long chartID)
  {
   return UI_CM_CreateDeleteControl(chartID);
  }

void UI_CM_DestroyDeleteButton(long chartID)
  {
   UI_CM_DestroyDeleteControl(chartID);
  }

void UI_CM_UpdateDeleteButton(long chartID,
                              bool enabled,
                              bool recoveryPending)
  {
   UI_CM_UpdateDeleteControl(chartID, enabled, recoveryPending);
  }

bool UI_CM_RouteDeleteAction(string objectName, int &actionCode)
  {
   return UI_CM_RouteDeleteObject(objectName, actionCode);
  }

bool UI_CM_ConfirmDeleteAction(string caseID,
                               string caseType,
                               string symbol,
                               string timeframe,
                               int &targetRows[])
  {
   return UI_CM_ConfirmDelete(caseID, caseType, symbol, timeframe,
                              targetRows);
  }

bool UI_CM_ConfirmRecoveryAction(string caseID,
                                 int &targetRows[])
  {
   return UI_CM_ConfirmDeleteRecovery(caseID, targetRows);
  }

void UI_CM_GetDeleteFeedback(int feedbackCode,
                             string detail,
                             UI_CM_DeleteFeedback &feedback)
  {
   UI_CM_BuildDeleteFeedback(feedbackCode, detail, feedback);
  }

#endif
