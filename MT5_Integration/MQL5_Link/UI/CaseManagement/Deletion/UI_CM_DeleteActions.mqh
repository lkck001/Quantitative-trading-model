#ifndef UI_CM_DELETE_ACTIONS_MQH
#define UI_CM_DELETE_ACTIONS_MQH

#define UI_CM_DELETE_ACTION_NONE 0
#define UI_CM_DELETE_ACTION_REQUEST 1

#define UI_CM_DELETE_OBJECT "btn_full_delete_case"

bool UI_CM_RouteDeleteObject(string objectName, int &actionCode)
  {
   actionCode = UI_CM_DELETE_ACTION_NONE;
   if(objectName != UI_CM_DELETE_OBJECT) return false;
   actionCode = UI_CM_DELETE_ACTION_REQUEST;
   return true;
  }

string UI_CM_DeleteCountsText(int &targetRows[])
  {
   if(ArraySize(targetRows) < 7) return "";
   return "主记录 " + IntegerToString(targetRows[0]) +
          " | 锚点 " + IntegerToString(targetRows[1]) +
          " | 关键Bar " + IntegerToString(targetRows[2]) +
          "\n图形 " + IntegerToString(targetRows[3]) +
          " | 区域 " + IntegerToString(targetRows[4]) +
          " | 语义 " + IntegerToString(targetRows[5]) +
          " | 通道边界 " + IntegerToString(targetRows[6]);
  }

bool UI_CM_ConfirmDelete(string caseID,
                         string caseType,
                         string symbol,
                         string timeframe,
                         int &targetRows[])
  {
   string message = "将永久删除当前正式案例，且无法撤销。\n\n" +
                    "案例：" + caseID + "\n" +
                    "类型：" + caseType + "\n" +
                    "来源：" + symbol + " / " + timeframe + "\n\n" +
                    UI_CM_DeleteCountsText(targetRows) + "\n\n" +
                    "是否确认永久删除？";
   int answer = MessageBox(message, "永久删除案例",
                           MB_YESNO|MB_ICONWARNING|MB_DEFBUTTON2);
   return (answer == IDYES);
  }

bool UI_CM_ConfirmDeleteRecovery(string caseID,
                                 int &targetRows[])
  {
   string message = "检测到未完成的案例删除事务。\n\n" +
                    "案例：" + caseID + "\n" +
                    UI_CM_DeleteCountsText(targetRows) + "\n\n" +
                    "将恢复到删除前的完整档案状态。是否继续？";
   int answer = MessageBox(message, "恢复删除事务",
                           MB_YESNO|MB_ICONWARNING|MB_DEFBUTTON2);
   return (answer == IDYES);
  }

#endif
