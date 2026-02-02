import time
import pandas as pd
import win32pipe, win32file, pywintypes
import os
import sys

PIPE_NAME = r'\\.\pipe\MT5_Python_Bridge'

class PipeController:
    def __init__(self):
        self.pipe = None
        self.df = None
        self.points_of_interest = []
        self.current_idx = 0
        self.year_filter = 2024

    def load_data(self, csv_path):
        if not os.path.exists(csv_path):
            print(f"❌ Data file not found: {csv_path}")
            return False
            
        print(f"📂 Loading {csv_path}...")
        self.df = pd.read_csv(csv_path)
        self.df['time'] = pd.to_datetime(self.df['time'])
        
        # Ensure we only work with 2024 data (Double Check)
        self.df = self.df[self.df['time'].dt.year == self.year_filter].copy()
        
        if self.df.empty:
            print(f"❌ No data found for year {self.year_filter}!")
            return False

        # 简单模拟：假设我们要找所有 "收盘价高于开盘价 0.5%" 的大阳线作为“关键点”
        # 在真实场景中，这里是 ZigZag 算法或 AI 模型的输出
        self.df['body_size'] = (self.df['close'] - self.df['open']) / self.df['open']
        self.points_of_interest = self.df[self.df['body_size'] > 0.002].index.tolist() # 0.2% 涨幅
        
        print(f"✅ Found {len(self.points_of_interest)} interesting points in {self.year_filter}.")
        return True

    def connect_pipe(self):
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
            
            # --- Initialize Range Visuals ---
            start_date = f"{self.year_filter}-01-01 00:00:00"
            end_date = f"{self.year_filter}-12-30 23:59:59"
            print(f"📐 Setting Replay Range: {start_date} to {end_date}")
            self.send_command(f"SET_RANGE|{start_date}|{end_date}")
            
            return True
        except Exception as e:
            print(f"❌ Pipe Error: {e}")
            return False

    def send_command(self, cmd):
        if not self.pipe:
            return
        try:
            print(f"📤 Sending: {cmd}")
            win32file.WriteFile(self.pipe, cmd.encode('utf-8'))
        except Exception as e:
            print(f"❌ Send Error: {e}")

    def run_loop(self):
        print("\n=== 🎮 Visual Replay Controller ===")
        print("Commands:")
        print("  [Enter] Next Point")
        print("  [p]     Previous Point")
        print("  [q]     Quit")
        
        while True:
            user_input = input(f"\nTarget Point [{self.current_idx+1}/{len(self.points_of_interest)}] > ").strip().lower()
            
            if user_input == 'q':
                break
            elif user_input == 'p':
                self.current_idx = max(0, self.current_idx - 1)
            else:
                # Default is Next
                self.current_idx = min(len(self.points_of_interest) - 1, self.current_idx + 1)

            # Get the data point
            row_idx = self.points_of_interest[self.current_idx]
            row = self.df.iloc[row_idx]
            time_str = str(row['time'])
            
            print(f"📍 Jump to: {time_str} | Close: {row['close']}")
            
            # Send Command: VLINE|YYYY-MM-DD HH:MM:SS
            self.send_command(f"VLINE|{time_str}")

    def close(self):
        if self.pipe:
            win32file.CloseHandle(self.pipe)
            print("🔌 Pipe Closed.")

if __name__ == "__main__":
    controller = PipeController()
    if controller.load_data("data/EURUSD@_2024_H1.csv"):
        if controller.connect_pipe():
            try:
                controller.run_loop()
            finally:
                controller.close()
