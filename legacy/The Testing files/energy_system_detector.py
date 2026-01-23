# -*- coding: utf-8 -*-
"""
能量系统交易机会识别程序
识别标准上三（做多）和下三（做空）交易机会

上三交易机会判断规则：
1. 向上的一段释放，幅度大，力度强，水平角度接近90°，不小于45°
2. 积累的回撤幅度小，不超过之前释放幅度的二分之一
3. 积累的结构完整，外观为三角形，具备初、中、末期特征
4. 积累的内部结构均匀，触及点间距比例接近1:1
5. 积累时间和能量释放跨度比，大于2倍

下三交易机会判断规则：
1. 向下的一段释放，幅度大，力度强，水平角度接近90°，不大于135°
2. 积累的回撤幅度小，不超过之前释放幅度的二分之一
3. 积累的结构完整，外观为三角形，具备初、中、末期特征
4. 积累的内部结构均匀，触及点间距比例接近1:1
5. 积累时间和能量释放跨度比，大于2倍

作者: AI Assistant
日期: 2024
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime, timedelta
import os
import warnings
warnings.filterwarnings('ignore')

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False


class ZigZag:
    """ZigZag算法 - 用于识别波峰波谷"""
    
    @staticmethod
    def calculate(df, deviation=0.001):
        """
        计算ZigZag点位
        
        参数:
            df: DataFrame，包含High, Low, Close列
            deviation: 最小偏离百分比（用于过滤噪音）
        
        返回:
            包含ZigZag点位的列表 [(index, price, type), ...]
            type: 1=波峰(高点), -1=波谷(低点)
        """
        highs = df['High'].values
        lows = df['Low'].values
        
        zigzag_points = []
        
        if len(df) < 3:
            return zigzag_points
        
        # 初始化
        last_pivot_type = 0  # 1=高点, -1=低点
        last_pivot_price = 0
        last_pivot_idx = 0
        
        # 找初始方向
        for i in range(1, min(10, len(df))):
            if highs[i] > highs[0] * (1 + deviation):
                last_pivot_type = -1  # 开始是低点
                last_pivot_price = lows[0]
                last_pivot_idx = 0
                break
            elif lows[i] < lows[0] * (1 - deviation):
                last_pivot_type = 1  # 开始是高点
                last_pivot_price = highs[0]
                last_pivot_idx = 0
                break
        
        if last_pivot_type == 0:
            return zigzag_points
        
        zigzag_points.append((df.index[last_pivot_idx], last_pivot_price, last_pivot_type))
        
        # 遍历寻找转折点
        for i in range(1, len(df)):
            if last_pivot_type == -1:  # 上一个是低点，找高点
                if highs[i] > last_pivot_price * (1 + deviation):
                    # 找到新高点
                    if len(zigzag_points) > 0 and zigzag_points[-1][2] == 1:
                        # 更新最后的高点
                        if highs[i] > zigzag_points[-1][1]:
                            zigzag_points[-1] = (df.index[i], highs[i], 1)
                    else:
                        zigzag_points.append((df.index[i], highs[i], 1))
                    last_pivot_type = 1
                    last_pivot_price = highs[i]
                    last_pivot_idx = i
                elif lows[i] < last_pivot_price:
                    # 新低
                    last_pivot_price = lows[i]
                    last_pivot_idx = i
                    if zigzag_points[-1][2] == -1:
                        zigzag_points[-1] = (df.index[i], lows[i], -1)
            else:  # 上一个是高点，找低点
                if lows[i] < last_pivot_price * (1 - deviation):
                    # 找到新低点
                    if len(zigzag_points) > 0 and zigzag_points[-1][2] == -1:
                        # 更新最后的低点
                        if lows[i] < zigzag_points[-1][1]:
                            zigzag_points[-1] = (df.index[i], lows[i], -1)
                    else:
                        zigzag_points.append((df.index[i], lows[i], -1))
                    last_pivot_type = -1
                    last_pivot_price = lows[i]
                    last_pivot_idx = i
                elif highs[i] > last_pivot_price:
                    # 新高
                    last_pivot_price = highs[i]
                    last_pivot_idx = i
                    if zigzag_points[-1][2] == 1:
                        zigzag_points[-1] = (df.index[i], highs[i], 1)
        
        return zigzag_points


class EnergySystemDetector:
    """能量系统交易机会识别器"""
    
    def __init__(self, df, 
                 min_release_pips=50,          # 最小释放幅度(点)
                 min_release_angle=45,          # 上三最小角度
                 max_release_angle=135,         # 下三最大角度  
                 max_retrace_ratio=0.5,         # 最大回撤比例
                 min_time_ratio=2.0,            # 最小时间比例(积累/释放)
                 touch_ratio_tolerance=0.3,     # 触及点间距比例容差
                 min_touch_points=5):           # 最小触及点数量
        """
        初始化检测器
        
        参数:
            df: OHLC数据，需要包含Open, High, Low, Close, 时间索引
            min_release_pips: 最小释放幅度（点数，对于EURUSD 1点=0.0001）
            min_release_angle: 上三的最小释放角度（度）
            max_release_angle: 下三的最大释放角度（度）
            max_retrace_ratio: 积累阶段最大回撤比例（不超过释放的1/2）
            min_time_ratio: 积累时间/释放时间的最小比例
            touch_ratio_tolerance: 三角形触及点间距比例的容差
            min_touch_points: 三角形最小触及点数量
        """
        self.df = df.copy()
        self.min_release_pips = min_release_pips
        self.min_release_angle = min_release_angle
        self.max_release_angle = max_release_angle
        self.max_retrace_ratio = max_retrace_ratio
        self.min_time_ratio = min_time_ratio
        self.touch_ratio_tolerance = touch_ratio_tolerance
        self.min_touch_points = min_touch_points
        
        # 存储识别结果
        self.opportunities = []
        
        # 计算ZigZag
        self.zigzag = ZigZag.calculate(df, deviation=0.0015)
        
    def _calculate_angle(self, start_price, end_price, bars):
        """
        计算价格运动的角度
        
        注意：由于价格和时间单位不同，需要标准化
        这里使用ATR来标准化价格变动
        """
        if bars == 0:
            return 90 if end_price > start_price else -90
        
        # 使用价格变化百分比来计算角度
        price_change = (end_price - start_price) / start_price * 100
        
        # 每根K线对应的"时间单位"
        time_unit = 1.0
        
        # 标准化：假设1%的价格变化对应1个时间单位是45度
        normalized_slope = price_change / (bars * time_unit) * 2
        
        # 转换为角度
        angle = np.degrees(np.arctan(normalized_slope))
        
        return angle
    
    def _is_valid_release(self, start_idx, end_idx, direction):
        """
        验证释放阶段是否有效
        
        参数:
            start_idx: 释放开始的数据索引
            end_idx: 释放结束的数据索引
            direction: 1=向上(上三), -1=向下(下三)
        
        返回:
            (是否有效, 释放详情字典)
        """
        start_pos = self.df.index.get_loc(start_idx)
        end_pos = self.df.index.get_loc(end_idx)
        
        if direction == 1:  # 向上释放
            start_price = self.df.loc[start_idx, 'Low']
            end_price = self.df.loc[end_idx, 'High']
        else:  # 向下释放
            start_price = self.df.loc[start_idx, 'High']
            end_price = self.df.loc[end_idx, 'Low']
        
        # 计算幅度（点数）
        amplitude_pips = abs(end_price - start_price) * 10000
        
        if amplitude_pips < self.min_release_pips:
            return False, None
        
        # 计算角度
        bars = end_pos - start_pos
        angle = self._calculate_angle(start_price, end_price, bars)
        
        # 验证角度
        if direction == 1:  # 上三要求角度 >= 45°
            if angle < self.min_release_angle:
                return False, None
        else:  # 下三要求角度 <= -45°（即向下）
            if angle > -self.min_release_angle:
                return False, None
        
        # 检查K线特征（阳盛阴衰 或 阴盛阳衰）
        release_df = self.df.iloc[start_pos:end_pos+1]
        bullish_bars = (release_df['Close'] > release_df['Open']).sum()
        bearish_bars = (release_df['Close'] < release_df['Open']).sum()
        
        if direction == 1 and bullish_bars <= bearish_bars:
            return False, None
        if direction == -1 and bearish_bars <= bullish_bars:
            return False, None
        
        return True, {
            'start_idx': start_idx,
            'end_idx': end_idx,
            'start_price': start_price,
            'end_price': end_price,
            'amplitude_pips': amplitude_pips,
            'angle': angle,
            'bars': bars,
            'direction': direction
        }
    
    def _find_triangle_touches(self, df_segment, direction):
        """
        在积累阶段寻找三角形的触及点
        
        参数:
            df_segment: 积累阶段的数据片段
            direction: 1=上三(找收敛三角形), -1=下三
        
        返回:
            触及点列表 [(index, price, type), ...]
        """
        # 使用较小的deviation来捕捉积累阶段的小波动
        local_zigzag = ZigZag.calculate(df_segment, deviation=0.0008)
        
        return local_zigzag
    
    def _validate_triangle(self, touches, release_info):
        """
        验证三角形形态是否有效
        
        参数:
            touches: 触及点列表
            release_info: 释放阶段信息
        
        返回:
            (是否有效, 三角形详情)
        """
        if len(touches) < self.min_touch_points:
            return False, None
        
        direction = release_info['direction']
        
        # 分离高点和低点
        highs = [(t[0], t[1]) for t in touches if t[2] == 1]
        lows = [(t[0], t[1]) for t in touches if t[2] == -1]
        
        if len(highs) < 2 or len(lows) < 2:
            return False, None
        
        # 检查是否形成收敛形态
        # 上三：高点递降，低点递升 -> 收敛三角形
        # 下三：高点递降，低点递升 -> 收敛三角形
        
        high_prices = [h[1] for h in highs]
        low_prices = [l[1] for l in lows]
        
        # 检查收敛（高点降低，低点升高）
        high_slope = (high_prices[-1] - high_prices[0]) / len(high_prices) if len(high_prices) > 1 else 0
        low_slope = (low_prices[-1] - low_prices[0]) / len(low_prices) if len(low_prices) > 1 else 0
        
        # 收敛条件：高点下降，低点上升
        is_converging = high_slope < 0 and low_slope > 0
        
        if not is_converging:
            return False, None
        
        # 检查触及点间距比例是否接近1:1
        touch_times = [self.df.index.get_loc(t[0]) for t in touches]
        intervals = np.diff(touch_times)
        
        if len(intervals) > 1:
            mean_interval = np.mean(intervals)
            std_interval = np.std(intervals)
            cv = std_interval / mean_interval if mean_interval > 0 else float('inf')
            
            if cv > self.touch_ratio_tolerance:
                return False, None
        
        # 检查回撤幅度
        all_prices = [t[1] for t in touches]
        max_price = max(all_prices)
        min_price = min(all_prices)
        
        retrace_amplitude = max_price - min_price
        release_amplitude = abs(release_info['end_price'] - release_info['start_price'])
        
        retrace_ratio = retrace_amplitude / release_amplitude if release_amplitude > 0 else float('inf')
        
        if retrace_ratio > self.max_retrace_ratio:
            return False, None
        
        return True, {
            'touches': touches,
            'highs': highs,
            'lows': lows,
            'retrace_ratio': retrace_ratio,
            'is_converging': is_converging
        }
    
    def detect_opportunities(self):
        """
        检测所有交易机会
        
        返回:
            交易机会列表
        """
        self.opportunities = []
        
        if len(self.zigzag) < 4:
            print("ZigZag点位不足，无法进行检测")
            return self.opportunities
        
        print(f"共找到 {len(self.zigzag)} 个ZigZag点位，开始分析...")
        
        # 遍历ZigZag点位寻找释放-积累模式
        for i in range(len(self.zigzag) - 3):
            # 尝试识别上三机会
            self._detect_pattern(i, direction=1)
            
            # 尝试识别下三机会
            self._detect_pattern(i, direction=-1)
        
        # 按时间排序
        self.opportunities.sort(key=lambda x: x['signal_time'])
        
        return self.opportunities
    
    def _detect_pattern(self, zigzag_start_idx, direction):
        """
        检测特定方向的交易模式
        
        参数:
            zigzag_start_idx: ZigZag起点索引
            direction: 1=上三, -1=下三
        """
        # 获取释放阶段的起止点
        point1 = self.zigzag[zigzag_start_idx]
        
        # 上三：从低点到高点；下三：从高点到低点
        if direction == 1 and point1[2] != -1:  # 上三需要从低点开始
            return
        if direction == -1 and point1[2] != 1:  # 下三需要从高点开始
            return
        
        # 寻找释放结束点
        for j in range(zigzag_start_idx + 1, min(zigzag_start_idx + 4, len(self.zigzag))):
            point2 = self.zigzag[j]
            
            # 验证释放方向
            if direction == 1 and point2[2] != 1:  # 上三释放结束在高点
                continue
            if direction == -1 and point2[2] != -1:  # 下三释放结束在低点
                continue
            
            # 验证释放阶段
            is_valid, release_info = self._is_valid_release(
                point1[0], point2[0], direction
            )
            
            if not is_valid:
                continue
            
            # 寻找积累阶段
            release_end_pos = self.df.index.get_loc(point2[0])
            
            # 积累阶段应该至少是释放时间的2倍
            min_accumulation_bars = int(release_info['bars'] * self.min_time_ratio)
            max_accumulation_bars = int(release_info['bars'] * 5)  # 不超过5倍
            
            # 检查是否有足够的数据
            if release_end_pos + min_accumulation_bars >= len(self.df):
                continue
            
            # 尝试不同长度的积累阶段
            for acc_len in range(min_accumulation_bars, 
                                min(max_accumulation_bars, len(self.df) - release_end_pos)):
                
                acc_start = release_end_pos
                acc_end = release_end_pos + acc_len
                
                if acc_end >= len(self.df):
                    break
                
                df_accumulation = self.df.iloc[acc_start:acc_end+1]
                
                # 寻找三角形触及点
                touches = self._find_triangle_touches(df_accumulation, direction)
                
                if len(touches) < self.min_touch_points:
                    continue
                
                # 验证三角形
                is_valid_tri, triangle_info = self._validate_triangle(touches, release_info)
                
                if not is_valid_tri:
                    continue
                
                # 计算时间比例
                time_ratio = acc_len / release_info['bars']
                
                if time_ratio < self.min_time_ratio:
                    continue
                
                # 找到有效机会！
                signal_time = self.df.index[acc_end]
                
                opportunity = {
                    'type': '上三' if direction == 1 else '下三',
                    'direction': direction,
                    'signal_time': signal_time,
                    'release_info': release_info,
                    'triangle_info': triangle_info,
                    'time_ratio': time_ratio,
                    'acc_start_idx': self.df.index[acc_start],
                    'acc_end_idx': signal_time,
                    'entry_price': self.df.loc[signal_time, 'Close']
                }
                
                # 避免重复添加相近的机会
                is_duplicate = False
                for existing in self.opportunities:
                    if abs((existing['signal_time'] - signal_time).total_seconds()) < 3600 * 24:
                        is_duplicate = True
                        break
                
                if not is_duplicate:
                    self.opportunities.append(opportunity)
                    print(f"发现 {opportunity['type']} 机会: {signal_time}")
                
                break  # 找到一个有效的积累阶段后跳出
    
    def plot_opportunity(self, opportunity, save_path=None, show_bars=100):
        """
        绘制交易机会图表
        
        参数:
            opportunity: 交易机会字典
            save_path: 保存路径（如果为None则显示）
            show_bars: 显示的K线数量
        """
        signal_time = opportunity['signal_time']
        signal_pos = self.df.index.get_loc(signal_time)
        
        # 计算显示范围
        release_start_pos = self.df.index.get_loc(opportunity['release_info']['start_idx'])
        start_pos = max(0, release_start_pos - 10)
        end_pos = min(len(self.df), signal_pos + 20)
        
        df_plot = self.df.iloc[start_pos:end_pos].copy()
        
        # 创建图表
        fig, ax = plt.subplots(figsize=(16, 9), facecolor='white')
        
        # 绘制K线
        for idx, row in df_plot.iterrows():
            pos = df_plot.index.get_loc(idx)
            color = '#26a69a' if row['Close'] >= row['Open'] else '#ef5350'
            
            # 绘制影线
            ax.plot([pos, pos], [row['Low'], row['High']], color=color, linewidth=1)
            
            # 绘制实体
            body_bottom = min(row['Open'], row['Close'])
            body_height = abs(row['Close'] - row['Open'])
            rect = plt.Rectangle((pos - 0.3, body_bottom), 0.6, body_height, 
                                 color=color, alpha=0.9)
            ax.add_patch(rect)
        
        # 标注释放阶段
        release = opportunity['release_info']
        rel_start_pos = df_plot.index.get_loc(release['start_idx']) if release['start_idx'] in df_plot.index else 0
        rel_end_pos = df_plot.index.get_loc(release['end_idx']) if release['end_idx'] in df_plot.index else len(df_plot)-1
        
        # 绘制释放区域
        if opportunity['direction'] == 1:  # 上三
            ax.annotate('', xy=(rel_end_pos, release['end_price']), 
                       xytext=(rel_start_pos, release['start_price']),
                       arrowprops=dict(arrowstyle='->', color='#2196F3', lw=2))
            ax.text(rel_start_pos, release['start_price'], '释放起点', 
                   fontsize=10, color='#2196F3', ha='right')
        else:  # 下三
            ax.annotate('', xy=(rel_end_pos, release['end_price']), 
                       xytext=(rel_start_pos, release['start_price']),
                       arrowprops=dict(arrowstyle='->', color='#F44336', lw=2))
            ax.text(rel_start_pos, release['start_price'], '释放起点', 
                   fontsize=10, color='#F44336', ha='right')
        
        # 绘制三角形积累区域
        triangle = opportunity['triangle_info']
        if triangle and 'touches' in triangle:
            touches = triangle['touches']
            touch_xs = []
            touch_ys = []
            
            for t in touches:
                if t[0] in df_plot.index:
                    touch_xs.append(df_plot.index.get_loc(t[0]))
                    touch_ys.append(t[1])
            
            if len(touch_xs) > 0:
                ax.scatter(touch_xs, touch_ys, color='#FF9800', s=100, 
                          zorder=5, marker='o', label='三角形触及点')
                
                # 绘制三角形边界线
                highs = [(df_plot.index.get_loc(h[0]), h[1]) for h in triangle['highs'] if h[0] in df_plot.index]
                lows = [(df_plot.index.get_loc(l[0]), l[1]) for l in triangle['lows'] if l[0] in df_plot.index]
                
                if len(highs) >= 2:
                    high_xs, high_ys = zip(*highs)
                    ax.plot(high_xs, high_ys, '--', color='#9C27B0', linewidth=1.5, label='上边界')
                
                if len(lows) >= 2:
                    low_xs, low_ys = zip(*lows)
                    ax.plot(low_xs, low_ys, '--', color='#9C27B0', linewidth=1.5, label='下边界')
        
        # 标注信号点
        signal_local_pos = df_plot.index.get_loc(signal_time) if signal_time in df_plot.index else len(df_plot)-1
        signal_price = opportunity['entry_price']
        
        marker_color = '#4CAF50' if opportunity['direction'] == 1 else '#F44336'
        ax.scatter([signal_local_pos], [signal_price], color=marker_color, 
                  s=200, zorder=10, marker='^' if opportunity['direction'] == 1 else 'v',
                  edgecolors='black', linewidths=1.5)
        
        ax.axvline(x=signal_local_pos, color=marker_color, linestyle='--', alpha=0.5)
        
        # 设置标题和标签
        type_str = opportunity['type']
        ax.set_title(f"EURUSD H1 - {type_str}交易机会\n"
                    f"信号时间: {signal_time.strftime('%Y-%m-%d %H:%M')}\n"
                    f"释放幅度: {release['amplitude_pips']:.1f}点 | "
                    f"释放角度: {release['angle']:.1f}° | "
                    f"时间比例: {opportunity['time_ratio']:.1f}x | "
                    f"回撤比例: {triangle['retrace_ratio']:.1%}",
                    fontsize=12, fontweight='bold', pad=20)
        
        ax.set_xlabel('K线序号', fontsize=10)
        ax.set_ylabel('价格', fontsize=10)
        
        # 设置x轴标签
        tick_positions = range(0, len(df_plot), max(1, len(df_plot)//10))
        tick_labels = [df_plot.index[i].strftime('%m-%d\n%H:%M') for i in tick_positions]
        ax.set_xticks(list(tick_positions))
        ax.set_xticklabels(tick_labels, fontsize=8)
        
        ax.legend(loc='best', fontsize=9)
        ax.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight', facecolor='white')
            plt.close()
            print(f"图表已保存: {save_path}")
        else:
            plt.show()
    
    def export_results(self, output_dir):
        """
        导出所有识别结果
        
        参数:
            output_dir: 输出目录
        """
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
        
        # 为每个机会生成图表
        for i, opp in enumerate(self.opportunities):
            filename = f"{opp['type']}_{opp['signal_time'].strftime('%Y%m%d_%H%M')}.png"
            filepath = os.path.join(output_dir, filename)
            self.plot_opportunity(opp, save_path=filepath)
        
        # 生成汇总CSV
        if self.opportunities:
            summary_data = []
            for opp in self.opportunities:
                summary_data.append({
                    '类型': opp['type'],
                    '信号时间': opp['signal_time'].strftime('%Y-%m-%d %H:%M'),
                    '入场价格': opp['entry_price'],
                    '释放幅度(点)': opp['release_info']['amplitude_pips'],
                    '释放角度(度)': opp['release_info']['angle'],
                    '时间比例': opp['time_ratio'],
                    '回撤比例': opp['triangle_info']['retrace_ratio'],
                    '方向': '做多' if opp['direction'] == 1 else '做空'
                })
            
            summary_df = pd.DataFrame(summary_data)
            csv_path = os.path.join(output_dir, 'trading_opportunities_summary.csv')
            summary_df.to_csv(csv_path, index=False, encoding='utf-8-sig')
            print(f"汇总表已保存: {csv_path}")
        
        return len(self.opportunities)


def load_forex_data(filepath):
    """
    加载外汇数据
    
    支持常见的CSV格式，特别是无表头的MT4/MT5导出格式
    格式: Date, Time, Open, High, Low, Close, Volume, ...
    示例: 2024.01.01,22:00,1.10427,1.10429,1.10425,1.10429,5900000,...
    """
    import pandas as pd
    
    # 尝试读取前几行来判断格式
    try:
        # 先尝试读取一行
        with open(filepath, 'r') as f:
            first_line = f.readline()
        
        # 检查是否包含表头关键字
        has_header = any(x in first_line.lower() for x in ['date', 'time', 'open', 'close'])
        
        if has_header:
            df = pd.read_csv(filepath)
            # 标准化列名
            col_mapping = {
                'time': 'Time', 'date': 'Time', 'datetime': 'Time',
                'open': 'Open', 'high': 'High', 'low': 'Low', 'close': 'Close',
                'volume': 'Volume', 'vol': 'Volume'
            }
            df.columns = [col_mapping.get(c.lower(), c) for c in df.columns]
        else:
            # 无表头，使用默认列名
            # 假设格式: Date, Time, Open, High, Low, Close, Volume, ...
            df = pd.read_csv(filepath, header=None)
            
            # 根据列数分配列名
            if len(df.columns) >= 7:
                df.columns = ['Date', 'TimeStr', 'Open', 'High', 'Low', 'Close', 'Volume'] + [f'Col_{i}' for i in range(7, len(df.columns))]
                
                # 合并日期和时间
                # 处理日期格式 2024.01.01
                df['Date'] = df['Date'].astype(str).str.replace('.', '-')
                df['Time'] = pd.to_datetime(df['Date'] + ' ' + df['TimeStr'])
            else:
                print("警告: CSV列数不足，无法识别")
                return None
        
        # 设置索引
        if 'Time' in df.columns:
            if not pd.api.types.is_datetime64_any_dtype(df['Time']):
                df['Time'] = pd.to_datetime(df['Time'])
            df.set_index('Time', inplace=True)
            return df
            
    except Exception as e:
        print(f"读取文件出错: {e}")
        return None
    
    return df


def generate_sample_data(start_date='2024-01-01', end_date='2025-01-01'):
    """
    生成模拟的EURUSD H1数据（用于测试）
    
    注意：实际使用时应该从MT4/MT5或数据提供商获取真实数据
    """
    print("生成模拟数据用于测试...")
    print("=" * 50)
    print("注意：这是模拟数据，实际使用请导入真实的EURUSD H1数据！")
    print("=" * 50)
    
    # 生成时间序列（排除周末）
    dates = pd.date_range(start=start_date, end=end_date, freq='H')
    dates = dates[dates.dayofweek < 5]  # 排除周末
    
    np.random.seed(42)
    
    # 模拟价格走势
    n = len(dates)
    base_price = 1.0800
    
    # 生成随机游走 + 一些趋势
    returns = np.random.normal(0, 0.0003, n)  # 小时波动约3点
    
    # 添加一些趋势段
    trend_periods = np.zeros(n)
    for i in range(0, n, 500):
        trend_length = min(100, n - i)
        trend_direction = np.random.choice([-1, 1])
        trend_periods[i:i+trend_length] = trend_direction * 0.0002
    
    returns = returns + trend_periods
    
    prices = base_price * np.exp(np.cumsum(returns))
    
    # 生成OHLC
    data = {
        'Open': prices,
        'High': prices * (1 + np.abs(np.random.normal(0, 0.0002, n))),
        'Low': prices * (1 - np.abs(np.random.normal(0, 0.0002, n))),
        'Close': prices * (1 + np.random.normal(0, 0.0001, n)),
        'Volume': np.random.randint(1000, 10000, n)
    }
    
    df = pd.DataFrame(data, index=dates)
    
    # 确保OHLC关系正确
    df['High'] = df[['Open', 'High', 'Close']].max(axis=1)
    df['Low'] = df[['Open', 'Low', 'Close']].min(axis=1)
    
    return df


def main():
    """主函数"""
    
    print("=" * 60)
    print("能量系统交易机会识别程序")
    print("目标：识别EURUSD H1级别的标准上三和下三机会")
    print("=" * 60)
    
    # ========================================
    # 数据加载方式选择
    # ========================================
    
    # 方式1：从CSV文件加载真实数据（如果已有数据文件）
    # data_path = r'E:\Quantitative trading model\EURUSD_H1.csv'
    # df = load_forex_data(data_path)
    
    # 方式2：自动从网络获取数据（推荐！）
    try:
        from forex_data_fetcher import ForexDataFetcher
        print("\n正在从网络获取EURUSD H1数据...")
        df = ForexDataFetcher.fetch_auto(
            symbol='EURUSD',
            timeframe='H1',
            start_date='2024-01-01',
            end_date='2025-01-01'
        )
        
        if df is None or len(df) == 0:
            print("\n⚠️ 网络获取失败，使用模拟数据...")
            df = generate_sample_data('2024-01-01', '2025-01-01')
    except ImportError:
        print("\n⚠️ 未找到数据获取模块，使用模拟数据...")
        df = generate_sample_data('2024-01-01', '2025-01-01')
    
    # 方式3：使用模拟数据测试（仅用于测试）
    # df = generate_sample_data('2024-01-01', '2025-01-01')
    
    print(f"\n数据加载完成:")
    print(f"  时间范围: {df.index[0]} 至 {df.index[-1]}")
    print(f"  数据量: {len(df)} 条H1 K线")
    print(f"  价格范围: {df['Low'].min():.5f} - {df['High'].max():.5f}")
    
    # ========================================
    # 参数配置（可根据需要调整）
    # ========================================
    
    detector = EnergySystemDetector(
        df,
        min_release_pips=50,          # 最小释放幅度50点
        min_release_angle=45,          # 上三最小角度45°
        max_release_angle=135,         # 下三最大角度135°
        max_retrace_ratio=0.5,         # 回撤不超过释放的50%
        min_time_ratio=2.0,            # 积累时间至少是释放的2倍
        touch_ratio_tolerance=0.4,     # 触及点间距比例容差40%
        min_touch_points=5             # 至少5个触及点
    )
    
    # ========================================
    # 执行检测
    # ========================================
    
    print("\n开始检测交易机会...")
    opportunities = detector.detect_opportunities()
    
    print(f"\n检测完成！")
    print(f"共发现 {len(opportunities)} 个交易机会:")
    
    up_count = sum(1 for o in opportunities if o['direction'] == 1)
    down_count = sum(1 for o in opportunities if o['direction'] == -1)
    print(f"  上三机会: {up_count} 个")
    print(f"  下三机会: {down_count} 个")
    
    # ========================================
    # 导出结果
    # ========================================
    
    output_dir = r'E:\Quantitative trading model\energy_system_results'
    
    if opportunities:
        print(f"\n正在导出结果到: {output_dir}")
        detector.export_results(output_dir)
        
        print("\n交易机会详情:")
        print("-" * 80)
        for i, opp in enumerate(opportunities, 1):
            print(f"{i}. [{opp['type']}] {opp['signal_time'].strftime('%Y-%m-%d %H:%M')}")
            print(f"   入场价: {opp['entry_price']:.5f}")
            print(f"   释放幅度: {opp['release_info']['amplitude_pips']:.1f}点")
            print(f"   释放角度: {opp['release_info']['angle']:.1f}°")
            print(f"   时间比例: {opp['time_ratio']:.1f}x")
            print(f"   回撤比例: {opp['triangle_info']['retrace_ratio']:.1%}")
            print()
    else:
        print("\n未发现符合条件的交易机会。")
        print("建议：")
        print("  1. 检查数据是否正确加载")
        print("  2. 适当放宽筛选条件（如降低min_release_pips）")
        print("  3. 确认数据时间范围内存在明显的趋势行情")
    
    print("\n程序执行完毕！")
    return detector, opportunities


if __name__ == '__main__':
    detector, opportunities = main()

