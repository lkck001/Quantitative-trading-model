import MetaTrader5 as mt5
from datetime import datetime

if not mt5.initialize():
    print("Initialize failed")
    quit()

symbol = "EURUSD" # Try without @
print(f"Checking {symbol}...")
info = mt5.symbol_info(symbol)
if info:
    print(f"✅ Symbol {symbol} found!")
    print(f"Visible: {info.visible}")
    print(f"Select: {info.select}")
    if not info.visible:
        print("Selecting symbol...")
        if not mt5.symbol_select(symbol, True):
             print("❌ Failed to select symbol")
else:
    print(f"❌ Symbol {symbol} NOT found")
    symbol = "EURUSD@" # Fallback
    print(f"Falling back to {symbol}...")

# Try to get last 10 bars M1
rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, 10)
if rates is None:
    print(f"❌ Failed to get M1 rates. Error: {mt5.last_error()}")
else:
    print(f"✅ Got {len(rates)} M1 bars. Last time: {datetime.fromtimestamp(rates[-1]['time'])}")

# Try to get last 10 bars H1
rates_h1 = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_H1, 0, 10)
if rates_h1 is None:
    print(f"❌ Failed to get H1 rates. Error: {mt5.last_error()}")
else:
    print(f"✅ Got {len(rates_h1)} H1 bars. Last time: {datetime.fromtimestamp(rates_h1[-1]['time'])}")

# Check 2024 history availability
start = datetime(2024, 1, 1)
end = datetime(2024, 1, 2)
rates_hist = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_M1, start, end)
if rates_hist is None:
     print(f"❌ Failed to get M1 history (2024-01-01). Error: {mt5.last_error()}")
else:
     print(f"✅ Got {len(rates_hist)} M1 history bars.")
     if len(rates_hist) > 0:
         print(f"   Bar 0 time: {datetime.fromtimestamp(rates_hist[0]['time'])}")

mt5.shutdown()
