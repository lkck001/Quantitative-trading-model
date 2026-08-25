#ifndef PR_SESSION_POLICY_MQH
#define PR_SESSION_POLICY_MQH

#include "..\Contract\PR_Types.mqh"

#define PR_SESSION_H1_SECONDS 3600
#define PR_SESSION_DAY_SECONDS 86400

#define PR_SESSION_GAP_STATUS_NOT_EVALUATED "NOT_EVALUATED"
#define PR_SESSION_GAP_STATUS_NONE "NO_GAP"
#define PR_SESSION_GAP_STATUS_EXPECTED_CLOSURE_ONLY "EXPECTED_CLOSURE_ONLY"
#define PR_SESSION_GAP_STATUS_UNEXPECTED "UNEXPECTED_GAP"

#define PR_SESSION_GAP_REASON_NONE "NO_SESSION_GAP"
#define PR_SESSION_GAP_REASON_WEEKEND "EXPECTED_WEEKEND_CLOSURE"
#define PR_SESSION_GAP_REASON_HOLIDAY "EXPECTED_KNOWN_HOLIDAY_CLOSURE"
#define PR_SESSION_GAP_REASON_UNEXPECTED "UNEXPECTED_TRADING_WINDOW_GAP"
#define PR_SESSION_GAP_REASON_INVALID_STEP "NON_H1_TIME_STEP"

bool PR_SameCalendarDate(datetime value, int year, int month, int day)
  {
   MqlDateTime parts;
   if(!TimeToStruct(value, parts)) return false;
   return (parts.year == year && parts.mon == month && parts.day == day);
  }

bool PR_GregorianEaster(int year, int &month, int &day)
  {
   if(year < 1) return false;
   int a = year % 19;
   int b = year / 100;
   int c = year % 100;
   int d = b / 4;
   int e = b % 4;
   int f = (b + 8) / 25;
   int g = (b - f + 1) / 3;
   int h = (19 * a + b - d - g + 15) % 30;
   int i = c / 4;
   int k = c % 4;
   int l = (32 + 2 * e + 2 * i - h - k) % 7;
   int m = (a + 11 * h + 22 * l) / 451;
   int value = h + l - 7 * m + 114;
   month = value / 31;
   day = (value % 31) + 1;
   return true;
  }

bool PR_IsKnownHolidayDate(datetime value)
  {
   MqlDateTime parts;
   if(!TimeToStruct(value, parts)) return false;
   if((parts.mon == 1 && parts.day == 1) ||
      (parts.mon == 12 && parts.day == 25))
      return true;

   int easterMonth = 0;
   int easterDay = 0;
   if(!PR_GregorianEaster(parts.year, easterMonth, easterDay)) return false;
   MqlDateTime easterParts;
   easterParts.year = parts.year;
   easterParts.mon = easterMonth;
   easterParts.day = easterDay;
   easterParts.hour = 0;
   easterParts.min = 0;
   easterParts.sec = 0;
   easterParts.day_of_week = 0;
   easterParts.day_of_year = 0;
   datetime easter = StructToTime(easterParts);
   MqlDateTime easterDate;
   MqlDateTime goodFridayDate;
   MqlDateTime easterMondayDate;
   if(!TimeToStruct(easter, easterDate) ||
      !TimeToStruct(easter - 2 * PR_SESSION_DAY_SECONDS, goodFridayDate) ||
      !TimeToStruct(easter + PR_SESSION_DAY_SECONDS, easterMondayDate))
      return false;
   return (PR_SameCalendarDate(value, easterDate.year,
                               easterDate.mon, easterDate.day) ||
           PR_SameCalendarDate(value, goodFridayDate.year,
                               goodFridayDate.mon, goodFridayDate.day) ||
           PR_SameCalendarDate(value, easterMondayDate.year,
                               easterMondayDate.mon, easterMondayDate.day));
  }

bool PR_IntervalContainsKnownHoliday(datetime previousTime,
                                     datetime nextTime)
  {
   MqlDateTime previousParts;
   if(!TimeToStruct(previousTime, previousParts)) return false;
   datetime cursor = StructToTime(previousParts);
   for(int i = 0; i <= 6; i++)
     {
      if(cursor > nextTime) break;
      if(PR_IsKnownHolidayDate(cursor)) return true;
      cursor += PR_SESSION_DAY_SECONDS;
     }
   if(PR_IsKnownHolidayDate(nextTime)) return true;
   return false;
  }

bool PR_IsExpectedSessionGap(datetime previousTime,
                             datetime nextTime,
                             string &reasonCode)
  {
   reasonCode = PR_SESSION_GAP_REASON_UNEXPECTED;
   if(previousTime <= 0 || nextTime <= previousTime) return false;
   long deltaSeconds = (long)(nextTime - previousTime);
   if(deltaSeconds <= PR_SESSION_H1_SECONDS) return false;
   if((deltaSeconds % PR_SESSION_H1_SECONDS) != 0)
     {
      reasonCode = PR_SESSION_GAP_REASON_INVALID_STEP;
      return false;
     }

   int deltaHours = (int)(deltaSeconds / PR_SESSION_H1_SECONDS);
   MqlDateTime previousParts;
   MqlDateTime nextParts;
   if(!TimeToStruct(previousTime, previousParts) ||
      !TimeToStruct(nextTime, nextParts))
      return false;

   bool weekendTransition =
      previousParts.day_of_week == 5 &&
      (nextParts.day_of_week == 0 || nextParts.day_of_week == 1) &&
      deltaHours >= 36 && deltaHours <= 80;
   if(weekendTransition)
     {
      reasonCode = PR_SESSION_GAP_REASON_WEEKEND;
      return true;
     }

   if(deltaHours <= 120 && PR_IntervalContainsKnownHoliday(previousTime, nextTime))
     {
      reasonCode = PR_SESSION_GAP_REASON_HOLIDAY;
      return true;
     }
   return false;
  }

#endif
