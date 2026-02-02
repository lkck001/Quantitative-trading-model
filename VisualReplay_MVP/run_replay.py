import time
import pandas as pd
import win32pipe, win32file, pywintypes
import os

PIPE_NAME = r'\\.\pipe\MT5_Python_Bridge'

def start_server_and_send_cmd():
    # 1. Load Data
    csv_path = "data/EURUSD@_2024_H1.csv"
    if not os.path.exists(csv_path):
        print(f"Data file not found: {csv_path}")
        return
        
    print(f"Loading {csv_path}...")
    df = pd.read_csv(csv_path)
    
    # Pick a random or specific row (e.g., 100th row)
    target_idx = 100
    target_row = df.iloc[target_idx]
    target_time_str = str(target_row['time']) # Format: YYYY-MM-DD HH:MM:SS
    
    print(f"Target Data Point: Index={target_idx}, Time={target_time_str}, Close={target_row['close']}")
    
    # 2. Create Pipe Server
    print(f"Creating Pipe: {PIPE_NAME}")
    try:
        pipe = win32pipe.CreateNamedPipe(
            PIPE_NAME,
            win32pipe.PIPE_ACCESS_DUPLEX,
            win32pipe.PIPE_TYPE_MESSAGE | win32pipe.PIPE_READMODE_MESSAGE | win32pipe.PIPE_WAIT,
            1, 65536, 65536,
            0,
            None
        )
        
        print(">>> Waiting for MT5 Script to connect... (Please drag MT5_Test_Pipe.mq5 to chart)")
        win32pipe.ConnectNamedPipe(pipe, None)
        print(">>> MT5 Connected!")
        
        # 3. Send Command
        # Format: VLINE|YYYY-MM-DD HH:MM:SS
        command = f"VLINE|{target_time_str}"
        print(f"Sending Command: {command}")
        
        win32file.WriteFile(pipe, command.encode('utf-8'))
        
        # Keep open briefly to ensure transmission
        time.sleep(2)
        
        win32file.CloseHandle(pipe)
        print("Pipe closed. Check MT5 chart for red vertical line.")
        
    except Exception as e:
        print(f"Pipe Error: {e}")

if __name__ == "__main__":
    start_server_and_send_cmd()
