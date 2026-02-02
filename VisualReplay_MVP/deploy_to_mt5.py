import MetaTrader5 as mt5
import os
import shutil

def deploy_mql5_files():
    # 1. Initialize to get path
    if not mt5.initialize():
        print("❌ MT5 Init Failed. Please open MT5 manually first.")
        return

    term_info = mt5.terminal_info()
    data_path = term_info.data_path
    print(f"📂 MT5 Data Path detected: {data_path}")
    mt5.shutdown()

    # 2. Define Source and Destination
    # Adjust source path based on your project structure
    project_root = os.getcwd()
    src_dir = os.path.join(project_root, "MT5_Integration", "MQL5_Link")
    
    # Destination Paths
    dest_scripts = os.path.join(data_path, "MQL5", "Scripts", "QuantitativeModel")
    dest_experts = os.path.join(data_path, "MQL5", "Experts", "QuantitativeModel")
    
    # Create Dirs if not exist
    os.makedirs(dest_scripts, exist_ok=True)
    os.makedirs(dest_experts, exist_ok=True)

    # 3. Deploy Files
    files_to_deploy = [
        # (Filename, Source_Subdir, Dest_Dir)
        ("Create_Custom_Symbol.mq5", "", dest_scripts),
        ("MT5_EnergyTrading.mq5", "", dest_experts),
    ]

    print("\n🚀 Deploying Files...")
    
    for filename, _, dest_dir in files_to_deploy:
        src_file = os.path.join(src_dir, filename)
        
        if not os.path.exists(src_file):
            print(f"⚠️ Source file not found: {src_file}")
            continue
            
        dest_file = os.path.join(dest_dir, filename)
        
        try:
            shutil.copy2(src_file, dest_file)
            print(f"✅ Copied {filename} -> {dest_dir}")
        except Exception as e:
            print(f"❌ Failed to copy {filename}: {e}")

    print("\n✨ Deployment Complete!")
    print("👉 Please restart MT5 or right-click 'Scripts'/'Experts' and Refresh.")
    print(f"   Look for folder: QuantitativeModel")

if __name__ == "__main__":
    deploy_mql5_files()
