import time
import pandas as pd
import win32pipe, win32file, pywintypes
import os
import threading

PIPE_NAME = r'\\.\pipe\MT5_Python_Bridge'
# Default Path (Can be overridden by user)
CSV_PATH = r'E:\Quantitative trading model\Data\Local_Data\split_by_year\EURUSD_2024.csv'
# CSV_PATH = r'E:\Quantitative trading model\Data\Online_Data\MT5_Data\EURUSD@_Recent_M1.csv'

class DataFeeder:
    def __init__(self, csv_path=None):
        self.csv_path = csv_path if csv_path else CSV_PATH
        self.pipe = None
        self.df = None
        self.is_paused = True # Default to PAUSED
        self.speed = 3.0      # Default speed (seconds per bar)
        self.batch_size = 1   # Default batch size
        self.running = True
        self.start_time = None
        self.sync_event = threading.Event()
    
    def load_data(self):
        if not os.path.exists(self.csv_path):
            print(f"❌ File not found: {self.csv_path}")
            return False
        
        print(f"📂 Loading {self.csv_path}...")
        try:
            # 1. Peek at first line to detect format
            with open(self.csv_path, 'r') as f:
                first_line = f.readline()
            
            # Check for header
            if "time" in first_line.lower() and "open" in first_line.lower():
                print("ℹ️ Detected format: Online Data (with Header)")
                self.df = pd.read_csv(self.csv_path)
                # Standardize time format: YYYY-MM-DD HH:MM:SS -> YYYY.MM.DD HH:MM
                self.df['time'] = pd.to_datetime(self.df['time']).dt.strftime('%Y.%m.%d %H:%M')
                
            else:
                print("ℹ️ Detected format: Local Data (No Header, Date+Time columns)")
                # Local Data format: Date,Time,Open,High,Low,Close,Vol,RealVol,Spread
                self.df = pd.read_csv(self.csv_path, header=None, names=['date', 'time_only', 'open', 'high', 'low', 'close', 'tick_volume', 'real_volume', 'spread'])
                
                # Combine Date and Time
                self.df['time'] = self.df['date'].astype(str) + ' ' + self.df['time_only'].astype(str)
                # Ensure format (Assuming input is already YYYY.MM.DD and HH:MM)
            
            print(f"Sample raw time: {self.df['time'].iloc[0]}")
            print(f"✅ Loaded {len(self.df)} bars.")
            return True
        except Exception as e:
            print(f"❌ Failed to load CSV: {e}")
            return False

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
            
            # Start Listener Thread if not already running
            if not any(t.name == "PipeListener" for t in threading.enumerate()):
                t = threading.Thread(target=self.listen_for_commands, name="PipeListener", daemon=True)
                t.start()
            
            return True
        except Exception as e:
            print(f"❌ Pipe Error: {e}")
            return False

    def reconnect_pipe(self):
        """Handle disconnection and wait for reconnection"""
        print("🔄 Reconnecting pipe...")
        if self.pipe:
            try:
                win32file.CloseHandle(self.pipe)
            except:
                pass
            self.pipe = None
            
        # Re-create and wait
        return self.create_pipe_server()

    def listen_for_commands(self):
        """Background thread to read commands from MT5"""
        print("👂 Listening for MT5 commands...")
        while self.running:
            if not self.pipe:
                time.sleep(1)
                continue

            try:
                # PeekNamedPipe returns a tuple. Let's handle dynamic unpacking.
                peek_result = win32pipe.PeekNamedPipe(self.pipe, 0)
                
                total_bytes_avail = 0
                if len(peek_result) >= 3:
                     total_bytes_avail = peek_result[2]
                
                if total_bytes_avail > 0:
                    hr, data = win32file.ReadFile(self.pipe, total_bytes_avail)
                    if hr == 0 and data:
                        cmd = data.decode('utf-8').strip()
                        self.process_command(cmd)
                else:
                    time.sleep(0.1)
                    
            except pywintypes.error as e:
                if e.winerror == 109: # ERROR_BROKEN_PIPE
                    print("⚠️ Pipe broken (Listener detected).")
                    print("💀 Host disconnected. Initiating self-termination sequence...")
                    self.running = False
                    if self.pipe:
                        try:
                            win32file.CloseHandle(self.pipe)
                        except:
                            pass
                    import sys
                    sys.exit(0) # Suicide Pact: Die immediately
                else:
                    # print(f"Pipe Read Error: {e}")
                    time.sleep(0.1)
            except Exception as e:
                print(f"Listener Error: {e}")
                time.sleep(0.1)

    def process_command(self, cmd):
        print(f"📩 Received: {cmd}")
        if cmd == "PAUSE":
            self.is_paused = True
            print("⏸️ PAUSED")
        elif cmd == "RESUME":
            self.is_paused = False
            print("▶️ RESUMED")
        elif cmd.startswith("SPEED|"):
            try:
                val = float(cmd.split("|")[1])
                self.speed = val
                print(f"⏩ Speed set to {self.speed}s")
            except Exception as e:
                print(f"❌ Error setting speed: {e}")
        elif cmd.startswith("BATCH|"):
            try:
                val = int(cmd.split("|")[1])
                self.batch_size = max(1, min(10, val)) # Clamp 1-10
                print(f"📦 Batch Size set to x{self.batch_size}")
            except Exception as e:
                print(f"❌ Error setting batch: {e}")
        elif cmd.startswith("STATUS|"):
            time_str = cmd.split("|")[1]
            print(f"🔄 Syncing with MT5... Last Bar: {time_str}")
            self.start_time = time_str # Keep as string for comparison
            self.sync_event.set()

    def send_command(self, cmd):
        if not self.pipe: return
        try:
            if not cmd.endswith("\n"):
                cmd += "\n"
            win32file.WriteFile(self.pipe, cmd.encode('utf-8'))
        except pywintypes.error as e:
            if e.winerror == 232 or e.winerror == 109: # Pipe being closed or broken
                print("⚠️ Pipe disconnected during send. Terminating...")
                import sys
                sys.exit(0) # Suicide Pact
            else:
                print(f"❌ Send Error: {e}")
        except Exception as e:
            print(f"❌ Send Error: {e}")

    def run(self):
        print("\n=== 🚀 Ready. Waiting for PLAY command... ===")
        print("Press Ctrl+C to stop.")
        
        # --- SYNC PHASE ---
        print("📡 Syncing with MT5 history...")
        self.sync_event.clear()
        self.start_time = None # Reset
        
        # Wait for connection before syncing
        # Note: self.pipe is set in create_pipe_server/reconnect_pipe, but we need to ensure it's valid
        print("⏳ Waiting for pipe connection...")
        while not self.pipe and self.running:
             time.sleep(0.1)
             
        # Wait for MT5 to send initial STATUS (Proactive Handshake)
        print("👂 Waiting for MT5 to send initial status...")
        if self.sync_event.wait(timeout=10): # Extended wait time for active connection
             print("✅ Received initial status from MT5.")
        else:
             print("⚠️ No initial status received. Falling back to active query...")
             # Fallback: Send query and wait for response
             print("❓ Querying status from MT5...")
             
             # Retry logic for Query
             max_retries = 5 # Increase retries
             for attempt in range(max_retries):
                 # Check pipe status before sending
                 if not self.pipe:
                     print("⚠️ Pipe disconnected before query. Waiting...")
                     time.sleep(1)
                     continue
                     
                 self.send_command("QUERY_STATUS")
                 
                 # Wait short time for response
                 if self.sync_event.wait(timeout=2):
                     break # Got it!
                 
                 print(f"⚠️ Sync attempt {attempt+1}/{max_retries} timed out. Retrying...")
                 time.sleep(1) # Wait a bit before retry
        
        start_index = 0
        if self.sync_event.is_set():
            if self.start_time:
                print(f"📥 MT5 Last Bar: [{self.start_time}]")
                # Find index where time > start_time
                # Assuming self.df['time'] is sorted and is string format "YYYY.MM.DD HH:MM"
                
                # Check if last bar exists in our data
                # Strip any potential whitespace
                clean_start_time = self.start_time.strip()
                
                # Debug: Show first few times in CSV to verify format matches
                # print(f"🔍 CSV First Time: [{self.df['time'].iloc[0]}]")
                
                mask = self.df['time'] == clean_start_time
                if mask.any():
                    # Get the index of the last bar
                    last_idx = self.df.index[mask].tolist()[0]
                    start_index = last_idx + 1
                    print(f"✅ Found continuation point. Resuming from index {start_index} (Time: {self.df.iloc[start_index]['time'] if start_index < len(self.df) else 'END'})")
                else:
                    print(f"⚠️ Last bar time [{clean_start_time}] not found in CSV. Starting from beginning.")
                    # Try fuzzy match? (e.g. nearest time) - For now, strict match is safer.
            else:
                 print("ℹ️ No history time returned. Starting from beginning.")
        else:
             print("❌ Sync completely failed after retries. Starting from beginning.")
        
        try:
            # Main Loop with Index Tracking
            # We use a while loop to handle batch increments
            current_idx = start_index
            total_bars = len(self.df)
            
            while current_idx < total_bars and self.running:
                
                # Check pipe status BEFORE sending
                if not self.pipe:
                    print("💀 Pipe disconnected. Terminating...")
                    import sys
                    sys.exit(0)
                
                # Wait loop for Pause
                while self.is_paused and self.running:
                    if not self.pipe:
                        print("💀 Paused but pipe disconnected. Terminating...")
                        import sys
                        sys.exit(0)
                    time.sleep(0.1)
                
                # --- Batch Processing ---
                # Send 'batch_size' bars in one go (or as many as remain)
                bars_sent = 0
                for _ in range(self.batch_size):
                    if current_idx >= total_bars: break
                    
                    row = self.df.iloc[current_idx]
                    
                    # Format: ADD_BAR|Time,Open,High,Low,Close,TickVol
                    data_str = f"{row['time']},{row['open']},{row['high']},{row['low']},{row['close']},{row['tick_volume']}"
                    cmd = f"ADD_BAR|{data_str}"
                    
                    # Only print every N bars to reduce spam if batch is high
                    if self.batch_size == 1 or bars_sent == 0:
                        print(f"[{current_idx+1}/{total_bars}] Sending Bar: {row['time']} (Batch x{self.batch_size}, Speed {self.speed:.2f}s)")
                        
                    self.send_command(cmd)
                    current_idx += 1
                    bars_sent += 1
                
                # Dynamic sleep based on speed
                # print(f"💤 Sleeping for {self.speed}s...")
                time.sleep(self.speed)
                # print("⚡ Woke up, next batch...")
                
        except KeyboardInterrupt:
            print("\n🛑 Replay Stopped by User.")
        finally:
            self.running = False
            if self.pipe:
                win32file.CloseHandle(self.pipe)

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="MT5 Data Feeder")
    parser.add_argument("file", nargs="?", default=CSV_PATH, help="Path to CSV file (Local or Online format)")
    
    args = parser.parse_args()
    
    try:
        feeder = DataFeeder(csv_path=args.file)
        if feeder.load_data():
            if feeder.create_pipe_server():
                feeder.run()
    except Exception as e:
        print(f"\n❌ CRITICAL ERROR: {e}")
        import traceback
        traceback.print_exc()
    
    print("\n[Process Finished]")
    # input("Press Enter to close this window...") # REMOVED: Auto-close immediately
