# 本次課程所使用套件
install.packages(c("fst", "data.table", "lubridate", "fastDummies", "survminer", "stringr", "gee"), dependencies = T)

### 研究問題
### 糖尿病人在使用胰島素的時候，是否會較容易發生低血糖

### 基本設定 ----

# 載入套件
library(fst)
library(data.table)
library(lubridate)
library(fastDummies)
library(survival)
library(survminer)
library(stringr)
library(gee)

# 檔案路徑
data <- "C:/Users/liu/Downloads/course/cohort-repeated-measurement-R/data"
temp <- "C:/Users/liu/Downloads/course/cohort-repeated-measurement-R/temp"





### 資料處理 ----



# ~ 研究樣本 ----

# 費用申報資料
setwd(data)
pt_1a_opdte <- read_fst(
  path = "opdte2014.fst", as.data.table = TRUE,
  columns = c("id", "func_date", "func_type", "prsn_id", "drug_day", "hosp_id", "fee_ym", "appl_type", "appl_date", "case_type", "seq_no"))
head(pt_1a_opdte)

pt_1b_druge <- read_fst(
  path = "druge2014.fst", as.data.table = TRUE,
  columns = c("id", "func_date", "r_hosp_id", "func_type", "prsn_id", "drug_day", "hosp_id", "fee_ym", "appl_type", "appl_date", "case_type", "seq_no"))
head(pt_1b_druge)

# 轉換日期屬性
class(pt_1a_opdte$func_date)
class(pt_1b_druge$func_date)
pt_1a_opdte <- pt_1a_opdte[, func_date := ymd(func_date)]
pt_1b_druge <- pt_1b_druge[, func_date := ymd(func_date)]
class(pt_1a_opdte$func_date)
class(pt_1b_druge$func_date)

# 轉換用藥天數屬性
class(pt_1a_opdte$drug_day)
class(pt_1b_druge$drug_day)
pt_1a_opdte <- pt_1a_opdte[, drug_day := as.numeric(drug_day)]
pt_1b_druge <- pt_1b_druge[, drug_day := as.numeric(drug_day)]
class(pt_1a_opdte$drug_day)
class(pt_1b_druge$drug_day)

# 醫令申報資料
setwd(data)
pt_1a_opdto <- read_fst(
  path = "opdto2014.fst", as.data.table = TRUE,
  columns = c("drug_no", "hosp_id", "fee_ym", "appl_type", "appl_date", "case_type", "seq_no"))
head(pt_1a_opdto)

pt_1b_drugo <- read_fst(
  path = "drugo2014.fst", as.data.table = TRUE,
  columns = c("drug_no", "hosp_id", "fee_ym", "appl_type", "appl_date", "case_type", "seq_no"))
head(pt_1b_drugo)

# 目標藥物清單
setwd(temp)
pt_1c_drug <- fread("drug_list.csv", skip = 1, encoding = "UTF-8")
head(pt_1c_drug)

pt_1c_drug <- pt_1c_drug[grep("^A10", atc_code)]
pt_1c_drug <- unique(pt_1c_drug[, .(drug_no, atc_code)])
pt_1c_drug <- pt_1c_drug[, `:=`(dmdrug = 1)]
pt_1c_drug <- pt_1c_drug[, insulin := 0][grep("^A10A", atc_code), insulin := 1]
table(pt_1c_drug$insulin)

# 保留目標藥物處方
pt_1a <- merge.data.table(pt_1a_opdto, pt_1c_drug, by = c("drug_no"))
pt_1b <- merge.data.table(pt_1b_drugo, pt_1c_drug, by = c("drug_no"))
head(pt_1a)
head(pt_1b)

# 整合就診資料
pt_1a <- merge.data.table(pt_1a_opdte, pt_1a, by = c("hosp_id", "fee_ym", "appl_type", "appl_date", "case_type", "seq_no"))
pt_1b <- merge.data.table(pt_1b_druge, pt_1b, by = c("hosp_id", "fee_ym", "appl_type", "appl_date", "case_type", "seq_no"))
head(pt_1a)
head(pt_1b)

# 歸戶就診資料
pt_2a <- pt_1a[, .(drug_day = max(drug_day), insulin = max(insulin)), by = .(id, func_date, hosp_id, prsn_id, fee_ym, appl_type, appl_date, case_type, seq_no)]
pt_2a <- pt_2a[, .(drug_day = sum(drug_day), insulin = max(insulin)), by = .(id, func_date, hosp_id, prsn_id)]

pt_2b <- pt_1b[, .(drug_day = max(drug_day), insulin = max(insulin)), by = .(id, func_date, r_hosp_id, prsn_id, hosp_id, fee_ym, appl_type, appl_date, case_type, seq_no)]
pt_2b <- pt_2b[, .(drug_day = sum(drug_day), insulin = max(insulin)), by = .(id, func_date, r_hosp_id, prsn_id)]
setnames(pt_2b, "r_hosp_id", "hosp_id")

pt_2 <- rbind(pt_2a, pt_2b)
pt_2 <- pt_2[, .(drug_day = sum(drug_day), insulin = max(insulin)), by = .(id, func_date, hosp_id, prsn_id)][order(id, func_date, hosp_id, prsn_id)]

pt_2 <- pt_2[, .(id, hosp_id, prsn_id, insulin, start_date = func_date, end_date = func_date + drug_day - 1, drug_day)]
pt_2 <- pt_2[order(id, start_date)]

head(pt_2)
table(pt_2$insulin)
mean(pt_2$insulin)
summary(pt_2$drug_day)

# 儲存資料
setwd(temp)
write_fst(pt_2, "pt_episode.fst")

# 新發糖尿病人
pt_3 <- pt_2[, .(id, index_date = start_date, insulin)]
pt_3 <- pt_3[order(id, index_date)]
View(pt_3)
nrow(pt_3)
pt_3 <- pt_3[, .SD[1], by = .(id)]
nrow(pt_3)
table(month(pt_3$index_date)) 
# 因為模擬檔人數限制，本處就先不限定"今年新發個案"，未來在研究當中需要留意
table(pt_3$insulin)

# 儲存資料
setwd(temp)
write_fst(pt_3, "pt_first.fst")

# 整理環境
rm(list = ls(pattern = "^pt"))
gc()



# ~ 目標結果 ----

# 研究樣本
setwd(temp)
xt_0 <- read_fst("pt_first.fst", as.data.table = TRUE, columns = c("id"))

# 費用申報資料
setwd(data)
xt_1_opdte <- read_fst(
  path = "opdte2014.fst", as.data.table = TRUE,
  columns = c("id", "func_date", "icd9cm_1", "icd9cm_2", "icd9cm_3", "func_type", "case_type"))
head(xt_1_opdte)
xt_1_opdte <- xt_1_opdte[case_type == "02" | func_type == "22"]

xt_1_ipdte <- read_fst(
  path = "ipdte2014.fst", as.data.table = TRUE,
  columns = c("id", "in_date", "icd9cm_1", "icd9cm_2", "icd9cm_3", "icd9cm_4", "icd9cm_5"))
setnames(xt_1_ipdte, "in_date", "func_date")
head(xt_1_ipdte)

# 保留研究樣本資料
nrow(xt_1_opdte)
xt_1_opdte <- merge.data.table(xt_1_opdte, xt_0, c("id"))
nrow(xt_1_opdte)

nrow(xt_1_ipdte)
xt_1_ipdte <- merge.data.table(xt_1_ipdte, xt_0, c("id"))
nrow(xt_1_ipdte)

# 轉換日期屬性
class(xt_1_opdte$func_date)
class(xt_1_ipdte$func_date)
xt_1_opdte <- xt_1_opdte[, func_date := ymd(func_date)]
xt_1_ipdte <- xt_1_ipdte[, func_date := ymd(func_date)]
class(xt_1_opdte$func_date)
class(xt_1_ipdte$func_date)

# 資料轉置
xt_2_opdte <- melt(xt_1_opdte, c("id", "func_date"), c("icd9cm_1", "icd9cm_2", "icd9cm_3"), "icd", "code")
xt_2_ipdte <- melt(xt_1_ipdte, c("id", "func_date"), c("icd9cm_1", "icd9cm_2", "icd9cm_3", "icd9cm_4", "icd9cm_5"), "icd", "code")

# 資料堆疊
xt_2 <- rbind(xt_2_opdte, xt_2_ipdte)

setnames(xt_2, "func_date", "ot_date")

# 目標結果 - hypoglycemia
xt_3 <- xt_2
xt_3 <- xt_3[grepl("^251[0–2]", code)]

# 歸戶
xt_3 <- unique(xt_3[, .(id, ot_date)])
xt_3$ot <- 1
head(xt_3)

# 儲存資料
setwd(temp)
write_fst(xt_3, "xt_every.fst", compress = 100)

# 首次事件
xt_4 <- xt_3
xt_4 <- xt_4[order(id, ot_date)]
xt_4 <- xt_4[, .SD[1], by = .(id)]
head(xt_4)

# 儲存資料
setwd(temp)
write_fst(xt_4, "xt_first.fst", compress = 100)

# 清理環境
rm(list = ls(pattern = "^xt_"))
gc()



# ~ 承保資料 ----

# 研究樣本
setwd(temp)
ins_0 <- read_fst("pt_first.fst", as.data.table = TRUE, columns = c("id", "index_date"))

# 讀取資料
setwd(data)
ins_1 <- read_fst("enrol2014.fst", as.data.table = TRUE, columns = c("id", "id_s", "id_birth_y", "prem_ym", "id1_amt"))
head(ins_1)

# 研究樣本所屬資料
nrow(ins_1)
ins_1 <- merge.data.table(ins_1, ins_0, c("id"))
nrow(ins_1)

# 找尋index date之前最近一次的承保資料
ins_2 <- ins_1
table(ins_2$prem_ym)
ins_2 <- ins_2[, `:=`(prem_date = ymd(paste0(prem_ym, "01")))]
head(ins_2)

ins_2 <- ins_2[prem_date < index_date]
ins_2 <- ins_2[order(id, -prem_date)][, .SD[1], by = .(id)]
head(ins_2)

# 所需變項
ins_2 <- unique(ins_2[, .(id, index_date, id_s, id_birth_y, id1_amt)])
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
ins_2 <- ins_2[, age := year(index_date) - id_birth_y]
summary(ins_2$age)
ins_2$index_date <- NULL
head(ins_2)

# 投保金額級距分類
ins_2 <- ins_2[!is.na(id1_amt)]
summary(ins_2$id1_amt)
ins_2 <- ins_2[, `:=`(ins_amt_gp = cut(id1_amt, c(0, 15840, 25000, 45000, 200000), c(1, 2, 3, 4), include.lowest = TRUE))]
table(ins_2$ins_amt_gp)
ins_2 <- dummy_cols(ins_2, select_columns = c("ins_amt_gp"))
head(ins_2)

# 儲存資料
setwd(temp)
write_fst(ins_2, "ins_first.fst", compress = 100)

# 清理空間
rm(list = ls(pattern = "^ins"))
gc()



# ~ 過去病史 ----

# 研究樣本
setwd(temp)
hx_0 <- read_fst("pt_first.fst", as.data.table = TRUE, columns = c("id", "index_date"))

# 讀取資料
setwd(data)
hx_1_opdte <- read_fst(
  "opdte2014.fst", as.data.table = T, 
  columns = c("id", "func_date", "icd9cm_1", "icd9cm_2", "icd9cm_3"))
hx_1_ipdte <- read_fst(
  "ipdte2014.fst", as.data.table = T, 
  columns = c("id", "in_date", "icd9cm_1", "icd9cm_2", "icd9cm_3", "icd9cm_4", "icd9cm_5"))
head(hx_1_opdte)
head(hx_1_ipdte)

# 日期文字轉換
hx_1_opdte$func_date <- ymd(hx_1_opdte$func_date)
hx_1_ipdte$func_date <- ymd(hx_1_ipdte$in_date)
hx_1_ipdte$in_date <- NULL
head(hx_1_opdte)
head(hx_1_ipdte)

# 研究樣本所屬 & index date之前90天的資料
hx_1_opdte <- hx_1_opdte[hx_0, on = .(id), nomatch = 0][index_date - 90 <= func_date & func_date < index_date]
hx_1_ipdte <- hx_1_ipdte[hx_0, on = .(id), nomatch = 0][index_date - 90 <= func_date & func_date < index_date]
head(hx_1_opdte)
head(hx_1_ipdte)

# 轉置(melt: wide to long)
hx_2_opdte <- melt(hx_1_opdte, id.vars = c("id", "func_date"), measure.vars = c("icd9cm_1", "icd9cm_2", "icd9cm_3"), variable.name = "icd", value.name = "code")
hx_2_ipdte <- melt(hx_1_ipdte, id.vars = c("id", "func_date"), measure.vars = c("icd9cm_1", "icd9cm_2", "icd9cm_3", "icd9cm_4", "icd9cm_5"), variable.name = "icd", value.name = "code")
head(hx_2_opdte)
head(hx_2_ipdte)

# 給予權重
hx_2_opdte$weight <- 1
hx_2_ipdte$weight <- 2
head(hx_2_opdte)
head(hx_2_ipdte)

# 將門診住院堆疊
hx_2 <- rbind(hx_2_opdte, hx_2_ipdte)
head(hx_2)
table(hx_2$weight)

# 去除重複
hx_3 <- hx_2
hx_3 <- hx_3[, .(weight = max(weight)), by = .(id, func_date, code)]
hx_3 <- hx_3[code != ""]

# 標註疾病
hx_3 <- hx_3[, `:=`(dx = "none")]
hx_3 <- hx_3[grepl("^48[0-6]", code), `:=`(dx = "pneumonia")]
hx_3 <- hx_3[grepl("^43[0-8]", code), `:=`(dx = "stroke")]
hx_3 <- hx_3[grepl("^40[1-5]", code), `:=`(dx = "htn")]
hx_3 <- hx_3[grepl("^272", code), `:=`(dx = "lipoid")]
hx_3 <- hx_3[grepl("^585", code), `:=`(dx = "ckd")]
hx_3 <- hx_3[grepl("^427", code), `:=`(dx = "dysrhyth")]
head(hx_3)
table(hx_3$dx)

# 去除與研究無關的診斷紀錄
hx_3 <- hx_3[dx != "none"]
head(hx_3)
table(hx_3$dx)

# 將病史的權重加總
hx_4 <- hx_3
nrow(hx_4)
hx_4 <- hx_4[, .(weight = sum(weight)), by = .(id, dx)]
nrow(hx_4)

# 至少有1次住院或是2次門診的認定有這個病史
table(hx_4$weight)
hx_4 <- hx_4[weight >= 2][, `:=`(hx = 1)]
table(hx_4$hx)
hx_4$weight <- NULL
head(hx_4)

# 轉置(dcast:long to wide)
hx_5 <- dcast(hx_4, id ~ dx, value.var = "hx", fill = 0)
head(hx_5)

# 儲存資料
setwd(temp)
write_fst(hx_5, "hx_first.fst", compress = 100)

# 清理
rm(list = ls(pattern = "hx"))
gc()



# ~ 資料合併 ----

# 讀取資料
setwd(temp)
pt <- read_fst("pt_first.fst", as.data.table = TRUE)
xt <- read_fst("xt_first.fst", as.data.table = TRUE)
ins <- read_fst("ins_first.fst", as.data.table = TRUE)
hx <- read_fst("hx_first.fst", as.data.table = TRUE)

head(pt)
head(xt)
head(ins)
head(hx)

# 合併資料
pt_merge <- merge(pt, xt, c("id"), all.x = TRUE)
pt_merge <- merge(pt_merge, ins, c("id"), all.x = TRUE)
pt_merge <- merge(pt_merge, hx, c("id"), all.x = TRUE)

# outcome補0
pt_merge <- pt_merge[is.na(ot_date) | is.na(ot), `:=`(ot = 0, ot_date = ymd("20141231"))]
table(pt_merge$ot)

pt_merge <- pt_merge[, ft := as.numeric(ot_date - index_date)]

# 病史補0
cc <- c("ckd", "dysrhyth", "htn", "lipoid", "pneumonia", "stroke")
pt_merge[, cc] <- pt_merge[, lapply(.SD, function(m){ifelse(is.na(m) == T, 0, m)}), .SDcols = cc, by = .(id)][, id := NULL]

head(pt_merge)

# 儲存資料
setwd(temp)
write_fst(pt_merge, "pt_merge_first.fst", compress = 100)

# 清理空間
rm(pt, xt, ins, hx, pt_merge, cc)
gc()



# ~ 納入排除 ----

# 讀取資料
setwd(temp)
pt_merge <- read_fst("pt_merge_first.fst", as.data.table = TRUE)

# 開始納入排除條件
pt_select <- pt_merge

# 排除條件 - 過去低血糖病史
table(pt_select$ot)
pt_select <- pt_select[!(ot_date <= index_date)]
nrow(pt_select)
table(pt_select$ot)

# 排除條件 - 基本資料不齊全
pt_select <- pt_select[id_s %in% c("1", "2") & !(is.na(id_birth_y)) & !(is.na(id1_amt))]
nrow(pt_select)

# 儲存資料
setwd(temp)
write_fst(pt_select, "pt_select.fst", compress = 100)

# 清理空間
rm(pt_merge, pt_select)
gc()



# ~ 存活分析 ----

# 分析樣本
setwd(temp)
pt_select <- read_fst("pt_select.fst", as.data.table = TRUE)

table(pt_select$ot)
summary(pt_select$ft)

with(pt_select, table(ot, insulin))

with(pt_select, lapply(list(ckd, dysrhyth, htn, lipoid, pneumonia, stroke), mean))



# 資料描述

# 比較兩組事件比率
print(pt_select[, .(totN = .N, totEvent = sum(ot)), by = .(insulin)][order(-insulin)])

# 比較兩組追蹤時間
print(pt_select[, .(totN = .N, totFU = sum(ft), minFU = min(ft), maxFU = max(ft)), by = .(insulin)][order(-insulin)])

# 比較兩組事件發生率(incidence rate, IR)
print(pt_select[, .(totN = .N, totEvent = sum(ot), totFU = sum(ft), IR = round((sum(ot)/sum(ft)) * 100000, 2)), by = .(insulin)][order(-insulin)])



# 組間比較

# 生存模型
f1a <- survfit(Surv(ft, ot) ~ insulin, data = pt_select)

# 生命表
summary(f1a, times = seq(from = 0, to = 366, by = 60))

# log-rank test
survdiff(Surv(ft, ot) ~ insulin, data = pt_select)

# KM curves
ggsurvplot(
  f1a, pt_select,
  palette = c("blue", "red"), 
  risk.table = T, risk.table.height = 0.3, 
  ylim = c(0.94, 1), break.y.by = 0.02,
  xlim = c(0, 366), break.x.by = 60,
  pval = TRUE, pval.coord = c(300, 0.98), 
  legend = c(0.85, 0.2), legend.title = "Insulin at begin", legend.labs = c("No", "Yes")
)



# 迴歸分析

# 暴露與事件之單變項Cox迴歸分析
m1a <- coxph(Surv(ft, ot) ~ insulin, data = pt_select)
summary(m1a)

# 暴露與事件之多變項Cox迴歸分析
m1b <- coxph(Surv(ft, ot) ~ insulin + age + male + ins_amt_gp_2 + ins_amt_gp_3 + ins_amt_gp_4 + htn, data = pt_select)
summary(m1b)

# Cox proportional hazard assumption text
cox.zph(m1b)

# 清理空間
rm(f1a, m1a, m1b, pt_select)





### 時間相依變數 ----

# ID X Y
# ******
# A1 1 1
# A2 0 0

# ID T X Y
# ********
# A1 1 1 0
# A1 2 1 1
# A1 3 0 0
# A2 1 0 0
# A2 2 0 0
# A2 3 1 1



# ~ 資料架構 ----

# 讀取資料
setwd(temp)
ps <- read_fst("pt_select.fst", as.data.table = TRUE)
pt <- read_fst("pt_episode.fst", as.data.table = TRUE) # 這個不一樣
xt <- read_fst("xt_every.fst", as.data.table = TRUE) # 這個不一樣
ins <- read_fst("ins_first.fst", as.data.table = TRUE)
hx <- read_fst("hx_first.fst", as.data.table = TRUE)

head(ps)
head(pt)
head(xt)
head(ins)
head(hx)

print(pt[id == unique(pt[insulin == 1]$id)[1]]) # 後面才開始用insulin
print(pt[id == unique(pt[insulin == 1]$id)[5]]) # 後面停止使用insulin
print(pt[id == unique(pt[insulin == 1]$id)[7]]) # 一直都是使用insulin



# ~ 觀察人月 ----

pt_head <- ps
pt_head <- pt_head[, .(id, index_date, win_key = 1)]

pt_window <- data.table(
  win_key = 1,
  obs_date = seq(from = ymd("20140101"), to = ymd("20141231"), by = 1)
)
head(pt_window)

pt_window$obs_ym <- substr(paste0(format(pt_window$obs_date, "%Y%m%d")), 1, 6)
head(pt_window)

pt_window <- pt_window[, .(obs_date_on = min(obs_date), obs_date_off = max(obs_date)), by = .(win_key, obs_ym)]
head(pt_window)

head(pt_head)
head(pt_window, 12)

pt_expand <- merge(pt_head, pt_window, by = c("win_key"), allow.cartesian = TRUE)
head(pt_expand)
nrow(pt_expand)
pt_expand <- pt_expand[!(obs_date_off < index_date)] # 排除開始用藥之前的月份
nrow(pt_expand)
head(pt_expand)
head(pt_expand[500:1000], 30)



# ~ 每人每月處理狀況 ----

pt_multitx <- pt_expand
pt_multitx <- merge(pt_multitx, pt[, .(id, insulin, start_date, end_date)], by = c("id"), allow.cartesian = TRUE)
nrow(pt_multitx)
head(pt_multitx)
table(pt_multitx$insulin)

pt_multitx <- pt_multitx[insulin == 1 & !(obs_date_on <= end_date & start_date <= obs_date_off), `:=`(insulin = 0)]
nrow(pt_multitx)
head(pt_multitx)
table(pt_multitx$insulin)

pt_multitx <- pt_multitx[, .(insulin = max(insulin)), by = .(id, index_date, obs_ym, obs_date_on, obs_date_off)]
nrow(pt_multitx)
head(pt_multitx, 50)

table(pt_multitx$insulin)



# ~ 每人每月發生事件 ----

pt_multievent <- pt_expand
pt_multievent <- merge(pt_multievent, xt, by = c("id"), all.x = TRUE, allow.cartesian = TRUE)
pt_multievent <- pt_multievent[is.na(ot), `:=`(ot = 0, ot_date = ymd(20150101))]
nrow(pt_multievent)
head(pt_multievent)
table(pt_multievent$ot)

pt_multievent <- pt_multievent[ot == 1 & !((obs_date_on <= ot_date & ot_date <= obs_date_off)), `:=`(ot = 0)]
nrow(pt_multievent)
head(pt_multievent)
table(pt_multievent$ot)

pt_multievent <- pt_multievent[, .(ot = sum(ot)), by = .(id, index_date, obs_ym, obs_date_on, obs_date_off)]
nrow(pt_multitx)
table(pt_multievent$ot)



head(ps)
head(pt_expand)
head(pt_multitx)
head(pt_multievent)



# ~ 資料合併 ----

pt_repeated <- pt_expand
pt_repeated <- merge(pt_repeated, ins, by = c("id"))
pt_repeated <- merge(pt_repeated, pt_multitx, by = c("id", "index_date", "obs_ym", "obs_date_on", "obs_date_off"))
pt_repeated <- merge(pt_repeated, pt_multievent, by = c("id", "index_date", "obs_ym", "obs_date_on", "obs_date_off"))

head(pt_repeated)



# ~ poisson regression ----

pt_repeated$id <- factor(pt_repeated$id)

m2 <- gee(
  ot ~ insulin + age + male + ins_amt_gp_2 + ins_amt_gp_3 + ins_amt_gp_4 + offset(log(win_key)),
  id = id,
  data = pt_repeated,
  family = poisson,
  corstr = "exchangeable"
)
summary(m2)

model_coef <- coef(summary(m2))[["insulin", "Estimate"]]
model_std  <- coef(summary(m2))[["insulin", "Robust S.E."]]
model_out <- paste(
  round(exp(model_coef), 2), 
  round(exp(model_coef - 1.96 * model_std), 2), 
  round(exp(model_coef + 1.96 * model_std), 2))
print(model_out)





### END ###