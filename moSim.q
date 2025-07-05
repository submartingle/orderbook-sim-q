/simulate impact of market order on limited order book, using LOBSTER sample files
/global variables message and OB10

d:(40#"JI"; ",") 0: hsym `$"MSFT_2012-06-21_orderbook_10.csv"
OB10:flip (`$(raze ("askprice_";"asksize_";"bidprice_";"bidsize_"),\:/: ("1";"2";"3";"4";"5";"6";"7";"8";"9";"10")))!d

imbpre:0; tolerance:0.03
exPrice:bestMPrice:0
imb_rec:imb_pre:recTime:exP:bestMP:()

md_sim:{[t;q;buysell] 
    s:(t, `time$(first message[`time])+1?0D06:30:00.000000000) null t;
/	show "trade time -",(string s), " order: ",(string buysell)," quantity: ", string q;
	
	idx:first message[`time] bin s;	
	endidx:first message[`time] bin `time$s+0D01:00:00.000000000;

	b:OB10[idx];  
	`imbpre set imbRatio[b];
	
	m:(endidx-idx)#(idx+1)_message; 
	OB:(endidx-idx)#(idx+1)_OB6;
	numSim:count OB;
	
	
    if[buysell=`buy; 
	  ap:raze b[lstKey where (string lstKey:key b) like\: "askprice*"];
	  as:raze b[lstKey where (string lstKey:key b) like\: "asksize*"];
	  bid:20#raze b[lstKey where (string lstKey:key b) like\: "b*"];
      exPrice::(l:deltas[q&sums as]) wavg ap;
      /return slippage  -to do
	  bestMPrice::ap[0]%10000;
	  show ("execution price ",(string (exPrice))," vs. best market price ",string (ap[0]));
  	  nq:as-l;if[not any nq;'liquiditydrainedout];
	  nask:raze (10#ap[where nq<>0]),'(10#nq[where nq<>0]);
	  nmarket:raze (2 cut nask),'(2 cut bid);if[any nmarket<0;'negativevalue]];

    if[buysell=`sell; 
	  bp:raze b[lstKey where (string lstKey:key b) like\: "bidprice*"];
	  bs:raze b[lstKey where (string lstKey:key b) like\: "bidsize*"];
	  ask:20#raze b[lstKey where (string lstKey:key b) like\: "a*"];
      exPrice::(l:deltas[q&sums bs]) wavg bp;
      /return slippage  -to do
	  bestMPrice::bp[0]%10000;
	  show ("execution price ",(string (exPrice))," vs. best market price ",string (bp[0]));
  	  nq:bs-l;if[not any nq;'liquiditydrainedout];	 
	  nbid:raze (10#bp[where nq<>0]),'(10#nq[where nq<>0]);
	  nmarket:raze (2 cut ask),'(2 cut nbid);if[any nmarket<0;'negativevalue]];	  	  
	  
	  initb:(`time,cols OB5)!(s,20#nmarket);
	  processRows[initb;m;(numSim-1)#OB]}
	  
	  


mktRec:{[i] 
	   resBook:md_sim[tlist[i];qlist[i];bors[i]];
	   l:{[tab;x]imbRatio[tab[x]]}[resBook;] each til 3000;
	   idx:first where (abs(l-imbpre))<tolerance;
	   if[null idx;0N!`noRecoverywithin3000lines;0N!"tradetime: ", string tlist[i];:()];
	   show "market recovery at time: ", (string resBook[`time][idx]);
	   show "imbalance Ratio pretrade: ",(string rnd[imbpre;0.01])," first recovered imbratio: ", string rnd[l[idx];0.01]}
	   


	   
mktRecIteration:{[i] 
	   resBook:md_sim[tlist[i];qlist[i];bors[i]];
	   l:{[tab;x]imbRatio[tab[x]]}[resBook;] each til 5000;
	   idx:first where (abs(l-imbpre))<tolerance;
	   if[null idx;0N!`noRecoverywithin5000lines;0N!"tradetime: ", string tlist[i];:()];
	   recTime,:resBook[`time][idx];
	   imb_pre,:rnd[imbpre;0.01];
	   imb_rec,:rnd[l[idx];0.01];
	   exP,:exPrice%10000;
	   bestMP,:bestMPrice}




N:15
/simulated time til one hour before market close
/tlist:`time$(first message[`time])+N?0D05:30:00.000000000
/qlist:22000+N?19000



/simulated trade times every 30min until market close
tlist:`time$(first message[`time])+0D00:30:00.000000000+0D00:20:00.000000000*til 15
qlist:N#600
bors:N?`buy`sell

/md_sim[;;]' [tlist;qlist;bors]

mktRecIteration each til N;
sumT:flip `tradeTime`recTime`RecPeriod`quantity`dirt`exePrice`bestMarket`imb_pre`imb_rec!(tlist;recTime;recTime-tlist;qlist;bors;exP;bestMP;imb_pre;imb_rec)
show sumT

/further analysis
/get res as a function of tradesize or time
/average cost against size of trade, and market recovery time

