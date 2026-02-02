import MetaTrader5 as mt5
import os
import shutil

def cleanup_mt5_folders():
    if not mt5.initialize():
        print("❌ MT5 Init Failed")
        return

    term_info = mt5.terminal_info()
    data_path = term_info.data_path
    mt5.shutdown()

    # Targets to remove
    targets = [
        os.path.join(data_path, "MQL5", "Scripts", "QuantitativeModel"),
        os.path.join(data_path, "MQL5", "Experts", "QuantitativeModel")
    ]

    print("🧹 Cleaning up duplicate folders...")
    
    for path in targets:
        if os.path.exists(path):
            try:
                shutil.rmtree(path)
                print(f"✅ Removed: {path}")
            except Exception as e:
                print(f"❌ Failed to remove {path}: {e}")
        else:
            print(f"⚪ Path not found (already clean): {path}")

    print("\n✨ Cleanup Complete. Please Refresh MT5 Navigator.")
    print("👉 You should now only use the 'MT5_EnergyTrading' folder.")

if __name__ == "__main__":
    cleanup_mt5_folders()
