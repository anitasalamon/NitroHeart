# Seed Nitro's complete medical history into NitroHeart
# Run once: Rscript seed_nitro.R

source("R/utils_db.R")

db <- init_db("nitroheart.sqlite")

# ============================================================================
# PET PROFILE
# ============================================================================
dbExecute(db, "DELETE FROM pets WHERE name = 'Nitro'")

dbExecute(db, "
  INSERT INTO pets (name, species, breed, color, sex, dob, weight_kg,
    diagnosis_date, acvim_stage, breeder, genetic_test_mybpc3,
    genetic_test_date, genetic_notes, owner_name, share_anonymized, notes)
  VALUES ('Nitro', 'Feline', 'Ragdoll', 'Seal Point', 'Male Neutered',
    '2024-10-05', 5.2, '2025-08-06', 'D',
    'Ridgeview Ragdolls, VA',
    'N/N (Negative)',
    '2025-09-08',
    'Parents: Polly (mom, Seal Bicolor, N/N tested 9/8/2025) and Yeti (dad, Seal Mink Colorpoint, N/N tested 9/8/2020). Both negative for MYBPC3 R820W. HCM likely non-R820W variant. Brother Blue from same breeder (different parents).',
    'Anita Salamon', 1,
    'Juvenile HOCM diagnosed at 10 months after being chased by a dog. Stage D refractory CHF. Multiple ER visits and hospitalizations. Currently on 8-medication regimen including off-label SGLT2 inhibitor and Felycin-CA1.')
")

nitro_id <- dbGetQuery(db, "SELECT pet_id FROM pets WHERE name = 'Nitro'")$pet_id[1]
cat("Nitro registered with pet_id:", nitro_id, "\n")

# ============================================================================
# LAB RESULTS - Complete timeline from all records
# ============================================================================
dbExecute(db, paste0("DELETE FROM lab_results WHERE pet_id = ", nitro_id))

labs <- data.frame(
  pet_id = nitro_id,
  lab_date = c(
    "2025-08-14",   # First VVS bloodwork
    "2025-09-16",   # ER visit Greenbrier
    "2025-10-01",   # VVS recheck with Dr. Paling
    "2025-10-11",   # VVS hospitalization
    "2025-10-12",   # VVS follow-up next day
    "2025-11-12",   # VVS recheck with Dr. Paling
    "2026-02-18"    # CVCA Colorado with Dr. Sharpe
  ),
  clinic = c(
    "Virginia Veterinary Specialists",
    "Greenbrier Emergency Animal Hospital",
    "Virginia Veterinary Specialists",
    "Virginia Veterinary Specialists",
    "Virginia Veterinary Specialists",
    "Virginia Veterinary Specialists",
    "CVCA Alameda East, Denver"
  ),
  vet_name = c(
    "Dr. Zach Crouse, DACVIM",
    "Dr. Sam Schaeffer",
    "Dr. Anna Paling, DACVIM (Cardiology)",
    "Dr. Paige Hymel",
    "Dr. Paige Hymel",
    "Dr. Anna Paling, DACVIM (Cardiology)",
    "Dr. Ashley Sharpe, DACVIM (Cardiology)"
  ),
  # Kidney
  bun         = c(NA,   40,   36,   45,   63,   38,   53),
  creatinine  = c(1.5,  2.6,  2.8,  2.8,  3.2,  2.0,  2.7),
  sdma        = c(NA,   NA,   NA,   NA,   NA,   NA,   13),
  upc         = c(NA,   NA,   NA,   NA,   NA,   NA,   0.2),
  # Electrolytes
  sodium      = c(NA,   160,  153,  164,  158,  159,  150),
  potassium   = c(NA,   4.3,  3.7,  4.1,  3.9,  3.4,  4.3),
  chloride    = c(NA,   117,  114,  118,  110,  114,  112),
  calcium     = c(NA,   NA,   9.4,  NA,   NA,   9.6,  10.6),
  phosphorus  = c(NA,   NA,   6.2,  NA,   NA,   5.1,  5.4),
  # Liver
  alt         = c(NA,   29,   22,   NA,   NA,   40,   47),
  ast         = c(NA,   NA,   NA,   NA,   NA,   NA,   35),
  alp         = c(NA,   22,   30,   NA,   NA,   35,   36),
  ggt         = c(NA,   NA,   0,    NA,   NA,   0,    1),
  bilirubin_total = c(NA, NA, 0.3,  NA,   NA,   0.3,  0.2),
  # Metabolic
  glucose     = c(NA,   88,   97,   NA,   NA,   92,   73),
  total_protein = c(NA, 6.3,  6.6,  NA,   NA,   6.7,  7.2),
  albumin     = c(NA,   2.8,  3.0,  NA,   NA,   3.2,  3.7),
  globulin    = c(NA,   3.4,  3.6,  NA,   NA,   3.6,  3.5),
  cholesterol = c(NA,   NA,   225,  NA,   NA,   208,  300),
  fructosamine = c(NA,  NA,   NA,   NA,   NA,   NA,   269),
  # Hematology
  hematocrit  = c(NA,   NA,   NA,   NA,   NA,   NA,   44.5),
  wbc         = c(NA,   NA,   NA,   NA,   NA,   NA,   8.8),
  platelets   = c(NA,   NA,   NA,   NA,   NA,   NA,   427),
  # Thyroid
  total_t4    = c(NA,   NA,   NA,   NA,   NA,   NA,   2.1),
  notes = c(
    "First bloodwork at initial diagnosis visit",
    "ER visit - recurrent CHF episode. Creatinine starting to rise.",
    "Recheck with cardiology. Compensated CHF. Added potassium supplementation. Creatinine elevated.",
    "Hospitalized for CHF. BUN rising. Atenolol discontinued.",
    "Follow-up next day. Creatinine peaked at 3.2, BUN 63. Worst kidney values.",
    "Recheck. Creatinine improved to 2.0 after HCTZ dose reduction. Started velagliflozin. K low at 3.4.",
    "First CVCA Colorado visit. Glucosuria 3+ from SGLT2i. Fructosamine 269 (normal). SDMA 13 (normal). Moderate azotemia stable."
  ),
  stringsAsFactors = FALSE
)

for (i in 1:nrow(labs)) {
  dbAppendTable(db, "lab_results", labs[i, , drop = FALSE])
}
cat("Inserted", nrow(labs), "lab records\n")

# ============================================================================
# ECHO RESULTS
# ============================================================================
dbExecute(db, paste0("DELETE FROM echo_results WHERE pet_id = ", nitro_id))

echos <- data.frame(
  pet_id = nitro_id,
  echo_date = c("2025-08-06", "2025-09-04", "2026-02-18"),
  clinic = c(
    "Virginia Veterinary Specialists",
    "Virginia Veterinary Specialists",
    "CVCA Alameda East, Denver"
  ),
  vet_name = c(
    "VVS Cardiology",
    "VVS Cardiology",
    "Dr. Ashley Sharpe, DACVIM (Cardiology)"
  ),
  ivsd       = c(0.76, NA,   NA),
  edd        = c(1.50, NA,   NA),
  lvfwd      = c(0.80, NA,   NA),
  fs_pct     = c(58,   NA,   NA),
  ao         = c(0.95, NA,   NA),
  la         = c(1.80, NA,   NA),
  la_ao_ratio = c(2.0, 2.0,  NA),
  lvot_vmax  = c(3.0,  5.0,  NA),
  lvot_pg    = c(NA,   NA,   133),
  sam_present = c(1L,  NA,   1L),
  mitral_regurg = c(NA, NA,  "Mild"),
  sec_present = c(0L,  0L,   1L),
  thrombus_present = c(0L, 0L, 0L),
  lv_systolic_function = c(NA, NA, "Mildly reduced"),
  acvim_stage = c("C", "C",  "D"),
  notes = c(
    "Initial diagnosis. Juvenile HOCM with acute decompensation. Scant pleural and pericardial effusion. Notable SAM. E/A > 2.0.",
    "Brief recheck echo. No pleural or pericardial effusion. Severe LAE > 2.0. No SEC or thrombus. LVOT Vmax increased to 5.0 m/s.",
    "Marked progressive thickening of IVS and LVFW with hyperechoic myocardium. Severe progressive LAE. Reduced LV systolic function. SAM causing severe LVOTO (PG 133 mmHg). NEW: spontaneous echo contrast. Reduced LAu flow velocity <25 cm/s. Infinite B-lines bilaterally. Trace pleural effusion. Moderate RA dilation."
  ),
  stringsAsFactors = FALSE
)

for (i in 1:nrow(echos)) {
  dbAppendTable(db, "echo_results", echos[i, , drop = FALSE])
}
cat("Inserted", nrow(echos), "echo records\n")

# ============================================================================
# MEDICATIONS - Complete history with start/end dates
# ============================================================================
dbExecute(db, paste0("DELETE FROM medications WHERE pet_id = ", nitro_id))

meds <- data.frame(
  pet_id = nitro_id,
  drug_name = c(
    # Initial regimen
    "Furosemide", "Pimobendan", "Spironolactone",
    # Added 9/4
    "Hydrochlorothiazide",
    # Atenolol trial
    "Atenolol",
    # Rapamycin/Felycin
    "Sirolimus", "Felycin-CA1",
    # Antithrombotics
    "Clopidogrel", "Rivaroxaban",
    # SGLT2 inhibitor
    "Velagliflozin",
    # Supplements
    "Potassium", "Gabapentin"
  ),
  dose_mg = c(
    12.5, 1.25, 12.5,
    6.25,
    6.25,
    NA, 1.2,
    18.75, 2.5,
    15,
    250, 100
  ),
  frequency = c(
    "q12h", "q12h", "q12h",
    "EOD alternating 6.25/3.125",
    "q24h then q12h",
    "weekly x4 doses", "weekly",
    "q24h", "q24h",
    "q24h",
    "3x/week (Mon/Wed/Fri)", "PRN vet visits"
  ),
  route = rep("PO", 12),
  start_date = c(
    "2025-08-06", "2025-08-06", "2025-08-14",
    "2025-09-04",
    "2025-09-04",
    "2025-09-15", "2025-10-04",
    "2025-09-04", "2026-02-18",
    "2025-11-13",
    "2025-10-01", "2025-08-06"
  ),
  end_date = c(
    NA, NA, NA,
    NA,
    "2025-10-11",
    "2025-10-04", NA,
    NA, NA,
    NA,
    NA, NA
  ),
  reason = c(
    "CHF - pulmonary edema", "Positive inotrope / CHF support", "Diuretic + cardioprotection",
    "Additional diuresis - refractory CHF",
    "Beta-blocker for LVOTO; poorly tolerated, CHF worsened",
    "mTOR inhibitor trial before Felycin-CA1 available", "Ventricular hypertrophy management (rapamycin)",
    "Antithrombotic - increased risk ATE/SEC", "Antithrombotic - new SEC on 2/18/26 echo",
    "SGLT2 inhibitor - off-label for CHF, suggested by Dr. Joshua Stern",
    "Hypokalemia from diuretics", "Anxiolytic for vet visits"
  ),
  off_label = c(
    0L, 0L, 0L,
    0L,
    0L,
    1L, 1L,
    0L, 0L,
    1L,
    0L, 0L
  ),
  notes = c(
    "Started at 12.5mg AM / 6.25mg PM. Increased to 12.5 q12h on 8/14. Briefly TID on decompensation episodes.",
    "Started 1.25mg q8h, reduced to 0.625 q12h, then back to 1.25 q12h. Controversial with LVOTO (PG 133mmHg) but Nitro decompensates without it.",
    "Added 8/14 at ER visit.",
    "Started 9/4. Dose adjusted to alternating 6.25/3.125 EOD due to kidney concerns. Critical - skipping doses causes pulmonary edema.",
    "Trial 9/4-10/11. Started q24h, increased to q12h. Nitro decompensated. Discontinued.",
    "4 weekly doses before switching to Felycin-CA1.",
    "15th dose 2/12/26. NOT approved for cats with LVOTO or CHF (both apply to Nitro). Off-label. Lab monitoring q6mo required.",
    "Started 9/4 with initial dosing. Stopped briefly (appetite concerns). Dose increased to 18.75mg (1/4 of 75mg tab) on 2/18/26.",
    "Started at CVCA Denver visit due to new spontaneous echo contrast finding.",
    "Off-label SGLT2 inhibitor. Idea from Dr. Joshua Stern (UC Davis). Mechanism: PANK1 activation -> CoA -> improved cardiac oxidative metabolism (Arany lab, UPenn). Causes expected glucosuria (3+ on UA). Fructosamine normal at 269.",
    "500mg tabs, 1/2 tab 3x/week for diuretic-induced hypokalemia.",
    "100mg capsule evening before + morning of vet visits."
  ),
  stringsAsFactors = FALSE
)

for (i in 1:nrow(meds)) {
  dbAppendTable(db, "medications", meds[i, , drop = FALSE])
}
cat("Inserted", nrow(meds), "medication records\n")

# ============================================================================
# CHF EPISODES
# ============================================================================
dbExecute(db, paste0("DELETE FROM chf_episodes WHERE pet_id = ", nitro_id))

chf <- data.frame(
  pet_id = nitro_id,
  episode_date = c(
    "2025-08-06", "2025-08-14", "2025-09-04", "2025-09-15",
    "2025-10-11", "2025-11-12", "2026-02-18"
  ),
  severity = c(
    "Critical - ICU / oxygen therapy needed",
    "Severe - hospitalization required",
    "Severe - hospitalization required",
    "Severe - hospitalization required",
    "Severe - hospitalization required",
    "Moderate - required ER visit but stabilized",
    "Moderate - required ER visit but stabilized"
  ),
  symptoms = c(
    "Acute respiratory distress after being chased by a dog. Tachypnea, increased respiratory effort.",
    "Respiratory distress. Worsening despite furosemide.",
    "Recurrent CHF. SRR >60 brpm with no response to morning medications.",
    "Worsening tachypnea 3 days after hospitalization discharge.",
    "CHF decompensation. Required hospitalization.",
    "CHF episode. Owners giving extra furosemide PRN. Have oxygen at home.",
    "Decompensated CHF on echo. Infinite B-lines bilaterally. Flash pulmonary edema possible from stress of car ride/vet visit."
  ),
  trigger = c(
    "Chased by a dog - acute stress",
    "Inadequate diuresis",
    "Medication wearing off between doses",
    "Transition from pimobendan to atenolol",
    "Disease progression",
    "Disease progression / diuretic resistance",
    "Car ride / vet visit stress (first CO visit after move from VA)"
  ),
  hospitalized = c(1L, 1L, 1L, 1L, 1L, 0L, 0L),
  er_visit     = c(1L, 1L, 0L, 0L, 0L, 1L, 0L),
  treatment = c(
    "Pimobendan 1.25mg q8h, O2 therapy, furosemide 1-2 mg/kg IV q2-4h",
    "Furosemide increased to 12.5mg q12h, started spironolactone 12.5mg q12h",
    "Started HCTZ 6.25mg q24h, maropitant. Plan to transition to atenolol + rapamycin.",
    "Restarted pimobendan 0.625mg q12h, restarted HCTZ 6.25mg q24h, reduced atenolol",
    "Furosemide 12.5 q12h, pimobendan 0.9375 q12h, atenolol discontinued, HCTZ alternating",
    "Started velagliflozin 15mg q24h (off-label SGLT2i)",
    "Furosemide 10mg SQ injection. Increased to TID x3 days then back to BID. Started rivaroxaban. Increased clopidogrel."
  ),
  outcome = c(
    "Stabilized. Diagnosed juvenile HOCM. Discharged on furosemide + pimobendan.",
    "Stabilized overnight. Discharged with triple therapy.",
    "Stabilized. LVOT Vmax worsened to 5.0 m/s.",
    "Stabilized after restarting pimobendan and HCTZ.",
    "Stabilized. Simplified regimen - atenolol removed.",
    "Stabilized on SGLT2i. Creatinine improved to 2.0 (from 3.2 peak).",
    "Discharged with increased furosemide and new anticoagulant. New finding: spontaneous echo contrast (clot risk)."
  ),
  notes = c(
    "FIRST CHF EVENT. Nitro was 10 months old. Echo: IVSd 0.76, LVFWd 0.80, LA/Ao 2.0, LVOT Vmax 3.0, FS 58%.",
    "8 days after first episode. Furosemide dose was insufficient.",
    "21 days since last episode. SRR not responding to morning meds.",
    "11 days since last. Atenolol trial was poorly tolerated.",
    "26 days since last. Pattern: ~2-4 weeks between episodes.",
    "32 days since last. Started SGLT2i as additional therapy.",
    "98 days since last - LONGEST INTERVAL. Possible the velagliflozin + Felycin-CA1 combination is helping maintain stability."
  ),
  stringsAsFactors = FALSE
)

for (i in 1:nrow(chf)) {
  dbAppendTable(db, "chf_episodes", chf[i, , drop = FALSE])
}
cat("Inserted", nrow(chf), "CHF episodes\n")

# ============================================================================
# SRR SAMPLES (representative readings based on clinical notes)
# ============================================================================
dbExecute(db, paste0("DELETE FROM srr_log WHERE pet_id = ", nitro_id))

srr <- data.frame(
  pet_id = nitro_id,
  log_date = c(
    "2025-09-04", "2025-09-15", "2025-10-01", "2025-10-11",
    "2025-11-12", "2025-12-15", "2026-01-15", "2026-02-01",
    "2026-02-10", "2026-02-18"
  ),
  log_time = c(
    "06:00", "07:00", "22:00", "03:00",
    "08:00", "23:00", "22:00", "23:00",
    "22:00", "07:00"
  ),
  srr_brpm = c(
    64, 52, 28, 48,
    42, 24, 26, 22,
    20, 64
  ),
  activity_before = c(
    "Sleeping", "Sleeping", "Sleeping", "Sleeping",
    "Sleeping", "Sleeping", "Sleeping", "Sleeping",
    "Sleeping", "Post-vet visit"
  ),
  notes = c(
    "Pre-hospital. Not responding to morning meds. Led to ER visit.",
    "Worsening tachypnea 3 days post-discharge.",
    "Compensated. Doing well on current regimen.",
    "Rising overnight. Hospitalized next morning.",
    "Elevated but manageable. Started SGLT2i today.",
    "Stable period. Best readings in months.",
    "Stable after move to Colorado. Adjusting to altitude.",
    "Excellent. Playful and active.",
    "Excellent. Stable.",
    "Elevated at CVCA visit - stress-related. Flash pulmonary edema possible."
  ),
  stringsAsFactors = FALSE
)

for (i in 1:nrow(srr)) {
  dbAppendTable(db, "srr_log", srr[i, , drop = FALSE])
}
cat("Inserted", nrow(srr), "SRR readings\n")

close_db(db)
cat("\nDone! Nitro's complete medical history has been loaded.\n")
cat("Lab results: 7 visits (Aug 2025 - Feb 2026)\n")
cat("Echo results: 3 studies\n")
cat("Medications: 12 drugs (including off-label SGLT2i and Felycin-CA1)\n")
cat("CHF episodes: 7 events\n")
cat("SRR readings: 10 entries\n")
