### 基本設定 ----

# 載入套件
library(fst)
library(data.table)
library(lubridate)
library(fastDummies)
library(Table1)
library(survival)

# 檔案路徑
data <- "C:/Users/liu/Downloads/course/cross-sectional-case-control-R/data"
temp <- "C:/Users/liu/Downloads/course/cross-sectional-case-control-R/temp"





### 資料處理 ----



# ~ 研究樣本 ----

# 讀取資料
setwd(data)
pt_adm_1a <- read_fst(
  "ipdte2014.fst", as.data.table = TRUE,
  columns = c(
    "id", "in_date", "icd9cm_1", "icd9cm_2", "icd9cm_3", "icd9cm_4", "icd9cm_5", "e_bed_day", "s_bed_day",
    "hosp_id", "fee_ym", "appl_date", "appl_type", "case_type", "seq_no"))
pt_adm_1b <- read_fst(
  "ipdto2014.fst", as.data.table = TRUE,
  columns = c("order_code", "hosp_id", "fee_ym", "appl_date", "appl_type", "case_type", "seq_no"))
head(pt_adm_1a)
head(pt_adm_1b)

# 目標變項
pt_adm_2a <- pt_adm_1a[, .(
  id, 
  in_date = ymd(in_date),
  icd9cm_1, icd9cm_2, icd9cm_3, icd9cm_4, icd9cm_5,
  e_bed_day = as.numeric(e_bed_day), s_bed_day = as.numeric(s_bed_day), 
  hosp_id, fee_ym, appl_date, appl_type, case_type, seq_no)]

pt_adm_2a <- pt_adm_2a[, `:=`(isk = 0, hsk = 0, pneumonia = 0)]

pt_adm_2a <- pt_adm_2a[grepl("^43[34]", icd9cm_1), isk := 1]
pt_adm_2a <- pt_adm_2a[grepl("^43[012]", icd9cm_1), hsk := 1]
pt_adm_2a <- pt_adm_2a[grepl("^48[0-6]", icd9cm_2) | grepl("^48[0-6]", icd9cm_3) | grepl("^48[0-6]", icd9cm_4) | grepl("^48[0-6]", icd9cm_5), pneumonia := 1]

with(pt_adm_2a, lapply(list(isk, hsk, pneumonia), table))
with(pt_adm_2a, lapply(list(e_bed_day, s_bed_day), summary))

# 相關變項
pt_adm_2b <- pt_adm_1b[, .(order_code, hosp_id, fee_ym, appl_date, appl_type, case_type, seq_no)]
pt_adm_2b <- pt_adm_2b[, `:=`(ng_tube = 0, urin_cath = 0)]
pt_adm_2b <- pt_adm_2b[order_code %in% c("47017C", "47018C"), ng_tube := 1]
pt_adm_2b <- pt_adm_2b[order_code %in% c("47013C", "47014C"), urin_cath := 1]
table(pt_adm_2b$ng_tube)
table(pt_adm_2b$urin_cath)

# 費用檔合併醫令檔
pt_adm_2 <- merge(pt_adm_2a, pt_adm_2b, c("hosp_id", "fee_ym", "appl_date", "appl_type", "case_type", "seq_no"))

# 住院歸戶
pt_adm_3 <- pt_adm_2[, lapply(.SD, max, na.rm = T), .SDcols = c("e_bed_day", "s_bed_day", "isk", "hsk", "pneumonia", "ng_tube", "urin_cath"), by = .(id, in_date, hosp_id, fee_ym)]

pt_adm_4a <- pt_adm_3[, lapply(.SD, sum, na.rm = T), .SDcols = c("e_bed_day", "s_bed_day"), by = .(id, in_date, hosp_id)]
pt_adm_4b <- pt_adm_3[, lapply(.SD, max, na.rm = T), .SDcols = c("isk", "hsk", "pneumonia", "ng_tube", "urin_cath"), by = .(id, in_date, hosp_id)]
pt_adm_4 <- merge(pt_adm_4a, pt_adm_4b, c("id", "in_date", "hosp_id"))
pt_adm_4 <- pt_adm_4[, bed_day := s_bed_day + e_bed_day]

# 主診斷為中風的
table(pt_adm_4$isk)
table(pt_adm_4$hsk)
pt_adm_5 <- pt_adm_4[isk == 1 | hsk == 1]
head(pt_adm_5)
with(pt_adm_5, table(hsk, isk))

# 若有不只一次的，只取今年第一次
pt_adm_6 <- pt_adm_5[order(id, in_date, -bed_day)]
pt_adm_6 <- pt_adm_6[, .SD[1], by = .(id)]
head(pt_adm_6)
with(pt_adm_6, table(hsk, isk))

# 儲存資料
setwd(temp)
write_fst(pt_adm_6, "pt_adm.fst", compress = 100)

# 清理環境
rm(list = ls(pattern = "^pt_adm"))
gc()



# ~ 承保資料 ----

# 讀取資料
setwd(data)
ins_1a <- read_fst("enrol2014.fst", as.data.table = TRUE, columns = c("id", "id_s", "id_birth_y", "prem_ym", "id1_amt"))
setwd(temp)
ins_1b <- read_fst("pt_adm.fst", as.data.table = TRUE, columns = c("id", "in_date"))
head(ins_1a)
head(ins_1b)

# 研究樣本所屬資料
ins_1 <- ins_1a[ins_1b, on = .(id), nomatch = 0]

# 找尋住院之前最近一次的承保資料
table(ins_1$prem_ym)
ins_1 <- ins_1[, `:=`(prem_date = ymd(paste0(prem_ym, "01")))]
head(ins_1)

ins_1 <- ins_1[prem_date < in_date]
ins_1 <- ins_1[order(id, -prem_date)][, .SD[1], by = .(id)]
head(ins_1)

# 所需變項
ins_2 <- unique(ins_1[, .(id, in_date, id_s, id_birth_y, id1_amt)])
head(ins_2)

# 出生年類型轉換
class(ins_2$id_birth_y)
ins_2 <- ins_2[, id_birth_y := as.numeric(id_birth_y)][!is.na(id_birth_y)]
class(ins_2$id_birth_y)
summary(ins_2$id_birth_y)

# 投保金額類型轉換
class(ins_2$id1_amt)
ins_2 <- ins_2[, id1_amt := as.numeric(id1_amt)][!is.na(id1_amt)]
class(ins_2$id1_amt)
summary(ins_2$id1_amt)

# 性別
ins_2 <- ins_2[id_s %in% c("1", "2")]
ins_2 <- ins_2[, `:=`(male = 0, female = 0)]
ins_2 <- ins_2[id_s == "1", `:=`(male = 1)]
ins_2 <- ins_2[id_s == "2", `:=`(female = 1)]
table(ins_2$male)
table(ins_2$female)
head(ins_2)

# 計算年齡
ins_2 <- ins_2[, age := year(in_date) - id_birth_y]
summary(ins_2$age)
ins_2$in_date <- NULL
head(ins_2)

# 投保金額級距分類
ins_2 <- ins_2[!is.na(id1_amt)]
summary(ins_2$id1_amt)
ins_2 <- ins_2[, `:=`(ins_amt_gp = cut(id1_amt, c(0, 15840, 25000, 200000), c(1, 2, 3), include.lowest = TRUE))]
table(ins_2$ins_amt_gp)
ins_2 <- dummy_cols(ins_2, select_columns = c("ins_amt_gp"))
head(ins_2)

# 儲存資料
setwd(temp)
write_fst(ins_2, "ins.fst", compress = 100)

# 清理空間
rm(list = ls(pattern = "^ins"))
gc()



# ~ 過去病史 ----

# 讀取資料
setwd(data)
cd <- read_fst(
  "opdte2014.fst", as.data.table = T, 
  columns = c("id", "func_date", "icd9cm_1", "icd9cm_2", "icd9cm_3"))
dd <- read_fst(
  "ipdte2014.fst", as.data.table = T, 
  columns = c("id", "in_date", "icd9cm_1", "icd9cm_2", "icd9cm_3", "icd9cm_4", "icd9cm_5"))
head(cd)
head(dd)

# 日期文字轉換
cd$func_date <- ymd(cd$func_date)
dd$func_date <- ymd(dd$in_date)
dd$in_date <- NULL
head(cd)
head(dd)

# 研究樣本所屬 & index date之前90天的資料
setwd(temp)
hx_1 <- read_fst("pt_adm.fst", as.data.table = T, columns = c("id", "in_date"))
hx_1_cd <- cd[hx_1, on = .(id), nomatch = 0][in_date - 90 <= func_date & func_date < in_date]
hx_1_dd <- dd[hx_1, on = .(id), nomatch = 0][in_date - 90 <= func_date & func_date < in_date]
head(hx_1_cd)
head(hx_1_dd)

# 轉置(melt: wide to long)
hx_2_cd <- melt(hx_1_cd, id.vars = c("id", "func_date"), measure.vars = c("icd9cm_1", "icd9cm_2", "icd9cm_3"), variable.name = "icd", value.name = "codes")
hx_2_dd <- melt(hx_1_dd, id.vars = c("id", "func_date"), measure.vars = c("icd9cm_1", "icd9cm_2", "icd9cm_3", "icd9cm_4", "icd9cm_5"), variable.name = "icd", value.name = "codes")
head(hx_2_cd)
head(hx_2_dd)

# 給予權重
hx_2_cd$weight <- 1
hx_2_dd$weight <- 2
head(hx_2_cd)
head(hx_2_dd)

# 將門診住院堆疊
hx_2 <- rbind(hx_2_cd, hx_2_dd)
head(hx_2)
table(hx_2$weight)

# 標註疾病
hx_3 <- hx_2
hx_3 <- hx_3[, `:=`(dx = "none")]
hx_3 <- hx_3[grepl("^48[0-6]", codes), `:=`(dx = "pneumonia")]
hx_3 <- hx_3[grepl("^43[0-8]", codes), `:=`(dx = "stroke")]
hx_3 <- hx_3[grepl("^250", codes), `:=`(dx = "dm")]
hx_3 <- hx_3[grepl("^40[1-5]", codes), `:=`(dx = "htn")]
hx_3 <- hx_3[grepl("^272", codes), `:=`(dx = "lipoid")]
hx_3 <- hx_3[grepl("^585", codes), `:=`(dx = "ckd")]
hx_3 <- hx_3[grepl("^427", codes), `:=`(dx = "dysrhyth")]
head(hx_3)
table(hx_3$dx)

# 去除與研究無關的診斷紀錄
hx_3 <- hx_3[dx != "none"]
hx_3 <- hx_3[, `:=`(dx = paste0("pre_", dx))]
head(hx_3)
table(hx_3$dx)

# 同一診斷在同一天只算一次
hx_4 <- hx_3
nrow(hx_4)
hx_4 <- hx_4[, .(weight = max(weight)), by = .(id, func_date, dx)]
nrow(hx_4)

# 將病史的權重加總
hx_5 <- hx_4
nrow(hx_5)
hx_5 <- hx_5[, .(weight = sum(weight)), by = .(id, dx)]
nrow(hx_5)

# 至少有1次住院或是2次門診的認定有這個病史
table(hx_5$weight)
hx_5 <- hx_5[weight >= 2][, `:=`(hx = 1)]
table(hx_5$hx)
hx_5$weight <- NULL
head(hx_5)

# 轉置(dcast:long to wide)
hx_6 <- dcast(hx_5, id ~ dx, value.var = "hx", fill = 0)
head(hx_6)

# 儲存資料
setwd(temp)
write_fst(hx_6, "hx.fst", compress = 100)

# 清理
rm(cd, dd)
rm(list = ls(pattern = "hx"))
gc()



# ~ 資料合併 ----

# 讀取資料
setwd(temp)
pt <- read_fst("pt_adm.fst", as.data.table = TRUE)
ins <- read_fst("ins.fst", as.data.table = TRUE)
hx <- read_fst("hx.fst", as.data.table = TRUE)

# 合併資料
pt_merge <- merge(pt, ins, c("id"), all.x = TRUE)
pt_merge <- merge(pt_merge, hx, c("id"), all.x = TRUE)

# 病史補0
pt_merge_i <- pt_merge[, lapply(.SD, function(m){ifelse(is.na(m) == T, 0, m)}), .SDcols = grep("^pre_", colnames(pt_merge)), by = .(id)]
pt_merge[, c(grep("^pre_", colnames(pt_merge)))] <- NULL
pt_merge <- pt_merge[pt_merge_i, on = .(id)]
rm(pt_merge_i)

# 儲存資料
setwd(temp)
write_fst(pt_merge, "pt_merge.fst", compress = 100)

# 清理空間
rm(pt, ins, hx, pt_merge)
gc()



# ~ 納入排除 ----

# 讀取資料
setwd(temp)
pt_merge <- read_fst("pt_merge.fst", as.data.table = TRUE)

# 納入條件 - 4月以後的
nrow(pt_merge)
table(month(pt_merge$in_date))
pt_select <- pt_merge[month(in_date) >= 4]
nrow(pt_select)
table(month(pt_select$in_date))

# 排除條件 - 過去中風史
table(pt_select$pre_stroke)
pt_select <- pt_select[pre_stroke != 1]
nrow(pt_select)

# 排除條件 - 基本資料不齊全
pt_select <- pt_select[id_s %in% c("1", "2") & !(is.na(id_birth_y)) & !(is.na(id1_amt))]
nrow(pt_select)

# 儲存資料
setwd(temp)
write_fst(pt_select, "pt_select.fst", compress = 100)

# 清理空間
rm(pt_merge, pt_select)
gc()



# ~ case-control配對 ----

# 讀取資料
setwd(temp)
pt_unmatch <- read_fst("pt_select.fst", as.data.table = TRUE)

# case    - 住院天數  > 7天
# control - 住院天數 <= 7天
# expose  - hsk vs isk(ref)
# match   - sex, age(<65 or >= 65)

# 住院天數
summary(pt_unmatch$bed_day)
pt_unmatch <- pt_unmatch[, bed_day_7 := 0][bed_day > 7, bed_day_7 := 1]
table(pt_unmatch$bed_day_7)

pt_unmatch <- pt_unmatch[, age_65 := 0][age >= 65, age_65 := 1]
table(pt_unmatch$age_65)

# 住院天數的差異未必是來自於中風本身的影響
# 兩者的性別年齡其實也有點差異
print(pt_unmatch[, .(tot_N = .N, prop_hsk = mean(hsk) * 100, prop_age_65 = mean(age_65) * 100, prop_male = mean(male) * 100), by = .(bed_day_7)][order(-bed_day_7)])

# 拆分為清單物件
# 每一個物件內的特性都相同
pt_unmatch <- split(pt_unmatch, by = c("age_65", "male"))

# 各性別年齡組合當中的人數
lapply(pt_unmatch, function(x){table(x$bed_day_7)})

# 配對
pt_match <- lapply(pt_unmatch, function(xx, rr){
  
  # 範例
  # xx <- pt_unmatch[[2]]
  
  # 配對比例
  rr <- 2
  
  # 配對變項
  xx <- xx[, `:=`(vc = (bed_day_7 == 1), vt = (bed_day_7 == 0))]
  
  # 配對數量
  if ((sum(xx$vt) / sum(xx$vc)) >= rr) {
    # 如果相同配對條件內(age, sex)的control足以被case進行1:r配對
    tt <- sum(xx$vc)
  } else {
    # 如果相同配對條件內(age, sex)的control無法被case進行1:r配對
    tt <- floor(sum(xx$vt) / rr)
  }
  
  # 配對程序
  set.seed(407)
  yy <- xx[, ss := runif(.N), by = .(vt)]
  yy <- yy[order(vt, ss)][, qq := 1:.N, by = .(vt)]
  yy <- yy[(vc == 1 & qq <= tt) | (vt == 1 & qq <= tt * rr)]
  yy <- yy[vt == 1, qq := ceiling(qq / rr)]
  yy <- yy[, gg := paste(age_65, male, qq, sep = "-")]
  
  # 最後處理
  yy <- yy[, `:=`(vc = NULL, vt = NULL, ss = NULL, qq = NULL)]
  return(yy)
})

# 配對完的檔案
pt_match <- rbindlist(pt_match)

# 比較配對前後的特質
print(rbindlist(pt_unmatch)[, .(tot_N = .N, prop_hsk = mean(hsk) * 100, prop_age_65 = mean(age_65) * 100, prop_male = mean(male) * 100), by = .(bed_day_7)][order(-bed_day_7)])
print(pt_match[, .(tot_N = .N, prop_hsk = mean(hsk) * 100, prop_age_65 = mean(age_65) * 100, prop_male = mean(male) * 100), by = .(bed_day_7)][order(-bed_day_7)])

# 儲存資料
setwd(temp)
write_fst(pt_match, "pt_match.fst", compress = 100)

# 清理空間
rm(pt_unmatch)
rm(pt_match)
gc()





### 統計分析 ----



# ~ 讀取資料 ----

# 篩選過後的樣本
setwd(temp)
pt_select <- read_fst("pt_select.fst", as.data.table = TRUE)

# 篩選過後的樣本
setwd(temp)
pt_match <- read_fst("pt_match.fst", as.data.table = TRUE)

# 屬性
pt_select$isk <- factor(pt_select$isk, c(1, 0))
pt_select$hsk <- factor(pt_select$hsk, c(1, 0))
pt_select$pneumonia <- factor(pt_select$pneumonia, c(1, 0))
pt_select$ng_tube <- factor(pt_select$ng_tube, c(1, 0))
pt_select$urin_cath <- factor(pt_select$urin_cath, c(1, 0))

pt_select$pre_dm <- factor(pt_select$pre_dm, c(1, 0))
pt_select$pre_htn <- factor(pt_select$pre_htn, c(1, 0))
pt_select$pre_lipoid <- factor(pt_select$pre_lipoid, c(1, 0))
pt_select$pre_ckd <- factor(pt_select$pre_ckd, c(1, 0))
pt_select$pre_dysrhyth <- factor(pt_select$pre_dysrhyth, c(1, 0))



# ~ 住院期間共病狀況及醫療處置 ----

# table 1
make.table(
  ### 標題 ###
  caption = "Table 1. In-hospital comorbidities and medical precedures",  footer = "MOHW demo data", tspanner = NULL, n.tspanner = NULL,
  ### 資料順序 ###
  dat = pt_select[, .(isk, age, id_s, ins_amt_gp, pneumonia, ng_tube, urin_cath, bed_day)],
  strat = "isk", cgroup = "Stroke type", n.cgroup = c(4),
  colnames = c(" ", "Ischemic stroke", "Hemorrhagic stroke", "Overall"),
  ### 類別變數 ###
  cat.varlist  = c("id_s", "ins_amt_gp", "pneumonia", "ng_tube", "urin_cath"),
  cat.header = c("Sex", "Income premium level", "Pneumonia", "Nasogastric intubation", "Urinary catheterization"),
  cat.rownames = list(
    c("Male", "Female"), 
    c("Financially dependent", "15,840-25,000", "Above 25,000"), 
    c("Yes", "No"), 
    c("Yes", "No"), 
    c("Yes", "No")),
  cat.rmstat = list(c("row", "count", "miss")),
  ### 連續變數 ###
  cont.varlist = c("age", "bed_day"),
  cont.header = c("Age", "Bed day"),
  cont.rmstat  = list(c("count", "miss", "q1q3", "minmax")),
  output = "html")



# ~ 住院天數(>7天)與中風類型之相關性分析 ----

# 描述性統計
make.table(
  # 分析資料
  dat = pt_match[, .(bed_day_7 = factor(bed_day_7, c(1, 0)), id_s, age, age_65, ins_amt_gp, hsk, pre_dm, pre_htn)],
  strat = "bed_day_7", cgroup = "Length of stay", n.cgroup = 4,
  colnames = c("", "<7 day", ">=7 day", "Overall"),
  output = "html", caption = "Table", footer = "MOHW", tspanner = NULL, n.tspanner = NULL,
  # 類別變數
  cat.varlist = c("id_s", "age_65", "ins_amt_gp", "hsk", "pre_dm", "pre_htn"),
  cat.header = c("Sex", "Age group", "Income", "Stroke type", "DM history", "HTN history"),
  cat.rownames = list(
    c("Male", "Female"),
    c("< 65", "Above 65"),
    c("Financially dependent", "15,840-25,000", "Above 25,000"),
    c("Ischemic", "Hemorrhagic"),
    c("No", "Yes"),
    c("No", "Yes")),
  cat.rmstat = list(c("row", "count", "miss")),
  # 數值變數
  cont.varlist = c("age"),
  cont.header = c("Age"),
  cont.rmstat = list(c("count", "miss", "q1q3", "minmax"))
)

# model
mod_1 <- glm(bed_day_7 ~ hsk, data = pt_match, family = binomial("logit"))
mod_2 <- glm(bed_day_7 ~ hsk + ins_amt_gp_1 + ins_amt_gp_3 + pre_dm + pre_htn, data = pt_match, family = binomial("logit"))
mod_3 <- clogit(bed_day_7 ~ hsk + ins_amt_gp_1 + ins_amt_gp_3 + pre_dm + pre_htn + strata(gg), data = pt_match)

# summary
summary(mod_1)
summary(mod_2)
summary(mod_3)

# odds ratio & ci & p value
cbind(
  OR = round(exp(coef(mod_1)), 2),
  round(exp(confint(mod_1)), 2),
  p.value = round(summary(mod_1)$coefficients[, 4], 4)
)

cbind(
  OR = round(exp(coef(mod_2)), 2),
  round(exp(confint(mod_2)), 2),
  p.value = round(summary(mod_2)$coefficients[, 4], 4)
)

cbind(
  OR = round(exp(coef(mod_3)), 2),
  round(exp(confint(mod_3)), 2),
  p.value = round(summary(mod_3)$coefficients[, 5], 4)
)






### END ###