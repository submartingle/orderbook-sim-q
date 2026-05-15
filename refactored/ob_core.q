/ Shared constants and utility functions used across all modules.
/ Load this file first (ob_main.q handles load order).

/ Round x down to nearest multiple of y
.util.rnd:{y*floor x%y}

/ Convert LOBSTER nanosecond timestamp to q timespan
.util.sec2t:{`time$(`long$1e9*x) mod 1D}

/ Aggregate order book snapshots at int-minute intervals; drops raw time column
.util.bookSnap:{[tab;int]
    res:?[tab;();(enlist `timestamp)!enlist(xbar;int;`time.minute);()];
    :delete time from res}

/ LOBSTER stores prices as integer x PRICE_SCALE; divide to get dollars
.util.PRICE_SCALE:10000
