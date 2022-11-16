/* 建立路徑 */
libname temp "C:\Users\liu\Downloads\course\confounding-factor-propensity-score-SAS";



/* 資料檢視 */

/* 讀取資料 */
proc import
  datafile = "C:\Users\liu\Downloads\course\confounding-factor-propensity-score-SAS\demo.csv"
  out = temp.dt_1 replace;
run;

proc contents data = temp.dt_1;
proc print data = temp.dt_1(obs = 10);
run;

/* 兩組基本特性比較 */
proc tabulate data = temp.dt_1;
  class noac;
  class male htn dm hyperlipidemia malignancy / descending;
  var age;

  table (age), noac * (mean std) / nocellmerge;
  table (male htn dm hyperlipidemia malignancy), noac * (n pctn) / nocellmerge;
run;

/* 發生率 */
proc sql;
  select noac, count(*) as totN, sum(stroke_ot) as totEvent, round(sum(stroke_ft)) as totFT, round((sum(stroke_ot) / sum(stroke_ft)) * 100, 0.01) as IR
  from temp.dt_1
  group by noac
  order by noac desc;
quit;

/* KM curves & Log-rank test */
proc lifetest data = temp.dt_1 method = km plots = survival(nocensor atrisk = 0 to 2 by 0.5 outside) notable;
  time stroke_ft * stroke_ot(0);
  strata noac / test = logrank;
run;

/* univariable Cox regression model */
proc phreg data = temp.dt_1;
  model stroke_ft * stroke_ot(0) = noac / rl;
run;

/* multivariable Cox regression model */
proc phreg data = temp.dt_1;
  model stroke_ft * stroke_ot(0) = noac male age dm htn hyperlipidemia malignancy / rl;
run;



/* 計算PS */

/* 建立模型 */
proc logistic data = temp.dt_1;
  class noac(ref = '0');
  model noac = male age dm htn hyperlipidemia malignancy;
  output out = temp.dt_1 predicted = noac_ps;
run;

proc means data = temp.dt_1;
  var noac_ps;
run;

/* 評估PS在兩組的分布 */
proc univariate data = temp.dt_1;
  class noac;
  var noac_ps;
  histogram noac_ps / overlay vscale = count endpoints = (0 to 1 by 0.05);
run;



/* 使用PSM */
data temp.dt_2;
  set temp.dt_1;
run;

/* Propensity score matching */
proc psmatch data = temp.dt_2 region = treated;
  class noac;
  psmodel noac(Treated = '1') = male age dm htn hyperlipidemia malignancy;
  match method = greedy(k = 1) caliper = 0.2;
  output out(obs = match) = temp.dt_2 matchid = _MatchID;
run;

/* 兩組基本特性比較 */
proc tabulate data = temp.dt_2;
  class noac;
  class male htn dm hyperlipidemia malignancy / descending;
  var age;

  table (age), noac * (mean std);
  table (male htn dm hyperlipidemia malignancy), noac * (n pctn);
run;

/* 發生率 */
proc sql;
  select noac, count(*) as totN, sum(stroke_ot) as totEvent, round(sum(stroke_ft)) as totFT, round((sum(stroke_ot) / sum(stroke_ft)) * 100, 0.01) as IR
  from temp.dt_2
  group by noac
  order by noac desc;
quit;

/* KM curves & Log-rank test */
proc lifetest data = temp.dt_2 method = km plots = survival(nocensor atrisk = 0 to 2 by 0.5 outside) notable;
  time stroke_ft * stroke_ot(0);
  strata noac / test = logrank;
run;

/* univariable Cox regression model accounting for matched pair */
proc phreg data = temp.dt_2;
  model stroke_ft * stroke_ot(0) = noac / rl;
  strata _MatchID;
run;



/* 使用IPTW */
data temp.dt_3;
  set temp.dt_1;
run;

/* marginal prevalence */
proc sql;
  create table temp.dt_3 as
  select *, mean(noac) as noac_ep
  from temp.dt_3;
quit;

/* IPTW */
data temp.dt_3;
  set temp.dt_3;
  iptw =
    ((noac * noac_ep) / noac_ps) +
    (((1 - noac) * (1 - noac_ep)) / (1 - noac_ps));
run;

proc means data = temp.dt_3;
  var iptw;
run;

/* 加權過後的baseline table */
proc freq data = temp.dt_3;
  table male * noac / norow nopercent;
  weight iptw;
run;

proc means data = temp.dt_3;
  class noac;
  var age;
  weight iptw;
run;

/* 發生率 */
proc sql;
  select noac, sum(iptw) as totN, sum(stroke_ot * iptw) as totEvent, round(sum(stroke_ft * iptw)) as totFT, round((sum(stroke_ot  * iptw) / sum(stroke_ft * iptw)) * 100, 0.01) as IR
  from temp.dt_3
  group by noac
  order by noac desc;
quit;

/* KM curves & Log-rank test */
proc lifetest data = temp.dt_3 method = km plots = survival(nocensor atrisk = 0 to 2 by 0.5 outside) notable;
  time stroke_ft * stroke_ot(0);
  strata noac / test = logrank;
  weight iptw;
run;

/* univariable Cox regression model */
proc phreg data = temp.dt_3;
  model stroke_ft * stroke_ot(0) = noac / rl;
  weight iptw;
run;





/* END */
/* Peter Pin-Sung Liu */
/* psliu520@gmail.com */
