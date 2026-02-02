import MetaTrader5 as mt5
import pandas as pd
from datetime import datetime

def test_connection():
    print("Attempting to connect to MT5 Terminal...")
    
    # 1. Initialize Connection
    # If MT5 is not open, this will launch it.
    if not mt5.initialize():
        print(f"initialize() failed, error code = {mt5.last_error()}")
        return False

    # 2. Print Terminal Info
    print("\n[Connection Successful!]")
    terminal_info = mt5.terminal_info()
    print(f"Terminal: {terminal_info.name} (Build {terminal_info.build})")
    print(f"Connected Server: {mt5.account_info().server}")
    print(f"Login Account: {mt5.account_info().login}")
    
    # 3. Fetch some data to prove it works
    print("\n[Data Fetch Test]")
    symbol = "EURUSD@"  # Updated based on list_symbols.py result
    # Attempt to enable symbol in MarketWatch if not visible
    selected = mt5.symbol_select(symbol, True)
    if not selected:
        print(f"Failed to select {symbol}")
        mt5.shutdown()
        return

    # Get last 5 M1 bars
    rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, 5)
    
    if rates is None:
        print("Failed to get rates. (Are you logged in?)")
    else:
        # Convert to DataFrame
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        print(f"Last 5 M1 bars for {symbol}:")
        print(df[['time', 'open', 'high', 'low', 'close']])

    # 4. Cleanup
    mt5.shutdown()
    print("\n[Connection Closed]")
    return True

if __name__ == "__main__":
    test_connection()