//+------------------------------------------------------------------+
//|                                                   PipeClient.mq5 |
//|                        Copyright 2026, Quantitative Trading Model|
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Quantitative Trading Model"
#property link      "https://www.mql5.com"
#property version   "1.00"

// Import file operations
#include <Files\FilePipe.mqh>

// Pipe Name (Must match Python side)
string pipeName = "\\\\.\\pipe\\MT5_Python_Bridge";
int pipeHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Attempting to open pipe: ", pipeName);
   
   // In Strategy Tester, we use standard FileOpen for pipes if they are treated as files
   // However, MQL5's FileOpen doesn't support named pipes directly in standard path.
   // We usually need kernel32.dll for CreateFile, BUT Strategy Tester sandboxes DLLs.
   // 
   // WAIT! The research said "Named Pipes are treated as files".
   // Actually, standard FileOpen in MQL5 is sandboxed to MQL5/Files.
   // To open a system pipe, we MUST use kernel32.dll.
   // 
   // CRITICAL: You must enable "Allow DLL imports" in Strategy Tester settings.
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(pipeHandle != INVALID_HANDLE)
     {
      // CloseHandle(pipeHandle); // Need kernel32 import
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. Try to read from pipe
   // 2. Parse command (e.g., "DRAW_LINE")
   // 3. Execute ObjectCreate
   
   Print("OnTick: Waiting for command...");
   
   // For MVP test, we just print
  }
//+------------------------------------------------------------------+
