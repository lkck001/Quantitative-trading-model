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
long CreateFileW(string lpFileName, uint dwDesiredAccess, uint dwShareMode, uint lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, long hTemplateFile);
bool ReadFile(long hFile, uchar &lpBuffer[], uint nNumberOfBytesToRead, uint &lpNumberOfBytesRead, long lpOverlapped);
bool WriteFile(long hFile, uchar &lpBuffer[], uint nNumberOfBytesToWrite, uint &lpNumberOfBytesWritten, long lpOverlapped);
bool CloseHandle(long hObject);
bool PeekNamedPipe(long hNamedPipe, long lpBuffer, int nBufferSize, long lpBytesRead, uint &lpTotalBytesAvail, long lpBytesLeftThisMessage);
#import

#import "shell32.dll"
int ShellExecuteW(int hwnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import

// --- Inputs ---
input bool     InpCreateCustomSymbol = true;          // Create Custom Symbol (EURUSD_2024)?
input string   InpSymbolName         = "EURUSD@_2024"; // Custom Symbol Name (with @ suffix)
input string   InpBaseSymbol         = "EURUSD@";     // Base Symbol (Source Specs)
// input string   InpFileName           = "EURUSD_2024_Import.csv"; // REMOVED: No longer used
input string   InpTemplateName       = "红绿入场.tpl"; // Chart template to apply
input string   InpTemplateAltPath    = "E:\\Quantitative trading model\\MT5_Integration\\MQL5_Link\\红绿入场.tpl"; // Fallback absolute path
input string   InpPythonPath         = "E:\\Quantitative trading model\\VisualReplay_MVP\\launch_feed.bat"; // Launcher Batch File
input string   InpScriptPath         = ""; // Script Path (Handled by Batch File)

// --- Constants ---
#define GENERIC_READ 0x80000000
#define GENERIC_WRITE 0x40000000
#define OPEN_EXISTING 3
#define INVALID_HANDLE_VALUE -1
#define PIPE_ACCESS_DUPLEX 3

// --- Global Variables ---
string pipeName = "\\\\.\\pipe\\MT5_Python_Bridge";
long hPipe = INVALID_HANDLE_VALUE;
bool isPaused = true; // Default to PAUSED (matches Python state)

// UI Globals
int ui_base_x = 6;
int ui_base_y = 20;
bool isDraggingPanel = false; // No longer used for panel, but maybe for general drag state?
bool isDraggingKnob = false;  // Track if we are currently dragging the knob
int last_mouse_x = 0;
int last_mouse_y = 0;
double currentSpeed = 3.0; // Default Speed
int batchSize = 1; // Default Batch Size (x1)
string rx_buffer = ""; // Accumulate pipe data for line-based parsing

// --- Forward Declarations ---
void CreateCustomSymbol();
void CloseExistingChart(string symbol);
long GetReplayChartID();
void ApplyTemplateToChart(long chartID);
void ConnectPipe();
void ReadPipeCommand();
void ProcessCommand(string message);
void ShowLabel(long chartID, string text);
void SendCommand(string cmd);
void CreateVLine(long chartID, datetime time);
void CreateRangeMarker(long chartID, datetime start, datetime end);
void JumpToTime(long chartID, datetime time);
void AddBarToChart(string data);
void UpdateBatchLabel()
  {
   string text = StringFormat("(x%d)", batchSize);
   ObjectSetString(0, "lbl_batch", OBJPROP_TEXT, text);
   Print("UI Event: 📦 Batch Changed to ", text);
  }

void CreateControlPanel();
void DestroyControlPanel();
void UpdateUIState();
void UpdateSpeedLabel(double speed);
void UpdateBatchLabel();
void CreateButton(string name, int x, int y, int w, int h, string text, color bg);
void CreateRectLabel(string name, int x, int y, int w, int h, color bg, ENUM_BORDER_TYPE border);
void CreateLabel(string name, int x, int y, string text, color col, int size);
void ShiftControlPanel(int dx, int dy);
void ShiftObj(string name, int dx, int dy);

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
         // Check if symbol ALREADY exists (Persisted from previous run)
         if(!SymbolSelect(InpSymbolName, true))
         {
             CreateCustomSymbol(); // Only create if missing (or first run)
         }
         else
         {
             Print("✅ Custom Symbol ", InpSymbolName, " found. Preserving history.");
             // Ensure it's selected
             SymbolSelect(InpSymbolName, true);
         }
         
         // "Single Window Experience": Close self after spawning the new chart
         // Note: We assume the new chart will load the EA via template or manual action.
         // BUT, to be safe and truly automated, we should apply a template to the new chart that INCLUDES this EA.
         Print("🚀 Launching Target Chart and closing Launcher...");
         
         // Give it a split second to ensure the new chart is registered
         Sleep(500);
         
         // Check if chart is already open?
         if(GetReplayChartID() == 0)
         {
             long chartID = ChartOpen(InpSymbolName, PERIOD_H1);
             if(chartID != 0) ApplyTemplateToChart(chartID);
         }
         
         // Close the CURRENT chart (Launcher)
         ChartClose(ChartID()); 
         return(INIT_SUCCEEDED);
        }
     }
   
   // --- 2. Pipe Connection & Auto-Launch ---
   EventSetMillisecondTimer(50); // Faster polling to prevent pipe blocking
   ConnectPipe();
   
   // Auto-Launch if not connected
   if(hPipe == INVALID_HANDLE_VALUE)
   {
      Print("🚀 Auto-Launching Python Server on Startup...");
      ShellExecuteW(0, "open", InpPythonPath, InpScriptPath, "", 1);
   }
   
   // --- 3. UI Initialization ---
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true); // Enable mouse move events for slider
   
   // Cleanup any leftover legacy labels from previous runs
   ObjectDelete(0, "PythonMsg");
   
   CreateControlPanel();
   
   // --- Restore Play/Pause State ---
   if(GlobalVariableCheck("Energy_IsPaused"))
     {
      isPaused = (bool)GlobalVariableGet("Energy_IsPaused");
     }
   else
     {
      isPaused = true; // Default if no history
     }
     
   // Sync UI and Python with restored state
   if(!isPaused)
     {
      // If we were playing, update button to PAUSE style and send RESUME
      ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "⏸ PAUSE");
      ObjectSetInteger(0, "btn_play_pause", OBJPROP_BGCOLOR, clrRed);
      
      // We need to send RESUME, but pipe might not be ready yet.
      // ConnectPipe() is called in OnTimer.
      // So we'll set a flag or handle it in OnTimer?
      // Actually, ConnectPipe is called immediately in OnInit via OnTimer? No.
      // Let's just set the state. When pipe connects, Python is waiting.
      // Python defaults to PAUSED. So we MUST send RESUME once connected.
     }
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   
   // Save UI Position (Always save position)
   GlobalVariableSet("EnergyUI_X", ui_base_x);
   GlobalVariableSet("EnergyUI_Y", ui_base_y);
   
   // Save Play/Pause State ONLY if switching timeframes or parameters
   // If removing EA or closing terminal, we want a fresh start next time.
   // BUT, speed preference is usually persistent across sessions (User Preference).
   // So we save speed regardless of reason.
   GlobalVariableSet("Energy_Speed", currentSpeed);
   GlobalVariablesFlush(); // Ensure persistence on shutdown
   
   if(reason == REASON_CHARTCHANGE || reason == REASON_PARAMETERS)
     {
      // FIX: Only save state if pipe is connected.
      // Prevents UI from getting stuck in "Resume" mode if timeframe changes before connection.
      if(hPipe != INVALID_HANDLE_VALUE)
        {
         GlobalVariableSet("Energy_IsPaused", isPaused);
        }
      else
        {
         // If not connected, clear any state so we reset to Launch screen
         GlobalVariableDel("Energy_IsPaused");
        }
     }
   else
     {
      // Clean up state so next run shows Launch button
      GlobalVariableDel("Energy_IsPaused");
     }
   
   DestroyControlPanel(); // Cleanup UI
   if(hPipe != INVALID_HANDLE_VALUE)
     {
      CloseHandle(hPipe);
      Print("Pipe handle closed.");
     }
  }

//+------------------------------------------------------------------+
//| Chart Event Handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   // Handle Button Click (Play/Pause/Reconnect)
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == "btn_play_pause")
        {
         // 1. Check if Offline -> Try to Connect/Launch
         if(hPipe == INVALID_HANDLE_VALUE)
         {
            Print("🚀 Start clicked (Offline). Launching Python...");
            ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "⌛ ...");
            ChartRedraw(0);
            
            // Try Launch
            ShellExecuteW(0, "open", InpPythonPath, InpScriptPath, "", 1);
            
            // Note: We don't change state here immediately. 
            // The OnTimer will detect the connection and UpdateUIState will switch it to RESUME/PAUSE.
            return;
         }
         
         // 2. Normal Toggle Logic (Online)
         isPaused = !isPaused; // Toggle State
         ObjectSetInteger(0, "btn_play_pause", OBJPROP_STATE, false);
         
         if(isPaused)
           {
            // State is now PAUSED
            ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "▶ RESUME"); // Show what will happen next
            ObjectSetInteger(0, "btn_play_pause", OBJPROP_BGCOLOR, clrGreen); // Green for "Go"
            Print("UI Event: ⏸️ Switched to PAUSE");
            SendCommand("PAUSE");
           }
         else
           {
            // State is now PLAYING
            ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "⏸ PAUSE"); // Show what will happen next
            ObjectSetInteger(0, "btn_play_pause", OBJPROP_BGCOLOR, clrRed); // Red for "Stop"
            Print("UI Event: ▶️ Switched to PLAY");
            SendCommand("RESUME");
           }
         ChartRedraw(0);
        }
      else if(sparam == "btn_batch_down" || sparam == "btn_batch_up")
        {
         int delta = (sparam == "btn_batch_up") ? 1 : -1;
         int newBatch = batchSize + delta;
         if(newBatch < 1) newBatch = 1;
         if(newBatch > 10) newBatch = 10;

         if(newBatch != batchSize)
           {
            batchSize = newBatch;
            UpdateBatchLabel();

            GlobalVariableSet("Energy_BatchSize", batchSize);
            GlobalVariablesFlush();

            if(hPipe != INVALID_HANDLE_VALUE)
              {
               SendCommand("BATCH|" + IntegerToString(batchSize));
              }
           }

         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ChartRedraw(0);
        }
      else if(sparam == "btn_launch")
        {
           // REMOVED LOGIC
        }
     }
     
   // Handle Mouse Move (Slider Drag ONLY - Panel is now fixed)
   if(id == CHARTEVENT_MOUSE_MOVE)
     {
      int x = (int)lparam;
      int y = (int)dparam;
      uint mouseState = (uint)sparam;
      
      // --- Prevent Chart Scrolling when interacting with UI ---
      // Check if mouse is inside the Main Panel area
      // Panel: x=ui_base_x, y=ui_base_y, w=260, h=90
      bool isInsidePanel = (x >= ui_base_x && x <= ui_base_x + 260 && y >= ui_base_y && y <= ui_base_y + 90);
      
      // If we are dragging the knob OR inside the panel, disable chart scroll
      if(isDraggingKnob || isInsidePanel)
      {
         ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
      }
      else
      {
         ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
      }
      
      // Check Mouse Left Button Down
      if((mouseState & 1) == 1)
        {
         // Check Slider Area (Relative: 90-190, 20-50)
         // Track is at base_x + 90. Width 100.
         // Knob is roughly at y+50, size 20.
         // Tight Hitbox: 45 to 75 (30px height) to match visual knob area
         int slider_x_min = ui_base_x + 90;
         int slider_x_max = ui_base_x + 190;
         int slider_y_min = ui_base_y + 45; // Tightened Top (was 10)
         int slider_y_max = ui_base_y + 75; // Tightened Bottom (was 80)
         
         // Sticky Drag: If already dragging, ignore boundary check
         bool inside = (x >= slider_x_min && x <= slider_x_max && y >= slider_y_min && y <= slider_y_max);
         
         if(isDraggingKnob || inside)
           {
            // Start or Continue Dragging
            isDraggingKnob = true;
            
            // Slider Drag Logic (Track 100px, Knob 20px)
            int knob_w = 20;
            int track_w = 100;
            int knob_x = x - (knob_w / 2); // Center the 20px knob
            int knob_min = slider_x_min;
            int knob_max = slider_x_min + track_w - knob_w;
            // Clamp knob position
            if(knob_x < knob_min) knob_x = knob_min;
            if(knob_x > knob_max) knob_x = knob_max;
            
            ObjectSetInteger(0, "slider_knob", OBJPROP_XDISTANCE, knob_x);
            
            double travel = (double)(track_w - knob_w);
            double pct = (double)(knob_x - knob_min) / travel;
            if(pct < 0) pct = 0;
            if(pct > 1) pct = 1;
            
            double speed = 0.5 + pct * 2.5;
            currentSpeed = speed; // Update global state
            UpdateSpeedLabel(speed);
            ChartRedraw(0);
           }
        }
      else
        {
         // Mouse Up (Release)
         if(isDraggingKnob)
         {
            isDraggingKnob = false;
            // Strategy A: Send SPEED command only on release
            Print("🖱️ Slider Released. Sending New Speed: ", currentSpeed);
            SendCommand("SPEED|" + DoubleToString(currentSpeed, 2));
            
            // IMMEDIATE SAVE: Persist speed preference to disk instantly
            GlobalVariableSet("Energy_Speed", currentSpeed);
            GlobalVariablesFlush(); 
         }
        }
     }
  }

//+------------------------------------------------------------------+
//| UI Creation Functions                                            |
//+------------------------------------------------------------------+
void CreateControlPanel()
  {
   // Try to load saved position from Terminal Global Variables
   if(GlobalVariableCheck("EnergyUI_X")) ui_base_x = (int)GlobalVariableGet("EnergyUI_X");
   if(GlobalVariableCheck("EnergyUI_Y")) ui_base_y = (int)GlobalVariableGet("EnergyUI_Y");
   
   Print("🎨 Creating UI at X=", ui_base_x, " Y=", ui_base_y);

   // 1. Background Panel (Standard)
   CreateRectLabel("ui_bg", ui_base_x, ui_base_y, 260, 90, C'50,50,50', BORDER_FLAT);
   
   // 2. Play/Pause/Start Button (Consolidated)
   // Initial State: PAUSED or START depending on connection
   CreateButton("btn_play_pause", ui_base_x + 10, ui_base_y + 45, 70, 30, "▶ START", clrGreen);
   
   // 3. Slider Track (Bottom Right) - Shortened
   // x=90, width=100 (end at 190)
   CreateRectLabel("slider_track", ui_base_x + 90, ui_base_y + 58, 100, 4, clrGray, BORDER_SUNKEN);
   
   // 4. Slider Knob (Default Position)
   CreateButton("slider_knob", ui_base_x + 90, ui_base_y + 50, 20, 20, "", clrWhite); // Init at start
   
   // 5. Speed Label
   CreateLabel("lbl_speed", ui_base_x + 90, ui_base_y + 35, "Speed: 3.0s", clrWhite, 10);
   
   // 6. Batch Controls
   // Label: at x+170 (above right part of slider)
   CreateLabel("lbl_batch", ui_base_x + 170, ui_base_y + 35, "(x1)", clrYellow, 10);
   
   // Buttons: at x+200, size 15x20
   CreateButton("btn_batch_down", ui_base_x + 200, ui_base_y + 50, 15, 20, "▼", C'80,80,80');
   CreateButton("btn_batch_up",   ui_base_x + 215, ui_base_y + 50, 15, 20, "▲", C'80,80,80');
   
   // --- Restore Speed Preference ---
   if(GlobalVariableCheck("Energy_Speed"))
     {
      currentSpeed = GlobalVariableGet("Energy_Speed");
      Print("💾 Restored Speed Preference: ", currentSpeed, "s");
      
      // Calculate knob position from speed (Track 100, Knob 20)
      double pct = (currentSpeed - 0.5) / 2.5;
      if(pct < 0) pct = 0;
      if(pct > 1) pct = 1;
      
      // Knob X = base + 90 + (pct * 80)
      int knob_x = ui_base_x + 90 + (int)(pct * 80.0);
      ObjectSetInteger(0, "slider_knob", OBJPROP_XDISTANCE, knob_x);
      
      UpdateSpeedLabel(currentSpeed);
     }
     
   // --- Restore Batch Preference ---
   if(GlobalVariableCheck("Energy_BatchSize"))
   {
      batchSize = (int)GlobalVariableGet("Energy_BatchSize");
      if(batchSize < 1) batchSize = 1;
      if(batchSize > 10) batchSize = 10;
      Print("💾 Restored Batch Preference: x", batchSize);
      UpdateBatchLabel();
   }
   
   UpdateUIState();
   ChartRedraw(0);
  }

void UpdateUIState()
{
   bool connected = (hPipe != INVALID_HANDLE_VALUE);
   
   if(connected)
   {
      // Show Controls
      ObjectSetInteger(0, "btn_play_pause", OBJPROP_XDISTANCE, ui_base_x + 10);
      ObjectSetInteger(0, "slider_track", OBJPROP_XDISTANCE, ui_base_x + 90);
      ObjectSetInteger(0, "lbl_speed", OBJPROP_XDISTANCE, ui_base_x + 90);
      
      // Batch Controls
      ObjectSetInteger(0, "lbl_batch", OBJPROP_XDISTANCE, ui_base_x + 170);
      ObjectSetInteger(0, "lbl_batch", OBJPROP_YDISTANCE, ui_base_y + 35);
      ObjectSetInteger(0, "btn_batch_down", OBJPROP_XDISTANCE, ui_base_x + 200);
      ObjectSetInteger(0, "btn_batch_down", OBJPROP_YDISTANCE, ui_base_y + 50);
      ObjectSetInteger(0, "btn_batch_up", OBJPROP_XDISTANCE, ui_base_x + 215);
      ObjectSetInteger(0, "btn_batch_up", OBJPROP_YDISTANCE, ui_base_y + 50);
      
      // Always Force-Update Knob Position based on current speed
      // This ensures it appears correctly after initialization, timeframe change, or reconnect
      double pct = (currentSpeed - 0.5) / 2.5;
      if(pct < 0) pct = 0;
      if(pct > 1) pct = 1;
      
      // Track 100, Knob 20
      int knob_x = ui_base_x + 90 + (int)(pct * 80.0);
      ObjectSetInteger(0, "slider_knob", OBJPROP_XDISTANCE, knob_x);
          
      // Restore Button State
       if(isPaused)
       {
          // If we have history (GlobalVariable), it means we are RESUMING
          if(GlobalVariableCheck("Energy_IsPaused"))
          {
             ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "▶ RESUME");
          }
          else
          {
             ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "▶ START");
          }
          ObjectSetInteger(0, "btn_play_pause", OBJPROP_BGCOLOR, clrGreen);
       }
       else
       {
          ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "⏸ PAUSE");
          ObjectSetInteger(0, "btn_play_pause", OBJPROP_BGCOLOR, clrRed);
       }
   }
   else
   {
      // Disconnected / Offline State
      // Show "START" button (which acts as Connect/Launch)
      ObjectSetInteger(0, "btn_play_pause", OBJPROP_XDISTANCE, ui_base_x + 10);
      ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "▶ START"); // Re-Launch
      ObjectSetInteger(0, "btn_play_pause", OBJPROP_BGCOLOR, clrGray); // Gray to indicate offline/ready
      
      // Hide Slider when offline
      ObjectSetInteger(0, "slider_track", OBJPROP_XDISTANCE, -1000);
      ObjectSetInteger(0, "slider_knob", OBJPROP_XDISTANCE, -1000);
      ObjectSetInteger(0, "lbl_speed", OBJPROP_XDISTANCE, -1000);

      // Hide Batch when offline
      ObjectSetInteger(0, "lbl_batch", OBJPROP_XDISTANCE, -1000);
      ObjectSetInteger(0, "btn_batch_down", OBJPROP_XDISTANCE, -1000);
      ObjectSetInteger(0, "btn_batch_up", OBJPROP_XDISTANCE, -1000);
   }
   ChartRedraw(0);
}

void ShiftControlPanel(int dx, int dy)
  {
   ShiftObj("ui_bg", dx, dy);
   
   // Removed btn_launch
   
   ShiftObj("btn_play_pause", dx, dy);
   ShiftObj("slider_track", dx, dy);
   ShiftObj("slider_knob", dx, dy);
   ShiftObj("lbl_speed", dx, dy);
  }

void ShiftObj(string name, int dx, int dy)
  {
   long x = ObjectGetInteger(0, name, OBJPROP_XDISTANCE);
   long y = ObjectGetInteger(0, name, OBJPROP_YDISTANCE);
   
   // If off-screen, keep it off-screen but update "virtual" position?
   // No, if it's -1000, adding dx doesn't matter much.
   // But when we Restore in UpdateUIState, we use ui_base_x.
   // So UpdateUIState relies on ui_base_x being correct.
   // ShiftControlPanel updates ui_base_x in OnChartEvent.
   // So we just need to shift the objects that are currently visible.
   // Or just shift everything.
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x + dx);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + dy);
  }

void DestroyControlPanel()
  {
   ObjectDelete(0, "ui_bg");
   // ObjectDelete(0, "btn_launch"); // REMOVED
   ObjectDelete(0, "btn_play_pause");
   ObjectDelete(0, "slider_track");
   ObjectDelete(0, "slider_knob");
   ObjectDelete(0, "lbl_speed");
   ObjectDelete(0, "lbl_batch");
   ObjectDelete(0, "btn_batch_down");
   ObjectDelete(0, "btn_batch_up");
   
   // Cleanup legacy labels
   ObjectDelete(0, "PythonMsg");
   
   ChartRedraw(0);
  }

void UpdateSpeedLabel(double speed)
  {
   string text = StringFormat("Speed: %.1fs", speed);
   ObjectSetString(0, "lbl_speed", OBJPROP_TEXT, text);
   Print("UI Event: ⏩ Speed Changed to ", text);
  }

// --- UI Helpers ---
void CreateButton(string name, int x, int y, int w, int h, string text, color bg)
  {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
  }

void CreateRectLabel(string name, int x, int y, int w, int h, color bg, ENUM_BORDER_TYPE border)
  {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, border);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
  }

void CreateLabel(string name, int x, int y, string text, color col, int size)
  {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
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
      // ShowLabel(0, "Python: Connected (Launcher)"); // REMOVED
      UpdateUIState();
      
      // Sync State immediately upon connection
      // Whether we are PAUSED or PLAYING, tell Python to match our state.
      if(isPaused)
      {
         SendCommand("PAUSE");
      }
      else
      {
         Print("🔄 Restoring PLAY state...");
         SendCommand("RESUME");
      }
      
      // NEW: Proactively send STATUS on connection!
      // This helps Python sync immediately without needing to ask/retry.
      // FIX: Use PERIOD_M1 to get granular timestamp (minute precision) instead of PERIOD_H1
      datetime lastTime = iTime(InpSymbolName, PERIOD_M1, 0);
      string timeStr = TimeToString(lastTime);
      Print("🔗 Connected. Sending Initial Status: ", timeStr);
      SendCommand("STATUS|" + timeStr);
      
      // Also sync Speed
      Print("🔗 Syncing Initial Speed: ", currentSpeed);
      SendCommand("SPEED|" + DoubleToString(currentSpeed, 2));

      // Also sync Batch
      Print("🔗 Syncing Initial Batch: x", batchSize);
      SendCommand("BATCH|" + IntegerToString(batchSize));
     }
  }

void ReadPipeCommand()
  {
   uchar buffer[1024];
   uint bytesRead = 0;
   uint bytesAvail = 0;
   
   if(!PeekNamedPipe(hPipe, 0, 0, 0, bytesAvail, 0))
     {
      // Pipe broken or disconnected
      CloseHandle(hPipe);
      hPipe = INVALID_HANDLE_VALUE;
      UpdateUIState();
      return;
     }
   
   if(bytesAvail > 0)
     {
      Print("Pipe has data: ", bytesAvail, " bytes"); // DEBUG
      if(ReadFile(hPipe, buffer, 1024, bytesRead, 0))
        {
         string chunk = CharArrayToString(buffer, 0, bytesRead);
         rx_buffer += chunk;

         string lines[];
         int count = StringSplit(rx_buffer, '\n', lines);
         if(count > 0)
           {
            // Keep the last (possibly incomplete) line in buffer
            rx_buffer = lines[count - 1];
            for(int i = 0; i < count - 1; i++)
              {
               string line = lines[i];
               StringReplace(line, "\r", "");
               StringTrimLeft(line);
               StringTrimRight(line);

               if(StringLen(line) > 0)
                 {
                  Print("Pipe Read: ", line); // DEBUG
                  ProcessCommand(line);
                 }
              }
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
      // Print("⚠️ Replay chart not found! Sending command to Launcher instead."); // Reduce noise
      targetChart = 0; // Fallback to current chart
   }
   
   string parts[];
   int count = StringSplit(message, '|', parts);
   
   if(count >= 2)
     {
      string cmd = parts[0];
      string data = parts[1];
      
      if(cmd == "MSG") 
      {
         // ShowLabel(targetChart, data); // REMOVED: Redundant
         Print("MSG: ", data);
      }
      else if(cmd == "VLINE")
        {
         datetime dt = StringToTime(data);
         CreateVLine(targetChart, dt);
         // ShowLabel(targetChart, "VLine at " + data); // REMOVED
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
            // ShowLabel(targetChart, "Range Set: " + startStr + " to " + endStr); // REMOVED
            JumpToTime(targetChart, startDt);
           }
        }
      else if(cmd == "ADD_BAR")
        {
         AddBarToChart(data);
        }
      else if(cmd == "QUERY_STATUS")
        {
         // Get last bar time of the custom symbol
         // FIX: Use PERIOD_M1 to get granular timestamp (minute precision) instead of PERIOD_H1
         datetime lastTime = iTime(InpSymbolName, PERIOD_M1, 0);
         
         // If no history exists (or initial dummy bar), we should probably indicate that.
         // But for now, returning the dummy bar time is fine, Python will check if it exists in CSV.
         // However, if the Python script was restarted, it wants to know the LAST REAL BAR.
         // If MT5 was restarted, the history is persisted on disk by MT5.
         
         // TimeToString default is yyyy.mm.dd hh:mi
         string timeStr = TimeToString(lastTime);
         Print("📅 Sync Request Received. Last Bar: ", timeStr);
         SendCommand("STATUS|" + timeStr);
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

void SendCommand(string cmd)
{
   if(hPipe == INVALID_HANDLE_VALUE) return;
   
   uchar buffer[];
   StringToCharArray(cmd, buffer);
   
   uint bytesWritten = 0;
   if(!WriteFile(hPipe, buffer, ArraySize(buffer)-1, bytesWritten, 0)) // -1 to skip null terminator? Python strip() handles it.
   {
      Print("❌ Failed to send command: ", cmd);
   }
   else
   {
      // Print("📤 Sent: ", cmd); // Debug
   }
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
      Print("✅ Added Bar: ", parts[0], " | Close: ", rates[0].close);
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
