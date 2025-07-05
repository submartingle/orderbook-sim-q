
/using initial status from order book to replay
/use orderbook level 10 file to extract top 5 levels for simulation, which should produce same orderbook as LOBSTER data
/When replaying the book, type 5 events don’t affect the resting book state, but they do affect trade statistics, i.e., they should still be accounted for in trade flow, volume, and order imbalance calculations.



tmp:("FISIJI"; ",") 0: hsym `$"MSFT_2012-06-21_message_10.csv"
message: flip `time`EventType`OrderID`Size`Price`Direction!tmp

d:(24#"JI"; ",") 0: hsym `$"MSFT_2012-06-21_orderbook_10.csv"
OB6:flip (`$(raze ("askprice_";"asksize_";"bidprice_";"bidsize_"),\:/: ("1";"2";"3";"4";"5";"6")))!d
OB5:flip (20#cols OB6)!OB6[20#cols OB6] 
OB6:flip (-4#cols OB6)!OB6[-4#cols OB6] /with 4 columns askprice_6,asksize_6,bidprice_6,bidsize_6
initbk:OB5@0; l:count OB5;



addM:{[b;dir;p;s]
      colb:key b;
	  if[dir=-1; 
	  ap:raze b[lstKey where (string lstKey:key b) like\: "askprice*"];
	  as:raze b[lstKey where (string lstKey:key b) like\: "asksize*"];
	  bid:raze b[lstKey where (string lstKey:key b) like\: "b*"];
	  i:bin[ap;p]; 
	  if[i>3;: (value 1_b)];
	  /outofL5 market, adjust for other depths, return book as it is
	  nask:raze (((i+1)#ap),p,(i+1)_(-1_ap)),'(((i+1)#as),s,(i+1)_(-1_as));
	  /bin need to have ap in ascending order
	  :raze (2 cut nask),'(2 cut bid)]		  
	  
	  if[dir=1;
	  bp:raze b[lstKey where (string lstKey:key b) like\: "bidprice*"];
	  bs:raze b[lstKey where (string lstKey:key b) like\: "bidsize*"];
	  ask:raze b[lstKey where (string lstKey:key b) like\: "a*"];
	  i:bin[bp:reverse bp;p];
	  bs:reverse bs;
	  nbid: raze (reverse -5#(((i+1)#bp),p,(i+1)_bp)),'(reverse -5#(((i+1)#bs),s,(i+1)_bs));
	  :raze (2 cut ask),'(2 cut nbid)]}		
	  
updM:{b:x,y;       		   
	   ask:raze b[lstKey where (string lstKey:key b) like\: "a*"];
	   bid:raze b[lstKey where (string lstKey:key b) like\: "b*"];
	   ask:10#ask[where ask<>0n];
	   bid:10#bid[where bid<>0n];
	   :raze (2 cut ask),'(2 cut bid)}
		   
//limit order book reconstruction algorithm//

replay:{[bk;ets;extLiq]
      /bk-initbk; ets-message; extLiq-OB6 
	       
  if[5=ets`EventType;:bk];
  /phantom liquidity
  
  bkCol:key bk; bk:value bk;	  
  if[any bk<0;'negativequantity];
  
  if[1=ets`EventType;
	 if[(idx:bk?ets`Price)<count bk;bk[idx+1]+:ets`Size;:bkCol!(ets[`time],1_bk)];
		:bkCol!(ets[`time],addM[bkCol!bk;ets`Direction;ets`Price;ets`Size])];
	
  if[2=ets`EventType; idx:bk?ets`Price; 
       if[idx>=count bk;:bkCol!bk]; 
	   if[(first bk[idx+1])<=ets`Size;bk:@[bk;(idx,idx+1);:;0n];:bkCol!(ets[`time],updM[bkCol!bk;extLiq])];
	   /for simulation when the order is executed by prior simulated orders and hence no longer has the original quantity to be removed, in which case remove the remaining quantity
       bk[idx+1]-:ets`Size;:bkCol!(ets[`time],1_bk)];
	   
  if[3=ets`EventType; idx:bk?ets`Price; 
       if[idx>=count bk;:bkCol!(ets[`time],1_bk)]; 
	   /the change happens out of L5 market and not in consideration here	   
	   if[(first bk[idx+1])<=ets`Size;bk:@[bk;(idx,idx+1);:;0n];:bkCol!(ets[`time],updM[bkCol!bk;extLiq])];
	   /for simulation when the order is executed by prior simulated orders and hence no longer has the original quantity to be removed, in which case remove the remaining quantity
	   bk:@[bk;idx+1;-;ets`Size];:bkCol!(ets[`time],1_bk)]
  
  /need to factor in trading stats
  if[4=ets`EventType; idx:bk?ets`Price; 
      if[idx>=count bk;:bkCol!(ets[`time],1_bk)]; 
	  /it could be partial execution
	   if[(first bk[idx+1])<=ets`Size;bk:@[bk;(idx,idx+1);:;0n];:bkCol!(ets[`time],updM[bkCol!bk;extLiq])];
	  /for simulation when the order is executed by prior simulated orders and hence no longer has the original quantity to be executed against, in which case only execute the remaining quantity
	   bk:@[bk;idx+1;-;ets`Size];:bkCol!(ets[`time],1_bk)]}
	  

/processRows:{[initb;messages;OrderBook6]{[t1;t2;state;i] replay[state;t1[i];t2[i]]}[messages;OrderBook6;;]/[initb;til count messages]}

initbk:(`time,(key initbk))!((message[`time] 0),value initbk);
processRows:{[initb;messages;OrderBook6] res:{[t1;t2;state;i] replay[state;t1[i+1];t2[i]]}[messages;OrderBook6;;]\[initb;til count OrderBook6]}
res:initbk,processRows[initbk;message;(l-1)#OB6]


/convert time from nanoseconds to timespan
sec2t:{`time$(`long$1e9*x) mod 1D}
update sec2t time from `res
update sec2t time from `message



/produce orderbook snapshot at specified intervals minutes
bookSnap:{[tab;int] res:?[tab;();(enlist `timestamp)! enlist (xbar;int;`time.minute);()]; :delete time from res}




/============================================				  
/ validation
/===========================================

/compare to LOBSTER snapshots
checkOutput:((1_cols res)#res)[til l]~OB5[til l];
if[checkOutput; show "result matches with the LOBSTER orderbook"];

/duplicate in price quote on different market depth
pricecols: cols[res] where cols[res] like "*price*"
if[null first where 10>({count distinct res[pricecols][;x]} each til count res);show "no duplicate in prices"];

/0 or negative size
sizecols: cols[res] where cols[res] like "*size*"
if[null first where ({sum 0>= distinct res[sizecols][;x]} each til count res);show "no 0 or negative in sizes"];



/

hidT:`Size xdesc select from message where EventType=5;
hiddenTrade:aj[`time;hidT;res];
/hidden trade occurred outside the market, i.e. less favourable for who placed the limited order 
select from hiddenTrade where Direction=-1,Price<bidprice_1 /buy trades;
select from hiddenTrade where Direction=1,Price>askprice_1  /sell trades;

\ts:5 processRows[initbk;message;(l-1)#OB6]
\




		   
