
##
## Network stats calculator for ARTnet Data
##

## Packages ##
library("tidyverse")
library("EpiModelHIV")
library("ARTnetData")


## Inputs ##
city_name <- "Atlanta"
coef_name <- paste0("city2", city_name)
network_size <- 10000
diss_nodematch <- TRUE
edges_avg_nfrace <- FALSE


## Load Data ##
fn <- paste("data/artnet.NetParam", gsub(" ", "", city_name), "rda", sep = ".")
nstats <- readRDS(file = fn)

fn <- paste("data/artnet.EpiStats", gsub(" ", "", city_name), "rda", sep = ".")
estats <- readRDS(file = fn)


# Demographic Initialization ----------------------------------------------

out <- list()
out$demog <- list()

# Overall network size
num <- network_size

# Population size by race group
race.dist.3cat
props <- race.dist.3cat[which(race.dist.3cat$City == city_name), -1]/100

num.B <- out$demog$num.B <- round(num * props$Black)
num.H <- out$demog$num.H <- round(num * props$Hispanic)
num.W <- out$demog$num.W <- num - num.B - num.H

## Age-sex-specific mortality rates in men by race/ethnicity (B, H, W)
#    in 5-year age increments starting with age 15
ages <- out$demog$ages <- 15:64
asmr.B <- c(0.00124, 0.00213, 0.00252, 0.00286, 0.00349,
            0.00422, 0.00578, 0.00870, 0.01366, 0.02052)
asmr.H <- c(0.00062, 0.00114, 0.00127, 0.00132, 0.00154,
            0.00186, 0.00271, 0.00440, 0.00643, 0.00980)
asmr.W <- c(0.00064, 0.00128, 0.00166, 0.00199, 0.00226,
            0.00272, 0.00382, 0.00591, 0.00889, 0.01266)

# transformed to weekly rates
trans.asmr.B <- 1 - (1 - asmr.B)^(1/52)
trans.asmr.H <- 1 - (1 - asmr.H)^(1/52)
trans.asmr.W <- 1 - (1 - asmr.W)^(1/52)

# Null rate for 0-14, transformed rates, total rate for 65
vec.asmr.B <- c(rep(0, 14), rep(trans.asmr.B, each = 5), 1)
vec.asmr.H <- c(rep(0, 14), rep(trans.asmr.H, each = 5), 1)
vec.asmr.W <- c(rep(0, 14), rep(trans.asmr.W, each = 5), 1)
asmr <- data.frame(age = 1:65, vec.asmr.B, vec.asmr.H, vec.asmr.W)

out$demog$asmr <- asmr

out$demog$city <- gsub(" ", "", city_name)


# Nodal Attribute Initialization ------------------------------------------

out$attr <- list()

# age attributes
attr_age <- runif(num, min = min(ages), max = max(ages) + (51/52))
out$attr$age <- attr_age

attr_sqrt.age <- sqrt(attr_age)
out$attr$sqrt.age <- attr_sqrt.age

age.breaks <- out$demog$age.breaks <- c(0, 25, 35, 45, 55, 65, 100)
attr_age.grp <- cut(attr_age, age.breaks, labels = FALSE)
out$attr$age.grp <- attr_age.grp

# race attribute
attr_race <- apportion_lr(num, 1:3, c(num.B/num, num.H/num, num.W/num), shuffled = TRUE)
out$attr$race <- attr_race

# deg.casl attribute
attr_deg.casl <- apportion_lr(num, 0:3, nstats$main$deg.casl.dist, shuffled = TRUE)
out$attr$deg.casl <- attr_deg.casl

# deg main attribute
attr_deg.main <- apportion_lr(num, 0:2, nstats$casl$deg.main.dist, shuffled = TRUE)
out$attr$deg.main <- attr_deg.main

# deg tot 3 attribute
attr_deg.tot <- apportion_lr(num, 0:3, nstats$inst$deg.tot.dist, shuffled = TRUE)
out$attr$deg.tot <- attr_deg.tot

# risk group
attr_risk.grp <- apportion_lr(num, 1:5, rep(0.2, 5), shuffled = TRUE)
out$attr$risk.grp <- attr_risk.grp

# role class
attr_role.class <- apportion_lr(num, 0:2, nstats$all$role.type, shuffled = TRUE)
out$attr$role.class <- attr_role.class

# diag status
xs <- data.frame(age = attr_age, race.cat3 = attr_race, cityYN = 1)
preds <- predict(estats$hiv.mod, newdata = xs, type = "response")
attr_diag.status <- rbinom(num, 1, preds)
out$attr$diag.status <- attr_diag.status


# 1. Main Model -----------------------------------------------------------

out$main <- list()

## edges
if (edges_avg_nfrace == FALSE) {
  out$main$edges <- (nstats$main$md.main * num) / 2
} else {
  out$main$edges <- sum(unname(table(out$attr$race)) * nstats$main$nf.race)/2
}

## nodefactor("age.grp
nodefactor_age.grp <- table(out$attr$age.grp) * nstats$main$nf.age.grp
out$main$nodefactor_age.grp <- unname(nodefactor_age.grp)

## nodematch("age.grp")
nodematch_age.grp <- nodefactor_age.grp/2 * nstats$main$nm.age.grp
out$main$nodematch_age.grp <- unname(nodematch_age.grp)

## absdiff("age")
absdiff_age <- out$main$edges * nstats$main$absdiff.age
out$main$absdiff_age <- absdiff_age

## absdiff("sqrt.age")
absdiff_sqrt.age <- out$main$edges * nstats$main$absdiff.sqrt.age
out$main$absdiff_sqrt.age <- absdiff_sqrt.age

## nodefactor("race")
nodefactor_race <- table(out$attr$race) * nstats$main$nf.race
out$main$nodefactor_race <- unname(nodefactor_race)

## nodematch("race")
nodematch_race <- nodefactor_race/2 * nstats$main$nm.race
out$main$nodematch_race <- unname(nodematch_race)

## nodematch("race", diff = FALSE)
nodematch_race <- out$main$edges * nstats$main$nm.race_diffF
out$main$nodematch_race_diffF <- unname(nodematch_race)

## nodefactor("deg.casl")
out$main$nodefactor_deg.casl <- num * nstats$main$deg.casl.dist * nstats$main$nf.deg.casl

## concurrent
out$main$concurrent <- num * nstats$main$concurrent

## nodefactor("diag.status")
nodefactor_diag.status <- table(out$attr$diag.status) * nstats$main$nf.diag.status
out$main$nodefactor_diag.status <- unname(nodefactor_diag.status)

## Dissolution
exp.mort <- (mean(trans.asmr.B) + mean(trans.asmr.H) + mean(trans.asmr.W)) / 3
if (diss_nodematch == FALSE) {
  out$main$diss <- dissolution_coefs(dissolution = ~offset(edges),
                                     duration = nstats$main$durs.main.homog$mean.dur.adj,
                                     d.rate = exp.mort)
} else {
  out$main$diss <- dissolution_coefs(dissolution = ~offset(edges) + offset(nodematch("age.grp", diff = TRUE)),
                                     duration = nstats$main$durs.main.byage$mean.dur.adj,
                                     d.rate = exp.mort)
}



# Casual Model ------------------------------------------------------------

out$casl <- list()

## edges
if (edges_avg_nfrace == FALSE) {
  out$casl$edges <- (nstats$casl$md.casl * num) / 2
} else {
  out$casl$edges <- sum(unname(table(out$attr$race)) * nstats$casl$nf.race)/2
}

## nodefactor("age.grp")
nodefactor_age.grp <- table(out$attr$age.grp) * nstats$casl$nf.age.grp
out$casl$nodefactor_age.grp <- unname(nodefactor_age.grp)

## nodematch("age.grp")
nodematch_age.grp <- nodefactor_age.grp/2 * nstats$casl$nm.age.grp
out$casl$nodematch_age.grp <- unname(nodematch_age.grp)

## absdiff("age")
absdiff_age <- out$casl$edges * nstats$casl$absdiff.age
out$casl$absdiff_age <- absdiff_age

## absdiff("sqrt.age")
absdiff_sqrt.age <- out$casl$edges * nstats$casl$absdiff.sqrt.age
out$casl$absdiff_sqrt.age <- absdiff_sqrt.age

## nodefactor("race")
nodefactor_race <- table(out$attr$race) * nstats$casl$nf.race
out$casl$nodefactor_race <- unname(nodefactor_race)

## nodematch("race")
nodematch_race <- nodefactor_race/2 * nstats$casl$nm.race
out$casl$nodematch_race <- unname(nodematch_race)

## nodematch("race", diff = FALSE)
nodematch_race <- out$casl$edges * nstats$casl$nm.race_diffF
out$casl$nodematch_race_diffF <- unname(nodematch_race)


## nodefactor("deg.main")
out$casl$nodefactor_deg.main <- num * nstats$casl$deg.main.dist * nstats$casl$nf.deg.main

## concurrent
out$casl$concurrent <- num * nstats$casl$concurrent

## nodefactor("diag.status")
nodefactor_diag.status <- table(out$attr$diag.status) * nstats$casl$nf.diag.status
out$casl$nodefactor_diag.status <- unname(nodefactor_diag.status)

## Dissolution
if (diss_nodematch == FALSE) {
  out$casl$diss <- dissolution_coefs(dissolution = ~offset(edges),
                                     duration = nstats$casl$durs.casl.homog$mean.dur.adj,
                                     d.rate = exp.mort)
} else {
  out$casl$diss <- dissolution_coefs(dissolution = ~offset(edges) + offset(nodematch("age.grp", diff = TRUE)),
                                     duration = nstats$casl$durs.casl.byage$mean.dur.adj,
                                     d.rate = exp.mort)
}



# One-Time Model ----------------------------------------------------------

out$inst <- list()

## edges
if (edges_avg_nfrace == FALSE) {
  out$inst$edges <- (nstats$inst$md.inst * num) / 2
} else {
  out$inst$edges <- sum(unname(table(out$attr$race)) * nstats$inst$nf.race)/2
}

## nodefactor("age.grp")
nodefactor_age.grp <- table(out$attr$age.grp) * nstats$inst$nf.age.grp
out$inst$nodefactor_age.grp <- unname(nodefactor_age.grp)

## nodematch("age.grp")
nodematch_age.grp <- nodefactor_age.grp/2 * nstats$inst$nm.age.grp
out$inst$nodematch_age.grp <- unname(nodematch_age.grp)

## absdiff("age")
absdiff_age <- out$inst$edges * nstats$inst$absdiff.age
out$inst$absdiff_age <- absdiff_age

## absdiff("sqrt.age")
absdiff_sqrt.age <- out$inst$edges * nstats$inst$absdiff.sqrt.age
out$inst$absdiff_sqrt.age <- absdiff_sqrt.age

## nodefactor("race")
nodefactor_race <- table(out$attr$race) * nstats$inst$nf.race
out$inst$nodefactor_race <- unname(nodefactor_race)

## nodematch("race")
nodematch_race <- nodefactor_race/2 * nstats$inst$nm.race
out$inst$nodematch_race <- unname(nodematch_race)

## nodematch("race", diff = FALSE)
nodematch_race <- out$inst$edges * nstats$inst$nm.race_diffF
out$inst$nodematch_race_diffF <- unname(nodematch_race)

## nodefactor("risk.grp")
nodefactor_risk.grp <- table(out$attr$risk.grp) * nstats$inst$nf.risk.grp
out$inst$nodefactor_risk.grp <- unname(nodefactor_risk.grp)

## nodefactor("deg.tot")
nodefactor_deg.tot <- table(out$attr$deg.tot) * nstats$inst$nf.deg.tot
out$inst$nodefactor_deg.tot <- unname(nodefactor_deg.tot) * nstats$inst$nf.deg.tot

## nodefactor("diag.status")
nodefactor_diag.status <- table(out$attr$diag.status) * nstats$inst$nf.diag.status
out$inst$nodefactor_diag.status <- unname(nodefactor_diag.status)


# Save Out File -----------------------------------------------------------

fns <- strsplit(fn, "[.]")[[1]]
fn.new <- paste(fns[1], "NetStats", fns[3], "rda", sep = ".")

saveRDS(out, file = fn.new)
