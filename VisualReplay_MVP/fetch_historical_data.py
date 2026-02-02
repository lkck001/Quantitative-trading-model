import MetaTrader5 as mt5
import pandas as pd
from datetime import datetime
import pytz
import os

def fetch_and_save_data(symbol_pattern="EURUSD", year=2024, timeframe_name="H1"):
    """
    连接 MT5，获取指定年份的数据，展示并保存为 CSV。
    """
    # 映射 Timeframe 字符串到 MT5 常量
    tf_map = {
        "M1": mt5.TIMEFRAME_M1,
        "M5": mt5.TIMEFRAME_M5,
        "M15": mt5.TIMEFRAME_M15,
        "M30": mt5.TIMEFRAME_M30,
        "H1": mt5.TIMEFRAME_H1,
        "H4": mt5.TIMEFRAME_H4,
        "D1": mt5.TIMEFRAME_D1,
    }
    
    timeframe = tf_map.get(timeframe_name, mt5.TIMEFRAME_H1)

    print(f"=== 正在连接 MT5 终端... ===")
    if not mt5.initialize():
        print(f"❌ MT5 初始化失败, 错误码 = {mt5.last_error()}")
        print("请确保 MT5 终端已安装并可以在当前环境启动。")
        return None

    print(f"✅ 连接成功。终端: {mt5.terminal_info().name}")

    # 1. 智能查找 Symbol
    target_symbol = None
    
    # 优先尝试常用变体
    candidates = [symbol_pattern, symbol_pattern + "@", symbol_pattern + ".m", symbol_pattern + "pro"]
    
    for cand in candidates:
        if mt5.symbol_select(cand, True):
            target_symbol = cand
            print(f"✅ 找到交易品种: {target_symbol}")
            break
            
    # 如果没找到，搜索包含该名称的所有品种
    if not target_symbol:
        print(f"⚠️ 未能直接找到 {symbol_pattern}，正在搜索包含该名称的品种...")
        all_symbols = mt5.symbols_get()
        for s in all_symbols:
            if symbol_pattern in s.name:
                target_symbol = s.name
                mt5.symbol_select(target_symbol, True)
                print(f"✅ 自动匹配到: {target_symbol}")
                break
    
    if not target_symbol:
        print(f"❌ 无法找到交易品种 {symbol_pattern}。")
        mt5.shutdown()
        return None

    # 2. 设定时间范围 (UTC)
    timezone = pytz.timezone("Etc/UTC")
    date_from = datetime(year, 1, 1, tzinfo=timezone)
    date_to = datetime(year, 12, 31, 23, 59, tzinfo=timezone)

    print(f"=== 正在获取 {year} 年 {timeframe_name} 数据 ({target_symbol})... ===")
    
    rates = mt5.copy_rates_range(target_symbol, timeframe, date_from, date_to)

    mt5.shutdown()

    if rates is None or len(rates) == 0:
        print("❌ 未获取到数据。可能是历史数据未下载，请在 MT5 图表中手动滚动以加载历史数据。")
        return None

    # 3. 数据处理与展示
    df = pd.DataFrame(rates)
    df['time'] = pd.to_datetime(df['time'], unit='s')
    
    # 重命名列以符合常见习惯 (可选)
    # df.rename(columns={'tick_volume': 'volume'}, inplace=True)

    print(f"\n✅ 数据获取成功! 总条数: {len(df)}")
    print("\n--- 数据预览 (前 5 行) ---")
    print(df[['time', 'open', 'high', 'low', 'close', 'tick_volume']].head())
    print("\n--- 数据预览 (后 5 行) ---")
    print(df[['time', 'open', 'high', 'low', 'close', 'tick_volume']].tail())

    # 4. 保存文件
    output_dir = "data"
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    filename = f"{output_dir}/{target_symbol}_{year}_{timeframe_name}.csv"
    df.to_csv(filename, index=False)
    print(f"\n💾 数据已保存至: {filename}")
    
    return df

if __name__ == "__main__":
    # 获取 2024 年 H1 数据作为示例
    df = fetch_and_save_data("EURUSD", 2024, "H1")
