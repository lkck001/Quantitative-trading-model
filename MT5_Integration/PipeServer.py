import time
import sys
import win32pipe, win32file, pywintypes

PIPE_NAME = r'\\.\pipe\MT5_Python_Bridge'

def create_pipe_server():
    print(f"Creating Named Pipe: {PIPE_NAME}")
    
    try:
        pipe = win32pipe.CreateNamedPipe(
            PIPE_NAME,
            win32pipe.PIPE_ACCESS_DUPLEX,
            win32pipe.PIPE_TYPE_MESSAGE | win32pipe.PIPE_READMODE_MESSAGE | win32pipe.PIPE_WAIT,
            1, 65536, 65536,
            0,
            None
        )
        
        print("Waiting for client (MT5) to connect...")
        win32pipe.ConnectNamedPipe(pipe, None)
        print("Client connected!")
        
        # Send a test message
        message = "Hello from Python!"
        print(f"Sending: {message}")
        win32file.WriteFile(pipe, message.encode('utf-8'))
        
        # Keep open for a bit
        time.sleep(5)
        
        win32file.CloseHandle(pipe)
        print("Pipe closed.")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    create_pipe_server()
