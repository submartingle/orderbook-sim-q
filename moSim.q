/simulate impact of market order on limited order book, using LOBSTER sample files
/global variables: message and OB10

d:(40#"JI"; ",") 0: `$"MSFT_2012-06-21_orderbook_10.csv"
OB10:flip (`$(raze ("askprice_";"asksize_";"bidprice_";"bidsize_"),\:/: ("1";"2";"3";"4";"5";"6";"7";"8";"9";"10")))!d

imbpre:0; tolerance:0.03
exPrice:bestMPrice:0
imb_rec:imb_pre:recTime:exP:bestMP:()

md_sim:{[t;q;buysell] 
    s:(t, `time$(first message[`time])+1?0D06:30:00.000000000) null t;
    /show "trade time -",(string s), " order: ",(string buysell)," quantity: ", string q;
	
	idx:first message[`time] bin s;	
	endidx:first message[`time] bin `time$s+0D01:00:00.000000000;

	b:OB10[idx];  
	imbpre: imbRatio[b];
	
	m:(endidx-idx)#(idx+1)_message; 
	OB:(endidx-idx)#(idx+1)_OB6;
	numSim:count OB;
	
	
    if[buysell=`buy; 
	  ap:raze b[lstKey where (string lstKey:key b) like\: "askprice*"];
	  as:raze b[lstKey where (string lstKey:key b) like\: "asksize*"];
	  bid:20#raze b[lstKey where (string lstKey:key b) like\: "b*"];
      exPrice:(l:deltas[q&sums as]) wavg ap;
   	  bestMPrice:ap[0]%10000;
	  show ("execution price ",(string (exPrice))," vs. best market price ",string (ap[0]));
  	  nq:as-l;if[not any nq;'liquiditydrainedout];
	  nask:raze (10#ap[where nq<>0]),'(10#nq[where nq<>0]);
	  nmarket:raze (2 cut nask),'(2 cut bid);if[any nmarket<0;'negativevalue]];

    if[buysell=`sell; 
	  bp:raze b[lstKey where (string lstKey:key b) like\: "bidprice*"];
	  bs:raze b[lstKey where (string lstKey:key b) like\: "bidsize*"];
	  ask:20#raze b[lstKey where (string lstKey:key b) like\: "a*"];
      exPrice:(l:deltas[q&sums bs]) wavg bp;
	  bestMPrice:bp[0]%10000;
	  show ("execution price ",(string (exPrice))," vs. best market price ",string (bp[0]));
  	  nq:bs-l;if[not any nq;'liquiditydrainedout];	 
	  nbid:raze (10#bp[where nq<>0]),'(10#nq[where nq<>0]);
	  nmarket:raze (2 cut ask),'(2 cut nbid);if[any nmarket<0;'negativevalue]];	  	  
	  
	  initb:(`time,cols OB5)!(s,20#nmarket);
	  : (processRows[initb;m;(numSim-1)#OB];imbpre;exPrice;bestMPrice)}
	  
	  

/simulate impact of one large market order on the orderbook 
mktRec:{[i] 
	   resBook:md_sim[tlist[i];qlist[i];bors[i]];
	   idx:0;
	   while[(idx<10000)&(abs(imbRatio[resBook[0;idx]]-resBook[1]))>tolerance;idx+:1];
	   $[idx>10000;
	     [0N!`noRecovery;0N!"tradetime: ", string tlist[i];:()];
	      (resBook[0][`time][idx];rnd[resBook[1];0.01];rnd[imbRatio[resBook[0;idx]];0.01];resBook[2]%10000;resBook[3])]
		}  
		  
	   /show "market recovery at time: ", (string resBook[`time][idx]);
	   /show "imbalance Ratio pretrade: ",(string rnd[imbpre;0.01])," first recovered imbratio: ", string rnd[l[idx];0.01]}
	   


/simulate a variety of different scenarios and store impact analysis results
mktRecIteration:{[i] 
	   resBook:md_sim[tlist[i];qlist[i];bors[i]];
	   idx:0;
	   while[(idx<10000)&(abs(imbRatio[resBook[0;idx]]-resBook[1]))>tolerance;idx+:1];
	   $[idx>10000;
	      [0N!`noRecovery;0N!"tradetime: ", string tlist[i];:0N];
	       (resBook[0][`time][idx];rnd[resBook[1];0.01];rnd[imbRatio[resBook[0;idx]];0.01];resBook[2]%10000;resBook[3])]
		}
		
		
		
	   


N:50 /N: number of scenarios
/simulated time til one hour before market close
/tlist:`time$(first message[`time])+N?0D05:30:00.000000000
/qlist:22000+N?19000



/simulated trade times every x min until market close
tlist:`time$(first message[`time])+0D00:30:00.000000000+0D00:06:50.000000000*til N
qlist:15000+N?19000
bors:N?`buy`sell

/md_sim[;;]' [tlist;qlist;bors]

\t IterationRes:mktRecIteration peach til N;
validIterRes:IterationRes;

if[count validIterRes;
   recTime,:validIterRes[;0];
   imb_pre,:validIterRes[;1];
   imb_rec,:validIterRes[;2];
   exP,:validIterRes[;3];
   bestMP,:validIterRes[;4]
  ];
   

show sumT:flip `tradeTime`recTime`RecPeriod`quantity`BuySell`exePrice`bestMarket`imb_pre`imb_rec!(tlist;recTime;recTime-tlist;qlist;bors;exP;bestMP;imb_pre;imb_rec)


/further analysis
/get res as a function of tradesize or time
/average cost against size of trade, and market recovery time

/	   
	   recTime,:resBook[`time][idx];
	   imb_pre,:rnd[imbpre;0.01];
	   imb_rec,:rnd[l[idx];0.01];
	   exP,:exPrice%10000;
	   bestMP,:bestMPrice}
\
