# -*- coding: utf-8 -*-
"""
外汇数据获取模块
支持从多个数据源获取EURUSD历史数据

推荐优先级：
1. MetaTrader5 (最准确，需要MT5终端)
2. investpy (免费，数据质量好)
3. yfinance/yahooquery (免费但外汇数据有限)
4. polygon.io (需要API key，数据质量高)
5. Dukascopy (免费Tick数据，需要转换)

作者: AI Assistant
日期: 2024
"""
import sys
import io

# 修复Windows命令行编码问题
if sys.platform == 'win32':
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
    except:
        pass

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')


class ForexDataFetcher:
    """外汇数据获取器 - 统一接口"""
    
    @staticmethod
    def fetch_from_mt5(symbol='EURUSD', timeframe='H1', 
                       start_date='2024-01-01', end_date='2025-01-01'):
        """
        方式1：从MetaTrader5获取数据（最推荐！）
        
        优点：
        - 数据最准确，与MT5终端一致
        - 支持所有货币对和时间周期
        - 免费（需要安装MT5）
        
        安装：
        pip install MetaTrader5
        
        使用前提：
        1. 安装MetaTrader5终端
        2. 登录任意MT5账户（模拟账户即可）
        3. 确保MT5终端正在运行
        """
        try:
            import MetaTrader5 as mt5
            
            # 初始化MT5
            if not mt5.initialize():
                print(f"MT5初始化失败: {mt5.last_error()}")
                return None
            
            print("✓ MT5连接成功")
            
            # 转换时间周期
            timeframe_map = {
                'M1': mt5.TIMEFRAME_M1,
                'M5': mt5.TIMEFRAME_M5,
                'M15': mt5.TIMEFRAME_M15,
                'M30': mt5.TIMEFRAME_M30,
                'H1': mt5.TIMEFRAME_H1,
                'H4': mt5.TIMEFRAME_H4,
                'D1': mt5.TIMEFRAME_D1
            }
            
            mt5_timeframe = timeframe_map.get(timeframe, mt5.TIMEFRAME_H1)
            
            # 解析日期
            start_dt = datetime.strptime(start_date, '%Y-%m-%d')
            end_dt = datetime.strptime(end_date, '%Y-%m-%d')
            
            # 获取数据
            print(f"正在从MT5获取 {symbol} {timeframe} 数据...")
            rates = mt5.copy_rates_range(symbol, mt5_timeframe, start_dt, end_dt)
            
            if rates is None or len(rates) == 0:
                print(f"未获取到数据，请检查：")
                print(f"  1. MT5终端是否运行")
                print(f"  2. 货币对名称是否正确（如EURUSD）")
                print(f"  3. 时间范围内是否有数据")
                mt5.shutdown()
                return None
            
            # 转换为DataFrame
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            df.set_index('time', inplace=True)
            
            # 重命名列
            df.columns = ['Open', 'High', 'Low', 'Close', 'tick_volume', 'spread', 'real_volume']
            # 使用tick_volume作为Volume
            df['Volume'] = df['tick_volume']
            df = df[['Open', 'High', 'Low', 'Close', 'Volume']]
            
            mt5.shutdown()
            
            print(f"✓ 成功获取 {len(df)} 条数据")
            print(f"  时间范围: {df.index[0]} 至 {df.index[-1]}")
            
            return df
            
        except ImportError:
            print("❌ 未安装MetaTrader5库")
            print("   安装命令: pip install MetaTrader5")
            return None
        except Exception as e:
            print(f"❌ MT5获取数据失败: {e}")
            return None
    
    @staticmethod
    def fetch_from_investpy(symbol='EUR/USD', timeframe='1hour',
                            start_date='2024-01-01', end_date='2025-01-01'):
        """
        方式2：从investpy获取数据（免费，推荐！）
        
        优点：
        - 完全免费
        - 数据质量好
        - 支持多种货币对
        
        安装：
        pip install investpy
        
        注意：
        - 符号格式为 'EUR/USD'（带斜杠）
        - 时间周期：'1hour', '4hours', 'daily' 等
        """
        try:
            import investpy
            
            print(f"正在从investpy获取 {symbol} {timeframe} 数据...")
            
            # 转换时间周期格式
            timeframe_map = {
                'H1': '1hour',
                'H4': '4hours',
                'D1': 'daily'
            }
            investpy_timeframe = timeframe_map.get(timeframe, '1hour')
            
            # 获取数据
            df = investpy.get_currency_cross_historical_data(
                currency_cross=symbol,
                from_date=start_date,
                to_date=end_date,
                interval=investpy_timeframe
            )
            
            if df is None or len(df) == 0:
                print(f"未获取到数据")
                return None
            
            # 标准化列名
            df.columns = [col.capitalize() for col in df.columns]
            df = df[['Open', 'High', 'Low', 'Close', 'Volume']]
            
            print(f"✓ 成功获取 {len(df)} 条数据")
            print(f"  时间范围: {df.index[0]} 至 {df.index[-1]}")
            
            return df
            
        except ImportError:
            print("❌ 未安装investpy库")
            print("   安装命令: pip install investpy")
            return None
        except Exception as e:
            print(f"❌ investpy获取数据失败: {e}")
            print("   提示：investpy有时会因网站更新而失效，建议使用MT5")
            return None
    
    @staticmethod
    def fetch_from_yfinance(symbol='EURUSD=X', start_date='2024-01-01', 
                            end_date='2025-01-01', interval='1h'):
        """
        方式3：从Yahoo Finance获取数据（免费但数据可能不完整）
        
        优点：
        - 免费
        - 安装简单
        
        缺点：
        - 外汇数据可能不完整
        - 历史数据可能缺失
        
        安装：
        pip install yfinance
        
        注意：
        - 符号格式：'EURUSD=X' 或 'EURUSD=X'
        - 时间周期：'1h', '4h', '1d' 等
        """
        try:
            import yfinance as yf
            
            print(f"正在从Yahoo Finance获取 {symbol} 数据...")
            
            # 创建ticker对象
            ticker = yf.Ticker(symbol)
            
            # 获取数据
            df = ticker.history(start=start_date, end=end_date, interval=interval)
            
            if df is None or len(df) == 0:
                print(f"未获取到数据，Yahoo Finance的外汇数据可能不完整")
                return None
            
            # 标准化列名
            df = df[['Open', 'High', 'Low', 'Close', 'Volume']]
            
            print(f"✓ 成功获取 {len(df)} 条数据")
            print(f"  时间范围: {df.index[0]} 至 {df.index[-1]}")
            print("  ⚠️ 警告：Yahoo Finance的外汇数据可能不完整，建议验证数据质量")
            
            return df
            
        except ImportError:
            print("❌ 未安装yfinance库")
            print("   安装命令: pip install yfinance")
            return None
        except Exception as e:
            print(f"❌ yfinance获取数据失败: {e}")
            return None
    
    @staticmethod
    def fetch_from_yahooquery(symbol='EURUSD=X', start_date='2024-01-01',
                              end_date='2025-01-01', interval='1h'):
        """
        方式4：从Yahoo Finance（非官方API）获取数据
        
        优点：
        - 免费
        - 有时比yfinance更稳定
        
        安装：
        pip install yahooquery
        """
        try:
            from yahooquery import Ticker
            
            print(f"正在从yahooquery获取 {symbol} 数据...")
            
            ticker = Ticker(symbol)
            
            # 获取历史数据
            df = ticker.history(start=start_date, end=end_date, interval=interval)
            
            if df is None or len(df) == 0:
                print(f"未获取到数据")
                return None
            
            # 处理多级索引
            if isinstance(df.index, pd.MultiIndex):
                df = df.reset_index(level=0, drop=True)
            
            # 标准化列名
            df = df[['open', 'high', 'low', 'close', 'volume']]
            df.columns = ['Open', 'High', 'Low', 'Close', 'Volume']
            
            print(f"✓ 成功获取 {len(df)} 条数据")
            print(f"  时间范围: {df.index[0]} 至 {df.index[-1]}")
            
            return df
            
        except ImportError:
            print("❌ 未安装yahooquery库")
            print("   安装命令: pip install yahooquery")
            return None
        except Exception as e:
            print(f"❌ yahooquery获取数据失败: {e}")
            return None
    
    @staticmethod
    def fetch_from_polygon(api_key, symbol='C:EURUSD', start_date='2024-01-01',
                           end_date='2025-01-01', timespan='hour', multiplier=1):
        """
        方式5：从Polygon.io获取数据（需要API key）
        
        优点：
        - 数据质量高
        - 支持高频数据
        
        缺点：
        - 需要注册获取免费API key
        - 免费版有调用限制
        
        安装：
        pip install polygon-api-client
        
        获取API key：
        https://polygon.io/
        """
        try:
            from polygon import RESTClient
            
            if not api_key:
                print("❌ 需要提供Polygon.io API key")
                print("   注册地址: https://polygon.io/")
                return None
            
            print(f"正在从Polygon.io获取 {symbol} 数据...")
            
            client = RESTClient(api_key)
            
            # 获取聚合数据
            aggs = []
            for agg in client.get_aggs(
                ticker=symbol,
                multiplier=multiplier,
                timespan=timespan,
                from_=start_date,
                to=end_date,
                limit=50000
            ):
                aggs.append(agg)
            
            if not aggs:
                print("未获取到数据")
                return None
            
            # 转换为DataFrame
            data = []
            for agg in aggs:
                data.append({
                    'Open': agg.open,
                    'High': agg.high,
                    'Low': agg.low,
                    'Close': agg.close,
                    'Volume': agg.volume,
                    'Time': pd.Timestamp.fromtimestamp(agg.timestamp / 1000)
                })
            
            df = pd.DataFrame(data)
            df.set_index('Time', inplace=True)
            df = df[['Open', 'High', 'Low', 'Close', 'Volume']]
            
            print(f"✓ 成功获取 {len(df)} 条数据")
            print(f"  时间范围: {df.index[0]} 至 {df.index[-1]}")
            
            return df
            
        except ImportError:
            print("❌ 未安装polygon-api-client库")
            print("   安装命令: pip install polygon-api-client")
            return None
        except Exception as e:
            print(f"❌ Polygon.io获取数据失败: {e}")
            return None
    
    @staticmethod
    def fetch_auto(symbol='EURUSD', timeframe='H1', 
                   start_date='2024-01-01', end_date='2025-01-01',
                   polygon_api_key=None):
        """
        自动尝试多个数据源（按优先级）
        
        优先级：
        1. MetaTrader5
        2. investpy
        3. yfinance
        4. yahooquery
        5. polygon.io (如果提供API key)
        """
        print("=" * 60)
        print("自动获取EURUSD历史数据")
        print("=" * 60)
        
        # 尝试MT5
        print("\n[1/5] 尝试从MetaTrader5获取...")
        df = ForexDataFetcher.fetch_from_mt5(symbol, timeframe, start_date, end_date)
        if df is not None and len(df) > 0:
            return df
        
        # 尝试investpy
        print("\n[2/5] 尝试从investpy获取...")
        investpy_symbol = symbol[:3] + '/' + symbol[3:]  # EURUSD -> EUR/USD
        df = ForexDataFetcher.fetch_from_investpy(
            investpy_symbol, timeframe, start_date, end_date
        )
        if df is not None and len(df) > 0:
            return df
        
        # 尝试yfinance
        print("\n[3/5] 尝试从yfinance获取...")
        yf_symbol = symbol + '=X'  # EURUSD -> EURUSD=X
        interval_map = {'H1': '1h', 'H4': '4h', 'D1': '1d'}
        interval = interval_map.get(timeframe, '1h')
        df = ForexDataFetcher.fetch_from_yfinance(yf_symbol, start_date, end_date, interval)
        if df is not None and len(df) > 0:
            return df
        
        # 尝试yahooquery
        print("\n[4/5] 尝试从yahooquery获取...")
        df = ForexDataFetcher.fetch_from_yahooquery(yf_symbol, start_date, end_date, interval)
        if df is not None and len(df) > 0:
            return df
        
        # 尝试polygon.io
        if polygon_api_key:
            print("\n[5/5] 尝试从Polygon.io获取...")
            polygon_symbol = f'C:{symbol}'  # EURUSD -> C:EURUSD
            timespan_map = {'H1': 'hour', 'H4': 'hour', 'D1': 'day'}
            timespan = timespan_map.get(timeframe, 'hour')
            multiplier = 1 if timeframe == 'H1' else (4 if timeframe == 'H4' else 1)
            df = ForexDataFetcher.fetch_from_polygon(
                polygon_api_key, polygon_symbol, start_date, end_date, timespan, multiplier
            )
            if df is not None and len(df) > 0:
                return df
        
        print("\n❌ 所有数据源都失败，请检查：")
        print("   1. 网络连接")
        print("   2. 数据源是否可访问")
        print("   3. 参数是否正确")
        print("\n推荐：安装MetaTrader5并使用MT5数据源（最可靠）")
        
        return None


def main():
    """示例：获取EURUSD H1数据"""
    
    # ========================================
    # 方式1：自动尝试（推荐）
    # ========================================
    df = ForexDataFetcher.fetch_auto(
        symbol='EURUSD',
        timeframe='H1',
        start_date='2024-01-01',
        end_date='2025-01-01'
    )
    
    if df is not None:
        # 保存为CSV
        output_path = r'E:\Quantitative trading model\EURUSD_H1.csv'
        df.to_csv(output_path)
        print(f"\n✓ 数据已保存到: {output_path}")
        
        # 显示数据预览
        print("\n数据预览:")
        print(df.head(10))
        print(f"\n数据统计:")
        print(f"  总条数: {len(df)}")
        print(f"  时间范围: {df.index[0]} 至 {df.index[-1]}")
        print(f"  价格范围: {df['Low'].min():.5f} - {df['High'].max():.5f}")
    else:
        print("\n未能获取数据，请检查网络或尝试其他数据源")
    
    # ========================================
    # 方式2：手动指定数据源（如果自动失败）
    # ========================================
    
    # # 从MT5获取（最推荐）
    # df = ForexDataFetcher.fetch_from_mt5('EURUSD', 'H1', '2024-01-01', '2025-01-01')
    
    # # 从investpy获取
    # df = ForexDataFetcher.fetch_from_investpy('EUR/USD', '1hour', '2024-01-01', '2025-01-01')
    
    # # 从yfinance获取
    # df = ForexDataFetcher.fetch_from_yfinance('EURUSD=X', '2024-01-01', '2025-01-01', '1h')
    
    return df


if __name__ == '__main__':
    df = main()

