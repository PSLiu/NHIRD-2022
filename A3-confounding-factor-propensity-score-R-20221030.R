### 基礎設定 ----

# 下載套件(如果還沒下載過的話)
package_need <- c("data.table", "ggplot2", "tableone", "survminer", "MatchIt")
install.packages(package_need, dependencies = T)
rm(package_need)
gc()

# 載入套件
library(data.table)
library(tableone)
library(survival)
library(survminer)
library(ggplot2)
library(MatchIt)
library(survey)

# 建立路徑
temp <- "C:/Users/liu/Downloads/course/confounding-factor-propensity-score"



### 資料檢視 ----

# 讀取資料
setwd(temp)
dt_1 <- fread("demo.csv")

summary(dt_1)

# 兩組基本特性比較
dt_1_baseline_all <- c("male", "age", "htn", "dm", "hyperlipidemia", "malignancy")
dt_1_baseline_cat <- c("male", "htn", "dm", "hyperlipidemia", "malignancy")
dt_1_baseline <- CreateTableOne(
  vars = dt_1_baseline_all, 
  factorVars = dt_1_baseline_cat,
  strata = "noac", data = dt_1, test = FALSE)
print(dt_1_baseline, smd = TRUE)

# 發生率
dt_1_irtable <- dt_1[, .(totN = .N, totEvent = sum(stroke_ot), totFT = round(sum(stroke_ft)), IR = round((sum(stroke_ot) / sum(stroke_ft)) * 100, 2)), by = .(noac)][order(-noac)]
print(dt_1_irtable)

# KM curves & Log-rank test
dt_1_km_model <- survfit(Surv(stroke_ft, stroke_ot) ~ noac, data = dt_1)
dt_1_km <- ggsurvplot(
  fit = dt_1_km_model, data = dt_1,
  palette = c("blue", "red"), censor = F,
  risk.table = T, risk.table.height = 0.3, 
  ylim = c(0.5, 1), break.y.by = 0.1,
  xlim = c(0, 2), break.x.by = 0.5,
  pval = TRUE, pval.coord = c(1.5, 0.6))
print(dt_1_km)

# univariable Cox regression model
dt_1_model_uni <- coxph(Surv(stroke_ft, stroke_ot) ~ noac, data = dt_1)
summary(dt_1_model_uni)

# multivariable Cox regression model
dt_1_model_multi <- coxph(Surv(stroke_ft, stroke_ot) ~ noac + male + age + dm + htn + hyperlipidemia + malignancy, data = dt_1)
summary(dt_1_model_multi)



### 計算PS ----

# 建立模型
dt_1_model_ps <- glm(noac ~ male + age + dm + htn + hyperlipidemia + malignancy, data = dt_1, family = binomial(link = "logit"))
summary(dt_1_model_ps)

# 計算預測機率
dt_1$noac_ps <- predict(dt_1_model_ps, data = dt_1, type = "response")
summary(dt_1$noac_ps)

# 評估PS在兩組的分布
ggplot(dt_1, aes(x = noac_ps, fill = factor(noac))) +
  geom_histogram(
    position = "identity", alpha = 0.5, 
    breaks = seq(from = 0, to = 1, by = 0.05), binwidth = 0.05, color = "black")



### 使用PSM ----

dt_2 <- dt_1

# PSM
dt_2 <- matchit(noac ~ male + age + dm + htn + hyperlipidemia + malignancy, data = dt_1, caliper = 0.2, ratio = 1)
dt_2 <- match.data(dt_2)

# 配對過後的baseline table
dt_2_baseline_all <- c("male", "age", "htn", "dm", "hyperlipidemia", "malignancy")
dt_2_baseline_cat <- c("male", "htn", "dm", "hyperlipidemia", "malignancy")
dt_2_baseline <- CreateTableOne(
  vars = dt_2_baseline_all, 
  factorVars = dt_2_baseline_cat,
  strata = "noac", data = dt_2, test = FALSE)
print(dt_2_baseline, smd = TRUE)

# 發生率
dt_2_irtable <- dt_2[, .(totN = .N, totEvent = sum(stroke_ot), totFT = round(sum(stroke_ft)), IR = round((sum(stroke_ot) / sum(stroke_ft)) * 100, 2)), by = .(noac)][order(-noac)]
print(dt_2_irtable)

# KM curves
dt_2_km_model <- survfit(Surv(stroke_ft, stroke_ot) ~ noac, data = dt_2)
dt_2_km <- ggsurvplot(fit = dt_2_km_model, data = dt_2,
                      palette = c("blue", "red"), censor = F,
                      risk.table = T, risk.table.height = 0.3, 
                      ylim = c(0.5, 1), break.y.by = 0.1,
                      xlim = c(0, 2), break.x.by = 0.5,
                      pval = TRUE, pval.coord = c(1.5, 0.6))
print(dt_2_km)

# univariable Cox regression model accounting for matched pair
dt_2_model_uni <- coxph(Surv(stroke_ft, stroke_ot) ~ noac + strata(subclass), data = dt_2)
summary(dt_2_model_uni)



### 使用IPTW ----

dt_3 <- dt_1

# marginal prevalence
dt_3 <- dt_3[, `:=`(noac_ep = mean(noac))]
summary(dt_3$noac_ep)

# IPTW
dt_3 <- dt_3[, `:=`(iptw = ((noac * noac_ep) / noac_ps) + (((1 - noac) * (1 - noac_ep)) / (1 - noac_ps)))]
summary(dt_3$iptw)

# 將樣本進行加權
dt_3_weighted <- svydesign(ids = ~ 1, data = dt_3, weights = ~ iptw)

# 加權過後的baseline table
dt_3_baseline_all <- c("male", "age", "htn", "dm", "hyperlipidemia", "malignancy")
dt_3_baseline_cat <- c("male", "htn", "dm", "hyperlipidemia", "malignancy")
dt_3_baseline <- svyCreateTableOne(
  vars = dt_3_baseline_all, 
  factorVars = dt_3_baseline_cat,
  strata = "noac", data = dt_3_weighted, test = FALSE)
print(dt_3_baseline, smd = TRUE)

# 發生率
dt_3_irtable <- dt_3[, .(totN = round(sum(iptw)), totEvent = round(sum(stroke_ot * iptw)), totFT = round(sum(stroke_ft * iptw)), IR = round((sum(stroke_ot * iptw) / sum(stroke_ft * iptw)) * 100, 2)), by = .(noac)][order(-noac)]
print(dt_3_irtable)

# KM curves
dt_3_km_model <- survfit(Surv(stroke_ft, stroke_ot) ~ noac, data = dt_3, weights = iptw)
dt_3_km <- ggsurvplot(fit = dt_3_km_model, data = dt_3,
                      palette = c("blue", "red"), censor = F,
                      risk.table = T, risk.table.height = 0.3, 
                      ylim = c(0.5, 1), break.y.by = 0.1,
                      xlim = c(0, 2), break.x.by = 0.5,
                      pval = TRUE, pval.coord = c(1.5, 0.6))
print(dt_3_km)

# univariable Cox regression model
dt_3_model_uni <- coxph(Surv(stroke_ft, stroke_ot) ~ noac, data = dt_3, weights = iptw)
summary(dt_3_model_uni)



### 結果比較 ----

# baseline table
print(dt_1_baseline, smd = TRUE)
print(dt_2_baseline, smd = TRUE)
print(dt_3_baseline, smd = TRUE)

# incidence rate
print(dt_1_irtable)
print(dt_2_irtable)
print(dt_3_irtable)

# KM plot
print(dt_1_km)
print(dt_2_km)
print(dt_3_km)

# Cox model estimate
summary(dt_1_model_multi)
summary(dt_2_model_uni)
summary(dt_3_model_uni)



# reference

# https://cran.r-project.org/web/packages/tableone/vignettes/smd.html





### END ###
### Peter Pin-Sung Liu
### psliu520@gmail.com