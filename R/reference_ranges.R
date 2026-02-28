# Feline reference ranges for lab values
# Sources: IDEXX VetConnect PLUS, CVCA clinical reports

feline_reference_ranges <- data.frame(
  analyte = c(
    "BUN", "Creatinine", "SDMA", "Potassium", "Sodium", "Chloride",
    "Calcium", "Phosphorus", "ALT", "AST", "ALP", "GGT",
    "Glucose", "Total Protein", "Albumin", "Globulin",
    "Cholesterol", "Hematocrit", "WBC", "Platelets",
    "Total T4", "Fructosamine", "Bilirubin Total"
  ),
  unit = c(
    "mg/dL", "mg/dL", "ug/dL", "mmol/L", "mmol/L", "mmol/L",
    "mg/dL", "mg/dL", "U/L", "U/L", "U/L", "U/L",
    "mg/dL", "g/dL", "g/dL", "g/dL",
    "mg/dL", "%", "K/uL", "K/uL",
    "ug/dL", "umol/L", "mg/dL"
  ),
  ref_low = c(
    16, 0.9, 0, 3.7, 147, 114,
    8.2, 2.9, 27, 16, 12, 0,
    72, 6.3, 2.6, 3.0,
    91, 31, 3.9, 100,
    0.8, 191, 0.0
  ),
  ref_high = c(
    37, 2.3, 14, 5.2, 157, 126,
    11.2, 6.3, 158, 67, 59, 6,
    175, 8.8, 3.9, 5.9,
    305, 51, 19, 440,
    4.7, 349, 0.3
  ),
  db_column = c(
    "bun", "creatinine", "sdma", "potassium", "sodium", "chloride",
    "calcium", "phosphorus", "alt", "ast", "alp", "ggt",
    "glucose", "total_protein", "albumin", "globulin",
    "cholesterol", "hematocrit", "wbc", "platelets",
    "total_t4", "fructosamine", "bilirubin_total"
  ),
  clinical_note = c(
    "Elevated with dehydration or kidney disease; diuretics increase BUN",
    "Key kidney marker; elevated in azotemia. Monitor closely on diuretics",
    "Early kidney biomarker; more sensitive than creatinine",
    "Low K (hypokalemia) common on diuretics; supplement if <3.5",
    "Monitor with diuretic therapy",
    "Low chloride can indicate metabolic alkalosis from diuretics",
    "Monitor for hypercalcemia",
    "Elevated in kidney disease",
    "Liver enzyme; monitor on rapamycin/Felycin-CA1",
    "Liver/muscle enzyme",
    "Liver enzyme",
    "Liver enzyme",
    "Monitor on SGLT2 inhibitors; check fructosamine for true glycemic status",
    "Low in malnutrition or liver disease",
    "Low albumin can worsen edema",
    "Elevated in inflammation or infection",
    "May be elevated on some cardiac medications",
    "Low indicates anemia; high indicates dehydration",
    "Elevated in infection/inflammation",
    "Low platelets increase bleeding risk (important with clopidogrel/rivaroxaban)",
    "Elevated in hyperthyroidism (secondary cause of HCM)",
    "True glycemic control marker; use with SGLT2i (which cause glucosuria)",
    "Liver function marker"
  ),
  stringsAsFactors = FALSE
)

# Echo reference ranges for cats
feline_echo_ranges <- data.frame(
  measurement = c("IVSd", "EDD", "LVFWd", "FS%", "LA/Ao", "LVOT Vmax"),
  unit = c("cm", "cm", "cm", "%", "ratio", "m/s"),
  normal_low = c(0.3, 1.2, 0.3, 30, 1.0, 0.7),
  normal_high = c(0.55, 1.9, 0.55, 55, 1.5, 1.5),
  hcm_threshold = c(0.6, NA, 0.6, NA, 1.8, 2.5),
  note = c(
    ">=6mm diagnostic for HCM",
    "LV internal dimension in diastole",
    ">=6mm diagnostic for HCM",
    "Fractional shortening; reduced in end-stage",
    ">1.5 indicates LAE; >2.0 severe",
    ">2.5 m/s indicates LVOTO"
  ),
  stringsAsFactors = FALSE
)

# SRR thresholds
srr_thresholds <- list(
  normal_max = 35,
  concern = 40,
  emergency = 60,
  unit = "breaths per minute (brpm)",
  note = "Normal sleeping respiratory rate for cats is <35 brpm. Consistently >35 may indicate fluid buildup. >60 warrants emergency evaluation."
)

# ACVIM staging reference
acvim_stages <- data.frame(
  stage = c("A", "B1", "B2", "C", "D"),
  description = c(
    "At risk but no structural changes",
    "Structural heart disease, no clinical signs, mild changes",
    "Structural heart disease, no clinical signs, moderate-severe changes",
    "Clinical signs of heart failure (current or past)",
    "Refractory heart failure not responding to standard therapy"
  ),
  stringsAsFactors = FALSE
)
