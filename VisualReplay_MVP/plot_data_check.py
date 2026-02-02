import pandas as pd
import matplotlib.pyplot as plt
import os

def plot_preview(csv_path):
    if not os.path.exists(csv_path):
        print(f"File not found: {csv_path}")
        return

    print(f"Reading {csv_path}...")
    df = pd.read_csv(csv_path)
    df['time'] = pd.to_datetime(df['time'])
    
    # Plot Closing Price
    plt.figure(figsize=(12, 6))
    plt.plot(df['time'], df['close'], label='Close Price', linewidth=0.8)
    plt.title(f"Price History: {os.path.basename(csv_path)}")
    plt.xlabel("Date")
    plt.ylabel("Price")
    plt.legend()
    plt.grid(True)
    
    output_img = csv_path.replace(".csv", ".png")
    plt.savefig(output_img)
    print(f"Chart saved to: {output_img}")

if __name__ == "__main__":
    # Adjust path if needed based on previous step
    csv_file = "data/EURUSD@_2024_H1.csv"
    plot_preview(csv_file)
