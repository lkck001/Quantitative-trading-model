# -*- coding: utf-8 -*-
"""
iTick外汇历史数据获取工具
获取EURUSD 2024-01-01 至 2025-01-01 的历史数据
"""

import requests
import pandas as pd
from datetime import datetime
import matplotlib.pyplot as plt
import warnings
warnings.filterwarnings('ignore')

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False


class ITickForexData:
    """iTick外汇数据获取类"""
    
    def __init__(self, api_key):
        """
        初始化
        
        参数:
            api_key: iTick API密钥
        """
        self.api_key = api_key
        self.base_url = 'https://api.itick.org/forex/kline'
        self.headers = {
            'accept': 'application/json',
            'token': api_key
        }
    
    def get_historical_data(self, symbol='EURUSD', ktype='8', 
                           start_date='2024-01-01', end_date='2025-01-01',
                           region='GB'):
        """
        获取历史K线数据
        
        参数:
            symbol: 货币对代码，如 'EURUSD'
            ktype: K线周期
                '1': 1分钟
                '2': 5分钟
                '3': 15分钟
                '4': 30分钟
                '5': 1小时
                '8': 日线
                '9': 周线
                '10': 月线
            start_date: 开始日期 'YYYY-MM-DD'
            end_date: 结束日期 'YYYY-MM-DD'
            region: 市场代码，外汇使用 'GB'
        
        返回:
            DataFrame: 包含OHLCV数据的DataFrame
        """
        # 转换日期为时间戳（毫秒）
        end_dt = datetime.strptime(end_date, '%Y-%m-%d')
        end_timestamp = int(end_dt.timestamp() * 1000)
        
        # 计算需要获取的数据条数
        start_dt = datetime.strptime(start_date, '%Y-%m-%d')
        days_diff = (end_dt - start_dt).days
        limit = str(days_diff + 10)  # 多获取一些以防遗漏
        
        # 构建请求URL
        url = f'{self.base_url}?region={region}&code={symbol}&kType={ktype}&et={end_timestamp}&limit={limit}'
        
        print(f"正在从iTick获取 {symbol} 数据...")
        print(f"  时间范围: {start_date} 至 {end_date}")
        print(f"  K线周期: {self._get_ktype_name(ktype)}")
        print(f"  请求URL: {url}")
        
        try:
            # 发送GET请求
            response = requests.get(url, headers=self.headers, timeout=30)
            
            # 检查响应状态
            if response.status_code == 200:
                data = response.json()
                
                if data.get('code') == 0 and 'data' in data:
                    # 转换为DataFrame
                    df = pd.DataFrame(data['data'])
                    
                    if len(df) == 0:
                        print("⚠️ 未获取到数据，请检查参数")
                        return None
                    
                    # 转换时间戳为日期时间
                    df['t'] = pd.to_datetime(df['t'], unit='ms')
                    
                    # 重命名列（iTick返回的字段名）
                    # t: 时间, o: 开盘, h: 最高, l: 最低, c: 收盘, v: 成交量
                    df.rename(columns={
                        't': 'Time',
                        'o': 'Open',
                        'h': 'High',
                        'l': 'Low',
                    'c': 'Close',
                        'v': 'Volume'
                    }, inplace=True)
                    
                    # 只保留需要的列
                    df = df[['Time', 'Open', 'High', 'Low', 'Close', 'Volume']]
                    
                    # 按日期排序
                    df.sort_values('Time', inplace=True)
                    df.reset_index(drop=True, inplace=True)
                    
                    # 过滤日期范围
                    df = df[(df['Time'] >= start_date) & (df['Time'] <= end_date)]
                    
                    print(f"✓ 成功获取 {len(df)} 条数据")
                    print(f"  实际时间范围: {df['Time'].min()} 至 {df['Time'].max()}")
                    
                    return df
                else:
                    error_msg = data.get('msg', 'Unknown error')
                    print(f"❌ API返回错误: {error_msg}")
                    return None
            else:
                print(f"❌ HTTP请求失败，状态码: {response.status_code}")
                print(f"   响应内容: {response.text[:200]}")
                return None
                
        except requests.exceptions.Timeout:
            print("❌ 请求超时，请检查网络连接")
            return None
        except requests.exceptions.RequestException as e:
            print(f"❌ 请求异常: {e}")
            return None
        except Exception as e:
            print(f"❌ 处理数据时出错: {e}")
            return None
    
    def _get_ktype_name(self, ktype):
        """获取K线周期名称"""
        ktype_map = {
            '1': '1分钟',
            '2': '5分钟',
            '3': '15分钟',
            '4': '30分钟',
            '5': '1小时',
            '8': '日线',
            '9': '周线',
            '10': '月线'
        }
        return ktype_map.get(ktype, f'未知({ktype})')
    
    def display_data(self, df, head_rows=10, tail_rows=10):
        """
        显示数据
        
        参数:
            df: DataFrame数据
            head_rows: 显示前N行
            tail_rows: 显示后N行
        """
        if df is None or len(df) == 0:
            print("没有数据可显示")
            return
        
        print("\n" + "=" * 80)
        print("数据预览（前{}行）".format(head_rows))
        print("=" * 80)
        print(df.head(head_rows).to_string(index=False))
        
        print("\n" + "=" * 80)
        print("数据预览（后{}行）".format(tail_rows))
        print("=" * 80)
        print(df.tail(tail_rows).to_string(index=False))
        
        print("\n" + "=" * 80)
        print("数据统计信息")
        print("=" * 80)
        print(f"总数据量: {len(df)} 条")
        print(f"时间范围: {df['Time'].min()} 至 {df['Time'].max()}")
        print(f"价格范围: {df['Low'].min():.5f} - {df['High'].max():.5f}")
        print(f"\n价格统计:")
        print(df[['Open', 'High', 'Low', 'Close']].describe())
    
    def plot_data(self, df, save_path=None):
        """
        绘制K线图
        
        参数:
            df: DataFrame数据
            save_path: 保存路径（如果为None则显示）
        """
        if df is None or len(df) == 0:
            print("没有数据可绘制")
            return
        
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(16, 10), 
                                       gridspec_kw={'height_ratios': [3, 1]})
        
        # 设置时间索引
        df_plot = df.set_index('Time')
        
        # 绘制价格走势
        ax1.plot(df_plot.index, df_plot['Close'], label='收盘价', linewidth=1.5, color='#2196F3')
        ax1.fill_between(df_plot.index, df_plot['Low'], df_plot['High'], 
                        alpha=0.2, color='#2196F3', label='价格区间')
        
        ax1.set_title('EURUSD 价格走势图 (2024-01-01 至 2025-01-01)', 
                     fontsize=14, fontweight='bold', pad=20)
        ax1.set_ylabel('价格', fontsize=12)
        ax1.legend(loc='best', fontsize=10)
        ax1.grid(True, alpha=0.3)
        
        # 绘制成交量
        ax2.bar(df_plot.index, df_plot['Volume'], alpha=0.6, color='#4CAF50')
        ax2.set_title('成交量', fontsize=12, fontweight='bold')
        ax2.set_xlabel('时间', fontsize=12)
        ax2.set_ylabel('成交量', fontsize=12)
        ax2.grid(True, alpha=0.3)
        
        # 格式化x轴日期
        fig.autofmt_xdate()
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"\n图表已保存: {save_path}")
            plt.close()
        else:
            plt.show()
    
    def save_to_csv(self, df, filepath='EURUSD_H1.csv'):
        """
        保存数据为CSV文件
        
        参数:
            df: DataFrame数据
            filepath: 保存路径
        """
        if df is None or len(df) == 0:
            print("没有数据可保存")
            return False
        
        try:
            df.to_csv(filepath, index=False, encoding='utf-8-sig')
            print(f"\n✓ 数据已保存到: {filepath}")
            return True
        except Exception as e:
            print(f"\n❌ 保存失败: {e}")
            return False


def main():
    """主函数"""
    
    print("=" * 80)
    print("iTick外汇历史数据获取工具")
    print("=" * 80)
    
    # API密钥
    API_KEY = '0383b34da95c4a3d973ebe4639aef9922375067966d047d585fd75abef379cf6'
    
    # 创建数据获取对象
    itick = ITickForexData(API_KEY)
    
    # 获取数据
    # 注意：iTick的ktype='5'表示1小时，'8'表示日线
    # 如果需要H1数据，使用ktype='5'
    df = itick.get_historical_data(
        symbol='EURUSD',
        ktype='5',  # 1小时K线（H1）
        start_date='2024-01-01',
        end_date='2025-01-01',
        region='GB'
    )
    
    if df is not None:
        # 显示数据
        itick.display_data(df)
        
        # 绘制图表
        itick.plot_data(df, save_path='EURUSD_price_chart.png')
        
        # 保存为CSV（用于量化交易系统）
        itick.save_to_csv(df, 'EURUSD_H1.csv')
        
        print("\n" + "=" * 80)
        print("数据获取完成！")
        print("=" * 80)
    else:
        print("\n数据获取失败，请检查：")
        print("  1. API密钥是否正确")
        print("  2. 网络连接是否正常")
        print("  3. 参数设置是否正确")
    
    return df


if __name__ == '__main__':
    df = main()

