import MetaTrader5 as mt5

def list_all_symbols():
    if not mt5.initialize():
        print("initialize() failed")
        return

    # Get all symbols
    symbols = mt5.symbols_get()
    
    print(f"Total symbols found: {len(symbols)}")
    print("\nSearching for EURUSD variants...")
    
    found_count = 0
    for s in symbols:
        if "EURUSD" in s.name:
            print(f"Found: {s.name} (Path: {s.path})")
            found_count += 1
            
    if found_count == 0:
        print("No symbol containing 'EURUSD' found. Printing first 10 symbols to check format:")
        for s in symbols[:10]:
            print(s.name)

    mt5.shutdown()

if __name__ == "__main__":
    list_all_symbols()