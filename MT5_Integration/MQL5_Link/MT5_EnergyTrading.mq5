//+------------------------------------------------------------------+
//|                                           MT5_EnergyTrading.mq5 |
//|                        Copyright 2026, Quantitative Trading Model|
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Quantitative Trading Model"
#property link      "https://www.mql5.com"
#property version   "1.70"

// --- DLL Imports for Named Pipe (Kernel32) ---
#import "kernel32.dll"
int CreateFileW(string lpFileName, uint dwDesiredAccess, uint dwShareMode, uint lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, int hTemplateFile);
bool ReadFile(int hFile, uchar &lpBuffer[], uint nNumberOfBytesToRead, uint &lpNumberOfBytesRead, int lpOverlapped);
bool WriteFile(int hFile, uchar &lpBuffer[], uint nNumberOfBytesToWrite, uint &lpNumberOfBytesWritten, int lpOverlapped);
bool CloseHandle(int hObject);
bool PeekNamedPipe(int hNamedPipe, int lpBuffer, int nBufferSize, int lpBytesRead, uint &lpTotalBytesAvail, int lpBytesLeftThisMessage);
#import

// --- Inputs ---
input bool     InpCreateCustomSymbol = true;          // Create Custom Symbol (EURUSD_2024)?
input string   InpSymbolName         = "EURUSD@_2024"; // Custom Symbol Name (with @ suffix)
input string   InpBaseSymbol         = "EURUSD@";     // Base Symbol (Source Specs)
// input string   InpFileName           = "EURUSD_2024_Import.csv"; // REMOVED: No longer used
input string   InpTemplateName       = "红绿入场.tpl"; // Chart template to apply
input string   InpTemplateAltPath    = "E:\\Quantitative trading model\\MT5_Integration\\MQL5_Link\\红绿入场.tpl"; // Fallback absolute path

// --- Constants ---
#define GENERIC_READ 0x80000000
#define GENERIC_WRITE 0x40000000
#define OPEN_EXISTING 3
#define INVALID_HANDLE_VALUE -1
#define PIPE_ACCESS_DUPLEX 3

// --- Global Variables ---
string pipeName = "\\\\.\\pipe\\MT5_Python_Bridge";
long hPipe = INVALID_HANDLE_VALUE;
bool isPaused = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Initializing Python Bridge EA (Remote Control - Empty Mode)...");
   
   // --- 1. Custom Symbol Creation Logic ---
   if(InpCreateCustomSymbol)
     {
      // Check if we are already running ON the custom chart
      if(_Symbol != InpSymbolName)
        {
         CreateCustomSymbol();
         // "Single Window Experience": Close self after spawning the new chart
         // Note: We assume the new chart will load the EA via template or manual action.
         // BUT, to be safe and truly automated, we should apply a template to the new chart that INCLUDES this EA.
         Print("🚀 Launching Target Chart and closing Launcher...");
         
         // Give it a split second to ensure the new chart is registered
         Sleep(500);
         
         // Close the CURRENT chart (Launcher)
         ChartClose(ChartID()); 
         return(INIT_SUCCEEDED);
        }
     }
   
   // --- 2. Pipe Connection ---
   EventSetMillisecondTimer(500);
   ConnectPipe();
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(hPipe != INVALID_HANDLE_VALUE)
     {
      CloseHandle(hPipe);
      Print("Pipe handle closed.");
     }
  }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(hPipe != INVALID_HANDLE_VALUE)
     {
      ReadPipeCommand();
     }
   else
     {
      ConnectPipe();
     }
  }

// --- Custom Symbol Logic ---

void CreateCustomSymbol()
  {
   // Check if exists
   if(SymbolSelect(InpSymbolName, true))
     {
      Print("Symbol ", InpSymbolName, " already exists. Deleting to ensure clean state...");
      
      // 1. Close any EXISTING chart of this symbol
      CloseExistingChart(InpSymbolName);
      Sleep(200); // Wait for chart to close
      
      // 2. Hide from Market Watch
      SymbolSelect(InpSymbolName, false);
      Sleep(200); // Wait for symbol to be deselected
      
      // 3. Delete Custom Symbol (Wipes History)
      if(!CustomSymbolDelete(InpSymbolName))
      {
         Print("⚠️ Failed to delete symbol: ", GetLastError(), ". Trying to delete rates only.");
         int deleted = CustomRatesDelete(InpSymbolName, 0, D'2099.01.01 00:00'); // Fallback: Clear all history
         Print("Deleted ", deleted, " bars from history.");
      }
      else
      {
         Print("✅ Custom Symbol Deleted: ", InpSymbolName);
      }
     }
     
   Print("Creating Custom Symbol: ", InpSymbolName, " based on ", InpBaseSymbol);
   
   // Ensure Base Symbol is selected
   if(!SymbolSelect(InpBaseSymbol, true))
     {
      Print("Error: Base symbol ", InpBaseSymbol, " not found!");
      return;
     }
     
   if(!CustomSymbolCreate(InpSymbolName, "Custom", InpBaseSymbol))
     {
      Print("Error creating custom symbol: ", GetLastError());
      return;
     }
     
   // --- Insert Initial Empty Bar (Using Replace to Wipe History) ---
   // Instead of reading CSV, we just insert ONE bar to make the chart valid.
   MqlRates rates[];
   ArrayResize(rates, 1);
   
   rates[0].time = D'2024.01.01 00:00';
   rates[0].open = 1.10000; // Dummy price
   rates[0].high = 1.10050;
   rates[0].low = 1.09950;
   rates[0].close = 1.10000;
   rates[0].tick_volume = 1;
   rates[0].spread = 10;
   rates[0].real_volume = 0;
   
   // USE REPLACE INSTEAD OF UPDATE TO FORCE WIPE OF ALL OTHER DATA
   int written = CustomRatesReplace(InpSymbolName, 0, D'2099.12.31', rates);
   Print("Initialized symbol with ", written, " dummy bar (History Replaced).");
      
   if(written > 0)
     {
      SymbolSelect(InpSymbolName, true);
      
      // Cleanup here too just in case
      CloseExistingChart(InpSymbolName);
      
      Print("Opening new chart for ", InpSymbolName);
      long chartID = ChartOpen(InpSymbolName, PERIOD_H1);
      
      // Apply template
      if(chartID != 0)
      {
         ApplyTemplateToChart(chartID);
         
         // IMPORTANT: The template "红绿入场.tpl" MUST contain this EA for the chain to continue!
         // If it doesn't, the new chart will just be a naked chart.
         // We can programmatically load the EA onto the new chart, but MQL5 restricts this for security.
         // Best approach: User saves "红绿入场.tpl" WITH the EA attached.
      }
     }
  }

void CloseExistingChart(string symbol)
{
   long currChart = ChartFirst();
   while(currChart != -1)
   {
      if(ChartSymbol(currChart) == symbol)
      {
         Print("Closing old chart: ", currChart);
         ChartClose(currChart);
         currChart = ChartFirst(); 
         continue; 
      }
      currChart = ChartNext(currChart);
   }
}

// Helper to find the Replay Chart ID dynamically
long GetReplayChartID()
{
   long currChart = ChartFirst();
   while(currChart != -1)
   {
      if(ChartSymbol(currChart) == InpSymbolName)
      {
         return currChart;
      }
      currChart = ChartNext(currChart);
   }
   return 0; // Not found
}

// Apply template to a chart with robust path resolution
void ApplyTemplateToChart(long chartID)
{
   if(chartID == 0) { Print("Template apply skipped: invalid chartID"); return; }
   
   // Default templates directory inside terminal data path
   string tplDefaultPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Profiles\\Templates\\" + InpTemplateName;
   bool applied = false;
   
   // Try alternative absolute path first (project path)
   if(FileIsExist(InpTemplateAltPath))
   {
      applied = ChartApplyTemplate(chartID, InpTemplateAltPath);
      if(applied) { Print("Applied template from alt path: ", InpTemplateAltPath); ChartRedraw(chartID); return; }
   }
   
   // Fallback to default templates directory
   if(FileIsExist(tplDefaultPath))
   {
      applied = ChartApplyTemplate(chartID, tplDefaultPath);
      if(applied) { Print("Applied template from default path: ", tplDefaultPath); ChartRedraw(chartID); return; }
   }
   
   // Last resort: try by name (some terminals resolve by name)
   applied = ChartApplyTemplate(chartID, InpTemplateName);
   if(applied) { Print("Applied template by name: ", InpTemplateName); ChartRedraw(chartID); return; }
   
   Print("❌ Unable to apply template: ", InpTemplateName);
}

// --- Pipe Logic (Unchanged) ---

void ConnectPipe()
  {
   hPipe = CreateFileW(pipeName, GENERIC_READ | GENERIC_WRITE, 0, 0, OPEN_EXISTING, 0, 0);
   if(hPipe != INVALID_HANDLE_VALUE)
     {
      Print("Successfully connected to Python Pipe!");
      ShowLabel(0, "Python: Connected (Launcher)"); // Show on current chart
     }
  }

void ReadPipeCommand()
  {
   uchar buffer[1024];
   uint bytesRead = 0;
   uint bytesAvail = 0;
   
   if(PeekNamedPipe(hPipe, 0, 0, 0, bytesAvail, 0))
     {
      if(bytesAvail > 0)
        {
         if(ReadFile(hPipe, buffer, 1024, bytesRead, 0))
           {
            string msg = CharArrayToString(buffer, 0, bytesRead);
            ProcessCommand(msg);
           }
        }
     }
  }

void ProcessCommand(string message)
  {
   Print("Received raw: ", message);
   
   // Find target chart
   long targetChart = GetReplayChartID();
   if(targetChart == 0)
   {
      Print("⚠️ Replay chart not found! Sending command to Launcher instead.");
      targetChart = 0; // Fallback to current chart
   }
   
   string parts[];
   int count = StringSplit(message, '|', parts);
   
   if(count >= 2)
     {
      string cmd = parts[0];
      string data = parts[1];
      
      if(cmd == "MSG") ShowLabel(targetChart, data);
      else if(cmd == "VLINE")
        {
         datetime dt = StringToTime(data);
         CreateVLine(targetChart, dt);
         ShowLabel(targetChart, "VLine at " + data);
         JumpToTime(targetChart, dt);
        }
      else if(cmd == "SET_RANGE")
        {
         if(count >= 3)
           {
            string startStr = parts[1];
            string endStr = parts[2];
            datetime startDt = StringToTime(startStr);
            datetime endDt = StringToTime(endStr);
            
            // Set period on target chart
            ChartSetSymbolPeriod(targetChart, InpSymbolName, PERIOD_H1);
            
            CreateRangeMarker(targetChart, startDt, endDt);
            ShowLabel(targetChart, "Range Set: " + startStr + " to " + endStr);
            JumpToTime(targetChart, startDt);
           }
        }
      else if(cmd == "ADD_BAR")
        {
         AddBarToChart(data);
        }
     }
  }

//Helper to show label
void ShowLabel(long chartID, string text)
{
   ObjectCreate(chartID, "PythonMsg", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(chartID, "PythonMsg", OBJPROP_TEXT, "Python: " + text);
   ObjectSetInteger(chartID, "PythonMsg", OBJPROP_XDISTANCE, 50);
   ObjectSetInteger(chartID, "PythonMsg", OBJPROP_YDISTANCE, 50);
   ObjectSetInteger(chartID, "PythonMsg", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(chartID, "PythonMsg", OBJPROP_FONTSIZE, 20);
   ChartRedraw(chartID);
}

// Helper to draw VLine
void CreateVLine(long chartID, datetime time)
{
   string name = "Py_VLine_" + TimeToString(time);
   ObjectCreate(chartID, name, OBJ_VLINE, 0, time, 0);
   ObjectSetInteger(chartID, name, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartID, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(chartID, name, OBJPROP_SELECTABLE, true);
   Print("Created VLine at ", time, " on Chart ", chartID);
}

// Helper to draw Range Markers (Start/End)
void CreateRangeMarker(long chartID, datetime start, datetime end)
{
   string nameStart = "Range_Start";
   ObjectCreate(chartID, nameStart, OBJ_VLINE, 0, start, 0);
   ObjectSetInteger(chartID, nameStart, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(chartID, nameStart, OBJPROP_WIDTH, 3);
   ObjectSetInteger(chartID, nameStart, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetString(chartID, nameStart, OBJPROP_TEXT, "Replay Start");

   string nameEnd = "Range_End";
   ObjectCreate(chartID, nameEnd, OBJ_VLINE, 0, end, 0);
   ObjectSetInteger(chartID, nameEnd, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(chartID, nameEnd, OBJPROP_WIDTH, 3);
   ObjectSetInteger(chartID, nameEnd, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetString(chartID, nameEnd, OBJPROP_TEXT, "Replay End");
}

// Helper to Jump to Time
void JumpToTime(long chartID, datetime time)
{
   ChartSetInteger(chartID, CHART_AUTOSCROLL, false);
   
   // Use Symbol() of the target chart, not _Symbol (which is Launcher's symbol)
   string sym = ChartSymbol(chartID);
   ENUM_TIMEFRAMES per = ChartPeriod(chartID);
   
   int barIndex = iBarShift(sym, per, time);
   Print("Navigating to Time: ", time, " | BarIndex: ", barIndex, " on ", sym);

   if(barIndex != -1)
   {
      ChartNavigate(chartID, CHART_END, -barIndex + 20); 
      ChartRedraw(0);
   }
   else
   {
      Print("❌ Time not found in history: ", time);
      ShowLabel(chartID, "Error: Time not found");
   }
}

// Helper to Add Bar
void AddBarToChart(string data)
{
   string parts[];
   int count = StringSplit(data, ',', parts);
   
   if(count < 6)
   {
      Print("❌ Invalid ADD_BAR data: ", data);
      return;
   }
   
   MqlRates rates[];
   ArrayResize(rates, 1);
   
   rates[0].time = StringToTime(parts[0]);
   rates[0].open = StringToDouble(parts[1]);
   rates[0].high = StringToDouble(parts[2]);
   rates[0].low = StringToDouble(parts[3]);
   rates[0].close = StringToDouble(parts[4]);
   rates[0].tick_volume = StringToInteger(parts[5]);
   rates[0].spread = 10;
   rates[0].real_volume = 0;
   
   int written = CustomRatesUpdate(InpSymbolName, rates);
   if(written > 0)
   {
      // Print("✅ Added Bar: ", parts[0]);
      // Force chart refresh
      long chartID = GetReplayChartID();
      if(chartID != 0)
      {
         // ChartSetInteger(chartID, CHART_AUTOSCROLL, true); // Optional: Force scroll
         ChartRedraw(chartID);
      }
   }
   else
   {
      Print("❌ Failed to add bar: ", GetLastError());
   }
}
