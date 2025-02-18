//+------------------------------------------------------------------+
//|                      Trend Breakout StrategyEA.mq4               |
//|                      Custom EA by Brandon.Kao                    |
//|                                                                  |
//+------------------------------------------------------------------+
//copyright information
#property copyright     "Brandon.Kao"
#property link          "shyan2812@hotmail.com"
#property version       "1.00"
#property strict

//
#define LMT_TIME        (D'3000.12.31 23:59:59')    //授權時間限制
#define ACCOUNT_NUM     12345678                    //授權帳戶限制
#define TIME_SCALE      3                           //0~5，數字越大，畫面放大比例越大
#define CHART_TYPE      CHART_CANDLES               //CHART_LINE

#define N0_TICK         0
#define N1_TICK         1
#define N2_TICK         2
#define N3_TICK         3

//#define DEBUG_MESSAGE

//交易類型定義
enum tradetype
{
    W_TYPE,
    M_TYPE,
    AUTO
};

//趨勢點位建立及交易狀態定義
enum statemachine
{
    H1_OPEN,
    L1_OPEN,
    H2_OPEN,
    L2_OPEN,
    TRADE_OPEN
};

//K棒型態定義
enum candlestick
{
    RED_CANDLESTICK,
    BLACK_CANDLESTICK,
    NONE
};

//訂單信息定義
struct orderinfo
{
    //順勢單相關參數，包含W底或M頭
    int order_number;               //順勢單號
    bool open_trade_flag;           //順勢單開倉旗標
    double open_lots;               //順勢單開倉手數
    int magic_number;               //順勢單開倉魔術號碼
    //順勢破壞單相關參數
    int order_number_rev;           //順勢破壞反向單號
    bool open_trade_rev_flag;       //順勢破壞反向單開倉旗標
    double rev_open_lots;           //順勢破壞單開倉手數
    int rev_magic_number;           //順勢破壞單開倉魔術號碼
    //通用參數
    tradetype trade_type;           //定義當前開單型態
    ENUM_TIMEFRAMES time_period;    //時間週期
    int spread;                     //允許最大點差，與市場當前時間段之交易量有關
    int slippage;                   //允許最大滑點，受到電腦、EA執行及網路速度影響
    double profit_rate;             //獲利計算比例
    double neckline_rate;           //頸線成形比例
    double topbottom_rate;          //底或頂成形比例
    bool moving_switch;             //移動盈利開關
    int moving_time;                //允許移動盈利次數
    bool profit_switch;             //止盈止損開關
    double max_profit;              //最大止盈金額
    double max_loss;                //最大止損金額
    bool time_switch;               //時間限制開關
    int start_time_hour;            //開始時間-小時
    int start_time_min;             //開始時間-分鐘
    int end_time_hour;              //結束時間-小時
    int end_time_min;               //結束時間-分鐘
};

//交易點位數據儲存結構體，包含點位價格、對應圖表XY軸、對應成交量及對應指標
struct x_type
{
    //紀錄價格點位結構體
    struct price
    {
        double H1;
        double L1;
        double H2;
        double L2;
    }price;
    //紀錄對應價格點位之XY軸
    struct position
    {
        struct x_axis
        {
            int H1;
            int L1;
            int H2;
            int L2;
        }x_axis;
        struct y_axis
        {
            int H1;
            int L1;
            int H2;
            int L2;
        }y_axis;
    }position;
    //紀錄點位對應之成交量
    struct volume
    {
        long H1;
        long L1;
        long H2;
        long L2;
    }volume;
    //紀錄套用之對應指標
    struct indicator
    {
        double H1;
        double L1;
        double H2;
        double L2;
    }indicator;
};

//指標濾波定義
enum indicatortype
{
    NULL_,
    MA,
    MACD,
    RSI,
    CCI,
    KD,
    BEARPOWER,
    BULLSPOWER
};

/*
* 參數定義及知識
* 點差計算公式：(買價-賣價)*(點差小數位)=點差，點差小數位以各家交易商為準
* 點差計算範例：黃金為例，買價2649.75、賣價2649.52、點差小數位2，則點差為(2649.75-2649.52)*(100)=23
*               EURUSD為例，買價1.03577、賣價1.03568、點差小數位5，則點差為(1.03577-1.03568)*(100000)=9
*
* 槓桿計算公式：交易合約價值/保證金=槓桿，即槓桿越高，所需繳交保證金越低
* 槓桿計算範例：交易合約價值100000、卷商提供槓桿100，則所需繳交保證金為100000/100=1000
*
* 庫存費計算公式：
* 庫存費計算範例：
*
*/


//使用者輸入參數
input tradetype TRADE_TYPE = AUTO;         //交易類型_Trading Type
input ENUM_TIMEFRAMES TIME_PERIOD = PERIOD_H1;    //時間週期_Time Frame
input double OPEN_LOTS = 0.3;          //開單手數_Open Lots
input int SPREAD = 45;           //最大點差_Max Spread
input int SLIPPAGE = 5;            //最大滑點_Max Slippage
input double RATE = 0.7;          //盈利倍率_Profit Rate
input double NECKLINE_RATE = 1.0;          //頸線比例_Neckline Rate(%)
input double TOPBOTTOM_RATE = 2.0;          //頂底比例_Top Bottom Rate(%)
input bool SL_REV_SWITCH = false;        //反向止損開關_Reverse Stop Loss Switch
input double REV_OPEN_LOTS = 0.3;          //反向開單手數_Reverse Open Lots
input bool MOVE_TP = true;         //移動止盈開關_Moving Take Profit
input int MOVE_TIME = 3;            //移動止盈次數_Moving Time
input bool PROFIT_LMT_EN = false;        //止盈止損開關_Profit/Loss Switch
input double MAX_PROFIT = 1000;         //最大止盈價格_Max Profit in Price
input double MAX_LOSS = 350;          //最大止損價格_Max Loss in Price
input indicatortype INDICATOR_TYPE = NULL_;        //指標開關_Indicator Filter
input bool TIME_LMT_EN = false;        //時間限制開關_Time ON/OFF Switch
input string START_TIME = "01:00";      //開始時間_Start Time in Server
input string END_TIME = "23:00";      //結束時間_End Time in Server
input int MAGIC_NUM = 12345678;     //魔術號碼_Magic Number

//全局變量，定義w及m型態之訂單信息結構體
orderinfo wTypeOrderInfo, mTypeOrderInfo;

//+------------------------------------------------------------------+
//| Detect Black or Red K function                                   |
//+------------------------------------------------------------------+
int detectBlackRed_K(int k, orderinfo& of)
{
    double openPrice = iOpen(Symbol(), of.time_period, k);
    double closePrice = iClose(Symbol(), of.time_period, k);

    candlestick status_K;

    status_K = (closePrice >= openPrice) ? RED_CANDLESTICK : BLACK_CANDLESTICK;

    return status_K;
}

//+------------------------------------------------------------------+
//| Function to parse time from string format HH:mm                  |
//+------------------------------------------------------------------+
void ParseTime(string timeStr, int& hour, int& minute)
{
    string parts[];
    int count = StringSplit(timeStr, ':', parts);
    if (count == 2)
    {
        hour = StringToInteger(parts[0]);
        minute = StringToInteger(parts[1]);
    }
    else
    {
        Print("Invalid time format: ", timeStr);
    }
}

//+------------------------------------------------------------------+
//| Function to check if current time is within allowed range        |
//+------------------------------------------------------------------+
bool IsWithinTimeRange(int currentHour, int currentMinute, int startHour, int startMinute, int endHour, int endMinute)
{
    int currentTime = currentHour * 60 + currentMinute; // 轉換成分鐘
    int startTime = startHour * 60 + startMinute;
    int endTime = endHour * 60 + endMinute;

    // 處理跨日情況
    if (endTime < startTime)
    {
        if (currentTime >= startTime || currentTime <= endTime)
            return true;
    }
    else
    {
        if (currentTime >= startTime && currentTime <= endTime)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Function to initial x-type trend strategy parameter              |
//+------------------------------------------------------------------+
void initXTypeOrderInfo(orderinfo& x_of)
{
    //趨勢單
    x_of.order_number = 0;
    x_of.open_trade_flag = false;
    x_of.open_lots = OPEN_LOTS;
    x_of.magic_number = MAGIC_NUM;
    //趨勢破壞單
    x_of.order_number_rev = 0;
    x_of.open_trade_rev_flag = false;
    x_of.rev_open_lots = OPEN_LOTS;
    x_of.rev_magic_number = MAGIC_NUM;
    //通用訂單信息
    x_of.trade_type = TRADE_TYPE;
    x_of.time_period = TIME_PERIOD;
    x_of.spread = SPREAD;
    x_of.slippage = SLIPPAGE;
    x_of.profit_rate = RATE;
    x_of.neckline_rate = (NECKLINE_RATE / 100);
    x_of.topbottom_rate = (TOPBOTTOM_RATE / 100);
    x_of.moving_switch = MOVE_TP;
    x_of.moving_time = MOVE_TIME;
    x_of.profit_switch = PROFIT_LMT_EN;
    x_of.max_profit = MAX_PROFIT;
    x_of.max_loss = MAX_LOSS;
    x_of.time_switch = TIME_LMT_EN;

    ParseTime(START_TIME, x_of.start_time_hour, x_of.start_time_min);
    ParseTime(END_TIME, x_of.end_time_hour, x_of.end_time_min);
}

void processWTypeTrend(void)
{
    //w型態點位建立順序 H1->L1->H2->L2->Open
    static int stateMachine = H1_OPEN;
    static x_type W_Type;
    static int moving_time = 0;

    switch (stateMachine)
    {
    case H1_OPEN:
        //當前為獲取H1價格區間，隱藏其餘趨勢線
        ObjectSet("W_TrendLine_L1", OBJPROP_WIDTH, 0);
        ObjectSet("W_TrendLine_H2", OBJPROP_WIDTH, 0);
        ObjectSet("W_TrendLine_L2", OBJPROP_WIDTH, 0);

        //清除交易信號
        wTypeOrderInfo.open_trade_flag = false;
        wTypeOrderInfo.open_trade_rev_flag = false;
        moving_time = 0;

        //若，[N-1]收盤價 大於等於 [N-2]收盤價，H1價格向上更新為[N-1]收盤價
        //若，[N-1]收盤價 小於 [N-2]收盤價，找到最高價格H1為[N-2]收盤價
        if (Close[N1_TICK] >= Close[N2_TICK])
        {
            ObjectMove(ChartID(), "W_TrendLine_H1", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "W_TrendLine_H1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            W_Type.price.H1 = Close[N1_TICK];
        }
        else if (Close[N1_TICK] < Close[N2_TICK])
        {
            ObjectMove(ChartID(), "W_TrendLine_H1", 0, Time[N2_TICK], Close[N2_TICK]);
            ObjectMove(ChartID(), "W_TrendLine_H1", 1, Time[N2_TICK + 3], Close[N2_TICK]);
            W_Type.price.H1 = Close[N2_TICK];
            W_Type.volume.H1 = iVolume(Symbol(), wTypeOrderInfo.time_period, N2_TICK);
            W_Type.indicator.H1 = iMACD(Symbol(), wTypeOrderInfo.time_period, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, N2_TICK);
            stateMachine = L1_OPEN;
#ifdef DEBUG_MESSAGE
            Print("W trend H1 price has found! [" + DoubleToString(W_Type.price.H1) + "]");
#endif
        }
        else
        {
            //do nothing
        }
        break;
    case L1_OPEN:
        //當前為獲取L1價格區間，顯示L1趨勢線
        ObjectSet("W_TrendLine_L1", OBJPROP_WIDTH, 10);
        ObjectSet("W_TrendLine_H2", OBJPROP_WIDTH, 0);
        ObjectSet("W_TrendLine_L2", OBJPROP_WIDTH, 0);

        //若，[N-1]收盤價 大於 H1收盤價，即表示趨勢被突破，重新計算並繪製H1為[N-1]收盤價
        if (Close[N1_TICK] > W_Type.price.H1)
        {
            ObjectMove(ChartID(), "W_TrendLine_H1", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "W_TrendLine_H1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            W_Type.price.H1 = Close[N1_TICK];
            W_Type.price.L1 = 0;
            stateMachine = H1_OPEN;
            break;
        }

        //若，[N-1]收盤價 大於等於 [N-2]收盤價，找到最低價格L1為[N-2]收盤價
        //若，[N-1]收盤價 小於 [N-2]收盤價，L1價格向下更新為[N-1]收盤價
        if (Close[N1_TICK] >= Close[N2_TICK])
        {
            ObjectMove(ChartID(), "W_TrendLine_L1", 0, Time[N2_TICK], Close[N2_TICK]);
            ObjectMove(ChartID(), "W_TrendLine_L1", 1, Time[N2_TICK + 3], Close[N2_TICK]);
            W_Type.price.L1 = Close[N2_TICK];
            W_Type.volume.L1 = iVolume(Symbol(), wTypeOrderInfo.time_period, N2_TICK);
            W_Type.indicator.L1 = iMACD(Symbol(), wTypeOrderInfo.time_period, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, N2_TICK);
            stateMachine = H2_OPEN;
#ifdef DEBUG_MESSAGE
            Print("W trend L1 price has found! [" + DoubleToString(W_Type.price.L1) + "]");
#endif
        }
        else if (Close[N1_TICK] < Close[N2_TICK])
        {
            ObjectMove(ChartID(), "W_TrendLine_L1", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "W_TrendLine_L1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            W_Type.price.L1 = Close[N1_TICK];
        }
        else
        {
            //do nothing
        }
        break;
    case H2_OPEN:
        //當前為獲取H2價格區間，顯示H2趨勢線
        ObjectSet("W_TrendLine_L1", OBJPROP_WIDTH, 10);
        ObjectSet("W_TrendLine_H2", OBJPROP_WIDTH, 10);
        ObjectSet("W_TrendLine_L2", OBJPROP_WIDTH, 0);

        //若，[N-1]收盤價 大於 H1收盤價，即表示趨勢被突破，重新計算並繪製H1為[N-1]收盤價
        if (Close[N1_TICK] > W_Type.price.H1)
        {
            ObjectMove(ChartID(), "W_TrendLine_H1", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "W_TrendLine_H1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            W_Type.price.H1 = Close[N1_TICK];
            W_Type.price.L1 = 0;
            W_Type.price.H2 = 0;
            stateMachine = H1_OPEN;
            break;
        }

        //若，[N-1]收盤價 小於 L1收盤價，即表示趨勢被突破，重新計算並繪製L1為[N-1]收盤價
        if (Close[N1_TICK] < W_Type.price.L1)
        {
            ObjectMove(ChartID(), "W_TrendLine_L1", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "W_TrendLine_L1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            W_Type.price.L1 = Close[N1_TICK];
            W_Type.price.H2 = 0;
            stateMachine = L1_OPEN;
            break;
        }

        //若，[N-1]收盤價 小於 [N-2]收盤價，找到次高價格H2為[N-2]收盤價
        //若，[N-1]收盤價 大於等於 [N-2]收盤價，H2價格向上更新為[N-1]收盤價
        if (Close[N1_TICK] < Close[N2_TICK] && Close[N2_TICK] >= W_Type.price.L1 * (1 + wTypeOrderInfo.neckline_rate))
        {
            ObjectMove(ChartID(), "W_TrendLine_H2", 0, Time[N2_TICK], Close[N2_TICK]);
            ObjectMove(ChartID(), "W_TrendLine_H2", 1, Time[N2_TICK + 3], Close[N2_TICK]);
            W_Type.price.H2 = Close[N2_TICK];
            W_Type.volume.H2 = iVolume(Symbol(), wTypeOrderInfo.time_period, N2_TICK);
            W_Type.indicator.H2 = iMACD(Symbol(), wTypeOrderInfo.time_period, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, N2_TICK);
            stateMachine = L2_OPEN;
#ifdef DEBUG_MESSAGE
            Print("W trend H2 price has found! [" + DoubleToString(W_Type.price.H2) + "]");
#endif
        }
        else if (Close[N1_TICK] >= Close[N2_TICK])
        {
            ObjectMove(ChartID(), "W_TrendLine_H2", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "W_TrendLine_H2", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            W_Type.price.H2 = Close[N1_TICK];
        }
        else
        {
            //do nothing
        }
        break;
    case L2_OPEN:
        //當前為獲取L2價格區間，顯示L2趨勢線
        ObjectSet("W_TrendLine_L1", OBJPROP_WIDTH, 10);
        ObjectSet("W_TrendLine_H2", OBJPROP_WIDTH, 10);
        ObjectSet("W_TrendLine_L2", OBJPROP_WIDTH, 10);

        //若，[N-1]收盤價 大於 H2收盤價，即表示趨勢被突破，重新計算並繪製H2為[N-1]收盤價
        if (Close[N1_TICK] > W_Type.price.H2)
        {
            ObjectMove(ChartID(), "W_TrendLine_H2", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "W_TrendLine_H2", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            W_Type.price.H2 = Close[N1_TICK];
            W_Type.price.L2 = 0;
            stateMachine = H2_OPEN;
            break;
        }

        //若，[N-1]收盤價 小於 L1收盤價，即表示趨勢被突破，重新計算並繪製L1為[N-1]收盤價
        if (Close[N1_TICK] < W_Type.price.L1 * (1 - wTypeOrderInfo.topbottom_rate))
        {
            ObjectMove(ChartID(), "W_TrendLine_L1", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "W_TrendLine_L1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            W_Type.price.L1 = Close[N1_TICK];
            W_Type.price.H2 = 0;
            W_Type.price.L2 = 0;
            stateMachine = L1_OPEN;
            break;
        }

        //若，[N-1]收盤價 大於等於 [N-2]收盤價，找到次低價格L2為[N-2]收盤價
        //若，[N-1]收盤價 小於 [N-2]收盤價，L2價格向下更新為[N-1]收盤價
        if (Close[N1_TICK] >= Close[N2_TICK] && Close[N2_TICK] <= W_Type.price.L1 * (1 + wTypeOrderInfo.topbottom_rate) && Close[N2_TICK] >= W_Type.price.L1 * (1 - wTypeOrderInfo.topbottom_rate))
        {
            ObjectMove(ChartID(), "W_TrendLine_L2", 0, Time[N2_TICK], Close[N2_TICK]);
            ObjectMove(ChartID(), "W_TrendLine_L2", 1, Time[N2_TICK + 3], Close[N2_TICK]);
            W_Type.price.L2 = Close[N2_TICK];
            W_Type.volume.L2 = iVolume(Symbol(), wTypeOrderInfo.time_period, N2_TICK);
            W_Type.indicator.L2 = iMACD(Symbol(), wTypeOrderInfo.time_period, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, N2_TICK);
            stateMachine = TRADE_OPEN;
#ifdef DEBUG_MESSAGE
            Print("W trend L2 price has found! [" + DoubleToString(W_Type.price.L2) + "]");
#endif
        }
        else if (Close[N1_TICK] < Close[N2_TICK])
        {
            ObjectMove(ChartID(), "W_TrendLine_L2", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "W_TrendLine_L2", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            W_Type.price.L2 = Close[N1_TICK];
        }
        else
        {
            //do nothing
        }
        break;
    case TRADE_OPEN:
        if (wTypeOrderInfo.open_trade_flag == false)
        {
            //開單限制導致無法開單，並順勢突破H2+(H2 - L2)或L2時，退回至相應狀態
            if (Close[N1_TICK] > (W_Type.price.H2 + (W_Type.price.H2 - W_Type.price.L2)))
            {
                ObjectMove(ChartID(), "W_TrendLine_H2", 0, Time[N1_TICK], Close[N1_TICK]);
                ObjectMove(ChartID(), "W_TrendLine_H2", 1, Time[N1_TICK + 3], Close[N1_TICK]);
                W_Type.price.H2 = Close[N1_TICK];
                W_Type.price.L2 = 0;
                stateMachine = H2_OPEN;
                break;
            }
            if (Close[N1_TICK] < W_Type.price.L2)
            {
                ObjectMove(ChartID(), "W_TrendLine_L2", 0, Time[N1_TICK], Close[N1_TICK]);
                ObjectMove(ChartID(), "W_TrendLine_L2", 1, Time[N1_TICK + 3], Close[N1_TICK]);
                W_Type.price.L2 = Close[N1_TICK];
                stateMachine = L2_OPEN;
                break;
            }

            //W底趨勢成形，近兩根K棒突破H2、當下無M頭空單開倉、且點差小於設定
            if (Close[N1_TICK] >= W_Type.price.H2 && Close[N2_TICK] >= W_Type.price.H2 && mTypeOrderInfo.open_trade_flag == false && SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) <= wTypeOrderInfo.spread)
            {
                //在此以市價開單，止盈設在X倍(H2 + [H2]-[L2])，止損設在L2

                if (W_Type.volume.L2 > W_Type.volume.H2 && W_Type.volume.L1 > W_Type.volume.L2)
                    wTypeOrderInfo.order_number = OrderSend(Symbol(), OP_BUY, wTypeOrderInfo.open_lots * 2, Ask, wTypeOrderInfo.slippage, W_Type.price.L2, Ask + (W_Type.price.H2 - W_Type.price.L2) * wTypeOrderInfo.profit_rate, NULL, wTypeOrderInfo.magic_number, 0, CLR_NONE);
                else
                    wTypeOrderInfo.order_number = OrderSend(Symbol(), OP_BUY, wTypeOrderInfo.open_lots, Ask, wTypeOrderInfo.slippage, W_Type.price.L2, Ask + (W_Type.price.H2 - W_Type.price.L2) * wTypeOrderInfo.profit_rate, NULL, wTypeOrderInfo.magic_number, 0, CLR_NONE);

                if (wTypeOrderInfo.order_number != -1)
                {
                    wTypeOrderInfo.open_trade_flag = true;
#ifdef DEBUG_MESSAGE

                    Print("H1 Price [" + DoubleToString(W_Type.price.H1) + "] H1 Res. [" + DoubleToString(W_Type.volume.H1) + "]");
                    Print("L1 Price [" + DoubleToString(W_Type.price.L1) + "] L1 Res. [" + DoubleToString(W_Type.volume.L1) + "]");
                    Print("H2 Price [" + DoubleToString(W_Type.price.H2) + "] H2 Res. [" + DoubleToString(W_Type.volume.H2) + "]");
                    Print("L2 Price [" + DoubleToString(W_Type.price.L2) + "] L2 Res. [" + DoubleToString(W_Type.volume.L2) + "]");


                    Print("H1 Price [" + DoubleToString(W_Type.price.H1) + "] H1 MACD. [" + DoubleToString(W_Type.indicator.H1) + "]");
                    Print("L1 Price [" + DoubleToString(W_Type.price.L1) + "] L1 MACD. [" + DoubleToString(W_Type.indicator.L1) + "]");
                    Print("H2 Price [" + DoubleToString(W_Type.price.H2) + "] H2 MACD. [" + DoubleToString(W_Type.indicator.H2) + "]");
                    Print("L2 Price [" + DoubleToString(W_Type.price.L2) + "] L2 MACD. [" + DoubleToString(W_Type.indicator.L2) + "]");
#endif
                    Print("W trend Buy Limit Succedd!");
                }
                else
                {
                    Print("W trend Buy Limit Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                }
            }
            else
            {
                //do nothing
            }
        }
        else
        {
            //選擇上一筆開單Ticket Number
            if (OrderSelect(wTypeOrderInfo.order_number, SELECT_BY_TICKET, MODE_TRADES))
            {
                //關單時間不為0，即表示此單已經觸發止盈或止損，移動止盈
                if (OrderCloseTime() != 0)
                {
                    wTypeOrderInfo.open_trade_flag = false;

                    //開啟移動止盈、前單盈利為正且未達止盈次數，持續移動H2及L2點位，若觸發H2高於H1，重新計算H1
                    if (wTypeOrderInfo.moving_switch && OrderProfit() > 0 && Close[N0_TICK] < W_Type.price.H1 * 1 && moving_time < wTypeOrderInfo.moving_time)
                    {
                        ObjectMove(ChartID(), "W_TrendLine_H2", 0, Time[N1_TICK], Close[N1_TICK]);
                        ObjectMove(ChartID(), "W_TrendLine_H2", 1, Time[N1_TICK + 3], Close[N1_TICK]);
                        W_Type.price.H2 = Close[N1_TICK];
                        W_Type.price.L2 = 0;
                        stateMachine = H2_OPEN;
                        moving_time++;
                        Print("W trend Moving Take Profit! [" + IntegerToString(moving_time) + "] times");
                        break;
                    }
                    else
                    {
                        ObjectMove(ChartID(), "W_TrendLine_H1", 0, Time[N1_TICK], Close[N1_TICK]);
                        ObjectMove(ChartID(), "W_TrendLine_H1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
                        W_Type.price.H1 = Close[N1_TICK];
                        W_Type.price.L1 = 0;
                        W_Type.price.H2 = 0;
                        W_Type.price.L2 = 0;
                        stateMachine = H1_OPEN;
                        break;
                    }
                }
                else
                {
                    //開啟強制平倉功能
                    if (wTypeOrderInfo.profit_switch == true)
                    {
                        //浮虧強制平倉
                        if (OrderProfit() < -1 * wTypeOrderInfo.max_loss)
                        {
                            //達到用戶設定強平浮虧
                            if (OrderClose(wTypeOrderInfo.order_number, wTypeOrderInfo.open_lots, Bid, wTypeOrderInfo.slippage, CLR_NONE))
                            {
                                wTypeOrderInfo.open_trade_flag = false;
                                ObjectMove(ChartID(), "W_TrendLine_H1", 0, Time[N1_TICK], Close[N1_TICK]);
                                ObjectMove(ChartID(), "W_TrendLine_H1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
                                W_Type.price.H1 = Close[N1_TICK];
                                W_Type.price.L1 = 0;
                                W_Type.price.H2 = 0;
                                W_Type.price.L2 = 0;
                                stateMachine = H1_OPEN;
                                Print("W trend Close order [" + IntegerToString(wTypeOrderInfo.order_number) + "] forcely!");
                                break;
                            }
                            else
                            {
                                Print("W trend Stop Loss to Close order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                            }
                        }
                        else //浮盈強制平倉，暫無實現
                        {
                            //do nothing
                        }
                    }
                }
            }
            else
            {
                //若訂單號選擇失敗，可能為人為手動關倉或曾關閉EA，此時關閉所有訂單及掛單
                Print("W trend Select Order Number Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                Print("Start to Close all Order!");
                for (int index = 0; index < OrdersTotal(); index++)
                {
                    if (OrderSelect(index, SELECT_BY_POS, MODE_TRADES))
                    {
                        switch (OrderType())
                        {
                        case OP_BUY:
                            if (OrderClose(OrderTicket(), OrderLots(), Bid, mTypeOrderInfo.slippage, CLR_NONE) == false)
                                Print("Close Order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                            break;
                        case OP_SELL:
                            if (OrderClose(OrderTicket(), OrderLots(), Ask, wTypeOrderInfo.slippage, CLR_NONE) == false)
                                Print("Close Order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                            break;
                        case OP_BUYLIMIT:
                        case OP_BUYSTOP:
                        case OP_SELLLIMIT:
                        case OP_SELLSTOP:
                            if (OrderDelete(OrderTicket(), CLR_NONE) == false)
                                Print("Close Order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                            break;
                        default:
                            Print("Order Type Error!");
                            break;
                        }
                    }
                    else
                    {
                        //finish to close all orders on market or pending
                    }
                }
                Print("End to Close all Order!");
            }
        }

        //處理趨勢破壞反向單
        if (SL_REV_SWITCH == true)
        {
            if (wTypeOrderInfo.open_trade_rev_flag == false)
            {
                if (Close[N1_TICK] < (W_Type.price.H2 - (W_Type.price.H2 - W_Type.price.L2) / 2) && wTypeOrderInfo.open_trade_flag == true && (iMA(Symbol(), wTypeOrderInfo.time_period, 5, 0, MODE_SMA, PRICE_CLOSE, N1_TICK) < iMA(Symbol(), wTypeOrderInfo.time_period, 20, 0, MODE_SMA, PRICE_CLOSE, N1_TICK)))
                {
                    //反向空單，觸及H2止損或均線交叉，觸及L1止盈或是均線交叉
                    wTypeOrderInfo.order_number_rev = OrderSend(Symbol(), OP_SELL, wTypeOrderInfo.rev_open_lots, Bid, wTypeOrderInfo.slippage, W_Type.price.H2, W_Type.price.L1, NULL, wTypeOrderInfo.rev_magic_number, 0, CLR_NONE);

                    if (wTypeOrderInfo.order_number_rev != 0)
                    {
                        wTypeOrderInfo.open_trade_rev_flag = true;
                        Print("W trend Sell Limit Succedd!");
                    }
                    else
                    {
                        Print("W trend Sell Limit Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                    }
                }
                else
                {
                    //do nothing
                }
            }
            else
            {
                if (OrderSelect(wTypeOrderInfo.order_number_rev, SELECT_BY_TICKET, MODE_TRADES))
                {
                    //關單時間不為0，即表示此單已經觸發止盈或止損，關閉反向單信號
                    if (OrderCloseTime() != 0)
                    {
                        wTypeOrderInfo.open_trade_rev_flag = false;
                    }
                    else
                    {
                        //反向空單尚未關閉，確認W底多單是否關閉、或著均線突破，則關閉反向空單
                        if (wTypeOrderInfo.open_trade_flag == false || (iMA(Symbol(), wTypeOrderInfo.time_period, 5, 0, MODE_SMA, PRICE_CLOSE, N1_TICK) > iMA(Symbol(), wTypeOrderInfo.time_period, 20, 0, MODE_SMA, PRICE_CLOSE, N1_TICK)))
                        {
                            if (OrderClose(wTypeOrderInfo.order_number_rev, wTypeOrderInfo.rev_open_lots, Ask, wTypeOrderInfo.slippage, CLR_NONE))
                            {
                                wTypeOrderInfo.open_trade_rev_flag = false;
                                Print("W trend Close order [" + IntegerToString(wTypeOrderInfo.order_number_rev) + "] forcely!");
                            }
                            else
                            {
                                Print("W trend Stop Loss to Close order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                            }
                        }
                        else
                        {
                            //do nothing
                        }
                    }
                }
                else
                {
                    //若訂單號選擇失敗，可能為人為手動關倉或曾關閉EA，此時關閉所有訂單及掛單
                    Print("Reverse W trend Select Order Number Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                    Print("Start to Close all Order!");
                    for (int index = 0; index < OrdersTotal(); index++)
                    {
                        if (OrderSelect(index, SELECT_BY_POS, MODE_TRADES))
                        {
                            switch (OrderType())
                            {
                            case OP_BUY:
                                if (OrderClose(OrderTicket(), OrderLots(), Bid, mTypeOrderInfo.slippage, CLR_NONE) == false)
                                    Print("Close Order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                                break;
                            case OP_SELL:
                                if (OrderClose(OrderTicket(), OrderLots(), Ask, wTypeOrderInfo.slippage, CLR_NONE) == false)
                                    Print("Close Order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                                break;
                            case OP_BUYLIMIT:
                            case OP_BUYSTOP:
                            case OP_SELLLIMIT:
                            case OP_SELLSTOP:
                                if (OrderDelete(OrderTicket(), CLR_NONE) == false)
                                    Print("Close Order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                                break;
                            default:
                                Print("Order Type Error!");
                                break;
                            }
                        }
                        else
                        {
                            //finish to close all orders on market or pending
                        }
                    }
                    Print("End to Close all Order!");
                }
            }
        }
        else
        {
            //do nothing
        }
        break;
    }
}

void processMTypeTrend(void)
{
    //m型態點位建立順序 L1->H1->L2->H2->Open
    static int stateMachine = L1_OPEN;
    static x_type M_Type;
    static int moving_time = 0;

    switch (stateMachine)
    {
    case L1_OPEN:
        //當前為獲取L1價格區間，隱藏其餘趨勢線
        ObjectSet("M_TrendLine_H1", OBJPROP_WIDTH, 0);
        ObjectSet("M_TrendLine_L2", OBJPROP_WIDTH, 0);
        ObjectSet("M_TrendLine_H2", OBJPROP_WIDTH, 0);

        //清除交易信號
        mTypeOrderInfo.open_trade_flag = false;
        mTypeOrderInfo.open_trade_rev_flag = false;
        moving_time = 0;

        //若，[N-1]收盤價 小於等於 [N-2]收盤價，L1價格向下更新為[N-1]收盤價
        //若，[N-1]收盤價 大於 [N-2]收盤價，找到最低價格L1為[N-2]收盤價
        if (Close[N1_TICK] <= Close[N2_TICK])
        {
            ObjectMove(ChartID(), "M_TrendLine_L1", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "M_TrendLine_L1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            M_Type.price.L1 = Close[N1_TICK];
        }
        else if (Close[N1_TICK] > Close[N2_TICK])
        {
            ObjectMove(ChartID(), "M_TrendLine_L1", 0, Time[N2_TICK], Close[N2_TICK]);
            ObjectMove(ChartID(), "M_TrendLine_L1", 1, Time[N2_TICK + 3], Close[N2_TICK]);
            M_Type.price.L1 = Close[N2_TICK];
            M_Type.volume.L1 = iVolume(Symbol(), mTypeOrderInfo.time_period, N2_TICK);
            M_Type.indicator.L1 = iMACD(Symbol(), mTypeOrderInfo.time_period, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, N2_TICK);
            stateMachine = H1_OPEN;
#ifdef DEBUG_MESSAGE
            Print("M trend L1 price has found! [" + DoubleToString(M_Type.price.L1) + "]");
#endif
        }
        else
        {
            //do nothing
        }
        break;
    case H1_OPEN:
        //當前為獲取H1價格區間，顯示H1趨勢線
        ObjectSet("M_TrendLine_H1", OBJPROP_WIDTH, 10);
        ObjectSet("M_TrendLine_L2", OBJPROP_WIDTH, 0);
        ObjectSet("M_TrendLine_H2", OBJPROP_WIDTH, 0);

        //若，[N-1]收盤價 小於 L1收盤價，即表示趨勢被跌破，重新計算並繪製L1為[N-1]收盤價
        if (Close[N1_TICK] < M_Type.price.L1)
        {
            ObjectMove(ChartID(), "M_TrendLine_L1", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "M_TrendLine_L1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            M_Type.price.L1 = Close[N1_TICK];
            M_Type.price.H1 = 0;
            stateMachine = L1_OPEN;
            break;
        }

        //若，[N-1]收盤價 小於等於 [N-2]收盤價，找到最高價格H1為[N-2]收盤價
        //若，[N-1]收盤價 大於 [N-2]收盤價，H1價格向上更新為[N-1]收盤價
        if (Close[N1_TICK] <= Close[N2_TICK])
        {
            ObjectMove(ChartID(), "M_TrendLine_H1", 0, Time[N2_TICK], Close[N2_TICK]);
            ObjectMove(ChartID(), "M_TrendLine_H1", 1, Time[N2_TICK + 3], Close[N2_TICK]);
            M_Type.price.H1 = Close[N2_TICK];
            M_Type.volume.H1 = iVolume(Symbol(), mTypeOrderInfo.time_period, N2_TICK);
            M_Type.indicator.H1 = iMACD(Symbol(), mTypeOrderInfo.time_period, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, N2_TICK);
            stateMachine = L2_OPEN;
#ifdef DEBUG_MESSAGE
            Print("M trens H1 price has found! [" + DoubleToString(M_Type.price.H1) + "]");
#endif
        }
        else if (Close[N1_TICK] > Close[N2_TICK])
        {
            ObjectMove(ChartID(), "M_TrendLine_H1", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "M_TrendLine_H1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            M_Type.price.H1 = Close[N1_TICK];
        }
        else
        {
            //do nothing
        }
        break;
    case L2_OPEN:
        //當前為獲取L2價格區間，顯示L2趨勢線
        ObjectSet("M_TrendLine_H1", OBJPROP_WIDTH, 10);
        ObjectSet("M_TrendLine_L2", OBJPROP_WIDTH, 10);
        ObjectSet("M_TrendLine_H2", OBJPROP_WIDTH, 0);

        //若，[N-1]收盤價 小於 L1收盤價，即表示趨勢被跌破，重新計算並繪製L1為[N-1]收盤價
        if (Close[N1_TICK] < M_Type.price.L1)
        {
            ObjectMove(ChartID(), "M_TrendLine_L1", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "M_TrendLine_L1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            M_Type.price.L1 = Close[N1_TICK];
            M_Type.price.H1 = 0;
            M_Type.price.L2 = 0;
            stateMachine = L1_OPEN;
            break;
        }

        //若，[N-1]收盤價 大於 H1收盤價，即表示趨勢被突破，重新計算並繪製H1為[N-1]收盤價
        if (Close[N1_TICK] > M_Type.price.H1)
        {
            ObjectMove(ChartID(), "M_TrendLine_H1", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "M_TrendLine_H1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            M_Type.price.H1 = Close[N1_TICK];
            M_Type.price.L2 = 0;
            stateMachine = H1_OPEN;
            break;
        }

        //若，[N-1]收盤價 大於 [N-2]收盤價，找到次低價格L2為[N-2]收盤價
        //若，[N-1]收盤價 小於等於 [N-2]收盤價，L2價格向下更新為[N-1]收盤價
        if (Close[N1_TICK] > Close[N2_TICK])
        {
            ObjectMove(ChartID(), "M_TrendLine_L2", 0, Time[N2_TICK], Close[N2_TICK]);
            ObjectMove(ChartID(), "M_TrendLine_L2", 1, Time[N2_TICK + 3], Close[N2_TICK]);
            M_Type.price.L2 = Close[N2_TICK];
            M_Type.volume.L2 = iVolume(Symbol(), mTypeOrderInfo.time_period, N2_TICK);
            M_Type.indicator.L2 = iMACD(Symbol(), mTypeOrderInfo.time_period, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, N2_TICK);
            stateMachine = H2_OPEN;

#ifdef DEBUG_MESSAGE
            Print("M trend L2 price has found! [" + DoubleToString(M_Type.price.L2) + "]");
#endif
        }
        else if (Close[N1_TICK] <= Close[N2_TICK])
        {
            ObjectMove(ChartID(), "M_TrendLine_L2", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "M_TrendLine_L2", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            M_Type.price.L2 = Close[N1_TICK];
        }
        else
        {
            //do nothing
        }
        break;
    case H2_OPEN:
        //當前為獲取H2價格區間，顯示H2趨勢線
        ObjectSet("M_TrendLine_H1", OBJPROP_WIDTH, 10);
        ObjectSet("M_TrendLine_L2", OBJPROP_WIDTH, 10);
        ObjectSet("M_TrendLine_H2", OBJPROP_WIDTH, 10);

        //若，[N-1]收盤價 小於 L2收盤價，即表示趨勢被跌破，重新計算並繪製L2為[N-1]收盤價
        if (Close[N1_TICK] < M_Type.price.L2)
        {
            ObjectMove(ChartID(), "M_TrendLine_L2", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "M_TrendLine_L2", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            M_Type.price.L2 = Close[N1_TICK];
            M_Type.price.H2 = 0;
            stateMachine = L2_OPEN;
            break;
        }

        //若，[N-1]收盤價 大於 H1收盤價，即表示趨勢被突破，重新計算並繪製H1為[N-1]收盤價
        if (Close[N1_TICK] > M_Type.price.H1)
        {
            ObjectMove(ChartID(), "M_TrendLine_H1", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "M_TrendLine_H1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            M_Type.price.H1 = Close[N1_TICK];
            M_Type.price.L2 = 0;
            M_Type.price.H2 = 0;
            stateMachine = H1_OPEN;
            break;
        }

        //若，[N-1]收盤價 小於等於 [N-2]收盤價，找到次高價格H2為[N-2]收盤價
        //若，[N-1]收盤價 大於 [N-2]收盤價，H2價格向上更新為[N-1]收盤價
        if (Close[N1_TICK] <= Close[N2_TICK])
        {
            ObjectMove(ChartID(), "M_TrendLine_H2", 0, Time[N2_TICK], Close[N2_TICK]);
            ObjectMove(ChartID(), "M_TrendLine_H2", 1, Time[N2_TICK + 3], Close[N2_TICK]);
            M_Type.price.H2 = Close[N2_TICK];
            M_Type.volume.H2 = iVolume(Symbol(), mTypeOrderInfo.time_period, N2_TICK);
            M_Type.indicator.H2 = iMACD(Symbol(), mTypeOrderInfo.time_period, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, N2_TICK);
            stateMachine = TRADE_OPEN;

#ifdef DEBUG_MESSAGE
            Print("M trend H2 price has found! [" + DoubleToString(M_Type.price.H2) + "]");
#endif
        }
        else if (Close[N1_TICK] > Close[N2_TICK])
        {
            ObjectMove(ChartID(), "M_TrendLine_H2", 0, Time[N1_TICK], Close[N1_TICK]);
            ObjectMove(ChartID(), "M_TrendLine_H2", 1, Time[N1_TICK + 3], Close[N1_TICK]);
            M_Type.price.H2 = Close[N1_TICK];
        }
        else
        {
            //do nothing
        }
        break;
    case TRADE_OPEN:
        if (mTypeOrderInfo.open_trade_flag == false)
        {
            //開單限制導致無法開單，並順勢跌破L2-(H2 - L2)或L2時，退回至相應狀態
            if (Close[N1_TICK] < (M_Type.price.L2 - (M_Type.price.H2 - M_Type.price.L2)))
            {
                ObjectMove(ChartID(), "M_TrendLine_L2", 0, Time[N1_TICK], Close[N1_TICK]);
                ObjectMove(ChartID(), "M_TrendLine_L2", 1, Time[N1_TICK + 3], Close[N1_TICK]);
                M_Type.price.L2 = Close[N1_TICK];
                stateMachine = L2_OPEN;
                break;
            }
            if (Close[N1_TICK] > M_Type.price.H2)
            {
                ObjectMove(ChartID(), "M_TrendLine_H2", 0, Time[N1_TICK], Close[N1_TICK]);
                ObjectMove(ChartID(), "M_TrendLine_H2", 1, Time[N1_TICK + 3], Close[N1_TICK]);
                M_Type.price.H2 = Close[N1_TICK];
                stateMachine = H2_OPEN;
                break;
            }

            //M頭趨勢成形，近兩根K棒跌破H2、當下無W底多單開倉、且點差小於設定
            if (Close[N1_TICK] <= M_Type.price.L2 && Close[N2_TICK] <= M_Type.price.L2 && wTypeOrderInfo.open_trade_flag == false && SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) <= mTypeOrderInfo.spread)
            {
                //在此以市價開單，止盈設在X倍(L2 - [H2]-[L2])，止損設在H2

                if (M_Type.volume.H2 > M_Type.volume.L2 && M_Type.volume.H1 > M_Type.volume.H2)
                    mTypeOrderInfo.order_number = OrderSend(Symbol(), OP_SELL, mTypeOrderInfo.open_lots * 2, Bid, mTypeOrderInfo.slippage, M_Type.price.H2, Bid - (M_Type.price.H2 - M_Type.price.L2) * mTypeOrderInfo.profit_rate, NULL, mTypeOrderInfo.magic_number, 0, CLR_NONE);
                else
                    mTypeOrderInfo.order_number = OrderSend(Symbol(), OP_SELL, mTypeOrderInfo.open_lots, Bid, mTypeOrderInfo.slippage, M_Type.price.H2, Bid - (M_Type.price.H2 - M_Type.price.L2) * mTypeOrderInfo.profit_rate, NULL, mTypeOrderInfo.magic_number, 0, CLR_NONE);

                if (mTypeOrderInfo.order_number != -1)
                {
                    mTypeOrderInfo.open_trade_flag = true;

                    /*
                    Print("L1 Price ["+DoubleToString(M_Type.price.L1)+"] L1 Sup. ["+DoubleToString(M_Type.volume.L1)+"]");
                    Print("H1 Price ["+DoubleToString(M_Type.price.H1)+"] H1 Res. ["+DoubleToString(M_Type.volume.H1)+"]");
                    Print("L2 Price ["+DoubleToString(M_Type.price.L2)+"] L2 Sup. ["+DoubleToString(M_Type.volume.L2)+"]");
                    Print("H2 Price ["+DoubleToString(M_Type.price.H2)+"] H2 Res. ["+DoubleToString(M_Type.volume.H2)+"]");
                    */

                    Print("L1 Price [" + DoubleToString(M_Type.price.L1) + "] L1 MACD. [" + DoubleToString(M_Type.indicator.L1) + "]");
                    Print("H1 Price [" + DoubleToString(M_Type.price.H1) + "] H1 MACD. [" + DoubleToString(M_Type.indicator.H1) + "]");
                    Print("L2 Price [" + DoubleToString(M_Type.price.L2) + "] L2 MACD. [" + DoubleToString(M_Type.indicator.L2) + "]");
                    Print("H2 Price [" + DoubleToString(M_Type.price.H2) + "] H2 MACD. [" + DoubleToString(M_Type.indicator.H2) + "]");

                    Print("M trend Sell Limit Succedd!");
                }
                else
                {
                    Print("M trend Sell Limit Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                }
            }
            else
            {
                //do nothing
            }
        }
        else
        {
            //選擇上一筆開單Ticket Number
            if (OrderSelect(mTypeOrderInfo.order_number, SELECT_BY_TICKET, MODE_TRADES))
            {
                //關單時間不為0，即表示此單已經觸發止盈或止損，移動止盈
                if (OrderCloseTime() != 0)
                {
                    mTypeOrderInfo.open_trade_flag = false;

                    //開啟移動止盈、前單盈利為正且未達止盈次數，持續移動L2及H2點位，若觸發L2高於L1，重新計算L1
                    if (mTypeOrderInfo.moving_switch && OrderProfit() > 0 && Close[N0_TICK] > M_Type.price.L1 * 1 && moving_time < mTypeOrderInfo.moving_time)
                    {
                        ObjectMove(ChartID(), "M_TrendLine_L2", 0, Time[N1_TICK], Close[N1_TICK]);
                        ObjectMove(ChartID(), "M_TrendLine_L2", 1, Time[N1_TICK + 3], Close[N1_TICK]);
                        M_Type.price.L2 = Close[N1_TICK];
                        M_Type.price.H2 = 0;
                        stateMachine = L2_OPEN;
                        moving_time++;
                        Print("M trend Moving Take Profit! [" + IntegerToString(moving_time) + "] times");
                        break;
                    }
                    else
                    {
                        ObjectMove(ChartID(), "M_TrendLine_L1", 0, Time[N1_TICK], Close[N1_TICK]);
                        ObjectMove(ChartID(), "M_TrendLine_L1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
                        M_Type.price.L1 = Close[N1_TICK];
                        M_Type.price.H1 = 0;
                        M_Type.price.L2 = 0;
                        M_Type.price.H2 = 0;
                        stateMachine = L1_OPEN;
                        break;
                    }
                }
                else
                {
                    //開啟強制平倉功能
                    if (mTypeOrderInfo.profit_switch == true)
                    {
                        //浮虧強制平倉
                        if (OrderProfit() < -1 * mTypeOrderInfo.max_loss)
                        {
                            //達到用戶設定強平浮虧
                            if (OrderClose(mTypeOrderInfo.order_number, mTypeOrderInfo.open_lots, Ask, mTypeOrderInfo.slippage, CLR_NONE))
                            {
                                mTypeOrderInfo.open_trade_flag = false;
                                ObjectMove(ChartID(), "M_TrendLine_L1", 0, Time[N1_TICK], Close[N1_TICK]);
                                ObjectMove(ChartID(), "M_TrendLine_L1", 1, Time[N1_TICK + 3], Close[N1_TICK]);
                                M_Type.price.L1 = Close[N1_TICK];
                                M_Type.price.H1 = 0;
                                M_Type.price.L2 = 0;
                                M_Type.price.H2 = 0;
                                stateMachine = L1_OPEN;
                                Print("M trend Close order [" + IntegerToString(mTypeOrderInfo.order_number) + "] forcely!");
                                break;
                            }
                            else
                            {
                                //do nothing
                            }
                        }
                        else //浮盈強制平倉，暫無實現
                        {
                            //do nothing
                        }
                    }
                }
            }
            else
            {
                //若訂單號選擇失敗，可能為人為手動關倉或曾關閉EA，此時關閉所有訂單及掛單
                Print("M trend Select Order Number Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                Print("Start to Close all Order!");
                for (int index = 0; index < OrdersTotal(); index++)
                {
                    if (OrderSelect(index, SELECT_BY_POS, MODE_TRADES))
                    {
                        switch (OrderType())
                        {
                        case OP_BUY:
                            if (OrderClose(OrderTicket(), OrderLots(), Bid, mTypeOrderInfo.slippage, CLR_NONE) == false)
                                Print("Close Order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                            break;
                        case OP_SELL:
                            if (OrderClose(OrderTicket(), OrderLots(), Ask, wTypeOrderInfo.slippage, CLR_NONE) == false)
                                Print("Close Order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                            break;
                        case OP_BUYLIMIT:
                        case OP_BUYSTOP:
                        case OP_SELLLIMIT:
                        case OP_SELLSTOP:
                            if (OrderDelete(OrderTicket(), CLR_NONE) == false)
                                Print("Close Order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                            break;
                        }
                    }
                    else
                    {
                        //finish to close all orders on market or pending
                    }
                }
                Print("End to Close all Order!");
            }
        }

        //處理趨勢破壞反向單
        if (SL_REV_SWITCH == true)
        {
            if (mTypeOrderInfo.open_trade_rev_flag == false)
            {
                if (Close[N1_TICK] > (M_Type.price.L2 + (M_Type.price.H2 - M_Type.price.L2) / 2) && mTypeOrderInfo.open_trade_flag == true && (iMA(Symbol(), mTypeOrderInfo.time_period, 5, 0, MODE_SMA, PRICE_CLOSE, N1_TICK) > iMA(Symbol(), mTypeOrderInfo.time_period, 20, 0, MODE_SMA, PRICE_CLOSE, N1_TICK)))
                {
                    //反向多單，觸及L2止損或均線交叉，觸及H1止盈或是均線交叉
                    mTypeOrderInfo.order_number_rev = OrderSend(Symbol(), OP_BUY, mTypeOrderInfo.rev_open_lots, Ask, mTypeOrderInfo.slippage, M_Type.price.L2, M_Type.price.H1, NULL, mTypeOrderInfo.rev_magic_number, 0, CLR_NONE);

                    if (mTypeOrderInfo.order_number_rev != 0)
                    {
                        mTypeOrderInfo.open_trade_rev_flag = true;
                        Print("M trend Buy Limit Succedd!");
                    }
                    else
                    {
                        Print("M trend Buy Limit Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                    }
                }
                else
                {
                    //do nothing
                }
            }
            else
            {
                if (OrderSelect(mTypeOrderInfo.order_number_rev, SELECT_BY_TICKET, MODE_TRADES))
                {
                    //關單時間不為0，即表示此單已經觸發止盈或止損，關閉反向單信號
                    if (OrderCloseTime() != 0)
                    {
                        mTypeOrderInfo.open_trade_rev_flag = false;
                    }
                    else
                    {
                        //反向多單尚未關閉，確認M頭空單是否關閉、或著均線跌破，則關閉反向多單
                        if (mTypeOrderInfo.open_trade_flag == false || (iMA(Symbol(), mTypeOrderInfo.time_period, 5, 0, MODE_SMA, PRICE_CLOSE, N1_TICK) < iMA(Symbol(), mTypeOrderInfo.time_period, 20, 0, MODE_SMA, PRICE_CLOSE, N1_TICK)))
                        {
                            if (OrderClose(mTypeOrderInfo.order_number_rev, mTypeOrderInfo.rev_open_lots, Bid, mTypeOrderInfo.slippage, CLR_NONE))
                            {
                                mTypeOrderInfo.open_trade_rev_flag = false;
                                Print("M trend Close order [" + IntegerToString(mTypeOrderInfo.order_number_rev) + "] forcely!");
                            }
                            else
                            {
                            }
                        }
                        else
                        {
                        }
                    }
                }
                else
                {
                    //若訂單號選擇失敗，可能為人為手動關倉或曾關閉EA，此時關閉所有訂單及掛單
                    Print("Reverse M trend Select Order Number Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                    Print("Start to Close all Order!");
                    for (int index = 0; index < OrdersTotal(); index++)
                    {
                        if (OrderSelect(index, SELECT_BY_POS, MODE_TRADES))
                        {
                            switch (OrderType())
                            {
                            case OP_BUY:
                                if (OrderClose(OrderTicket(), OrderLots(), Bid, mTypeOrderInfo.slippage, CLR_NONE) == false)
                                    Print("Close Order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                                break;
                            case OP_SELL:
                                if (OrderClose(OrderTicket(), OrderLots(), Ask, wTypeOrderInfo.slippage, CLR_NONE) == false)
                                    Print("Close Order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                                break;
                            case OP_BUYLIMIT:
                            case OP_BUYSTOP:
                            case OP_SELLLIMIT:
                            case OP_SELLSTOP:
                                if (OrderDelete(OrderTicket(), CLR_NONE) == false)
                                    Print("Close Order Fail! Error Code [" + IntegerToString(GetLastError()) + "]");
                                break;
                            }
                        }
                        else
                        {
                            //finish to close all orders on market or pending
                        }
                    }
                    Print("End to Close all Order!");
                }
            }
        }
        else
        {
            //do nothing
        }
        break;
    }
}

void processIndicator(void)
{
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // 帳戶使用限制：只允許特定帳戶號碼，除非是模擬帳戶
    if (AccountNumber() != ACCOUNT_NUM && ACCOUNT_TRADE_MODE_DEMO != AccountInfoInteger(ACCOUNT_TRADE_MODE))
    {
        Print("This EA is restricted to account number " + IntegerToString(ACCOUNT_NUM) + ". Please contact support.");
        return(INIT_FAILED);
    }

    //超過有效時效
    if (TimeCurrent() > LMT_TIME)
    {
        Print("EA has expired. Please contact support.");
        return(INIT_FAILED);
    }

    //獲取服務器及本地時間並顯示
    string serverTime = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
    string localTime = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES);
    Comment("\n\nServer Time: ", serverTime, "\n\n  Local Time: ", localTime);

    //初始化w型態訂單資訊
    initXTypeOrderInfo(wTypeOrderInfo);

    //初始化m型態訂單資訊
    initXTypeOrderInfo(mTypeOrderInfo);

    //修改顯示為K棒
    if (ChartSetInteger(ChartID(), CHART_MODE, CHART_TYPE))
        Print("Modify Chart Mode Success!");
    else
        Print("Modify Chart Mode Fail. Error Code [" + IntegerToString(GetLastError()) + "]");

    //修改時間週期
    if (ChartSetSymbolPeriod(ChartID(), Symbol(), wTypeOrderInfo.time_period))
        Print("Modify Time Period Success!");
    else
        Print("Modify Time Period Fail. Error Code [" + IntegerToString(GetLastError()) + "]");

    //修改時間顯示比例
    if (ChartSetInteger(ChartID(), CHART_SCALE, 0, TIME_SCALE))
        Print("Modify Chart Scale Success!");
    else
        Print("Modify Chart Scale Fail. Error Code [" + IntegerToString(GetLastError()) + "]");

    //計算當前畫面中所有K棒數量
    int BarsNum = WindowBarsPerChart();

    //當前圖表中收盤最高價格
    int valH_index = iHighest(Symbol(), wTypeOrderInfo.time_period, MODE_CLOSE, BarsNum);
    double valH = High[valH_index];

    //當前圖表中影線最低價格
    int valL_index = iLowest(Symbol(), wTypeOrderInfo.time_period, MODE_LOW, BarsNum);
    double valL = Low[valL_index];

    //繪製最高價格壓力線Resistance Line
    ObjectCreate(ChartID(), "HLine_RL", OBJ_HLINE, 0, NULL, valH);
    ObjectSetInteger(ChartID(), "HLine_RL", OBJPROP_COLOR, clrAquamarine);
    ObjectSetInteger(ChartID(), "HLine_RL", OBJPROP_WIDTH, 3);

    //繪製最低價格支撐線Support Line
    ObjectCreate(ChartID(), "HLine_SL", OBJ_HLINE, 0, NULL, valL);
    ObjectSetInteger(ChartID(), "HLine_SL", OBJPROP_COLOR, clrAquamarine);
    ObjectSetInteger(ChartID(), "HLine_SL", OBJPROP_WIDTH, 3);

    //繪製上通道趨勢線(H1_H2)
    ObjectCreate(ChartID(), "TrendLine_UpTunnel", OBJ_TREND, 0, Time[valH_index], valH, Time[valL_index], valL);
    ObjectSetInteger(ChartID(), "TrendLine_UpTunnel", OBJPROP_COLOR, clrDarkTurquoise);
    ObjectSetInteger(ChartID(), "TrendLine_UpTunnel", OBJPROP_WIDTH, 3);
    ObjectSetInteger(ChartID(), "TrendLine_UpTunnel", OBJPROP_RAY, false);

    //繪製下通道趨勢線(L1_L2)
    ObjectCreate(ChartID(), "TrendLine_DownTunnel", OBJ_TREND, 0, Time[valH_index], valH, Time[valL_index], valL);
    ObjectSetInteger(ChartID(), "TrendLine_DownTunnel", OBJPROP_COLOR, clrDarkTurquoise);
    ObjectSetInteger(ChartID(), "TrendLine_DownTunnel", OBJPROP_WIDTH, 3);
    ObjectSetInteger(ChartID(), "TrendLine_DownTunnel", OBJPROP_RAY, false);

    //繪製H1 W趨勢線及壓力指示
    ObjectCreate(ChartID(), "W_TrendLine_H1", OBJ_TREND, 0, Time[valH_index], valH, Time[valH_index], valH);
    ObjectSetInteger(ChartID(), "W_TrendLine_H1", OBJPROP_COLOR, clrRed);
    ObjectSetInteger(ChartID(), "W_TrendLine_H1", OBJPROP_WIDTH, 10);
    ObjectSetInteger(ChartID(), "W_TrendLine_H1", OBJPROP_RAY, false);

    //繪製L1 W趨勢線及支撐指示
    ObjectCreate(ChartID(), "W_TrendLine_L1", OBJ_TREND, 0, Time[valL_index], valL, Time[valL_index], valL);
    ObjectSetInteger(ChartID(), "W_TrendLine_L1", OBJPROP_COLOR, clrChartreuse);
    ObjectSetInteger(ChartID(), "W_TrendLine_L1", OBJPROP_WIDTH, 10);
    ObjectSetInteger(ChartID(), "W_TrendLine_L1", OBJPROP_RAY, false);

    //繪製H2 W趨勢線及壓力指示
    ObjectCreate(ChartID(), "W_TrendLine_H2", OBJ_TREND, 0, Time[valL_index], valL, Time[valL_index], valL);
    ObjectSetInteger(ChartID(), "W_TrendLine_H2", OBJPROP_COLOR, clrTomato);
    ObjectSetInteger(ChartID(), "W_TrendLine_H2", OBJPROP_WIDTH, 10);
    ObjectSetInteger(ChartID(), "W_TrendLine_H2", OBJPROP_RAY, false);

    //繪製L2 W趨勢線及支撐指示
    ObjectCreate(ChartID(), "W_TrendLine_L2", OBJ_TREND, 0, Time[valL_index], valL, Time[valL_index], valL);
    ObjectSetInteger(ChartID(), "W_TrendLine_L2", OBJPROP_COLOR, clrSpringGreen);
    ObjectSetInteger(ChartID(), "W_TrendLine_L2", OBJPROP_WIDTH, 10);
    ObjectSetInteger(ChartID(), "W_TrendLine_L2", OBJPROP_RAY, false);

    //繪製H1 M趨勢線及壓力指示
    ObjectCreate(ChartID(), "M_TrendLine_H1", OBJ_TREND, 0, Time[valH_index], valH, Time[valH_index], valH);
    ObjectSetInteger(ChartID(), "M_TrendLine_H1", OBJPROP_COLOR, clrRed);
    ObjectSetInteger(ChartID(), "M_TrendLine_H1", OBJPROP_WIDTH, 10);
    ObjectSetInteger(ChartID(), "M_TrendLine_H1", OBJPROP_RAY, false);

    //繪製L1 M趨勢線及支撐指示
    ObjectCreate(ChartID(), "M_TrendLine_L1", OBJ_TREND, 0, Time[valL_index], valL, Time[valL_index], valL);
    ObjectSetInteger(ChartID(), "M_TrendLine_L1", OBJPROP_COLOR, clrChartreuse);
    ObjectSetInteger(ChartID(), "M_TrendLine_L1", OBJPROP_WIDTH, 10);
    ObjectSetInteger(ChartID(), "M_TrendLine_L1", OBJPROP_RAY, false);

    //繪製H2 M趨勢線及壓力指示
    ObjectCreate(ChartID(), "M_TrendLine_H2", OBJ_TREND, 0, Time[valL_index], valL, Time[valL_index], valL);
    ObjectSetInteger(ChartID(), "M_TrendLine_H2", OBJPROP_COLOR, clrTomato);
    ObjectSetInteger(ChartID(), "M_TrendLine_H2", OBJPROP_WIDTH, 10);
    ObjectSetInteger(ChartID(), "M_TrendLine_H2", OBJPROP_RAY, false);

    //繪製L2 M趨勢線及支撐指示
    ObjectCreate(ChartID(), "M_TrendLine_L2", OBJ_TREND, 0, Time[valL_index], valL, Time[valL_index], valL);
    ObjectSetInteger(ChartID(), "M_TrendLine_L2", OBJPROP_COLOR, clrSpringGreen);
    ObjectSetInteger(ChartID(), "M_TrendLine_L2", OBJPROP_WIDTH, 10);
    ObjectSetInteger(ChartID(), "M_TrendLine_L2", OBJPROP_RAY, false);

    return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Trend Breakout Strategy EA deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //設定時間內才執行交易策略
    if (wTypeOrderInfo.time_switch == true && IsWithinTimeRange(Hour(), Minute(), wTypeOrderInfo.start_time_hour, wTypeOrderInfo.start_time_min, wTypeOrderInfo.end_time_hour, wTypeOrderInfo.end_time_min) != true)
    {
        //do nothing, since time switch is enable and not in time setting
    }
    else
    {
        //判定交易型態
        switch (TRADE_TYPE)
        {
        case AUTO:
            processWTypeTrend();
            processMTypeTrend();
            break;
        case W_TYPE:
            processWTypeTrend();
            break;
        case M_TYPE:
            processMTypeTrend();
            break;
        }
    }

    //更新服務器及本地時間
    string serverTime = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
    string localTime = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES);
    Comment("\n\nServer Time: ", serverTime, "\n\n  Local Time: ", localTime);

    //計算當前畫面中所有K棒數量
    int BarsNum = WindowBarsPerChart();

    //當前圖表中收盤最高價格
    int valH_index = iHighest(Symbol(), wTypeOrderInfo.time_period, MODE_CLOSE, BarsNum);
    double valH = High[valH_index];

    //修改最高價格壓力線
    ObjectMove(ChartID(), "HLine_RL", 0, NULL, valH);

    //當前圖表中影線最低價格
    int valL_index = iLowest(Symbol(), wTypeOrderInfo.time_period, MODE_LOW, BarsNum);
    double valL = Low[valL_index];

    //修改最低價格支撐線
    ObjectMove(ChartID(), "HLine_SL", 0, NULL, valL);
}

//+------------------------------------------------------------------+