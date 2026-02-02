import MetaTrader5 as mt5
import os
import shutil

def move_script_to_scripts_folder():
    if not mt5.initialize():
        print("❌ MT5 Init Failed")
        return

    term_info = mt5.terminal_info()
    data_path = term_info.data_path
    mt5.shutdown()

    # Source: It's currently in the Experts folder (because of your folder mapping)
    # We need to copy/move it to the Scripts folder manually to fix the compilation issue.
    
    # Path assuming MQL5_Link is mapped to Experts/MT5_EnergyTrading
    src_path = os.path.join(data_path, "MQL5", "Experts", "MT5_EnergyTrading", "Create_Custom_Symbol.mq5")
    
    # Target: MQL5/Scripts/Create_Custom_Symbol.mq5
    dest_dir = os.path.join(data_path, "MQL5", "Scripts")
    dest_path = os.path.join(dest_dir, "Create_Custom_Symbol.mq5")

    print(f"📂 Source: {src_path}")
    print(f"📂 Target: {dest_path}")

    if os.path.exists(src_path):
        try:
            shutil.copy2(src_path, dest_path)
            print("✅ File copied to Scripts folder successfully.")
            print("👉 Now open MetaEditor, find 'Create_Custom_Symbol.mq5' under 'Scripts', and Compile (F7).")
        except Exception as e:
            print(f"❌ Failed to copy: {e}")
    else:
        print("⚠️ Source file not found. Please check if the folder mapping is active.")

if __name__ == "__main__":
    move_script_to_scripts_folder()
