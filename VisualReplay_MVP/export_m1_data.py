import MetaTrader5 as mt5
import pandas as pd
from datetime import datetime
import os

# Configuration
SYMBOL = "EURUSD@"
TIMEFRAME = mt5.TIMEFRAME_M1
START_DATE = datetime(2025, 11, 1)
END_DATE = datetime(2026, 2, 1)
OUTPUT_FILE = r"E:\Quantitative trading model\Data\EURUSD@_Recent_M1.csv"

def export_data():
    # 1. Initialize MT5
    if not mt5.initialize():
        print(f"❌ MT5 Initialize failed, error code = {mt5.last_error()}")
        return

    print(f"✅ MT5 Connected. Version: {mt5.version()}")

    # 2. Copy rates
    # Attempt to download by range first (if configured), otherwise download latest
    # rates = mt5.copy_rates_range(SYMBOL, TIMEFRAME, START_DATE, END_DATE)
    
    # Fallback: Download latest N bars (More reliable if history is sparse)
    COUNT = 10000 # Back to safe 10,000 to debug
    print(f"📥 Downloading last {COUNT} M1 bars for {SYMBOL}...")
    rates = mt5.copy_rates_from_pos(SYMBOL, TIMEFRAME, 0, COUNT)

    if rates is None or len(rates) == 0:
        print(f"❌ No data received. Error: {mt5.last_error()}")
        print("Check if symbol exists and history is available.")
        mt5.shutdown()
        return

    print(f"✅ Received {len(rates)} bars.")

    # 3. Convert to DataFrame
    df = pd.DataFrame(rates)
    
    # 4. Format columns
    # Convert timestamp to string format "YYYY-MM-DD HH:MM:SS"
    df['time'] = pd.to_datetime(df['time'], unit='s')
    
    # Select and rename columns to match our feeder requirements
    # We need: time, open, high, low, close, tick_volume
    export_df = df[['time', 'open', 'high', 'low', 'close', 'tick_volume']]
    
    # 5. Save to CSV
    # Ensure directory exists
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    
    export_df.to_csv(OUTPUT_FILE, index=False)
    print(f"💾 Saved to: {OUTPUT_FILE}")
    print("Sample data:")
    print(export_df.head())

    # 6. Shutdown
    mt5.shutdown()

if __name__ == "__main__":
    export_data()
    input("\nPress Enter to exit...")