/ Entry point for the order book simulation.
/ Load order: ob_util -> ob_stats -> ob_replay -> ob_mosim -> this file
/ Usage: q refactored/ob_main.q

\l refactored/ob_util.q
\l refactored/ob_stats.q
\l refactored/ob_replay.q
\l refactored/ob_mosim.q

/ ============================================================
/ Data loading
/ ============================================================

MSG_FILE:"MSFT_2012-06-21_message_10.csv"
OB_FILE:"MSFT_2012-06-21_orderbook_10.csv"

tmp:("FISIJI";",") 0: hsym `$MSG_FILE
message:flip `time`EventType`OrderID`Size`Price`Direction!tmp

/ Load 6-level book: OB5 = top-5 levels used for replay; OB6 = 6th-level backfill data
d:(24#"JI";",") 0: hsym `$OB_FILE
OB_L6:flip (`$(raze ("askprice_";"asksize_";"bidprice_";"bidsize_"),\:/: string 1+til 6))!d
OB5:flip (20#cols OB_L6)!OB_L6[20#cols OB_L6]
OB6:flip (-4#cols OB_L6)!OB_L6[-4#cols OB_L6]

/ Load 10-level book for pre-trade depth snapshot in market order simulation
d:(40#"JI";",") 0: hsym `$OB_FILE
OB10:flip (`$(raze ("askprice_";"asksize_";"bidprice_";"bidsize_"),\:/: string 1+til 10))!d

l:count OB5
initBk:(`time,(key OB5@0))!((message[`time]@0),value OB5@0)

/ ============================================================
/ Order book replay
/ ============================================================

res:.replay.replayMessages[initBk;message;(l-1)#OB6]
update .util.sec2t time from `res
update .util.sec2t time from `message

/ ============================================================
/ Validation
/ ============================================================

checkOutput:((1_cols res)#res)[til l]~OB5[til l]
if[checkOutput; show "result matches with the LOBSTER orderbook"]

pricecols:cols[res] where cols[res] like "*price*"
if[null first where 10>({count distinct res[pricecols][;x]} each til count res); show "no duplicate in prices"]

sizecols:cols[res] where cols[res] like "*size*"
if[null first where ({sum 0>=distinct res[sizecols][;x]} each til count res); show "no 0 or negative in sizes"]

/ ============================================================
/ Statistics
/ ============================================================

show .stats.calcStats[message;res]
show .stats.calcDepth[res]

/ ============================================================
/ Market order simulation
/ ============================================================

N:50 / number of scenarios
tlist:`time$(first message[`time])+0D00:30:00.000000000+0D00:06:50.000000000*til N
qlist:15000+N?19000
bors:N?`buy`sell

/ Project data arguments; leaves (t;q;buysell) as free parameters for each scenario
scenarioFn:.sim.runScenario[message;OB5;OB6;OB10;;;]

\t iterRes:scenarioFn'[tlist;qlist;bors]

/ Filter out scenarios where recovery was not observed
validMask:not ('[any;null]) each iterRes
if[sum validMask;
    validRes:iterRes where validMask;
    recTime:validRes[;0];
    imbPre:validRes[;1];
    imbRec:validRes[;2];
    exP:validRes[;3];
    bestMP:validRes[;4];
    show sumT:flip `tradeTime`recTime`RecPeriod`quantity`BuySell`exePrice`bestMarket`imb_pre`imb_rec!
        (tlist where validMask;recTime;recTime-tlist where validMask;
         qlist where validMask;bors where validMask;exP;bestMP;imbPre;imbRec)]
