# NitroHeart Clinical Calculators
# Evidence-based staging and risk assessment tools for feline HCM

# ============================================================================
# ACVIM STAGING CALCULATOR
# Reference: Luis Fuentes et al., JVIM 2020 (ACVIM Consensus Statement)
# ============================================================================

#' Calculate ACVIM stage from echocardiographic and clinical data
#' @param ivsd Interventricular septum thickness in diastole (mm)
#' @param lvfwd LV free wall thickness in diastole (mm)
#' @param la_ao LA/Ao ratio
#' @param la_mm LA diameter in mm
#' @param chf_history Has the cat had CHF or is currently in CHF?
#' @param ate_history Has the cat had arterial thromboembolism?
#' @param refractory_chf CHF not responding to standard therapy?
#' @return List with stage, description, color, risk_factors
calculate_acvim_stage <- function(ivsd = NULL, lvfwd = NULL, la_ao = NULL,
                                  la_mm = NULL, chf_history = FALSE,
                                  ate_history = FALSE, refractory_chf = FALSE) {
  # Stage D: Refractory CHF
  if (isTRUE(refractory_chf)) {
    return(list(
      stage = "D",
      label = "Refractory Heart Failure",
      description = "CHF not responding to standard therapy. Requires aggressive management.",
      color = "#991B1B",
      severity = 5
    ))
  }

  # Stage C: Current or historical CHF/ATE
  if (isTRUE(chf_history) || isTRUE(ate_history)) {
    return(list(
      stage = "C",
      label = "Heart Failure",
      description = "Current or previous congestive heart failure or arterial thromboembolism.",
      color = "#DC2626",
      severity = 4
    ))
  }

  # Check for hypertrophy (need echo data)
  has_hypertrophy <- FALSE
  if (!is.null(ivsd) && !is.na(ivsd) && ivsd >= 6) has_hypertrophy <- TRUE
  if (!is.null(lvfwd) && !is.na(lvfwd) && lvfwd >= 6) has_hypertrophy <- TRUE

  if (!has_hypertrophy) {
    return(list(
      stage = "A",
      label = "At Risk",
      description = "Predisposed breed or family history, but no structural heart disease detected.",
      color = "#5BA89D",
      severity = 1
    ))
  }

  # Differentiate B1 vs B2
  b2_criteria <- c()

  if (!is.null(la_ao) && !is.na(la_ao) && la_ao >= 1.8) {
    b2_criteria <- c(b2_criteria, paste0("LA/Ao ratio ", la_ao, " (>= 1.8)"))
  }
  if (!is.null(la_mm) && !is.na(la_mm) && la_mm >= 18) {
    b2_criteria <- c(b2_criteria, paste0("LA diameter ", la_mm, "mm (>= 18mm)"))
  }

  # Additional risk markers for B2
  risk_factors <- c()
  if (!is.null(ivsd) && !is.na(ivsd) && ivsd >= 9) {
    risk_factors <- c(risk_factors, paste0("Extreme hypertrophy: IVSd ", ivsd, "mm"))
  }

  if (length(b2_criteria) > 0) {
    return(list(
      stage = "B2",
      label = "Subclinical, High Risk",
      description = "Structural heart disease with significant left atrial enlargement. Higher risk for CHF and ATE.",
      color = "#E5A84B",
      b2_criteria = b2_criteria,
      risk_factors = risk_factors,
      severity = 3
    ))
  }

  return(list(
    stage = "B1",
    label = "Subclinical, Low Risk",
    description = "Structural heart disease present but left atrium is normal or only mildly enlarged.",
    color = "#7EB8A8",
    risk_factors = risk_factors,
    severity = 2
  ))
}

# ============================================================================
# IRIS CKD STAGING CALCULATOR
# Reference: IRIS (International Renal Interest Society) 2023 Guidelines
# ============================================================================

#' Calculate IRIS CKD stage from renal biomarkers
#' @param creatinine Serum creatinine (mg/dL)
#' @param sdma SDMA (ug/dL)
#' @param upc Urine protein:creatinine ratio
#' @param systolic_bp Systolic blood pressure (mmHg)
#' @return List with stage, substaging, description
calculate_iris_stage <- function(creatinine = NULL, sdma = NULL,
                                 upc = NULL, systolic_bp = NULL) {
  if (is.null(creatinine) && is.null(sdma)) return(NULL)

  # Creatinine-based staging (feline)
  creat_stage <- NA
  if (!is.null(creatinine) && !is.na(creatinine)) {
    creat_stage <- if (creatinine < 1.6) 1L
                   else if (creatinine <= 2.8) 2L
                   else if (creatinine <= 5.0) 3L
                   else 4L
  }

  # SDMA-based staging (feline)
  sdma_stage <- NA
  if (!is.null(sdma) && !is.na(sdma)) {
    sdma_stage <- if (sdma < 18) 1L
                  else if (sdma <= 25) 2L
                  else if (sdma <= 38) 3L
                  else 4L
  }

  # SDMA up-staging rule: use the higher of the two
  stage <- max(creat_stage, sdma_stage, na.rm = TRUE)

  upstaged <- !is.na(sdma_stage) && !is.na(creat_stage) && sdma_stage > creat_stage

  # Stage descriptions
  stage_info <- list(
    `1` = list(label = "Stage 1", desc = "Non-azotemic. CKD detected by other markers.",
               color = "#5BA89D"),
    `2` = list(label = "Stage 2", desc = "Mild renal azotemia. Clinical signs usually mild or absent.",
               color = "#E5A84B"),
    `3` = list(label = "Stage 3", desc = "Moderate renal azotemia. Extrarenal clinical signs may be present.",
               color = "#E8967A"),
    `4` = list(label = "Stage 4", desc = "Severe renal azotemia. Significant clinical signs expected.",
               color = "#991B1B")
  )

  info <- stage_info[[as.character(stage)]]

  # Proteinuria substaging
  proteinuria <- NULL
  if (!is.null(upc) && !is.na(upc)) {
    proteinuria <- if (upc < 0.2) list(status = "Non-proteinuric", color = "#5BA89D")
                   else if (upc <= 0.4) list(status = "Borderline proteinuric", color = "#E5A84B")
                   else list(status = "Proteinuric", color = "#E8967A")
  }

  # Blood pressure substaging
  bp_status <- NULL
  if (!is.null(systolic_bp) && !is.na(systolic_bp)) {
    bp_status <- if (systolic_bp < 140) list(status = "Normotensive", risk = "Minimal", color = "#5BA89D")
                 else if (systolic_bp < 160) list(status = "Prehypertensive", risk = "Low", color = "#E5A84B")
                 else if (systolic_bp < 180) list(status = "Hypertensive", risk = "Moderate", color = "#E8967A")
                 else list(status = "Severely hypertensive", risk = "High", color = "#991B1B")
  }

  list(
    stage = stage,
    label = info$label,
    description = info$desc,
    color = info$color,
    upstaged = upstaged,
    upstage_note = if (upstaged) "SDMA suggests more advanced disease than creatinine alone" else NULL,
    creatinine_stage = creat_stage,
    sdma_stage = sdma_stage,
    proteinuria = proteinuria,
    bp_status = bp_status
  )
}

# ============================================================================
# DRUG INTERACTION CHECKER
# References: Tufts CardioRush Formulary, CEG Feline Formulary,
#             Merck Veterinary Manual
# ============================================================================

# Drug interaction database
drug_interactions <- data.frame(
  drug_a = c("Atenolol", "Benazepril", "Clopidogrel", "ACE Inhibitor",
             "Furosemide", "Atenolol", "Diltiazem", "Clopidogrel"),
  drug_b = c("Diltiazem", "Spironolactone", "NSAIDs", "Sacubitril/Valsartan",
             "CKD (advancing)", "CHF onset", "CHF onset", "Aspirin"),
  severity = c("contraindicated", "monitor", "avoid", "contraindicated",
               "monitor", "dose_adjust", "dose_adjust", "avoid"),
  description = c(
    "Both negative inotropes/chronotropes. Risk of severe bradycardia, AV block, hypotension.",
    "Both increase potassium. Monitor electrolytes closely for hyperkalemia.",
    "Increased GI bleeding risk. Cats are extremely NSAID-sensitive.",
    "Cannot be given concurrently. Risk of angioedema.",
    "Can worsen azotemia. Monitor renal values closely with each dose change.",
    "Reduce atenolol dose by ~50% if CHF develops. Do NOT stop abruptly.",
    "Reduce diltiazem dose by ~50% if CHF develops. Do NOT stop abruptly.",
    "Combination shows minimal benefit in cats with increased bleeding risk."
  ),
  recommendation = c(
    "CONTRAINDICATED unless cardiologist-supervised. Never combine without specialist.",
    "Check potassium at baseline and 1 week after any dose change.",
    "AVOID all NSAIDs in cats on clopidogrel. Use gabapentin for pain.",
    "36-hour washout required between ACE-I and sacubitril/valsartan.",
    "Recheck BUN/creatinine/SDMA within 5-7 days of any furosemide dose increase.",
    "Halve the dose when CHF signs appear. Taper gradually if discontinuing.",
    "Halve the dose when CHF signs appear. Taper gradually if discontinuing.",
    "Clopidogrel alone is preferred for ATE prevention in cats."
  ),
  stringsAsFactors = FALSE
)

#' Check for drug interactions among a list of medications
#' @param current_meds Character vector of current medication names
#' @param has_ckd Logical: does the cat have CKD?
#' @param has_chf Logical: is the cat in CHF?
#' @return Data frame of found interactions with severity
check_drug_interactions <- function(current_meds, has_ckd = FALSE, has_chf = FALSE) {
  if (length(current_meds) == 0) return(data.frame())

  # Normalize drug names for matching
  meds_lower <- tolower(current_meds)

  # Map common drug names to canonical names
  name_map <- list(
    "atenolol" = "Atenolol",
    "diltiazem" = "Diltiazem",
    "benazepril" = "Benazepril",
    "enalapril" = "ACE Inhibitor",
    "furosemide" = "Furosemide",
    "lasix" = "Furosemide",
    "clopidogrel" = "Clopidogrel",
    "plavix" = "Clopidogrel",
    "spironolactone" = "Spironolactone",
    "pimobendan" = "Pimobendan",
    "vetmedin" = "Pimobendan",
    "bexagliflozin" = "Bexagliflozin",
    "bexacat" = "Bexagliflozin",
    "felycin" = "Felycin-CA1",
    "rapamycin" = "Felycin-CA1",
    "sirolimus" = "Sirolimus",
    "rivaroxaban" = "Rivaroxaban"
  )

  canonical_meds <- c()
  for (m in meds_lower) {
    matched <- FALSE
    for (nm in names(name_map)) {
      if (grepl(nm, m, fixed = TRUE)) {
        canonical_meds <- c(canonical_meds, name_map[[nm]])
        matched <- TRUE
        break
      }
    }
    if (!matched) canonical_meds <- c(canonical_meds, current_meds[which(meds_lower == m)])
  }

  # Also check for ACE inhibitor class
  ace_inhibitors <- c("Benazepril", "Enalapril", "Ramipril", "Lisinopril")
  if (any(canonical_meds %in% ace_inhibitors)) {
    canonical_meds <- c(canonical_meds, "ACE Inhibitor")
  }

  # Add condition-based checks
  if (has_ckd && "Furosemide" %in% canonical_meds) {
    canonical_meds <- c(canonical_meds, "CKD (advancing)")
  }
  if (has_chf) {
    if ("Atenolol" %in% canonical_meds) canonical_meds <- c(canonical_meds, "CHF onset")
    if ("Diltiazem" %in% canonical_meds) canonical_meds <- c(canonical_meds, "CHF onset")
  }

  # Find interactions
  found <- drug_interactions[
    (drug_interactions$drug_a %in% canonical_meds & drug_interactions$drug_b %in% canonical_meds) |
    (drug_interactions$drug_b %in% canonical_meds & drug_interactions$drug_a %in% canonical_meds),
  ]

  # Sort by severity
  sev_order <- c("contraindicated" = 1, "avoid" = 2, "dose_adjust" = 3, "monitor" = 4)
  if (nrow(found) > 0) {
    found$sev_order <- sev_order[found$severity]
    found <- found[order(found$sev_order), ]
    found$sev_order <- NULL
  }

  found
}

# Clopidogrel resistance note
clopidogrel_resistance_note <- paste(
  "16.3% of cats are homozygous poor metabolizers of clopidogrel (CYP2C polymorphism),",
  "and 51% are heterozygous. Genetic testing is recommended for cats on clopidogrel",
  "for ATE prevention. (Guillaumin, 2025)"
)
