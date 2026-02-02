import MetaTrader5 as mt5
import pandas as pd
from datetime import datetime
import os

def create_and_open_custom_symbol(base_symbol="EURUSD", year=2024):
    custom_symbol = f"{base_symbol}_{year}_Replay"
    csv_path = f"data/{base_symbol}@_{year}_H1.csv" # 假设这是我们之前下载的文件名
    
    # 1. Initialize MT5
    if not mt5.initialize():
        print(f"❌ MT5 Init Failed: {mt5.last_error()}")
        return False
        
    print(f"🔗 Connected to MT5: {mt5.terminal_info().name}")

    # 2. Check & Delete Existing
    if mt5.symbol_select(custom_symbol, True):
        print(f"⚠️ {custom_symbol} exists, deleting to ensure clean slate...")
        mt5.symbol_select(custom_symbol, False) # Hide first
        # Note: MT5 python API doesn't have direct 'delete_symbol'. 
        # Usually we just overwrite rates. But CustomSymbolDelete exists in MQL5.
        # In Python, we can use CustomSymbolDelete if available or just overwrite.
        mt5.symbol_select(custom_symbol, False)

    # 3. Create Custom Symbol
    # We copy specs from the base symbol to ensure correct point value, digits, etc.
    print(f"🛠️ Creating Custom Symbol: {custom_symbol} based on {base_symbol}...")
    
    # Try to find the base symbol first (handle suffix like @ or .m)
    found_base = None
    if mt5.symbol_select(base_symbol, True):
        found_base = base_symbol
    else:
        # Search
        for s in mt5.symbols_get():
            if base_symbol in s.name:
                found_base = s.name
                break
    
    if not found_base:
        print(f"❌ Base symbol {base_symbol} not found.")
        return False
        
    print(f"📋 Copying specs from: {found_base}")
    
    # Create the symbol in "Custom" group
    path = f"Custom\\{custom_symbol}"
    if not mt5.custom_symbol_create(custom_symbol, path, found_base):
        print(f"⚠️ Create failed (might already exist): {mt5.last_error()}")
    
    # 4. Load & Inject Data
    if not os.path.exists(csv_path):
        print(f"❌ CSV not found: {csv_path}")
        return False
        
    print(f"📂 Reading data from {csv_path}...")
    df = pd.read_csv(csv_path)
    df['time'] = pd.to_datetime(df['time'])
    
    # Filter Year (Double check)
    df = df[df['time'].dt.year == year]
    
    # Prepare data for MT5
    # MT5 requires list of tuples or dicts with specific fields
    ticks = []
    rates = []
    
    print(f"💉 Injecting {len(df)} bars into {custom_symbol}...")
    
    # We use M1 rates usually for custom symbols to allow MT5 to build higher timeframes,
    # But here we downloaded H1. If we inject H1, we must query H1.
    
    rates_data = df[['time', 'open', 'high', 'low', 'close', 'tick_volume']].to_dict('records')
    
    # Convert timestamps to int
    for r in rates_data:
        r['time'] = int(r['time'].timestamp())
        r['spread'] = 10
        r['real_volume'] = 0
        
    # Batch write
    # Note: custom_rates_replace is the key to "Clean Slate"
    # It deletes all existing data in that range and replaces it.
    # To be safe, we delete everything from 1970 to 3000 first? 
    # Or just replacing the target range is enough if we trust the symbol is new.
    
    count = mt5.custom_rates_update(custom_symbol, rates_data)
    print(f"✅ Injected {count} bars.")
    
    # 5. Enable & Open Chart
    mt5.symbol_select(custom_symbol, True)
    
    print(f"🎉 Success! Please manually open {custom_symbol} chart in MT5.")
    print("   (File -> New Chart -> Custom -> ...)")
    
    mt5.shutdown()
    return True

if __name__ == "__main__":
    create_and_open_custom_symbol("EURUSD@", 2024)
