//+------------------------------------------------------------------+
//|                                                MT5_Test_Pipe.mq5 |
//|                        Copyright 2026, Quantitative Trading Model|
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Quantitative Trading Model"
#property link      "https://www.mql5.com"
#property version   "1.10"
#property script_show_inputs

// --- DLL Imports for Named Pipe ---
#import "kernel32.dll"
int CreateFileW(string lpFileName, uint dwDesiredAccess, uint dwShareMode, uint lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, int hTemplateFile);
bool ReadFile(int hFile, uchar &lpBuffer[], uint nNumberOfBytesToRead, uint &lpNumberOfBytesRead, int lpOverlapped);
bool CloseHandle(int hObject);
#import

// --- Constants ---
#define GENERIC_READ 0x80000000
#define GENERIC_WRITE 0x40000000
#define OPEN_EXISTING 3
#define INVALID_HANDLE_VALUE -1

// Pipe Name
string pipeName = "\\\\.\\pipe\\MT5_Python_Bridge";

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("Connecting to pipe: ", pipeName);
   
   // 1. Open the Pipe
   int hPipe = CreateFileW(pipeName, GENERIC_READ | GENERIC_WRITE, 0, 0, OPEN_EXISTING, 0, 0);
   
   if(hPipe == INVALID_HANDLE_VALUE)
     {
      Print("Failed to connect to pipe. Is Python server running?");
      Alert("Pipe Connection Failed! Run Python script first.");
      return;
     }
     
   Print("Connected! Waiting for message...");
   
   // 2. Read from Pipe
   uchar buffer[1024];
   uint bytesRead = 0;
   
   if(ReadFile(hPipe, buffer, 1024, bytesRead, 0))
     {
      string message = CharArrayToString(buffer, 0, bytesRead);
      Print("Received raw: ", message);
      
      // Parse Command: TYPE|CONTENT
      string parts[];
      int count = StringSplit(message, '|', parts);
      
      if(count >= 2)
        {
         string cmd = parts[0];
         string data = parts[1];
         
         if(cmd == "MSG")
           {
            ShowLabel(data);
           }
         else if(cmd == "VLINE")
           {
            datetime dt = StringToTime(data);
            CreateVLine(dt);
            ShowLabel("VLine at " + data);
            
            // Jump to that time
            ChartSetInteger(0, CHART_AUTOSCROLL, false);
            ChartNavigate(0, CHART_END, 0); // Reset
            // Simple navigation to time is tricky in script without tick loop, 
            // but we can try ensuring the object is visible.
           }
        }
      else
        {
         ShowLabel("Unknown: " + message);
        }
     }
   else
     {
      Print("Error reading from pipe.");
     }
     
   // 3. Close
   CloseHandle(hPipe);
   Print("Pipe closed.");
  }

//Helper to show label
void ShowLabel(string text)
{
   ObjectCreate(0, "PythonMsg", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "PythonMsg", OBJPROP_TEXT, "Python: " + text);
   ObjectSetInteger(0, "PythonMsg", OBJPROP_XDISTANCE, 50);
   ObjectSetInteger(0, "PythonMsg", OBJPROP_YDISTANCE, 50);
   ObjectSetInteger(0, "PythonMsg", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, "PythonMsg", OBJPROP_FONTSIZE, 20);
   ChartRedraw(0);
}

// Helper to draw VLine
void CreateVLine(datetime time)
{
   string name = "Py_VLine_" + TimeToString(time);
   ObjectCreate(0, name, OBJ_VLINE, 0, time, 0);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   Print("Created VLine at ", time);
}
