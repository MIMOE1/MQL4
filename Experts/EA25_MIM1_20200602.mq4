//+------------------------------------------------------------------+
//|                                                         EA25.mq4 |
//|                                                              MIM |
//+------------------------------------------------------------------+
#property copyright "MIM"
#property link      ""
#property version   "1.0"
#property strict

extern bool MainSwitch = true; // Hauptschalter zum Öffnen neuer Positionen
extern int  Slippage = 3;    // Maximale Slippage in Points
extern int TimeFrameMinutes = 60; // Zeitordnung in Minuten (Standard: 60min)
int TimeFrame;
extern string Settings = "/// ";
extern int LotsFactor = 1; // Multiplikator Start-Positionsgröße
extern double MaxLotsPerTrade = 0.6; // Maximale Lots aller Orders in einem Trade
extern double MaxLotsPerOrder = 0.2; // Maximale Lots einer Order
extern double OrderStopLossSpacing = 0.00010; // Mindest-Verschiebung des StopLoss in Punkten
extern double RiskInPercent = 0.5; // Risiko in % des Kontostands
extern int ClusterOrders = 1; // Anzahl Teilorders pro Trade

extern int StopLossMinPoints = 300; // Stoploss in Punkten
extern double TakeProfitFactor = 1.2; // TakeProfit: Vielfaches des StopLoss

int ExpertMagicNumber = 3000;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime Time_old;
bool IsNewBar, NewOrderAllowed, Closed, Modified, Selected, OpenOrderBuy = false, OpenOrderSell = false, CloseOrderBuy = false, CloseOrderSell = false;
bool NextOrderSaveLosses = false, NextOrderTrailing = true, Blocked = false;

double OrdersLossSum = 0.0;
int OrdersLossInRow = 0;
double OrdersLossLots = 0.0;
double ProbabilityBorder = 1;
double rndnmbr = 1;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   MathSrand(GetTickCount());
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
// Setze boolsche Flags zurück
   OpenOrderBuy = false;
   OpenOrderSell = false;
   CloseOrderBuy = false;
   CloseOrderSell = false;
   NextOrderSaveLosses = false;
   NextOrderTrailing = true;

// Zeitordnung
   switch(TimeFrameMinutes)
     {
      case 15:
         TimeFrame = PERIOD_M15;
         break; // M15
      case 60:
         TimeFrame = PERIOD_H1;
         break; // H1
      default:
         break;
     }


//+------------------------------------------------------------------+
//| Filter                                                           |
//+------------------------------------------------------------------+
// Kriterien müssen erfüllt sein, damit neue Orders geöffnet werden dürfen
   if(
      MainSwitch &&  //Hauptschalter
//TradingDaysTimes() && // zeitliche Einschränkung
      IsNewBar()
//WaitHoursAfterLostTrade(4)
// Drawdown-Grenze (Balance)
// Verfügbare Margin prüfen
// AccountFreeMargin()

   )
     {
      Blocked = false; // Setze Sperre zurück
     }
   else
      Blocked = true;

//+------------------------------------------------------------------+
//| Berechnungen                                                     |
//+------------------------------------------------------------------+
   double VLT = RangeOfDays(15);

   double HighMA1  = iMA(Symbol(),TimeFrame,24,0,MODE_SMA,PRICE_HIGH,1);
   double OpenMA1  = iMA(Symbol(),TimeFrame,12,0,MODE_EMA,PRICE_OPEN,1);
   double CloseMA1 = iMA(Symbol(),TimeFrame,12,0,MODE_EMA,PRICE_CLOSE,1);
   double LowMA1   = iMA(Symbol(),TimeFrame,24,0,MODE_SMA,PRICE_LOW,1);

   double DiffMA1 = NormalizeDouble(MathAbs(OpenMA1 - CloseMA1),Digits());

//+------------------------------------------------------------------+
//| Trade-Management: StopLoss / Schließen / Invertieren             |
//+------------------------------------------------------------------+
   if(OrdersOpen() > 0)
     {
      OrderMoveStopLossToBreakEven();
     }



// Signale

// ToDo: günstige Bedingungen finden - wo lohnt sich tendenziell ein Einstieg
// Idee 1: Close[1] über wievielen Highs der letzten Kerzen? Close[1] unter wievielen Lows der letzten Kerzen?
//          CloseOverHighs > CloseUnderLows -> SELL (tendeziell höherer Punkt gefunden)

// Idee 2: Candle-Formation

   if(OrdersOpen() == 0)
     {
      /*
      if(Close[1] > iHigh(Symbol(),PERIOD_D1,1))
         OpenOrderBuy = true;
      if(Close[1] < iLow(Symbol(),PERIOD_D1,1))
         OpenOrderSell = true;
      */

      // Idee: 3 Zonen: long, flat, short

      double Factor_MA = 1;
      if(CloseMA1 < LowMA1)
         Factor_MA = 1.2;
      if(CloseMA1 > HighMA1)
         Factor_MA = 0.833;

      double Factor_Trend = 1;

      // Trend oder Seitwärtsmarkt?
      if(CloseMA1 > OpenMA1)
         Factor_Trend = 0.7;
      if(CloseMA1 < OpenMA1)
         Factor_Trend = 1.428;


      double rnd = MathRand();
      rndnmbr = NormalizeDouble(rnd / 32767 * 2, 3); // Auf den Bereich 0 bis 2 normalisieren

      double LowerBorder = 0;
      double UpperBorder = 2;
      ProbabilityBorder  = 1;// * Factor_MA * Factor_Trend;




      if(rndnmbr > ProbabilityBorder)
         OpenOrderBuy = true;

      if(rndnmbr < ProbabilityBorder)
         OpenOrderSell = true;

      /*
      if( (LowMA1 < CloseMA1 && CloseMA1 < HighMA1) ||
          (Bid > HighMA1 || Ask < LowMA1)



          )
           {
            OpenOrderBuy=false; OpenOrderSell=false;
           }
      */

      if(OpenOrderBuy || OpenOrderSell)
         OrderSendMarket(OpenOrderBuy, OpenOrderSell, true, false, VLT, VLT * TakeProfitFactor);

     }


   /*
      if(OrdersOpen() > 0 )
        {
         for(int i = OrdersTotal() - 1; i >= 0; i--)
           {
            if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
               continue;
            if(OrderMagicNumber() > 0 && OrderProfit() < 0)
              {
               if(LowMA1 < CloseMA1 && CloseMA1 < HighMA1)
                 {
                  OrderCloseMarket(true, true);
                 }
              }
           }
        }
   */



// Weitere Orders im Trend nachschieben
// Orders werden eröffnet wenn letzte Order BreakEven gesichert ist
// Weitere Kriterien festlegen
   /*
      if(OrdersOpen() > 0 && !Blocked)
        {
         if(OrdersOpenByMagicNumber(1) == OrdersBreakEven())
           {
            if(OrderSelect(OrdersTotal() - 1,SELECT_BY_POS,MODE_TRADES))
              {
               if(OrderSymbol() == Symbol() && OrderMagicNumber() == 1)
                 {
                  if(OrderType() == OP_BUY)
                     OrderSendMarket(false, true, false, true, Lots, StopLossPoints, 0);

                  if(OrderType() == OP_SELL)
                     OrderSendMarket(true, false, false, true, Lots, StopLossPoints, 0);
                 }
              }
           }
        }
   */


//+------------------------------------------------------------------+
//| Anzeige im Chart                                                 |
//+------------------------------------------------------------------+
   Comment("Verlust: " + DoubleToString(OrdersLossSum,2) + "\n" + "Trades verloren: " + IntegerToString(OrdersLossInRow) + "\n" +
           "BasisWährung: " + SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE) + "\n" +
           "KontoWährung: " + AccountCurrency() + "\n" +
           "VLT: " + DoubleToString(VLT,Digits()) + "\n" +
           "DailyRange: " + DoubleToString(RangeOfDays(10),Digits()) + "\n" +
           "OrdersOpen: " + IntegerToString(OrdersOpen()) + "\n" +
           "OrdersBreakEven: " + IntegerToString(OrdersBreakEven()) + "\n" +
           "ProbabilityBorder: " + ProbabilityBorder + "\n" +
           "Random: " + rndnmbr
          );


  }// Ende On-Tick

//+------------------------------------------------------------------+
//| Funktionen                                                       |
//+------------------------------------------------------------------+
// Aktueller Kurs oder Close ist höher als wieviele Kerzen vorher?
int AboveLastHighs(int Start, int End)
  {
   int Count = 0;
   for(int i = Start; i < End; i++)
     {
      if(Close[Start] > High[i + 1])
         Count++;
     }
   return(Count);
  }

// Aktueller Kurs oder Close ist niedriger als wieviele Kerzen vorher?
int BelowLastLows(int Start, int End)
  {
   int Count = 0;
   for(int i = Start; i < End; i++)
     {
      if(Close[Start] < Low[i + 1])
         Count++;
     }
   return(Count);
  }

// Tages-Range
double RangeOfDays(int Days)
  {
   int RealDays = 0;
   double Sum = 0;
   double DailyRange = 0;
   for(int i = 1; i <= Days; i++)
     {
      Sum += MathAbs(iHigh(Symbol(),PERIOD_D1,i) - iLow(Symbol(),PERIOD_D1,i));
      RealDays++;
     }

   if(0 < RealDays && RealDays <= Days)
     {
      DailyRange = NormalizeDouble(0.75 * Sum / RealDays, Digits());
     }
   return(DailyRange);
  }

// Erlaube Trading nur zu bestimmten Zeiten
bool TradingDaysTimes()
  {
   if(1 <= DayOfWeek() && DayOfWeek() <= 5 && 6 <= Hour() && Hour() <= 18)
      return(true);
   else
      return(false);
  }

// Weitere Funktion, zählen der Orders auf allen Symbolen (wenn EA mehrere S. handelt)

//
int OrdersOpenByMagicNumber(int Magic)
  {
   int Orders = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderMagicNumber() == Magic)
         Orders++;
     }
   return(Orders);
  }

// Funktion: Zähle nur Market Orders
int OrdersOpen()
  {
   int Orders = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderMagicNumber() > 0 && (OrderType() == OP_BUY || OrderType() == OP_SELL))
         Orders++;
     }
   return(Orders);
  }

// Funktion: Zähle offene Positionen mit BreakEvenStop
int OrdersBreakEven()
  {
   int Orders = 0;
// Prüfe, ob der BreakevenStop schon gelegt wurde
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      double Error = 5 * Point();

      if(OrderMagicNumber() > 0 && OrderSymbol() == Symbol() && (OrderType() == OP_BUY || OrderType() == OP_SELL)
         && OrderStopLoss() >= OrderOpenPrice() - Error && OrderOpenPrice() + Error >= OrderStopLoss())
        {
         Orders++;
        }
     }
   return(Orders);
  }

// Order-Eröffnung
bool OrderSendMarket(bool OpenBuy, bool OpenSell, bool TakeProfitOrder, bool TrailingStopOrder, double StopLossRange, double TakeProfitRange)
  {
   bool Successful = false;
   if(!Blocked)
     {
      // alle eingabe-werte prüfen
      // maximale Order-Anzahl und Lotgrößen
      // Sind die Werte für Stoploss usw. realistisch?
      // Bei Order-Eröffnung Mindestabstände von TP und SL vom Preis beachten

      // Berechne zuerst Werte für eine (1) Order
      double TakeProfitLevel = -1;
      double StopLossLevel   = -1;
      double TakeProfitRange = NormalizeDouble(StopLossRange * TakeProfitFactor, Digits());
      double StopLossMinRange = StopLossMinPoints * Point();
      double TakeProfitMinRange = NormalizeDouble(StopLossMinRange * TakeProfitFactor, 0);

      // Prüfen ob Kontowährung gleich Basiswährung, 2 Möglichkeiten behandeln
      string BaseCurrency = SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE);
      //double ContractSize = MarketInfo(Symbol(), MODE_LOTSIZE); // Lot-Größe, meist 100000

      // Berechne Lotgröße des Trade
      double LotsPerTrade = 0.01;
      if(StopLossRange > StopLossMinRange)
        {
         double RiskInMoney = AccountBalance() * RiskInPercent * 0.01;

         if(true)   //BaseCurrency == AccountCurrency() )
           {
            LotsPerTrade = NormalizeDouble(RiskInMoney * Ask / (StopLossRange * MathPow(10,Digits())), 2);
           }
         // zweiter Fall: Kontowährung ungleich Basiswährung
         Print("RiskInMoney: " + RiskInMoney);
         Print("StopLossRange: " + StopLossRange);
         Print("TradeLots: " + LotsPerTrade);
        }
      else
        {
         Print("Fehler bei Positionsgrößen-Berechnung");
         OpenBuy = false;
         OpenSell = false;
        }

      // Begrenze Lots pro Trade
      if(LotsPerTrade < 0.01)
         LotsPerTrade = 0.01;
      if(LotsPerTrade > MaxLotsPerTrade)
         LotsPerTrade = MaxLotsPerTrade;

      // Berechne Lotgröße pro Order falls mehrere Teilorders geöffnet werden
      double LotsPerOrder = 0.01;
      if(ClusterOrders >= 1)
        {
         // Berechne Positionsgröße für jede Teilorder
         LotsPerOrder = NormalizeDouble(LotsPerTrade / ClusterOrders, 2);
        }

      // Begrenze Lots pro Order
      if(LotsPerOrder < 0.01)
         LotsPerOrder = 0.01;
      if(LotsPerOrder > MaxLotsPerOrder)
         LotsPerOrder = MaxLotsPerOrder;

      // Eröffnung der einzelnen Orders
      if(LotsPerOrder >= 0.01)
        {
         for(int i = 1; i <= ClusterOrders; i++)
           {
            int Ticket = 0;
            // Berechnung der TakeProfit-Level nach Fibonacci


            if(OpenBuy == true)
              {
               TakeProfitLevel = NormalizeDouble(Bid + TakeProfitRange * i / ClusterOrders, Digits());
               StopLossLevel   = Bid - StopLossRange;

               if(TakeProfitOrder) // weitere Checks
                 {
                  Ticket = OrderSend(Symbol(), OP_BUY, LotsPerOrder, Ask, Slippage, StopLossLevel, TakeProfitLevel, "EA", 1, 0, clrBlue);
                 }
              }

            if(OpenSell == true)
              {
               StopLossLevel   = Ask + StopLossRange;
               TakeProfitLevel = NormalizeDouble(Ask - TakeProfitRange * i / ClusterOrders, Digits());

               if(TakeProfitOrder)
                  Ticket = OrderSend(Symbol(), OP_SELL, LotsPerOrder, Bid, Slippage, StopLossLevel, TakeProfitLevel, "EA", 1, 0, clrOrangeRed);
              }

            if(Ticket > 0)
              {
               Successful = true;
               Blocked = true;
              }
            else
               if(Ticket == 0)
                  Print("Keine Order eröffnet.");
            if(Ticket < 0)
              {
               Print("Fehler bei Order!");
               Blocked = true;
              }
           }
        }
     }

   return(Successful);
  }

// Bewege StopLoss auf Break Even
bool OrderMoveStopLossToBreakEven()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      // OrderSymbol OrderMagicNumber
      // OrderStopLoss prüfen! falls nicht vorhanden neu berechnen und ergänzen
      // Funktioniert gut: Break-Even Stop ab bestimmten Trigger-Level. Trailing Stop nicht am Anfang bereits eng nachziehen!
      // nicht so gut: Stop bei allen Orders nach TrailingT
      if(OrderSymbol() == Symbol() && OrderMagicNumber() > 0) //OrderTakeProfit() == 0)
        {
         double OrderStopLossNewLevel = 0;
         double OrderMinLossTriggerLevel = 0;
         double OrderTriggerLevelBreakEven = 0;
         double OrderTakeProfitRange = 0;
         double OrderStopLossRange = 0;

         if(OrderTakeProfit() > 0)
            OrderTakeProfitRange = NormalizeDouble(MathAbs(OrderTakeProfit() - OrderOpenPrice()), Digits());
         if(OrderStopLoss()  >  0)
            OrderStopLossRange = NormalizeDouble(MathAbs(OrderStopLoss() - OrderOpenPrice()), Digits());

         // Schließen, falls zu große Kerze in die falsche Richtung kommt
         //int BarsSinceOpen = iBarShift(Symbol(), PERIOD_H1, OrderOpenTime(), false);
         //if(OrderProfit() < 0 && BarsSinceOpen >= 12)
         // OrderCloseMarket(true,true);

         if(OrderType() == OP_BUY)
           {
            double OrderTriggerLevelBreakEven = NormalizeDouble(OrderOpenPrice() + 0.75 * OrderStopLossRange, Digits());

            if(OrderMagicNumber() == 1 && OrderTakeProfit() > 0)
              {
               if(Bid > OrderTriggerLevelBreakEven && OrderTriggerLevelBreakEven != 0)
                  OrderStopLossNewLevel = OrderOpenPrice();
              }

            if(Bid > OrderStopLossSpacing + OrderStopLossNewLevel && OrderStopLossNewLevel > OrderStopLoss() + OrderStopLossSpacing && OrderStopLossNewLevel != 0)
              {
               Modified = OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLossNewLevel, OrderTakeProfit(), 0, clrNONE);
              }
           }

         if(OrderType() == OP_SELL)
           {
            double OrderTriggerLevelBreakEven = NormalizeDouble(OrderOpenPrice() - 0.75 * OrderStopLossRange, Digits());

            if(OrderMagicNumber() == 1 && OrderTakeProfit() > 0)
              {
               if(Ask < OrderTriggerLevelBreakEven && OrderTriggerLevelBreakEven != 0)
                  OrderStopLossNewLevel = OrderOpenPrice();
              }

            if(Ask < OrderStopLossNewLevel - OrderStopLossSpacing && OrderStopLossNewLevel < OrderStopLoss() - OrderStopLossSpacing && OrderStopLossNewLevel != 0)
              {
               Modified = OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLossNewLevel, OrderTakeProfit(), 0, clrNONE);
              }
           }
        }
     }
     return(true);
  }


// Schließe Orders
bool OrderCloseMarket(bool CloseBuy, bool CloseSell)
  {
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS) == false)
         continue;
      if(OrderSelect(i,SELECT_BY_POS) == true && OrderSymbol() == Symbol())
        {
         int Type = OrderType();
         if((Type == OP_BUY  || Type == OP_BUYLIMIT  || Type == OP_BUYSTOP) && CloseBuy  == true)
            Closed = OrderClose(OrderTicket(),OrderLots(),Bid,0,clrAqua);
         if((Type == OP_SELL || Type == OP_SELLLIMIT || Type == OP_SELLSTOP) && CloseSell == true)
            Closed = OrderClose(OrderTicket(),OrderLots(),Ask,0,clrOrange);
        }
     }
   return(Closed);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Neue Kerze eröffnet?
bool IsNewBar()
  {
   if(Time_old != Time[0])
     {
      Time_old  = Time[0];
      return(true);
     }
   else
      return(false);
  }

// Warte nach verlorenem Trade#
// Erst "true" nachdem Stunden abgelaufen sind
bool WaitHoursAfterLostTrade(int HoursToWaitFor)
  {
   if(OrderSelect(OrdersHistoryTotal() - 1, SELECT_BY_POS, MODE_HISTORY) && OrderCloseTime() > 0 && OrderMagicNumber() > 0)
     {
      int HoursSinceClosed = iBarShift(Symbol(),TimeFrame,OrderCloseTime(), false);
      if(OrderProfit() < 0.0 && HoursToWaitFor >= HoursSinceClosed)
         return(false);
      else
         return(true);
     }
   else
      return(true);
  }




// Funktion: Höchstes Hoch
double HighestHigh(int End, int Periode)
  {
   int HiBar = iHighest(Symbol(),Periode,MODE_HIGH,End,1);
   double Hi = iHigh(Symbol(),0,HiBar);
   return(Hi);
  }

// Funktion: Tiefstes Tief
double LowestLow(int End, int Periode)
  {
   int LoBar = iLowest(Symbol(),Periode,MODE_LOW,End,1);
   double Lo = iLow(Symbol(),0,LoBar);
   return(Lo);
  }

// Funktion: Steigende oder fallende Kerze
int Direction(int i)
  {
   int dir = 0;
   if(i == 0)
     {
      if(Open[0] <  Bid)
         dir = 1;
      if(Open[0] >  Bid)
         dir = -1;
      if(Open[0] == Bid)
         dir = 0;
     }

   if(i > 0)
     {
      if(Open[i] <  Close[i])
         dir = 1;
      if(Open[i] >  Close[i])
         dir = -1;
      if(Open[i] == Close[i])
         dir = 0;
     }
   return(dir);
  }

/*
         if(OrdersOpen == 0)
           {
            OrdersLossSum = 0.0;
            OrdersLossLots = 0.0;
            OrdersLossInRow = 0;

            // OrdersHistoryTotal begrenzen (nicht die ganze Liste durchsehen
            for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
              {
               if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
                  continue;

               if(OrderCloseTime() > 0 && OrderMagicNumber() == ExpertMagicNumber)
                 {
                  if(OrderProfit() >= 0.0)
                    {
                     if(i == OrdersHistoryTotal() - 1)
                       {
                        NextOrderTrailing = true;
                        NextOrderSaveLosses = false;
                       }
                     break;
                    }

                  if(OrderProfit() < 0.0)
                    {
                     //NextOrderSaveLosses = true;
                     //NextOrderTrailing = false;
                     OrdersLossSum += OrderProfit();
                     OrdersLossLots += OrderLots();
                     OrdersLossInRow++;
                    }
                 }
              }
            // Sicherheitsprüfungen bei OrdersLostInRow und OrdersLossSum (Werte realistisch?), Grenzen setzen (was kann das Konto verkraften?)

            // Martingale Berechnungen
            /*
            int OrderLotsFactor = NormalizeDouble(MathPow(2, OrdersLossInRow), 0);
            if(OrdersLossInRow == 0)
               Lots = 0.01 * LotsFactor;
               else Lots = 0.01 * LotsFactor * OrderLotsFactor;


                  if(OrdersLossInRow == 1)
                     Lots = OrdersLossLots + 0.01;
                  if(OrdersLossInRow >  1)
                     Lots = OrdersLossLots;


            if(Lots < 0.01)
               Lots = 0.01;
            if(Lots > 0.32)
               Lots = 0.32;

            // Mindest-TakeProfit um Verluste der letzten verlorenen Trades zu begleichen (Break-Even)
            // Prüfen ob Kontowährung gleich Basiswährung, 2 Möglichkeiten behandeln
            string BaseCurrency = SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE);
            double ContractSize = MarketInfo(Symbol(), MODE_LOTSIZE); // Lot-Größe, meist 100000


            if(true)   //BaseCurrency == AccountCurrency() )
              {
               BreakEvenRange  = NormalizeDouble((MathAbs(OrdersLossSum) * Ask / Lots + MarketInfo(Symbol(), MODE_SPREAD)) * Point(), Digits()) ;   // Mindestwerte festlegen
              }
           }
      */
//+------------------------------------------------------------------+
// BACKUP
/*

// Order-Eröffnung
bool OrderSendMarket(bool OpenBuy, bool OpenSell, bool TakeProfitOrder, bool TrailingStopOrder, double StopLossRange, double TakeProfitRange)
  {
   bool Successful = false;
   if(!Blocked)
     {
      // alle eingabe-werte prüfen
      // maximale Order-Anzahl und Lotgrößen
      // Sind die Werte für Stoploss usw. realistisch?
      // Bei Order-Eröffnung Mindestabstände von TP und SL vom Preis beachten

      double TakeProfitLevel = -1;
      double StopLossLevel = -1;
      double TakeProfitRange = NormalizeDouble(StopLossRange * TakeProfitFactor, Digits());
      double StopLossMinRange = StopLossMinPoints * Point();
      double TakeProfitMinRange = NormalizeDouble(StopLossMinRange * TakeProfitFactor, 0);

      // Prüfen ob Kontowährung gleich Basiswährung, 2 Möglichkeiten behandeln
      string BaseCurrency = SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE);
      //double ContractSize = MarketInfo(Symbol(), MODE_LOTSIZE); // Lot-Größe, meist 100000

      // Berechne Positionsgröße
      double Lots = 0.01;
      if(true)   //BaseCurrency == AccountCurrency() )
        {
         // BreakEvenRange = NormalizeDouble((MathAbs(OrdersLossSum) * Ask / Lots + MarketInfo(Symbol(), MODE_SPREAD)) * Point(), Digits()) ;   // Mindestwerte festlegen

         if(StopLossRange > StopLossMinRange)
           {
            double RiskInMoney = AccountBalance() * RiskInPercent * 0.01;
            Lots = NormalizeDouble(RiskInMoney * Ask / (StopLossRange * MathPow(10,Digits())), 2);
            Print("RiskInMoney: " + RiskInMoney);
            Print("StopLossRange: " + StopLossRange);
            Print("Lots: " + Lots);
           }
         else
           {
            Print("Fehler bei Positionsgrößen-Berechnung");
            OpenBuy = false;
            OpenSell = false;
           }
        }

      if(Lots < 0.01)
         Lots = 0.01;
      if(Lots > MaxLots)
         Lots = MaxLots;

      int Ticket = 0;
      if(OpenBuy == true)
        {
         TakeProfitLevel = Bid + TakeProfitRange;
         StopLossLevel   = Bid - StopLossRange;

         if(TakeProfitOrder)
         {
            Ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, StopLossLevel, TakeProfitLevel, "EA", 1, 0, clrBlue);
         }
         if(TrailingStopOrder)
            Ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, StopLossLevel, 0, "EA", 2, 0, clrBlue);
        }
      if(OpenSell == true)
        {
         StopLossLevel   = Ask + StopLossRange;
         TakeProfitLevel = Ask - TakeProfitRange;

         if(TakeProfitOrder)
            Ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, StopLossLevel, TakeProfitLevel, "EA", 1, 0, clrOrangeRed);
         if(TrailingStopOrder)
            Ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, StopLossLevel, 0, "EA", 2, 0, clrOrangeRed);
        }

      if(Ticket > 0)
        {
         Successful = true;
         Blocked = true;
        }
      else
         if(Ticket == 0)
            Print("Keine Order eröffnet.");
      if(Ticket < 0)
         Print("Fehler bei Order!");
     }

   return(Successful);
  }

  */
