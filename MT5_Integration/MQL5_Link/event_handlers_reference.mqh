/*

 */
// ============================================================================
// MQL5 Event Handler Signatures
// ============================================================================
// Use these as a quick reference when expanding the EA functionality.

// ----------------------------------------------------------------------------
// 1. Transaction Events (交易事务)
// ----------------------------------------------------------------------------

// Called when a trade event occurs (order placed, deal executed, position changed)
void OnTrade()
{
}

// Called when a trade transaction occurs (more detailed than OnTrade)
void OnTradeTransaction(
   const MqlTradeTransaction& trans,  // Transaction structure
   const MqlTradeRequest& request,    // Request structure
   const MqlTradeResult& result       // Result structure
)
{
}

// ----------------------------------------------------------------------------
// 2. Timer Event (定时器)
// ----------------------------------------------------------------------------

// Called when the timer event occurs (requires EventSetTimer/EventSetMillisecondTimer)
void OnTimer()
{
}

// ----------------------------------------------------------------------------
// 3. Chart Events (图表交互)
// ----------------------------------------------------------------------------

// Called when a chart event occurs (mouse click, key press, object create/delete)
// id: CHARTEVENT_KEYDOWN, CHARTEVENT_MOUSE_MOVE, CHARTEVENT_OBJECT_CREATE, etc.
void OnChartEvent(
   const int id,         // Event ID
   const long& lparam,   // Parameter of type long
   const double& dparam, // Parameter of type double
   const string& sparam  // Parameter of type string
)
{
}

// ----------------------------------------------------------------------------
// 4. Book Event (市场深度/订单簿)
// ----------------------------------------------------------------------------

// Called when the Depth of Market (DOM) changes
void OnBookEvent(
   const string& symbol  // The symbol for which the event occurred
)
{
}

// ----------------------------------------------------------------------------
// 5. Tester Events (策略测试器/优化)
// ----------------------------------------------------------------------------

// Called after testing a pass in the Strategy Tester
// Returns a value to be used as the optimization criterion (Custom Max)
double OnTester()
{
   return(0.0);
}

// Called before the start of optimization in the strategy tester
void OnTesterInit()
{
}

// Called when a new optimization frame is received
void OnTesterPass()
{
}

// Called after the completion of optimization in the strategy tester
void OnTesterDeinit()
{
}
