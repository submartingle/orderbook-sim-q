/========================================================================
/================     analysis         ==================================
/========================================================================
/📈 Spread curve	        Intraday avg spread (1-min bins)
/📊 Depth histogram	        Top-5 depth distribution
/📉 Quote duration chart	% of time spread stayed stable
/🧮 Backtest log	        Simulated passive orders with fill/cost
/📊 Heatmap	                Order book imbalance vs. slippage



rnd:{y*floor x%y}
OBstats:{[res]

	trades:select time,EventType,Size,Price from message where EventType in (4,5);
	avgTsize:exec avg Size from trades; /not the same as liquidity on the orderbook
	Tnum:count trades;
	TQ:select time, askprice_1,asksize_1,bidprice_1,bidsize_1,(ttype:EventType),(tsize:Size),(tprice:Price) from (res lj 1!trades);
	TQ:update wMid:((bidprice_1*bidsize_1) + askprice_1*asksize_1)%(bidsize_1 + asksize_1) from TQ;
	maxcst:value max select (wMid-tprice)%10000 from TQ where tprice>0, ttype=4;
	mincst:value min select (wMid-tprice)%10000 from TQ where tprice>0, ttype=4;
	
	
	maxSpr:0.0001*value max select avgSpread: avg(askprice_1 - bidprice_1) by 1 xbar time.minute from res;
	minSpr:0.0001*value min select avgSpread: avg(askprice_1 - bidprice_1) by 1 xbar time.minute from res;
	/`avgSpread xdesc select avgSpread: avg(askprice_1 - bidprice_1) by 1 xbar time.minute from `res;
	/observation:spread widest when market open 
	
	
	res:update Tbidsizes:(bidsize_1+bidsize_2+bidsize_3+bidsize_4+bidsize_5) from res;
	res:update Tasksizes:(asksize_1+asksize_2+asksize_3+asksize_4+asksize_5) from res;
	res:update Tvol:bidsize_1+bidsize_2+bidsize_3+bidsize_4+bidsize_5+asksize_1+asksize_2+asksize_3+asksize_4+asksize_5 from res;
	/select imbRatio: (Tbidsizes - Tasksizes)%Tvol from res
        resIMB:select imbRatio: (sum(Tbidsizes - Tasksizes))%sum(Tvol) by 10 xbar time.second from res;
	/The reduction in variance from snapshots to aggregated windows indicates liquidity imbalances are transient.
    :`num_trades`avgTradeSize`ExCostWMid_type4`avgTradeSpread_1m`imbalanceRatio_10s!(Tnum;avgTsize;(rnd[mincst;0.001],rnd[maxcst;0.001]);(minSpr,maxSpr);(rnd[value min resIMB;0.001],rnd[value max resIMB;0.001]))}

/measure percentage liquidity from each level of the book, bid and ask side,
Depth:{[tab] 
	asklst:`$("asksize_"),/: ("1";"2";"3";"4";"5");
	avgASK:(+/){?[x;();0b;(enlist y)!enlist (avg;y)]}[tab;] each asklst;
	bidlst:`$("bidsize_"),/: ("1";"2";"3";"4";"5");
	avgBID:(+/){?[x;();0b;(enlist y)!enlist (avg;y)]}[tab;] each bidlst;
	tmp:flip (avgASK%(sum avgASK[0]))+(avgBID%(sum avgBID[0]));
  :rnd[tmp;0.01]}

imbRatio:{[tab]
	tab:update Tbidsizes:(bidsize_1+bidsize_2+bidsize_3+bidsize_4+bidsize_5) from tab;
    tab:update Tasksizes:(asksize_1+asksize_2+asksize_3+asksize_4+asksize_5) from tab;
	tab:update Tvol:bidsize_1+bidsize_2+bidsize_3+bidsize_4+bidsize_5+asksize_1+asksize_2+asksize_3+asksize_4+asksize_5 from tab;
	:exec (Tbidsizes - Tasksizes)%Tvol from tab;
	}
