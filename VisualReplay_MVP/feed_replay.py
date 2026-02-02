import time
import pandas as pd
import win32pipe, win32file, pywintypes
import os

PIPE_NAME = r'\\.\pipe\MT5_Python_Bridge'
CSV_PATH = r'E:\Quantitative trading model\Data\EURUSD@_2024_H1.csv'

class DataFeeder:
    def __init__(self):
        self.pipe = None
        self.df = None
    
    def load_data(self):
        if not os.path.exists(CSV_PATH):
            print(f"❌ File not found: {CSV_PATH}")
            return False
        
        print(f"📂 Loading {CSV_PATH}...")
        self.df = pd.read_csv(CSV_PATH)
        # Convert time to string compatible with MQL5 StringToTime (YYYY.MM.DD HH:MM)
        self.df['time'] = pd.to_datetime(self.df['time']).dt.strftime('%Y.%m.%d %H:%M')
        print(f"✅ Loaded {len(self.df)} bars.")
        return True

    def create_pipe_server(self):
        print(f"🔗 Creating Pipe Server: {PIPE_NAME}")
        try:
            self.pipe = win32pipe.CreateNamedPipe(
                PIPE_NAME,
                win32pipe.PIPE_ACCESS_DUPLEX,
                win32pipe.PIPE_TYPE_MESSAGE | win32pipe.PIPE_READMODE_MESSAGE | win32pipe.PIPE_WAIT,
                1, 65536, 65536,
                0,
                None
            )
            print("⏳ Waiting for MT5 to connect... (Ensure EA is running on chart)")
            win32pipe.ConnectNamedPipe(self.pipe, None)
            print("✅ MT5 Connected!")
            return True
        except Exception as e:
            print(f"❌ Pipe Error: {e}")
            return False

    def send_command(self, cmd):
        if not self.pipe: return
        try:
            win32file.WriteFile(self.pipe, cmd.encode('utf-8'))
        except Exception as e:
            print(f"❌ Send Error: {e}")

    def run(self):
        print("\n=== 🚀 Starting Data Feed (1 Bar / 3s) ===")
        print("Press Ctrl+C to stop.")
        
        try:
            for index, row in self.df.iterrows():
                # Format: ADD_BAR|Time,Open,High,Low,Close,TickVol
                data_str = f"{row['time']},{row['open']},{row['high']},{row['low']},{row['close']},{row['tick_volume']}"
                cmd = f"ADD_BAR|{data_str}"
                
                print(f"[{index+1}/{len(self.df)}] Sending Bar: {row['time']}")
                self.send_command(cmd)
                
                time.sleep(3)
                
        except KeyboardInterrupt:
            print("\n🛑 Replay Stopped by User.")
        finally:
            if self.pipe:
                win32file.CloseHandle(self.pipe)

if __name__ == "__main__":
    feeder = DataFeeder()
    if feeder.load_data():
        if feeder.create_pipe_server():
            feeder.run()
