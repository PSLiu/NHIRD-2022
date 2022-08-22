/* 研究問題 */
/* 糖尿病人在使用胰島素的時候，是否會較容易發生低血糖 */

/* 基本設定 */

/* 檔案路徑 */
libname data "C:/Users/liu/Downloads/course/cohort-repeated-measurement-SAS/data";
libname temp "C:/Users/liu/Downloads/course/cohort-repeated-measurement-SAS/temp";





/* 資料處理 */



/* 研究樣本 */

/* 費用申報資料*/
data temp.pt_1a_opdte;
  set data.opdte2014;
  keep id func_date func_type prsn_id drug_day hosp_id fee_ym appl_type appl_date case_type seq_no;
run;

proc print data = temp.pt_1a_opdte(obs = 5);
run;

data temp.pt_1b_druge;
  set data.druge2014;
  keep id func_date r_hosp_id func_type prsn_id drug_day hosp_id fee_ym appl_type appl_date case_type seq_no;
run;

proc print data = temp.pt_1b_druge(obs = 5);
run;


/* 轉換日期屬性 */
proc sql;
  create table temp.pt_1a_opdte as 
  select 
    id, input(func_date, yymmdd8.) as func_date format yymmdd10., hosp_id as r_hosp_id,  func_type, prsn_id, drug_day, 
    hosp_id, fee_ym, appl_type, appl_date, case_type, seq_no
  from temp.pt_1a_opdte;
quit;


proc sql;
  create table temp.pt_1b_druge as 
  select 
    id, input(func_date, yymmdd8.) as func_date format yymmdd10., r_hosp_id,  func_type, prsn_id, drug_day, 
    hosp_id, fee_ym, appl_type, appl_date, case_type, seq_no
  from temp.pt_1b_druge;
quit;

/* 醫令申報資料 */
data temp.pt_1a_opdto;
  set data.opdto2014;
  keep drug_no hosp_id fee_ym appl_type appl_date case_type seq_no;
run;

proc print data = temp.pt_1a_opdto(obs = 5);
run;

data temp.pt_1b_drugo;
  set data.drugo2014;
  keep drug_no hosp_id fee_ym appl_type appl_date case_type seq_no;
run;

proc print data = temp.pt_1b_drugo(obs = 5);
run;

/* 目標藥物清單 */
data temp.pt_1c_drug;
  set temp.drug_list;

  if substr(atc_code, 1, 3) = "A10";
  keep drug_no atc_code;
run;

proc sort data = temp.pt_1c_drug nodupkey;
  by drug_no atc_code;
run;

data temp.pt_1c_drug;
  set temp.pt_1c_drug;

  insulin = 0;
  if substr(atc_code, 1, 4) = "A10A" then insulin = 1;
run;

proc freq data = temp.pt_1c_drug;
  table insulin;
run;

/* 保留目標藥物處方 */
proc sort data = temp.pt_1a_opdto; by drug_no; run;
proc sort data = temp.pt_1c_drug; by drug_no; run;
data temp.pt_1a;
  merge
    temp.pt_1a_opdto(in = a)
    temp.pt_1c_drug(in = b);
  by drug_no;
  if a = 1 & b = 1;
run;

proc sort data = temp.pt_1b_drugo; by drug_no; run;
proc sort data = temp.pt_1c_drug; by drug_no; run;
data temp.pt_1b;
  merge
    temp.pt_1b_drugo(in = a)
    temp.pt_1c_drug(in = b);
  by drug_no;
  if a = 1 & b = 1;
run;

proc print data = temp.pt_1a(obs = 5);
run;
proc print data = temp.pt_1b(obs = 5);
run;

/* 整合就診資料 */
proc sort data = temp.pt_1a; by hosp_id fee_ym appl_type appl_date case_type seq_no; run;
proc sort data = temp.pt_1a_opdte; by hosp_id fee_ym appl_type appl_date case_type seq_no; run;
data temp.pt_1a;
  merge
    temp.pt_1a(in = a)
    temp.pt_1a_opdte(in = b);
  by hosp_id fee_ym appl_type appl_date case_type seq_no;
  if a = 1 & b = 1;
run;

proc sort data = temp.pt_1b; by hosp_id fee_ym appl_type appl_date case_type seq_no; run;
proc sort data = temp.pt_1b_druge; by hosp_id fee_ym appl_type appl_date case_type seq_no; run;
data temp.pt_1b;
  merge
    temp.pt_1b(in = a)
    temp.pt_1b_druge(in = b);
  by hosp_id fee_ym appl_type appl_date case_type seq_no;
  if a = 1 & b = 1;
run;

proc print data = temp.pt_1a(obs = 5);
run;
proc print data = temp.pt_1b(obs = 5);
run;

/* 歸戶就診資料 */
proc sql;
  create table temp.pt_2a as
  select id, func_date, r_hosp_id as hosp_id, prsn_id, sum(drug_day) as drug_day, max(insulin) as insulin
  from
   (
     select id, func_date, r_hosp_id, prsn_id, hosp_id, fee_ym, appl_type, appl_date, case_type, seq_no, max(drug_day) as drug_day, max(insulin) as insulin
	 from temp.pt_1a
	 group by id, func_date, r_hosp_id, prsn_id, hosp_id, fee_ym, appl_type, appl_date, case_type, seq_no
   )
  group by id, func_date, r_hosp_id, prsn_id;
quit;

proc sql;
  create table temp.pt_2b as
  select id, func_date, r_hosp_id as hosp_id, prsn_id, sum(drug_day) as drug_day, max(insulin) as insulin
  from
   (
     select id, func_date, r_hosp_id, prsn_id, hosp_id, fee_ym, appl_type, appl_date, case_type, seq_no, max(drug_day) as drug_day, max(insulin) as insulin
	 from temp.pt_1b
	 group by id, func_date, r_hosp_id, prsn_id, hosp_id, fee_ym, appl_type, appl_date, case_type, seq_no
   )
  group by id, func_date, r_hosp_id, prsn_id;
quit;

proc print data = temp.pt_2a(obs = 5);
run;
proc print data = temp.pt_2b(obs = 5);
run;

data temp.pt_2;
  set 
    temp.pt_2a
    temp.pt_2b;
run;

proc sql;
  create table temp.pt_2 as
  select id, func_date, hosp_id, prsn_id, sum(drug_day) as drug_day, max(insulin) as insulin
  from temp.pt_2
  group by id, func_date, hosp_id, prsn_id;
quit;

proc sql;
  create table temp.pt_2 as 
  select id, hosp_id, prsn_id, insulin, func_date as start_date, func_date + drug_day - 1 as end_date format yymmdd10., drug_day
  from temp.pt_2
  order by id, start_date;
quit;

proc print data = temp.pt_2(obs = 5);
run;

proc freq data = temp.pt_2;
  table insulin;
run;

/* 所有DM用藥紀錄 */
data temp.pt_episode;
  set temp.pt_2;
run;

/* 新發糖尿病人 */
data temp.pt_first;
  set temp.pt_episode;
  keep id start_date insulin;
  rename start_date = index_date;
run;

/* 因為模擬檔人數限制，本處就先不限定"今年新發個案"，未來在研究當中需要留意 */
proc sort data = temp.pt_first;
  by id index_date;
data temp.pt_first;
  set temp.pt_first;
  by id;
  if first.id;
run;

proc freq data = temp.pt_first;
  table insulin;
run;




/* 目標結果 */

/* 研究樣本 */
data xt_0;
  set temp.pt_first;
  keep id;
run;

/* 費用申報資料 */
data temp.xt_1_opdte;
  set data.opdte2014;
  keep id func_date icd9cm_1 icd9cm_2 icd9cm_3 func_type case_type;
run;

data temp.xt_1_opdte;
  set temp.xt_1_opdte;
  if case_type = "02" | func_type = "22";
run;

data temp.xt_1_ipdte;
  set data.ipdte2014;
  keep id in_date icd9cm_1 icd9cm_2 icd9cm_3 icd9cm_4 icd9cm_5;
  rename in_date = func_date;
run;

proc print data = temp.xt_1_opdte(obs = 5);
run;
proc print data = temp.xt_1_ipdte(obs = 5);
run;

/* 保留研究樣本資料 */
proc sql;
  create table temp.xt_1_opdte as
  select b.*
  from xt_0 as a,  temp.xt_1_opdte as b
  where a.ID = b.ID;
quit;

proc sql;
  create table temp.xt_1_ipdte as
  select b.*
  from xt_0 as a,  temp.xt_1_ipdte as b
  where a.ID = b.ID;
quit;

/* 資料轉置 */
data temp.xt_2_opdte;
  set 
    temp.xt_1_opdte(keep = id func_date icd9cm_1 rename = (icd9cm_1 = code) where = (code ^= "")) 
    temp.xt_1_opdte(keep = id func_date icd9cm_2 rename = (icd9cm_2 = code) where = (code ^= "")) 
    temp.xt_1_opdte(keep = id func_date icd9cm_3 rename = (icd9cm_3 = code) where = (code ^= ""));
run;

data temp.xt_2_ipdte;
  set 
    temp.xt_1_ipdte(keep = id func_date icd9cm_1 rename = (icd9cm_1 = code) where = (code ^= "")) 
    temp.xt_1_ipdte(keep = id func_date icd9cm_2 rename = (icd9cm_2 = code) where = (code ^= "")) 
    temp.xt_1_ipdte(keep = id func_date icd9cm_3 rename = (icd9cm_3 = code) where = (code ^= "")) 
    temp.xt_1_ipdte(keep = id func_date icd9cm_4 rename = (icd9cm_4 = code) where = (code ^= "")) 
    temp.xt_1_ipdte(keep = id func_date icd9cm_5 rename = (icd9cm_5 = code) where = (code ^= ""));
run;

proc print data = temp.xt_2_opdte(obs = 5);
run;
proc print data = temp.xt_2_ipdte(obs = 5);
run;

data temp.xt_2;
  set
    temp.xt_2_opdte
	temp.xt_2_ipdte;
run;

/* 轉換日期屬性 */
proc sql;
  create table temp.xt_2 as 
  select 
    id, input(func_date, yymmdd8.) as ot_date format yymmdd10., code
  from temp.xt_2;
quit;

/* 目標結果 - hypoglycemia */
data temp.xt_3;
  set temp.xt_2;
  if substr(code, 1, 4) in ("2510", "2511", "2512");
  ot = 1;
  drop weight code;
run;

proc sort data = temp.xt_3 nodupkey;
  by id ot_date ot;
run;

/* 儲存資料 */
data temp.xt_every;
  set temp.xt_3;
run;

/* 首次事件 */
data temp.xt_first;
  set temp.xt_every;
  by id;
  if first.id then output;
run;



/* 承保資料 */

/* 研究樣本 */
data temp.ins_0;
  set temp.pt_first;
  keep id index_date;
run;

data temp.ins_1;
  set data.enrol2014;
  keep id id_s id_birth_y prem_ym id1_amt;
run;

/* 找尋index date之前最近一次的承保資料 */
proc sql;
  create table temp.ins_2 as
  select a.index_date, b.*, input(cat(prem_ym, "01"), yymmdd8.) as prem_date format yymmdd10.
  from temp.ins_0 as a,  temp.ins_1 as b
  where a.ID = b.ID;
quit;

data temp.ins_2;
  set temp.ins_2;
  if prem_date < index_date;
run;

proc sort data = temp.ins_2;
  by id descending prem_date;
run;

data temp.ins_2;
  set temp.ins_2;
  by id;
  if first.id then output;
run;

/* 所需變項 */
proc sql;
  create table temp.ins_2 as
  select id, index_date, id_s, input(id_birth_y, 4.) as id_birth_y, id1_amt * 1 as id1_amt
  from temp.ins_2;
quit;

/* 性別 */
data temp.ins_2;
  set temp.ins_2;

  if  id_s in ("1", "2");

  male = 0; if id_s = "1" then male = 1;
  female = 0; if id_s = "2" then female = 1;
run;

proc freq data = temp.ins_2;
  table id_s * male * female / list;
run;

/* 計算年齡 */
data temp.ins_2;
  set temp.ins_2;
  age = year(index_date) - id_birth_y;
run;

proc means data = temp.ins_2;
  var age;
run;

/* 投保金額級距分類 */
data temp.ins_2;
  set temp.ins_2(rename = (id1_amt = ins_amt));

  if ins_amt ^= .;

  ins_amt_gp = 0;
       if 0     <= ins_amt < 15840  then do; ins_amt_gp = 1; ins_amt_gp_1 = 1; ins_amt_gp_2 = 0; ins_amt_gp_3 = 0; ins_amt_gp_4 = 0; end;
  else if 15840 <= ins_amt < 25000  then do; ins_amt_gp = 2; ins_amt_gp_1 = 0; ins_amt_gp_2 = 1; ins_amt_gp_3 = 0; ins_amt_gp_4 = 0; end;
  else if 25000 <= ins_amt < 45000  then do; ins_amt_gp = 3; ins_amt_gp_1 = 0; ins_amt_gp_2 = 0; ins_amt_gp_3 = 1; ins_amt_gp_4 = 0; end;
  else if 45000 <= ins_amt < 200000 then do; ins_amt_gp = 4; ins_amt_gp_1 = 0; ins_amt_gp_2 = 0; ins_amt_gp_3 = 0; ins_amt_gp_4 = 1; end;
run;

proc freq data = temp.ins_2;
  table ins_amt_gp * ins_amt_gp_1 * ins_amt_gp_2 * ins_amt_gp_3 * ins_amt_gp_4 / list;
run;

proc print data = temp.ins_2(obs = 5);
run;



/* 過去病史 */

/* 研究樣本 */
data temp.hx_0;
  set temp.pt_first;
  keep id index_date;
run;

/* 讀取資料 */
data temp.hx_1_opdte;
  set data.opdte2014;
  keep id func_date icd9cm_1 icd9cm_2 icd9cm_3;
run;

data temp.hx_1_ipdte;
  set data.ipdte2014;
  keep id in_date icd9cm_1 icd9cm_2 icd9cm_3 icd9cm_4 icd9cm_5;
  rename in_date = func_date;
run;

/* 保留研究樣本 & index date之前90天的資料 */
proc sql;
  create table temp.hx_1_opdte as
  select b.*
  from temp.hx_0 as a, temp.hx_1_opdte as b
  where a.ID = b.ID & a.index_date - 90 <= input(b.func_date, yymmdd8.) < a.index_date;
quit;

proc sql;
  create table temp.hx_1_ipdte as
  select b.*
  from temp.hx_0 as a, temp.hx_1_ipdte as b
  where a.ID = b.ID & a.index_date - 90 <= input(b.func_date, yymmdd8.) < a.index_date;
quit;

/* 資料轉置 */
data temp.hx_2_opdte;
  set 
    temp.hx_1_opdte(keep = id func_date icd9cm_1 rename = (icd9cm_1 = code) where = (code ^= "")) 
    temp.hx_1_opdte(keep = id func_date icd9cm_2 rename = (icd9cm_2 = code) where = (code ^= "")) 
    temp.hx_1_opdte(keep = id func_date icd9cm_3 rename = (icd9cm_3 = code) where = (code ^= ""));
  weight = 1;
run;

data temp.hx_2_ipdte;
  set 
    temp.hx_1_ipdte(keep = id func_date icd9cm_1 rename = (icd9cm_1 = code) where = (code ^= "")) 
    temp.hx_1_ipdte(keep = id func_date icd9cm_2 rename = (icd9cm_2 = code) where = (code ^= "")) 
    temp.hx_1_ipdte(keep = id func_date icd9cm_3 rename = (icd9cm_3 = code) where = (code ^= "")) 
    temp.hx_1_ipdte(keep = id func_date icd9cm_4 rename = (icd9cm_4 = code) where = (code ^= "")) 
    temp.hx_1_ipdte(keep = id func_date icd9cm_5 rename = (icd9cm_5 = code) where = (code ^= ""));
  weight = 2;
run;

/* 將門診住院堆疊 */
data temp.hx_2;
  set
    temp.hx_2_opdte
	temp.hx_2_ipdte;
run;

/* 去除重複 */
proc sql;
  create table temp.hx_3 as
  select id, func_date, code, max(weight) as weight
  from temp.hx_2
  group by id, func_date, code;
quit;

/* 標註疾病 & 去除與研究無關的診斷紀錄 */
proc sql;
  create table temp.hx_3 as
  select 
    id, func_date, code, weight,
	case
	  when substr(code, 1, 3)in ("480", "481", "482", "483", "484", "485", "486") then "pneumonia"
	  when substr(code, 1, 3)in ("430", "431", "432", "433", "434", "435", "436", "437", "438") then "stroke"
	  when substr(code, 1, 3)in ("401", "402", "403", "404", "405") then "htn"
	  when substr(code, 1, 3)in ("272") then "lipoid"
	  when substr(code, 1, 3)in ("585") then "ckd"
	  when substr(code, 1, 3)in ("427") then "dysrhyth"
	  else "none"
	  end as dx
  from temp.hx_3
  having dx ^= "none";
quit;

proc freq data = temp.hx_3;
  table dx;
run;

proc print data = temp.hx_3(obs = 5);
run;

/* 將病史的權重加總 */
proc sql;
  create table temp.hx_4 as
  select *, 1 as hx
  from
    (
	  select id, dx, sum(weight) as weight
      from temp.hx_3
      group by id, dx
    )
  where weight >= 2;
quit;

proc freq data = temp.hx_4;
  table dx;
run;

/* 轉置(long to wide) */
proc transpose data = temp.hx_4 out = temp.hx_5(drop = _name_);
  by id;
  id dx;
  var hx;
run; 

proc print data = temp.hx_5(obs = 20);
run;




/* 資料合併 */
data temp.pt_merge_first;
  merge
    temp.pt_first(in = a)
    temp.xt_first
    temp.ins_2
    temp.hx_5;
  by id;

  /* 遺漏值補0 */
  if ckd = . then ckd = 0;
  if dysrhyth = . then dysrhyth = 0;
  if htn = . then htn = 0;
  if lipoid = . then lipoid = 0;
  if pneumonia = . then pneumonia = 0;
  if stroke  = . then stroke  = 0;

  if ot = . | ot_date = . then do; ot = 0; ot_date = input("20141231", yymmdd8.); end;

  /* 追蹤時間 */
  ft = ot_date - index_date;
run;

proc freq data = temp.pt_merge_first;
  table ot;
run;



/* 納入排除 */

/* 開始納入排除條件 */
data temp.pt_select;
  set temp.pt_merge_first;
run;

/* 排除條件 - 過去低血糖病史 */
proc freq data = temp.pt_select;
  table ot;
run;
data temp.pt_select;
  set temp.pt_select;

  if ot_date <= index_date then delete;
run;
proc freq data = temp.pt_select;
  table ot;
run;


/* 排除條件 - 基本資料不齊全 */
proc freq data = temp.pt_select;
  table id_s;
run;
data temp.pt_select;
  set temp.pt_select;

  if (id_s in ("1", "2") & id_birth_y ^= . & ins_amt ^= .) = 0 then delete;
run;
proc freq data = temp.pt_select;
  table id_s;
run;



/* 存活分析 */
proc freq data = temp.pt_select;
  table ot * insulin / norow nopercent;
run;

proc means data = temp.pt_select;
  class insulin / descending;
  var ft;
run;

proc freq data = temp.pt_select;
  table ckd dysrhyth htn lipoid pneumonia stroke;
run;




/* 資料描述 */

/* 比較兩組事件比率 */
proc sql;
  select insulin, sum(1) as totN, sum(ot) as totEvent
  from temp.pt_select
  group by insulin
  order by insulin desc;
quit;

/* 比較兩組追蹤時間 */
proc sql;
  select insulin, sum(1) as totN, sum(ft) as totFU
  from temp.pt_select
  group by insulin
  order by insulin desc;
quit;

/* 比較兩組事件發生率(incidence rate, IR) */
proc sql;
  select insulin, sum(1) as totN, sum(ot) as totEvent, sum(ft) as totFU, round((sum(ot)/sum(ft)) * 100000, 0.01) as IR
  from temp.pt_select
  group by insulin
  order by insulin desc;
quit;



/* 組間比較 */

/* 生命表 */
proc lifetest data = temp.pt_select method = lt intervals=(0 to 366 by 60);
  time ft * ot(0);
  strata insulin;
run;

/* KM curves & log-rank test */
proc lifetest data = temp.pt_select method = km plots = survival(nocensor atrisk = 0 to 366 by 60 outside) notable;
  time ft * ot(0);
  strata insulin / test = logrank;
run;



/* 迴歸分析 */

/* 暴露與事件之單變項Cox迴歸分析 */
proc phreg data = temp.pt_select;
  model ft * ot(0) = insulin / rl;
run;

/* 暴露與事件之多變項Cox迴歸分析 */
proc phreg data = temp.pt_select;
  model ft * ot(0) = insulin age male ins_amt_gp_2 ins_amt_gp_3 ins_amt_gp_4 htn / rl;
run;





/* 時間相依變數 */

/* 
ID X Y
******
A1 1 1
A2 0 0

ID T X Y
********
A1 1 1 0
A1 2 1 1
A1 3 0 0
A2 1 0 0
A2 2 0 0
A2 3 1 1
*/



/* 資料架構 */

/* 讀取資料 */
data temp.pt_head;
  set temp.pt_select;
  win_key = 1;
  keep id index_date win_key;
run;
proc print data = temp.pt_head(obs = 20);
run;

/* 觀察人月 */
data temp.pt_window;
  win_on = input("20140101", yymmdd8.);
  win_off = input("20141231", yymmdd8.);
  format win_on yymmddn8. win_off yymmddn8.;
run;
proc print data = temp.pt_window;
run;

data temp.pt_window;
  set temp.pt_window;
  do obs_date = win_on to win_off;
    output;
  end;
  format obs_date yymmddn8.;
  keep obs_date;
run;
proc print data = temp.pt_window(obs = 60);
run;

data temp.pt_window;
  set temp.pt_window;
  obs_ym = substr(put(obs_date, yymmddn8.), 1, 6);
run;
proc print data = temp.pt_window(obs = 60);
run;

proc sql;
  create table temp.pt_window as
  select 
    obs_ym, 
    min(obs_date) as obs_date_on format yymmdd10., 
    max(obs_date) as obs_date_off format yymmdd10.,
	1 as win_key
  from temp.pt_window
  group by obs_ym;
quit;
proc print data = temp.pt_window;
run;

proc sql;
  create table temp.pt_expand as 
  select a.ID, a.index_date, b.*
  from temp.pt_head as a, temp.pt_window as b
  where a.win_key = b.win_key;
quit;

data temp.pt_expand;
  set temp.pt_expand;

  if obs_date_off < index_date then delete; /* 排除開始用藥之前的月份 */
run;

proc print data = temp.pt_expand(obs = 20);
run;



/* 每人每月處理狀況 */
proc sql;
  create table temp.pt_multitx as 
  select a.*, b.insulin, b.start_date, b.end_date
  from temp.pt_expand as a left join temp.pt_episode as b
  on a.ID = b.ID;  
quit;

proc freq data = temp.pt_multitx;
  table insulin;
run;

data temp.pt_multitx;
  set temp.pt_multitx;

  if (insulin = 1 & (obs_date_on <= end_date & start_date <= obs_date_off) = 0) then insulin = 0;
run;

proc freq data = temp.pt_multitx;
  table insulin;
run;

proc sql;
  create table temp.pt_multitx as
  select id, index_date, obs_ym, obs_date_on, obs_date_off, max(insulin) as insulin
  from temp.pt_multitx
  group by id, index_date, obs_ym, obs_date_on, obs_date_off;
quit;

proc freq data = temp.pt_multitx;
  table insulin;
run;



/* 每人每月發生事件 */
proc sql;
  create table temp.pt_multievent as 
  select a.*, b.ot, b.ot_date
  from temp.pt_expand as a left join temp.xt_every as b
  on a.ID = b.ID;  
quit;

proc freq data = temp.pt_multievent;
  table ot;
run;

data temp.pt_multievent;
  set temp.pt_multievent;
  if ot = . then do; ot = 0; ot_date = input("20150101", yymmdd8.); end;
run;

proc freq data = temp.pt_multievent;
  table ot;
run;

data temp.pt_multievent;
  set temp.pt_multievent;
  if (ot = 1 & (obs_date_on <= ot_date <= obs_date_off) = 0) then ot = 0;
run;

proc sql;
  create table temp.pt_multievent as
  select id, index_date, obs_ym, obs_date_on, obs_date_off, sum(ot) as ot
  from temp.pt_multievent
  group by id, index_date, obs_ym, obs_date_on, obs_date_off;
quit;

proc freq data = temp.pt_multievent;
  table ot;
run;

/* 素材 */

proc print data = temp.pt_select(obs = 20);
proc print data = temp.pt_expand(obs = 20);
proc print data = temp.pt_multitx(obs = 20);
proc print data = temp.pt_multievent(obs = 20);
run;



/* 資料合併 */
proc sort data = temp.pt_expand;
  by id;
proc sort data = temp.ins_2;
  by id;
data temp.pt_repeated;
  merge
    temp.pt_expand
    temp.ins_2;
  by id;
run;

proc sort data = temp.pt_repeated;
  by id index_date obs_ym obs_date_on obs_date_off;
proc sort data = temp.pt_multitx;
  by id index_date obs_ym obs_date_on obs_date_off;
proc sort data = temp.pt_multievent;
  by id index_date obs_ym obs_date_on obs_date_off;
data temp.pt_repeated;
  merge
    temp.pt_repeated
    temp.pt_multitx
    temp.pt_multievent;
  by id index_date obs_ym obs_date_on obs_date_off;

  log_win_key = log(win_key);
run;

proc print data = temp.pt_repeated(obs = 20);
run;



/* repeated measurement poisson regression */
proc genmod data = temp.pt_repeated;
   class id insulin(ref = "0") / param = ref;
   model ot = insulin age male / dist = poisson link = log offset = log_win_key;
   repeated subject = id / corr = exch corrw;
   ods output GEEEmpPEst = temp.z_result;
run;

proc print data = temp.z_result;
run;

proc sql;
  select
    exp(estimate) as aIRR,
    exp(LowerCL)  as aIRR_lower,
    exp(UpperCL)  as aIRR_upper,
	ProbZ as p_value
  from temp.z_result
  where Parm = "insulin";
quit;





/* END */
