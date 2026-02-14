import MetaTrader5 as mt5

if not mt5.initialize():
    print("Initialize failed")
    quit()

symbols = mt5.symbols_get(group="*EURUSD*")
if symbols:
    print(f"Found {len(symbols)} symbols matching *EURUSD*:")
    for s in symbols:
        print(f" - {s.name}")
else:
    print("No symbols found matching *EURUSD*")

mt5.shutdown()
