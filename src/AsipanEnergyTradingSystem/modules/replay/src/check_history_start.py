import MetaTrader5 as mt5
from datetime import datetime

if not mt5.initialize():
    quit()

symbol = "EURUSD@"
# Get first bar (oldest)
# To do this, we can ask for rates from a very old date, or use copy_rates_from_pos with huge index?
# No, copy_rates_from_pos(symbol, timeframe, 0, count) gets latest.
# To get oldest, we need to know how many bars there are?

# Let's try to get bars from 2020 to 2026
start = datetime(2020, 1, 1)
end = datetime(2026, 1, 1)

# Asking for too much might be slow or fail.
# Let's just ask for the header of the history?
# Use copy_rates_from(symbol, timeframe, datetime(2020,1,1), 1) -> This gets 1 bar starting from 2020.
rates = mt5.copy_rates_from(symbol, mt5.TIMEFRAME_M1, datetime(2020, 1, 1), 1)
if rates is not None and len(rates) > 0:
    print(f"Oldest bar after 2020: {datetime.fromtimestamp(rates[0]['time'])}")
else:
    print("No data after 2020")

# Try 2025
rates = mt5.copy_rates_from(symbol, mt5.TIMEFRAME_M1, datetime(2025, 1, 1), 1)
if rates is not None and len(rates) > 0:
    print(f"Oldest bar after 2025-01-01: {datetime.fromtimestamp(rates[0]['time'])}")

mt5.shutdown()
