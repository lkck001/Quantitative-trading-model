#ifndef UI_CM_DELETE_PRESENTER_MQH
#define UI_CM_DELETE_PRESENTER_MQH

#define UI_CM_DELETE_FEEDBACK_RECOVERY_BLOCKED 1
#define UI_CM_DELETE_FEEDBACK_RECOVERY_INVALID 2
#define UI_CM_DELETE_FEEDBACK_RECOVERY_CANCELLED 3
#define UI_CM_DELETE_FEEDBACK_RECOVERY_SUCCEEDED 4
#define UI_CM_DELETE_FEEDBACK_RECOVERY_WARNING 5
#define UI_CM_DELETE_FEEDBACK_NOT_DISPLAYED 6
#define UI_CM_DELETE_FEEDBACK_HOST_IDENTITY_CONFLICT 7
#define UI_CM_DELETE_FEEDBACK_DELETE_CANCELLED 8
#define UI_CM_DELETE_FEEDBACK_DELETE_SUCCEEDED 9
#define UI_CM_DELETE_FEEDBACK_DELETE_WARNING 10
#define UI_CM_DELETE_FEEDBACK_DOMAIN_NOT_FORMAL 11
#define UI_CM_DELETE_FEEDBACK_DOMAIN_IDENTITY_CONFLICT 12
#define UI_CM_DELETE_FEEDBACK_DOMAIN_STALE 13
#define UI_CM_DELETE_FEEDBACK_DOMAIN_ARCHIVE_MISSING 14
#define UI_CM_DELETE_FEEDBACK_DOMAIN_ROLLED_BACK 15
#define UI_CM_DELETE_FEEDBACK_DOMAIN_RECOVERY_REQUIRED 16
#define UI_CM_DELETE_FEEDBACK_DOMAIN_TRANSACTION_BUSY 17
#define UI_CM_DELETE_FEEDBACK_DOMAIN_OTHER 18

struct UI_CM_DeleteFeedback
  {
   string text;
   uint durationMs;
  };

void UI_CM_BuildDeleteFeedback(int feedbackCode,
                               string detail,
                               UI_CM_DeleteFeedback &feedback)
  {
   feedback.durationMs = 4000;
   if(feedbackCode == UI_CM_DELETE_FEEDBACK_RECOVERY_BLOCKED)
      feedback.text = "请先恢复未完成的删除事务";
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_RECOVERY_INVALID)
      feedback.text = "恢复失败 | 删除事务日志无效";
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_RECOVERY_CANCELLED)
     {
      feedback.text = "恢复已取消";
      feedback.durationMs = 3000;
     }
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_RECOVERY_SUCCEEDED)
     {
      feedback.text = "删除事务已恢复 | 当前未选择案例";
      feedback.durationMs = 3000;
     }
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_RECOVERY_WARNING)
      feedback.text = "删除事务已恢复 | 空态或目录刷新失败";
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_NOT_DISPLAYED)
      feedback.text = "删除不可用 | 请先展示正式案例";
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_HOST_IDENTITY_CONFLICT)
      feedback.text = "删除不可用 | 案例身份冲突";
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_DELETE_CANCELLED)
     {
      feedback.text = "删除已取消";
      feedback.durationMs = 3000;
     }
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_DELETE_SUCCEEDED)
     {
      feedback.text = "案例已永久删除 | 当前未选择案例";
      feedback.durationMs = 3000;
     }
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_DELETE_WARNING)
      feedback.text = "案例已删除 | 空态或目录刷新失败";
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_DOMAIN_NOT_FORMAL)
      feedback.text = "删除不可用 | 当前不是正式案例";
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_DOMAIN_IDENTITY_CONFLICT)
      feedback.text = "删除不可用 | 案例身份冲突";
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_DOMAIN_STALE)
      feedback.text = "删除失败 | 档案已变化，请重试";
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_DOMAIN_ARCHIVE_MISSING)
      feedback.text = "删除失败 | 正式档案不可用";
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_DOMAIN_ROLLED_BACK)
      feedback.text = "删除失败 | 已恢复删除前档案";
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_DOMAIN_RECOVERY_REQUIRED)
      feedback.text = "删除中断 | 请点击恢复删除";
   else if(feedbackCode == UI_CM_DELETE_FEEDBACK_DOMAIN_TRANSACTION_BUSY)
      feedback.text = "删除忙碌 | 请稍后重试";
   else
      feedback.text = "删除失败 | " + detail;
  }

#endif
