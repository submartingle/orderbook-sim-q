/ Market order impact simulation.
/ Injects a simulated market order into the order book at a given time and measures
/ depth consumption, execution cost, and imbalance recovery dynamics.
/ Key design change from original: global state (imbpre, exPrice, bestMPrice) has been
/ eliminated. marketOrderImpact returns a dict; runScenario is fully pure.
/ Depends on: ob_util.q, ob_stats.q (.stats.imbRatio), ob_replay.q (.replay.replayMessages)

/ Threshold for declaring imbalance recovery (abs deviation from pre-trade level)


.sim.TOLERANCE:0.03

/ Simulate impact of a single market order and return post-trade book evolution.
/ msgs:    full message table
/ ob5:     5-level order book table
/ ob6:     level-6 (external liquidity) order book table
/ ob10:    10-level order book table (used to read pre-trade depth)
/ t:       trade time (null -> random time within first 6h30m of session)
/ qty:     order quantity
/ buysell: `buy or `sell
/ Returns dict: `book`imbPre`exPrice`bestMktPrice

.sim.marketOrderImpact:{[msgs;ob5;ob6;ob10;t;qty;buysell]
    s:(t,`time$(first msgs[`time])+1?0D06:30:00.000000000) null t;
    idx:first msgs[`time] bin s;
    endidx:first msgs[`time] bin `time$s+0D01:00:00.000000000;
    b:ob10[idx];
    imbPre:.stats.imbRatio[b];
    m:(endidx-idx)#(idx+1)_msgs;
    obSlice:(endidx-idx)#(idx+1)_ob6;
    if[buysell=`buy;
        lstKey:key b;
        ap:raze b[lstKey where lstKey like "askprice*"];
        as:raze b[lstKey where lstKey like "asksize*"];
        bid:20#raze b[lstKey where lstKey like "b*"];
        exPrice:(consumed:deltas[qty&sums as]) wavg ap;
        bestMktPrice:ap[0];
        show ("execution price ",(string exPrice)," vs. best market price ",string ap[0]);
        nq:as-consumed; if[not any nq; 'liquiditydrainedout];
        nask:raze (10#ap[where nq<>0]),'(10#nq[where nq<>0]);
        nmarket:raze (2 cut nask),'(2 cut bid); if[any nmarket<0; 'negativevalue]];
    if[buysell=`sell;
        lstKey:key b;
        bp:raze b[lstKey where lstKey like "bidprice*"];
        bs:raze b[lstKey where lstKey like "bidsize*"];
        ask:20#raze b[lstKey where lstKey like "a*"];
        exPrice:(consumed:deltas[qty&sums bs]) wavg bp;
        bestMktPrice:bp[0];
        show ("execution price ",(string exPrice)," vs. best market price ",string bp[0]);
        nq:bs-consumed; if[not any nq; 'liquiditydrainedout];
        nbid:raze (10#bp[where nq<>0]),'(10#nq[where nq<>0]);
        nmarket:raze (2 cut ask),'(2 cut nbid); if[any nmarket<0; 'negativevalue]];
    initb:(`time,cols ob5)!(s,20#nmarket);
    / .replay.replayMessages prepends initb (the immediate post-order book) to its result.
    / Recovery is measured from the first market update AFTER the order, so drop that leading
    / row — otherwise idx 0 compares initb against imbPre and any order whose immediate
    / perturbation is already within .sim.TOLERANCE reports a recovery time of exactly zero.
    book:1_.replay.replayMessages[initb;m;-1_obSlice];
    :`book`imbPre`exPrice`bestMktPrice!(book;imbPre;exPrice;bestMktPrice)}

/ Run a single simulation scenario and return imbalance recovery statistics.
/ Returns 0N if recovery not observed within 10000 steps, else returns
/ (recTime; imbPre; imbAtRecovery; exPrice; bestMktPrice) as a 5-element list.
/ Bug fix vs original: recovery failure check uses >= 10000 (was > 10000, off-by-one)


.sim.runScenario:{[msgs;ob5;ob6;ob10;t;qty;buysell]
    res:.sim.marketOrderImpact[msgs;ob5;ob6;ob10;t;qty;buysell];
    idx:0;
    while[(idx<10000)&(abs(.stats.imbRatio[res[`book;idx]]-res`imbPre))>.sim.TOLERANCE; idx+:1];
    $[idx>=10000;
        [0N!"noRecovery"; 0N!"tradetime: ",string t; :0N];
        (res[`book][`time][idx];
         .util.rnd[res`imbPre;0.01];
         .util.rnd[.stats.imbRatio[res[`book;idx]];0.01];
         res[`exPrice]%.util.PRICE_SCALE;
         res[`bestMktPrice]%.util.PRICE_SCALE)]}
