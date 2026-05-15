/ Limit order book reconstruction from LOBSTER message events.
/ All functions are pure: state is passed as parameters; no globals are modified.
/ Depends on: ob_util.q (for .util namespace)

/ Insert a new price/size entry into the correct level of the book.
/ Returns updated flat book values (time field excluded).
/ dir=-1: ask side (ascending price); dir=1: bid side (descending price)
.replay.insertLevel:{[bk;dir;p;s]
    colb:key bk;
    if[dir=-1;
        ap:raze bk[colb where colb like\: "askprice*"];
        as:raze bk[colb where colb like\: "asksize*"];
        bid:raze bk[colb where colb like\: "b*"];
        i:bin[ap;p];
        if[i>3;:(value 1_bk)];   / price beyond top-5 depth; return book unchanged
        nask:raze (((i+1)#ap),p,(i+1)_(-1_ap)),'(((i+1)#as),s,(i+1)_(-1_as));
        :raze (2 cut nask),'(2 cut bid)];
    if[dir=1;
        bp:raze bk[colb where colb like\: "bidprice*"];
        bs:raze bk[colb where colb like\: "bidsize*"];
        ask:raze bk[colb where colb like\: "a*"];
        i:bin[bp:reverse bp;p];
        bs:reverse bs;
        nbid:raze (reverse -5#(((i+1)#bp),p,(i+1)_bp)),'(reverse -5#(((i+1)#bs),s,(i+1)_bs));
        :raze (2 cut ask),'(2 cut nbid)]}

/ Remove null entries left by a cancellation/deletion and backfill from level-6 data.
/ bk: current book dict (includes nulled-out level); extLiq: level-6 row dict for backfill
.replay.compactBook:{[bk;extLiq]
    b:bk,extLiq;
    colb:key b;
    ask:raze b[colb where colb like\: "a*"];
    bid:raze b[colb where colb like\: "b*"];
    ask:10#ask[where ask<>0n];
    bid:10#bid[where bid<>0n];
    :raze (2 cut ask),'(2 cut bid)}

/ EventType 1: Submission of a new limit order
.replay.evtNewLimitOrder:{[bk;evt;extLiq]
    bkCol:key bk; bk:value bk;
    if[(idx:bk?evt`Price)<count bk; bk[idx+1]+:evt`Size; :bkCol!(evt[`time],1_bk)];
    :bkCol!(evt[`time],.replay.insertLevel[bkCol!bk;evt`Direction;evt`Price;evt`Size])}

/ EventType 2: Partial cancellation of a limit order
.replay.evtCancelOrder:{[bk;evt;extLiq]
    bkCol:key bk; bk:value bk; idx:bk?evt`Price;
    if[idx>=count bk; :bkCol!(evt[`time],1_bk)];
    if[(first bk[idx+1])<=evt`Size; bk:@[bk;(idx,idx+1);:;0n]; :bkCol!(evt[`time],.replay.compactBook[bkCol!bk;extLiq])];
    / remaining qty removed when order was already partially consumed by earlier simulated orders
    bk[idx+1]-:evt`Size; :bkCol!(evt[`time],1_bk)}

/ EventType 3 & 4: Full deletion or execution of a visible limit order
.replay.evtDeleteOrder:{[bk;evt;extLiq]
    bkCol:key bk; bk:value bk; idx:bk?evt`Price;
    if[idx>=count bk; :bkCol!(evt[`time],1_bk)];
    if[(first bk[idx+1])<=evt`Size; bk:@[bk;(idx,idx+1);:;0n]; :bkCol!(evt[`time],.replay.compactBook[bkCol!bk;extLiq])];
    / remaining qty removed when order was already partially consumed by earlier simulated orders
    bk:@[bk;idx+1;-;evt`Size]; :bkCol!(evt[`time],1_bk)}

/ EventType 5: Execution of a hidden limit order — book state is unaffected
.replay.evtHiddenExec:{[bk;evt;extLiq] :bk}

/ Dispatch table mapping LOBSTER event type to its handler function
.replay.evtDispatch:(1 2 3 4 5)!(.replay.evtNewLimitOrder;.replay.evtCancelOrder;.replay.evtDeleteOrder;.replay.evtDeleteOrder;.replay.evtHiddenExec)

/ Apply a single message event to the current book state
.replay.applyEvent:{[bk;evt;extLiq] .replay.evtDispatch[evt`EventType;bk;evt;extLiq]}

/ Replay all messages against the book using a scan accumulator.
/ initBk: initial book dict (with time key); msgs: full message table; ob6: level-6 OB table
/ Returns complete sequence of book states (including initBk as first row)
.replay.replayMessages:{[initBk;msgs;ob6]
    res:{[t1;t2;state;i] .replay.applyEvent[state;t1[i+1];t2[i]]}[msgs;ob6;;]\[initBk;til count ob6];
    :initBk,res}
