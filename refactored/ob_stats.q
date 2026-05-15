/ Order book analytics: imbalance, spread, depth, and execution cost metrics.
/ Depends on: ob_core.q (for .util.rnd and .util.PRICE_SCALE)

/ Order book imbalance ratio: (bid depth - ask depth) / total depth.
/ Accepts either a single-row dict or a table; returns scalar or vector accordingly.
.stats.imbRatio:{[tab]
    tab:update Tbidsizes:(bidsize_1+bidsize_2+bidsize_3+bidsize_4+bidsize_5),
               Tasksizes:(asksize_1+asksize_2+asksize_3+asksize_4+asksize_5) from tab;
    tab:update Tvol:Tbidsizes+Tasksizes from tab;
    :exec (Tbidsizes-Tasksizes)%Tvol from tab}

/ Aggregate order book statistics over a full replay result.
/ msgs: message table; res: replay result table
/ Returns a dict of key metrics.
.stats.calcStats:{[msgs;res]
    trades:select time,EventType,Size,Price from msgs where EventType in (4,5);
    Tnum:count trades;
    avgTsize:exec avg Size from trades;
    TQ:select time,askprice_1,asksize_1,bidprice_1,bidsize_1,(ttype:EventType),(tsize:Size),(tprice:Price) from (res lj 1!trades);
    TQ:update wMid:((bidprice_1*bidsize_1)+askprice_1*asksize_1)%(bidsize_1+asksize_1) from TQ;
    maxcst:value max select (wMid-tprice)%.util.PRICE_SCALE from TQ where tprice>0,ttype=4;
    mincst:value min select (wMid-tprice)%.util.PRICE_SCALE from TQ where tprice>0,ttype=4;
    spr:select avgSpread:avg(askprice_1-bidprice_1) by 1 xbar time.minute from res;
    maxSpr:0.0001*value max spr;
    minSpr:0.0001*value min spr;
    res:update Tbidsizes:(bidsize_1+bidsize_2+bidsize_3+bidsize_4+bidsize_5),
               Tasksizes:(asksize_1+asksize_2+asksize_3+asksize_4+asksize_5) from res;
    res:update Tvol:Tbidsizes+Tasksizes from res;
    resIMB:select imbRatio:(sum(Tbidsizes-Tasksizes))%sum(Tvol) by 10 xbar time.second from res;
    :`num_trades`avgTradeSize`ExCostWMid_type4`avgTradeSpread_1m`imbalanceRatio_10s!(
        Tnum;
        avgTsize;
        (.util.rnd[mincst;0.001],.util.rnd[maxcst;0.001]);
        (minSpr,maxSpr);
        (.util.rnd[value min resIMB;0.001],.util.rnd[value max resIMB;0.001]))}

/ Normalised depth distribution across the top 5 levels (bid + ask combined).
/ Returns a 5-row table of fractional depth per level.
.stats.calcDepth:{[tab]
    asklst:`$("asksize_"),/: ("1";"2";"3";"4";"5");
    bidlst:`$("bidsize_"),/: ("1";"2";"3";"4";"5");
    avgASK:(+/){?[x;();0b;(enlist y)!enlist(avg;y)]}[tab;] each asklst;
    avgBID:(+/){?[x;();0b;(enlist y)!enlist(avg;y)]}[tab;] each bidlst;
    tmp:flip (avgASK%(sum avgASK[0]))+(avgBID%(sum avgBID[0]));
    :.util.rnd[tmp;0.01]}
