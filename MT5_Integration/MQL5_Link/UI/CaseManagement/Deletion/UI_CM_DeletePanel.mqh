#ifndef UI_CM_DELETE_PANEL_MQH
#define UI_CM_DELETE_PANEL_MQH

#include "UI_CM_DeleteActions.mqh"

bool UI_CM_CreateDeleteControl(long chartID)
  {
   ResetLastError();
   if(ObjectFind(chartID, UI_CM_DELETE_OBJECT) < 0 &&
      !ObjectCreate(chartID, UI_CM_DELETE_OBJECT,
                    OBJ_BUTTON, 0, 0, 0))
      return false;
   bool configured = true;
   configured = ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                                 OBJPROP_XDISTANCE, 210) && configured;
   configured = ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                                 OBJPROP_YDISTANCE, 58) && configured;
   configured = ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                                 OBJPROP_XSIZE, 90) && configured;
   configured = ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                                 OBJPROP_YSIZE, 24) && configured;
   configured = ObjectSetString(chartID, UI_CM_DELETE_OBJECT,
                                OBJPROP_TEXT, "删除案例") && configured;
   configured = ObjectSetString(chartID, UI_CM_DELETE_OBJECT,
                                OBJPROP_FONT, "Microsoft YaHei") && configured;
   configured = ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                                 OBJPROP_BGCOLOR, clrDimGray) && configured;
   configured = ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                                 OBJPROP_COLOR, clrWhite) && configured;
   configured = ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                                 OBJPROP_FONTSIZE, 8) && configured;
   configured = ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                                 OBJPROP_STATE, false) && configured;
   configured = ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                                 OBJPROP_SELECTABLE, false) && configured;
   configured = ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                                 OBJPROP_SELECTED, false) && configured;
   configured = ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                                 OBJPROP_HIDDEN, false) && configured;
   configured = ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                                 OBJPROP_BACK, false) && configured;
   configured = ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                                 OBJPROP_ZORDER, 1000) && configured;
   configured = ObjectSetString(chartID, UI_CM_DELETE_OBJECT,
                                OBJPROP_TOOLTIP,
                                "仅可永久删除当前正式案例") && configured;
   return configured;
  }

void UI_CM_DestroyDeleteControl(long chartID)
  {
   ObjectDelete(chartID, UI_CM_DELETE_OBJECT);
  }

void UI_CM_UpdateDeleteControl(long chartID,
                               bool enabled,
                               bool recoveryPending)
  {
   if(ObjectFind(chartID, UI_CM_DELETE_OBJECT) < 0) return;
   string text = recoveryPending ? "恢复删除" : "删除案例";
   color background = (enabled || recoveryPending) ?
                      clrFireBrick : clrDimGray;
   string tooltip = recoveryPending ?
                    "恢复未完成事务到删除前状态" :
                    (enabled ? "永久删除当前正式案例" :
                     "请先展示身份一致的正式案例");
   ObjectSetString(chartID, UI_CM_DELETE_OBJECT,
                   OBJPROP_TEXT, text);
   ObjectSetString(chartID, UI_CM_DELETE_OBJECT,
                   OBJPROP_TOOLTIP, tooltip);
   ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                    OBJPROP_BGCOLOR, background);
   ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                    OBJPROP_STATE, false);
   ObjectSetInteger(chartID, UI_CM_DELETE_OBJECT,
                    OBJPROP_SELECTED, false);
  }

#endif
