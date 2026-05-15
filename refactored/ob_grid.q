/ Order book resilience grid analysis.
/ Sweeps .sim.runScenario over a grid of trade sizes (1x-10x daily avg quote size)
/ and trade times (10:00 AM to 3:00 PM NY, hourly) for both buy and sell.
/ Produces a flat results table (120 rows = 10 sizes x 6 times x 2 directions).
/ Depends on: ob_core.q, ob_stats.q, ob_replay.q, ob_mosim.q

/ Daily average best quote size: mean of (bidsize_1 + asksize_1) halved across all rows
.grid.baseQuoteSize:{[ob5]
    :floor avg exec (bidsize_1+asksize_1)%2 from ob5}

/ Size grid: base * 1x through 10x (100% to 1000% of daily avg quote size)
.grid.sizeGrid:{[ob5]
    base:.grid.baseQuoteSize[ob5];
    :floor base*1+til 10}

/ Time grid: 10:00 AM to 3:00 PM NY time, hourly (6 points)
/ Returns `time` type values matching the format produced by .util.sec2t
.grid.timeGrid:{
    :`time$36000000+3600000*til 6}

/ Run full resilience grid and return results table.
/ msgs : message table (time already converted via .util.sec2t)
/ ob5, ob6, ob10 : order book tables
/ Returns 120-row table: one row per (tradeTime x tradeSize x direction) combination.
.grid.runGrid:{[msgs;ob5;ob6;ob10]
    baseSize:.grid.baseQuoteSize[ob5];
    mults:1+til 10;
    sizes:floor baseSize*mults;
    times:.grid.timeGrid[];
    nT:count times;
    nM:count mults;
    nD:2;

    t_col:raze (nM*nD)#/: times;
    m_col:raze nT#enlist raze nD#/: mults;
    s_col:floor baseSize*m_col;
    d_col:raze (nT*nM)#enlist `buy`sell;

    / protected eval: errors (liquidity drained, negative value) return 0N
    raw:{.[.sim.runScenario;(msgs;ob5;ob6;ob10;x;y;z);{0N}]}'[t_col;s_col;d_col];

    recov:  not (0N~) each raw;
    recTime:{$[x~0N; 0Nt; x[0]]} each raw;
    imbPre: {$[x~0N; 0n;  x[1]]} each raw;
    imbRec: {$[x~0N; 0n;  x[2]]} each raw;
    exeP:   {$[x~0N; 0n;  x[3]]} each raw;
    bestMkt:{$[x~0N; 0n;  x[4]]} each raw;

    :flip `tradeTime`tradeSize`sizeMult`direction`recovered`recTime`RecPeriod`imb_pre`imb_rec`exePrice`bestMarket`slippage!(
        t_col;
        s_col;
        m_col;
        d_col;
        recov;
        recTime;
        recTime-t_col;
        imbPre;
        imbRec;
        exeP;
        bestMkt;
        abs exeP-bestMkt)}

/ Aggregate grid results by size multiplier and direction.
/ Averages over all trade times. Non-recovered scenarios contribute to recovRate
/ but are excluded from RecPeriod and slippage averages (nulls ignored by avg).
.grid.summaryBySize:{[gridRes]
    :select
        scenarioCount:count i,
        recovRate:avg`float$recovered,
        avgRecPeriod:avg RecPeriod,
        avgSlippage:avg slippage,
        avgImb_pre:avg imb_pre,
        avgImb_rec:avg imb_rec
    by sizeMult,direction from gridRes}

/ Aggregate grid results by trade time and direction.
/ Averages over all size multipliers.
.grid.summaryByTime:{[gridRes]
    :select
        scenarioCount:count i,
        recovRate:avg`float$recovered,
        avgRecPeriod:avg RecPeriod,
        avgSlippage:avg slippage,
        avgImb_pre:avg imb_pre,
        avgImb_rec:avg imb_rec
    by tradeTime,direction from gridRes}
