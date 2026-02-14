import win32pipe, win32file
import time

PIPE_NAME = r'\\.\pipe\MT5_Python_Bridge'

def run_server():
    print(f"🔗 Creating Pipe Server: {PIPE_NAME}")
    pipe = win32pipe.CreateNamedPipe(
        PIPE_NAME,
        win32pipe.PIPE_ACCESS_DUPLEX,
        win32pipe.PIPE_TYPE_MESSAGE | win32pipe.PIPE_READMODE_MESSAGE | win32pipe.PIPE_WAIT,
        1, 65536, 65536,
        0,
        None
    )
    
    print("⏳ Waiting for MT5 EA to connect...")
    win32pipe.ConnectNamedPipe(pipe, None)
    print("✅ MT5 Connected!")
    
    # 1. Send Text Message
    msg = "MSG|System Check: OK\n"
    print(f"Sending: {msg}")
    win32file.WriteFile(pipe, msg.encode('utf-8'))
    time.sleep(2)
    
    # 2. Send VLine (Visual Test) at Dummy Bar Time
    vline = "VLINE|2024.01.01 00:00\n"
    print(f"Sending: {vline}")
    win32file.WriteFile(pipe, vline.encode('utf-8'))
    time.sleep(2)
    
    print("Closing pipe...")
    win32file.CloseHandle(pipe)

if __name__ == "__main__":
    run_server()
