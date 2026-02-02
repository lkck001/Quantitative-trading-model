import MetaTrader5 as mt5
import pandas as pd
import os
import shutil

def prepare_data_and_move():
    if not mt5.initialize():
        print("❌ MT5 Init Failed")
        return

    # 1. Get MT5 Data Path
    term_info = mt5.terminal_info()
    data_path = term_info.data_path
    print(f"📂 MT5 Data Path: {data_path}")
    
    mql5_files_path = os.path.join(data_path, "MQL5", "Files")
    if not os.path.exists(mql5_files_path):
        print(f"❌ MQL5/Files path not found: {mql5_files_path}")
        return

    # 2. Load Data
    src_csv = "data/EURUSD@_2024_H1.csv"
    if not os.path.exists(src_csv):
        print(f"❌ Source CSV not found: {src_csv}")
        return

    print(f"📖 Reading {src_csv}...")
    df = pd.read_csv(src_csv)
    df['time'] = pd.to_datetime(df['time'])
    
    # 3. Format for MQL5 (YYYY.MM.DD HH:MM:SS, Open, High, Low, Close, TickVol, Vol, Spread)
    # We will just write a simple CSV: Date,Time,Open,High,Low,Close,TickVol
    # MQL5 Script will parse it.
    
    target_csv_name = "EURUSD_2024_Import.csv"
    target_path = os.path.join(mql5_files_path, target_csv_name)
    
    print(f"💾 Writing MQL5-ready CSV to: {target_path}")
    
    with open(target_path, 'w') as f:
        # Write Header? No, simplify parsing in MQL5
        # Format: YYYY.MM.DD HH:MM:SS,Open,High,Low,Close,TickVol
        for idx, row in df.iterrows():
            dt_str = row['time'].strftime("%Y.%m.%d %H:%M:%S")
            line = f"{dt_str},{row['open']},{row['high']},{row['low']},{row['close']},{int(row['tick_volume'])}\n"
            f.write(line)
            
    print(f"✅ Data prepared successfully! ({len(df)} rows)")
    mt5.shutdown()

if __name__ == "__main__":
    prepare_data_and_move()
