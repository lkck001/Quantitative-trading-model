import MetaTrader5 as mt5

if mt5.initialize():
    print("Connected to MT5")
    print(f"Version: {mt5.version()}")
    
    # List all attributes that start with 'custom'
    print("\nChecking for Custom Symbol APIs:")
    for attr in dir(mt5):
        if 'custom' in attr.lower():
            print(f" - {attr}")
            
    mt5.shutdown()
else:
    print("Failed to init MT5")
