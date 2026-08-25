#ifndef PR_MARKET_DATA_MQH
#define PR_MARKET_DATA_MQH

#include "..\Contract\PR_Types.mqh"
#include "..\Core\PR_SessionPolicy.mqh"

#define PR_H1_SECONDS 3600
#define PR_CONTEXT_LOOKBACK_SECONDS 3888000

void PR_SetMarketFailure(PR_MarketSnapshot &snapshot,
                         string statusCode,
                         string reasonCode,
                         int lastError)
  {
   snapshot.captureOK = false;
   snapshot.statusCode = statusCode;
   snapshot.reasonCode = reasonCode;
   snapshot.lastError = lastError;
  }

bool PR_IsValidMarketBar(MqlRates &bar)
  {
   if(bar.time <= 0) return false;
   if(!MathIsValidNumber(bar.open) || !MathIsValidNumber(bar.high) ||
      !MathIsValidNumber(bar.low) || !MathIsValidNumber(bar.close))
      return false;
   if(bar.open <= 0.0 || bar.high <= 0.0 ||
      bar.low <= 0.0 || bar.close <= 0.0)
      return false;
   if(bar.high < bar.low || bar.high < bar.open || bar.high < bar.close)
      return false;
   if(bar.low > bar.open || bar.low > bar.close)
      return false;
   return true;
  }

bool PR_IsH1OpenTimestamp(datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts)) return false;
   return (parts.min == 0 && parts.sec == 0);
  }

bool PR_RecordSessionGap(PR_MarketSnapshot &snapshot,
                         datetime previousTime,
                         datetime nextTime,
                         bool releaseWindow)
  {
   if(nextTime <= previousTime)
     {
      PR_SetMarketFailure(snapshot, PR_DATA_STATUS_INVALID_BAR,
                          PR_DATA_REASON_INVALID_BAR, 0);
      return false;
     }
   long deltaSeconds = (long)(nextTime - previousTime);
   if(deltaSeconds == PR_H1_SECONDS) return true;

   string gapReason = PR_SESSION_GAP_REASON_UNEXPECTED;
   bool expected = PR_IsExpectedSessionGap(previousTime, nextTime, gapReason);
   int missingHours = 0;
   if((deltaSeconds % PR_H1_SECONDS) == 0)
      missingHours = (int)(deltaSeconds / PR_H1_SECONDS) - 1;
   if(expected && missingHours > 0)
     {
      snapshot.expectedClosureGapCount++;
      snapshot.expectedClosureHours += missingHours;
      snapshot.gapStatus = PR_SESSION_GAP_STATUS_EXPECTED_CLOSURE_ONLY;
      snapshot.gapReason = gapReason;
      return true;
     }

   snapshot.unexpectedGapCount++;
   snapshot.gapStatus = PR_SESSION_GAP_STATUS_UNEXPECTED;
   snapshot.gapReason = gapReason;
   if(snapshot.firstUnexpectedGapPrevious == 0)
     {
      snapshot.firstUnexpectedGapPrevious = previousTime;
      snapshot.firstUnexpectedGapNext = nextTime;
      snapshot.firstUnexpectedGapHours = missingHours;
     }
   PR_SetMarketFailure(
      snapshot, PR_DATA_STATUS_DISCONTIGUOUS_WINDOW,
      releaseWindow ? PR_DATA_REASON_UNEXPECTED_RELEASE_GAP :
                      PR_DATA_REASON_UNEXPECTED_CONTEXT_GAP,
      0);
   return false;
  }

uint PR_UpdateMarketHash(uint hash, string value)
  {
   int length = StringLen(value);
   for(int i = 0; i < length; i++)
     {
      ushort character = (ushort)StringGetCharacter(value, i);
      hash ^= (uchar)(character & 0x00FF);
      hash *= 16777619;
      hash ^= (uchar)((character >> 8) & 0x00FF);
      hash *= 16777619;
     }
   return hash;
  }

uint PR_UpdateMarketHashWithBar(uint hash, MqlRates &bar)
  {
   string value = IntegerToString((long)bar.time) + ":" +
                  DoubleToString(bar.open, 16) + ":" +
                  DoubleToString(bar.high, 16) + ":" +
                  DoubleToString(bar.low, 16) + ":" +
                  DoubleToString(bar.close, 16);
   return PR_UpdateMarketHash(hash, value);
  }

string PR_BuildMarketFingerprint(PR_MarketSnapshot &snapshot)
  {
   uint hash = 2166136261;
   hash = PR_UpdateMarketHash(hash, snapshot.symbol);
   hash = PR_UpdateMarketHash(hash, IntegerToString((int)snapshot.timeframe));
   hash = PR_UpdateMarketHash(hash, IntegerToString((long)snapshot.windowStart));
   hash = PR_UpdateMarketHash(hash, IntegerToString((long)snapshot.windowEnd));
   hash = PR_UpdateMarketHash(hash, snapshot.sessionPolicyVersion);
   hash = PR_UpdateMarketHash(hash, snapshot.gapStatus);
   hash = PR_UpdateMarketHash(hash, snapshot.gapReason);
   hash = PR_UpdateMarketHash(hash, IntegerToString(snapshot.expectedClosureHours));
   hash = PR_UpdateMarketHash(hash, IntegerToString(snapshot.unexpectedGapCount));
   for(int i = 0; i < ArraySize(snapshot.contextBars); i++)
      hash = PR_UpdateMarketHashWithBar(hash, snapshot.contextBars[i]);
   for(int i = 0; i < ArraySize(snapshot.releaseBars); i++)
      hash = PR_UpdateMarketHashWithBar(hash, snapshot.releaseBars[i]);
   return "PRMD1|symbol=" + snapshot.symbol +
          "|tf=" + IntegerToString((int)snapshot.timeframe) +
          "|start=" + IntegerToString((long)snapshot.windowStart) +
          "|end=" + IntegerToString((long)snapshot.windowEnd) +
          "|calendar_hours=" + IntegerToString(snapshot.calendarSpanHours) +
          "|calendar_bars=" + IntegerToString(snapshot.expectedReleaseBarCount) +
          "|context=" + IntegerToString(snapshot.contextBarCount) +
          "|release=" + IntegerToString(snapshot.releaseBarCount) +
          "|gap_status=" + snapshot.gapStatus +
          "|gap_reason=" + snapshot.gapReason +
          "|expected_closure_gaps=" + IntegerToString(snapshot.expectedClosureGapCount) +
          "|expected_closure_hours=" + IntegerToString(snapshot.expectedClosureHours) +
          "|unexpected_gaps=" + IntegerToString(snapshot.unexpectedGapCount) +
          "|session_policy=" + snapshot.sessionPolicyVersion +
          "|hash=" + IntegerToString((long)hash);
  }

bool PR_IsExactH1Open(string symbol, datetime value)
  {
   ResetLastError();
   int shift = iBarShift(symbol, PERIOD_H1, value, true);
   if(shift < 0) return false;
   return (iTime(symbol, PERIOD_H1, shift) == value);
  }

bool PR_CopyRecentContextBars(string symbol,
                              datetime windowStart,
                              PR_MarketSnapshot &snapshot)
  {
   MqlRates candidates[];
   ArraySetAsSeries(candidates, false);
   ResetLastError();
   int copied = CopyRates(symbol, PERIOD_H1,
                          windowStart - PR_CONTEXT_LOOKBACK_SECONDS,
                          windowStart - 1, candidates);
   if(copied < 0)
     {
      PR_SetMarketFailure(snapshot, PR_DATA_STATUS_COPY_FAILED,
                          PR_DATA_REASON_COPY_FAILED, GetLastError());
      return false;
     }
   if(copied < PR_ATR_CONTEXT_BAR_COUNT)
     {
      PR_SetMarketFailure(snapshot, PR_DATA_STATUS_INSUFFICIENT_ATR_CONTEXT,
                          PR_DATA_REASON_INSUFFICIENT_ATR_CONTEXT, 0);
      return false;
     }
   if(ArrayResize(snapshot.contextBars, PR_ATR_CONTEXT_BAR_COUNT) !=
      PR_ATR_CONTEXT_BAR_COUNT)
     {
      PR_SetMarketFailure(snapshot, PR_DATA_STATUS_COPY_FAILED,
                          PR_DATA_REASON_COPY_FAILED, 0);
      return false;
     }
   int first = copied - PR_ATR_CONTEXT_BAR_COUNT;
   for(int i = 0; i < PR_ATR_CONTEXT_BAR_COUNT; i++)
      snapshot.contextBars[i] = candidates[first + i];
   snapshot.contextBarCount = PR_ATR_CONTEXT_BAR_COUNT;
   return true;
  }

bool PR_ValidateMarketBars(PR_MarketSnapshot &snapshot)
  {
   for(int i = 0; i < snapshot.contextBarCount; i++)
     {
      if(!PR_IsValidMarketBar(snapshot.contextBars[i]))
        {
         PR_SetMarketFailure(snapshot, PR_DATA_STATUS_INVALID_BAR,
                             PR_DATA_REASON_INVALID_BAR, 0);
         return false;
        }
      if(!PR_IsH1OpenTimestamp(snapshot.contextBars[i].time))
        {
         PR_SetMarketFailure(snapshot, PR_DATA_STATUS_INVALID_BAR,
                             PR_DATA_REASON_INVALID_BAR, 0);
         return false;
        }
      if(i > 0 && !PR_RecordSessionGap(snapshot,
                                       snapshot.contextBars[i - 1].time,
                                       snapshot.contextBars[i].time, false))
         return false;
     }
   for(int i = 0; i < snapshot.releaseBarCount; i++)
     {
      if(!PR_IsValidMarketBar(snapshot.releaseBars[i]))
        {
         PR_SetMarketFailure(snapshot, PR_DATA_STATUS_INVALID_BAR,
                             PR_DATA_REASON_INVALID_BAR, 0);
         return false;
        }
      if(!PR_IsH1OpenTimestamp(snapshot.releaseBars[i].time))
        {
         PR_SetMarketFailure(snapshot, PR_DATA_STATUS_INVALID_BAR,
                             PR_DATA_REASON_INVALID_BAR, 0);
         return false;
        }
      if(i > 0 && !PR_RecordSessionGap(snapshot,
                                       snapshot.releaseBars[i - 1].time,
                                       snapshot.releaseBars[i].time, true))
         return false;
     }
   return true;
  }

bool PR_CaptureH1MarketSnapshot(string symbol,
                                ENUM_TIMEFRAMES timeframe,
                                datetime windowStart,
                                datetime windowEnd,
                                PR_MarketSnapshot &snapshot)
  {
   PR_ResetMarketSnapshot(snapshot);
   snapshot.symbol = symbol;
   snapshot.timeframe = timeframe;
   snapshot.windowStart = windowStart;
   snapshot.windowEnd = windowEnd;
   snapshot.calendarSpanHours = (int)((windowEnd - windowStart) / PR_H1_SECONDS);
   if(windowStart <= 0 || windowEnd <= windowStart ||
      (windowEnd - windowStart) % PR_H1_SECONDS != 0)
     {
      PR_SetMarketFailure(snapshot, PR_DATA_STATUS_INVALID_WINDOW,
                          PR_DATA_REASON_INVALID_WINDOW, 0);
      return false;
     }
   if(timeframe != PERIOD_H1)
     {
      PR_SetMarketFailure(snapshot, PR_DATA_STATUS_UNSUPPORTED_TIMEFRAME,
                          PR_DATA_REASON_UNSUPPORTED_TIMEFRAME, 0);
      return false;
     }
   if(!PR_IsExactH1Open(symbol, windowStart) ||
      !PR_IsExactH1Open(symbol, windowEnd))
     {
      PR_SetMarketFailure(snapshot, PR_DATA_STATUS_BOUNDARY_NOT_ALIGNED,
                          PR_DATA_REASON_BOUNDARY_NOT_ALIGNED, GetLastError());
      return false;
     }
   snapshot.expectedReleaseBarCount =
      (int)((windowEnd - windowStart) / PR_H1_SECONDS);
   if(snapshot.expectedReleaseBarCount < PR_MIN_RELEASE_BAR_COUNT)
     {
      PR_SetMarketFailure(snapshot, PR_DATA_STATUS_INSUFFICIENT_RELEASE_BARS,
                          PR_DATA_REASON_INSUFFICIENT_RELEASE_BARS, 0);
      return false;
     }

   ArraySetAsSeries(snapshot.releaseBars, false);
   ResetLastError();
   int copied = CopyRates(symbol, PERIOD_H1, windowStart, windowEnd - 1,
                          snapshot.releaseBars);
   if(copied < 0)
     {
      PR_SetMarketFailure(snapshot, PR_DATA_STATUS_COPY_FAILED,
                          PR_DATA_REASON_COPY_FAILED, GetLastError());
      return false;
     }
   snapshot.releaseBarCount = copied;
   if(copied < PR_MIN_RELEASE_BAR_COUNT)
     {
      PR_SetMarketFailure(snapshot, PR_DATA_STATUS_INSUFFICIENT_RELEASE_BARS,
                          PR_DATA_REASON_INSUFFICIENT_RELEASE_BARS, 0);
      return false;
     }
   if(!PR_CopyRecentContextBars(symbol, windowStart, snapshot)) return false;
   if(!PR_ValidateMarketBars(snapshot)) return false;

   snapshot.captureOK = true;
   snapshot.statusCode = PR_DATA_STATUS_VALID;
   snapshot.reasonCode = snapshot.expectedClosureGapCount > 0 ?
                         PR_DATA_REASON_VALID_EXPECTED_CLOSURES :
                         PR_DATA_REASON_VALID;
   snapshot.lastError = 0;
   snapshot.fingerprint = PR_BuildMarketFingerprint(snapshot);
   return true;
  }

#endif
