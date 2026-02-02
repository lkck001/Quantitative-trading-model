import time
import win32pipe, win32file
import sys

PIPE_NAME = r'\\.\pipe\MT5_Python_Bridge'

def jump_to_start():
    print(f"🔗 Connecting to Pipe: {PIPE_NAME}")
    try:
        # Create Client Pipe (Write Only or Duplex)
        # Note: In our architecture, Python acts as the Pipe SERVER usually, 
        # but to keep it simple, let's stick to the Server pattern 
        # where we wait for EA (Client) to connect.
        
        pipe = win32pipe.CreateNamedPipe(
            PIPE_NAME,
            win32pipe.PIPE_ACCESS_DUPLEX,
            win32pipe.PIPE_TYPE_MESSAGE | win32pipe.PIPE_READMODE_MESSAGE | win32pipe.PIPE_WAIT,
            1, 65536, 65536,
            0,
            None
        )
        
        print("⏳ Waiting for MT5 EA to connect... (Please ensure 'MT5_EnergyTrading' is running on chart)")
        win32pipe.ConnectNamedPipe(pipe, None)
        print("✅ MT5 Connected!")
        
        # Target Time: Start of 2024 Data (from our CSV)
        target_time = "2024-01-02 08:00:00" 
        
        print(f"🚀 Jumping to Start of Year: {target_time}")
        command = f"VLINE|{target_time}"
        win32file.WriteFile(pipe, command.encode('utf-8'))
        
        # Keep connection alive briefly to ensure message is received
        time.sleep(2)
        
        win32file.CloseHandle(pipe)
        print("🏁 Done. Check MT5 Chart.")
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    jump_to_start()
