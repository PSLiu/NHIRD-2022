libname data "C:\Users\liu\Downloads\course\cross-sectional-case-control-SAS\data";
libname temp "C:\Users\liu\Downloads\course\cross-sectional-case-control-SAS\temp";




/****************/
/*** ��ƳB�z ***/
/****************/



/*** ��s�˥� ***/

/* Ū����� */
proc sql;
  create table pt_adm_1a as
  select 
    id, in_date, icd9cm_1, icd9cm_2, icd9cm_3, icd9cm_4, icd9cm_5, e_bed_day, s_bed_day,
    hosp_id, fee_ym, appl_date, appl_type, case_type, seq_no
  from data.ipdte2014;
quit;

proc sql;
  create table pt_adm_1b as
  select 
    order_code, hosp_id, fee_ym, appl_date, appl_type, case_type, seq_no
  from data.ipdto2014;
quit;

proc print data = pt_adm_1a(obs = 6);
run;
proc print data = pt_adm_1b(obs = 6);
run;

/* �ؼ��ܶ� */
proc sql;
  create table pt_adm_2a as
  select
    id, input(in_date, yymmdd8.) format yymmdd10. as in_date,
	icd9cm_1, icd9cm_2, icd9cm_3, icd9cm_4, icd9cm_5,
    input(e_bed_day, 5.) as e_bed_day, input(s_bed_day, 5.) as s_bed_day,
	hosp_id, fee_ym, appl_date, appl_type, case_type, seq_no
  from pt_adm_1a;
quit;

proc sql;
  create table pt_adm_2a as
  select 
    *,
	case
      when 
        substr(icd9cm_1, 1, 3) in ("433", "434") then 1 else 0
      end as isk,
	case
      when 
        substr(icd9cm_1, 1, 3) in ("430", "431", "432") then 1 else 0
      end as hsk,
	case
      when 
        substr(icd9cm_2, 1, 3) in ("480", "481", "482", "483", "484", "485", "486") | 
        substr(icd9cm_3, 1, 3) in ("480", "481", "482", "483", "484", "485", "486") | 
        substr(icd9cm_4, 1, 3) in ("480", "481", "482", "483", "484", "485", "486") | 
        substr(icd9cm_5, 1, 3) in ("480", "481", "482", "483", "484", "485", "486") then 1 else 0
      end as pneumonia
  from pt_adm_2a;
quit;

proc freq data = pt_adm_2a;
  table isk hsk pneumonia;
run;

proc means data = pt_adm_2a;
  var e_bed_day s_bed_day;
run;

proc sql;
  create table pt_adm_2b as 
  select 
    *,
	case
      when 
        order_code in ("47017C", "47018C") then 1 else 0
      end as ng_tube,
	case
      when 
        order_code in ("47013C", "47014C") then 1 else 0
      end as urin_cath
  from pt_adm_1b;
quit;

proc freq data = pt_adm_2b;
  table ng_tube urin_cath;
run;

/* �O���ɦX����O�� */
proc sql;
  create table pt_adm_2 as 
  select a.*, b.order_code, b.ng_tube, b.urin_cath
  from pt_adm_2a as a, pt_adm_2b as b
  where 
    a.hosp_id = b.hosp_id & 
    a.fee_ym = b.fee_ym & 
    a.appl_date = b.appl_date & 
    a.appl_type = b.appl_type & 
    a.case_type = b.case_type & 
    a.seq_no = b.seq_no;
quit;

/* ��|�k�� */
proc sql;
  create table pt_adm_3 as
  select
    id, in_date, hosp_id, fee_ym,
    max(e_bed_day) as e_bed_day,
    max(s_bed_day) as s_bed_day,
    max(isk) as isk,
    max(hsk) as hsk,
    max(pneumonia) as pneumonia,
    max(ng_tube) as ng_tube,
    max(urin_cath) as urin_cath
  from pt_adm_2
  group by id, in_date, hosp_id, fee_ym;
quit;

proc sql;
  create table pt_adm_4 as
  select
    id, in_date, hosp_id,
	sum(e_bed_day) + sum(s_bed_day) as bed_day,
    sum(e_bed_day) as e_bed_day,
    sum(s_bed_day) as s_bed_day,
    max(isk) as isk,
    max(hsk) as hsk,
    max(pneumonia) as pneumonia,
    max(ng_tube) as ng_tube,
    max(urin_cath) as urin_cath
  from pt_adm_3
  group by id, in_date, hosp_id;
quit;

/* �D�E�_�������� */
proc freq data = pt_adm_4;
  table isk hsk;
run;

data pt_adm_5;
  set pt_adm_4;
  if (isk = 1) | (hsk = 1);
run;

proc freq data = pt_adm_5;
  table hsk * isk / norow nocol nopercent;
run;

/* �Y�����u�@�����A�u�����~�Ĥ@�� */
proc sort data = pt_adm_5 out = pt_adm_6;
  by id in_date descending bed_day;
run;

data pt_adm_6;
  set pt_adm_6;
  by id;
  if first.id;
run;

proc print data = pt_adm_6(obs = 6);
run;

proc freq data = pt_adm_6;
  table hsk * isk / norow nocol nopercent;
run;

/* �x�s��� */
data temp.pt_adm;
  set pt_adm_6;
run;



/*** �ӫO��� ***/

/* Ū����� */
proc sql;
  create table ins_1a as
  select 
    id, id_s, id_birth_y, prem_ym, id1_amt
  from data.enrol2014;
quit;

proc sql;
  create table ins_1b as
  select 
    id, in_date
  from temp.pt_adm;
quit;

proc print data = ins_1a(obs = 6);
run;

proc print data = ins_1b(obs = 6);
run;

/* ��s�˥����ݸ�� */
proc sql;
  create table ins_1 as
  select a.*, b.in_date
  from ins_1a as a, ins_1b as b
  where a.id = b.id;
quit;

/* ��M��|���e�̪�@�����ӫO��� */
proc sql;
  create table ins_1 as
  select *, input(cat(prem_ym, "01"), yymmdd8.) as prem_date format yymmdd10.
  from ins_1;
quit;

proc sql;
  create table ins_1 as
  select *
  from ins_1
  where prem_date < in_date
  order by id, prem_date desc;
quit;

proc print data = ins_1(obs = 6);
run;

data ins_1;
  set ins_1;
  by id;
  if first.id;
run;

/* �һ��ܶ� */
data ins_2;
  set ins_1;
  keep id in_date id_s id_birth_y id1_amt;
run;

proc contents data = ins_2;
run;

/* �X�ͦ~�����ഫ */
proc sql;
  create table ins_2 as
  select id, in_date, id_s, input(id_birth_y, 4.) as id_birth_y, id1_amt
  from ins_2
  having id_birth_y ^= . & id1_amt ^= .;
quit;

proc contents data = ins_2;
run;

/* �ʧO */
proc sql;
  create table ins_2 as 
  select 
    *, 
    case when id_s = "1" then 1 else 0 end as male, 
    case when id_s = "2" then 1 else 0 end as female
  from ins_2
  where id_s in ("1", "2");
quit;

proc freq data = ins_2;
  table id_s * male * female / list;
run;

proc print data = ins_2(obs = 6);
run;

/* �p��~�� */
proc sql;
  create table ins_2 as 
  select 
    *, 
    year(in_date) - id_birth_y as age
  from ins_2;
quit;

proc means data = ins_2;
  var age;
run;

proc print data = ins_2(obs = 6);
run;

/* ��O���B�ŶZ���� */
data ins_2;
  set ins_2;

  if id1_amt ^= .;

       if 0     <= id1_amt < 15840  then do; ins_amt_gp = 1; ins_amt_gp_1 = 1; ins_amt_gp_2 = 0; ins_amt_gp_3 = 0; end;
  else if 15840 <= id1_amt < 25000  then do; ins_amt_gp = 2; ins_amt_gp_1 = 0; ins_amt_gp_2 = 1; ins_amt_gp_3 = 0; end;
  else if 25000 <= id1_amt < 200000 then do; ins_amt_gp = 3; ins_amt_gp_1 = 0; ins_amt_gp_2 = 0; ins_amt_gp_3 = 1; end;
run;

proc freq data = ins_2;
  table ins_amt_gp * ins_amt_gp_1 * ins_amt_gp_2 * ins_amt_gp_3 / list;
run;

/* �x�s��� */
data temp.ins;
  set ins_2;
run;



/*** �L�h�f�v ***/

/* Ū����� */
proc sql;
  create table cd as
  select 
    id, input(func_date, yymmdd8.) as func_date format yymmdd10., icd9cm_1, icd9cm_2, icd9cm_3
  from data.opdte2014;
quit;

proc sql;
  create table dd as
  select 
    id, input(in_date, yymmdd8.) as func_date format yymmdd10., icd9cm_1, icd9cm_2, icd9cm_3, icd9cm_4, icd9cm_5
  from data.ipdte2014;
quit;

proc print data = cd(obs = 6);
run;

proc print data = dd(obs = 6);
run;

/* ��s�˥����� & index date���e90�Ѫ���� */
proc sql;
  create table hx_1 as
  select 
    id, in_date
  from temp.pt_adm;
quit;

proc sql;
  create table hx_1_cd as 
  select a.*
  from cd as a, hx_1 as b
  where a.id = b.id & (b.in_date - 90 <= a.func_date < b.in_date);
quit;

proc sql;
  create table hx_1_dd as 
  select a.*
  from dd as a, hx_1 as b
  where a.id = b.id & (b.in_date - 90 <= a.func_date < b.in_date);
quit;

proc print data = hx_1_cd(obs = 6);
run;

proc print data = hx_1_dd(obs = 6);
run;

/* ��m(wide to long) */

/* �쪩
proc sort data = hx_1_cd out = hx_2_cd;
  by id func_date;
run;
proc transpose data = hx_2_cd out = hx_2_cd;
  var icd9cm_1 icd9cm_2 icd9cm_3;
  by id func_date;
run; 
*/

data hx_2_cd;
  set 
    hx_1_cd(keep = id func_date icd9cm_1 rename = (icd9cm_1 = codes) where = (codes ^= "")) 
    hx_1_cd(keep = id func_date icd9cm_2 rename = (icd9cm_2 = codes) where = (codes ^= "")) 
    hx_1_cd(keep = id func_date icd9cm_3 rename = (icd9cm_3 = codes) where = (codes ^= ""));
  weight = 1;
run;

data hx_2_dd;
  set 
    hx_1_dd(keep = id func_date icd9cm_1 rename = (icd9cm_1 = codes) where = (codes ^= "")) 
    hx_1_dd(keep = id func_date icd9cm_2 rename = (icd9cm_2 = codes) where = (codes ^= "")) 
    hx_1_dd(keep = id func_date icd9cm_3 rename = (icd9cm_3 = codes) where = (codes ^= "")) 
    hx_1_dd(keep = id func_date icd9cm_4 rename = (icd9cm_4 = codes) where = (codes ^= "")) 
    hx_1_dd(keep = id func_date icd9cm_5 rename = (icd9cm_5 = codes) where = (codes ^= ""));
  weight = 2;
run;

proc print data = hx_2_cd(obs = 6);
run;

proc print data = hx_2_dd(obs = 6);
run;

/* �N���E��|���| */
data hx_2;
  set hx_2_cd hx_2_dd;
run;

proc freq data = hx_2;
  table weight;
run;

/* �е��e�f */
proc sql;
  create table hx_3 as 
  select *,
    case 
      when substr(codes, 1, 3) in ("480", "481", "482", "483", "484", "485", "486") then "pneumonia"
      when substr(codes, 1, 3) in ("430", "431", "432", "433", "434", "435", "436", "437", "438") then "stroke"
      when substr(codes, 1, 3) in ("250") then "dm"
      when substr(codes, 1, 3) in ("401", "402", "403", "404", "405") then "htn"
      when substr(codes, 1, 3) in ("272") then "lipoid"
      when substr(codes, 1, 3) in ("585") then "ckd"
      when substr(codes, 1, 3) in ("427") then "dysrhyth"
	  else "none"
	  end as dx
  from hx_2;
quit;

proc freq data = hx_3;
  table dx;
run;

/* �h���P��s�L�����E�_���� */
data hx_3;
  set hx_3;
  if dx ^= "none";
  dx = cat("pre_", dx);
run;

proc freq data = hx_3;
  table dx;
run;

/* �P�@�E�_�b�P�@�ѥu��@�� */
proc sql;
  create table hx_4 as 
  select id, func_date, dx, max(weight) as weight
  from hx_3
  group by id, func_date, dx;
quit;

/* �N�f�v���v���[�` */
proc sql;
  create table hx_5 as 
  select id, dx, sum(weight) as weight
  from hx_4
  group by id, dx;
quit;

/* �ܤ֦�1����|�άO2�����E���{�w���o�ӯf�v */
data hx_5;
  set hx_5;
  where weight >= 2;
  hx = 1;
run;

proc print data = hx_5(obs = 6);
run;

/* ��m(long to wide) */
proc sort data = hx_5 out = hx_6;
  by id dx;
run;

proc transpose data = hx_6 out = hx_6(drop = _NAME_);
  var hx;
  by id;
  id dx;
run; 

proc print data = hx_6(obs = 6);
run;

data hx_6;
  set hx_6;
  rename 
    pre_strok = pre_stroke
    pre_lipoi = pre_lipoid
    pre_dysrh = pre_dysrhyth
    pre_pneum = pre_pneumonia;
run;

proc freq data = hx_6;
  table pre_htn pre_lipoid pre_dm pre_stroke pre_ckd pre_dysrhyth pre_pneumonia;
run;

/* �x�s��� */
data temp.hx;
  set hx_6;
run;



/*** ��ƦX�� ***/

/* �Ƨ� */
proc sort data = temp.pt_adm;
  by id;
proc sort data = temp.ins;
  by id;
proc sort data = temp.hx;
  by id;
run;

/* �X�� */
data temp.pt_merge;
  merge
    temp.pt_adm(in = a)
    temp.ins
    temp.hx;
 by id;
 if a = 1;
run;

/* ��0 */
proc print data = temp.pt_merge(obs = 6);
  var id in_date pre_htn pre_lipoid pre_dm pre_stroke pre_ckd pre_dysrhyth pre_pneumonia;
run;

data temp.pt_merge;
  set temp.pt_merge;
  array v{*} pre_htn pre_lipoid pre_dm pre_stroke pre_ckd pre_dysrhyth pre_pneumonia;
  do i = 1 to 7;
    if v[i] = . then v[i] = 0;
  end;
  drop i;
run;

proc print data = temp.pt_merge(obs = 6);
  var id in_date pre_htn pre_lipoid pre_dm pre_stroke pre_ckd pre_dysrhyth pre_pneumonia;
run;



/*** �ǤJ�ư� ***/

/* �ǤJ���� - 4��H�᪺ */
data temp.pt_select;
  set temp.pt_merge;
  in_year = year(in_date);
  in_month = month(in_date);
run;

proc freq data = temp.pt_select;
  table in_year in_month;
run;

data temp.pt_select;
  set temp.pt_select;

  if 4 <= in_month;
run;

proc freq data = temp.pt_select;
  table in_month;
run;


/* �ư����� - �L�h�����v */
proc freq data = temp.pt_select;
  table pre_stroke;
run;

data temp.pt_select;
  set temp.pt_select;

  if pre_stroke ^= 1;
run;

proc freq data = temp.pt_select;
  table pre_stroke;
run;


/* �ư����� - �򥻸�Ƥ����� */
data temp.pt_select;
  set temp.pt_select;

  if 
    (id_s not in ("1", "2")) | 
    (id_birth_y = .) | 
    (id1_amt = .) 
    then delete;
run;



/*** case-control�t�� ***/

/* �g�L�ǤJ�P�ư����󪺼˥� */
data pt_unmatch;
  set temp.pt_select;
  bed_day_7 = 0; if bed_day > 7 then bed_day_7 = 1;
  age_65 = 0; if age >= 65 then age_65 = 1;
run;

proc freq data = pt_unmatch;
  table bed_day_7;
run;

/* �y�z�ʲέp */
proc sql;
  select
    bed_day_7,
	count(*) as tot_N,
	mean(hsk) * 100 as  prop_hsk,
	mean(age_65) * 100 as  prop_age_65,
	mean(male) * 100 as  prop_male
  from pt_unmatch
  group by bed_day_7
  order by bed_day_7 desc;
quit;

/* ���աGcase ��|>7�� control <=7�� */
/* ���S�G�X�夤�� vs �ʦ夤��              */
/* �t��G�~��(<65 or >= 65)�B�ʧO */

/* ��ҡG1:1 */
%let rr = 2;

/* �էO�R�W */
proc sql;
  create table pt_match as
  select
    *,
	case when bed_day_7 = 1 then 1 else 0 end as vc,
	case when bed_day_7 = 0 then 1 else 0 end as vt
  from pt_unmatch;
quit;

/* �p��t����󤧦U�h�����O���X��case��control */
proc sql;
  create table pt_match as
  select
    *,
	sum(vc) as vc_sum,
	sum(vt) as vt_sum
  from pt_match
  group by age_65, male;
quit;

/* tt���n�U�h�����˥����̤p��� */
proc sql;
  create table pt_match as
  select
    *,
	case
	  when (vt_sum / vc_sum) >= &rr. 
        then vc_sum
	    else floor(vt_sum / &rr.)
	  end as tt
  from pt_match
  group by age_65, male;
quit;

/* �H���üƥ��� */
proc sql;
  create table pt_match as
  select
    *, ranuni(407) as ss
  from pt_match
  group by age_65, male, vt
  order by age_65, male, vt, ss;
quit;

/* �s�Ǹ� */
data pt_match;
  set pt_match;
  by age_65 male vt;
    if first.vt then qq = 0;
    qq + 1;
run;

/* ���ŦX���󪺰t��˥� */
data pt_match;
  set pt_match;
  if (vc = 1 & qq <= tt) | (vt = 1 & qq <= tt * &rr.);
run;

/* control�ҹ���case���Ǹ� */
data pt_match;
  set pt_match;
  if vt = 1 then qq = ceil(qq / &rr.);
run;

/* �t��h���ܶ� */
data pt_match;
  set pt_match;
  gg = catx("-", age_65, male, qq);
run;



/* �y�z�ʲέp(�t��e) */
proc sql;
  select
    bed_day_7,
	count(*) as tot_N,
	mean(hsk) * 100 as  prop_hsk,
	mean(age_65) * 100 as  prop_age_65,
	mean(male) * 100 as  prop_male
  from pt_unmatch
  group by bed_day_7
  order by bed_day_7 desc;
quit;

/* �y�z�ʲέp(�t���) */
proc sql;
  select
    bed_day_7,
	count(*) as tot_N,
	mean(hsk) * 100 as  prop_hsk,
	mean(age_65) * 100 as  prop_age_65,
	mean(male) * 100 as  prop_male
  from pt_match
  group by bed_day_7
  order by bed_day_7 desc;
quit;

data temp.pt_match;
  set pt_match;
  drop vc vt qq tt qq;
run;






/****************/
/*** �έp���R ***/
/****************/



/* ��|�����@�f���p�������B�m */
proc tabulate data = temp.pt_select;

  class isk hsk pneumonia ng_tube urin_cath / descending;
  class id_s ins_amt_gp;
  var age bed_day;

  table (age), isk * (mean std) / nocellmerge;
  table (age), isk * (median qrange) / nocellmerge;

  table (id_s ins_amt_gp), isk * (n colpctn) / nocellmerge;

  table (pneumonia ng_tube urin_cath), isk * (n colpctn) / nocellmerge;

  table (bed_day), isk * (mean std) / nocellmerge;
  table (bed_day), isk * (median qrange) / nocellmerge;
run;



/* ��|�Ѽ�(>7��)�P���������������ʤ��R */
proc tabulate data = temp.pt_match;

  class bed_day_7 / descending;
  class id_s age_65 ins_amt_gp hsk pre_dm pre_htn;
  var age;

  table (age), bed_day_7 * (mean std) / nocellmerge;
  table (age), bed_day_7 * (median qrange) / nocellmerge;

  table (id_s ins_amt_gp), bed_day_7 * (n colpctn) / nocellmerge;

  table (hsk pre_dm pre_htn), bed_day_7 * (n colpctn) / nocellmerge;
run;



/* �j�k�ҫ����R - univariable */
proc logistic data = temp.pt_match desc;
  model bed_day_7 = hsk;
run;

/* �j�k�ҫ����R - multivariable */
proc logistic data = temp.pt_match desc;
  model bed_day_7 = hsk ins_amt_gp_1 ins_amt_gp_3 pre_dm pre_htn;
run;

/* �j�k�ҫ����R - conditional logistic regression for matched pairs  */
proc logistic data = temp.pt_match desc;
  strata gg;
  model bed_day_7 = hsk ins_amt_gp_1 ins_amt_gp_3 pre_dm pre_htn;
run;
