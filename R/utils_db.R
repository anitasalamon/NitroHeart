# NitroHeart Database Utilities
# SQLite-based storage for pet health records

library(DBI)
library(RSQLite)

#' Initialize the NitroHeart database
#' Creates all tables if they don't exist
#' @param db_path Path to SQLite database file
#' @return DBI connection object
init_db <- function(db_path = "nitroheart.sqlite") {
  con <- dbConnect(RSQLite::SQLite(), db_path)

  # Enable foreign keys
  dbExecute(con, "PRAGMA foreign_keys = ON;")

  # Pet profiles
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS pets (
      pet_id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      species TEXT DEFAULT 'Feline',
      breed TEXT,
      color TEXT,
      sex TEXT,
      dob DATE,
      weight_kg REAL,
      diagnosis_date DATE,
      acvim_stage TEXT,
      breeder TEXT,
      microchip TEXT,
      genetic_test_mybpc3 TEXT,
      genetic_test_date DATE,
      genetic_notes TEXT,
      owner_name TEXT,
      owner_email TEXT,
      share_anonymized INTEGER DEFAULT 0,
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  ")

  # Lab results
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS lab_results (
      lab_id INTEGER PRIMARY KEY AUTOINCREMENT,
      pet_id INTEGER NOT NULL,
      lab_date DATE NOT NULL,
      clinic TEXT,
      vet_name TEXT,
      -- Kidney panel
      bun REAL,
      creatinine REAL,
      sdma REAL,
      bun_creat_ratio REAL,
      upc REAL,
      usg REAL,
      -- Electrolytes
      sodium REAL,
      potassium REAL,
      chloride REAL,
      calcium REAL,
      phosphorus REAL,
      -- Liver
      alt REAL,
      ast REAL,
      alp REAL,
      ggt REAL,
      bilirubin_total REAL,
      -- Metabolic
      glucose REAL,
      total_protein REAL,
      albumin REAL,
      globulin REAL,
      cholesterol REAL,
      fructosamine REAL,
      -- Hematology
      hematocrit REAL,
      wbc REAL,
      platelets REAL,
      -- Thyroid
      total_t4 REAL,
      -- Other
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (pet_id) REFERENCES pets(pet_id)
    );
  ")

  # Echo measurements
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS echo_results (
      echo_id INTEGER PRIMARY KEY AUTOINCREMENT,
      pet_id INTEGER NOT NULL,
      echo_date DATE NOT NULL,
      clinic TEXT,
      vet_name TEXT,
      -- LV measurements
      ivsd REAL,
      edd REAL,
      lvfwd REAL,
      fs_pct REAL,
      -- Atrial
      ao REAL,
      la REAL,
      la_ao_ratio REAL,
      -- Flow velocities
      lvot_vmax REAL,
      lvot_pg REAL,
      rvot_vmax REAL,
      -- Diastolic function
      e_a_ratio REAL,
      -- Qualitative
      sam_present INTEGER,
      mitral_regurg TEXT,
      tricuspid_regurg TEXT,
      pleural_effusion TEXT,
      pericardial_effusion TEXT,
      sec_present INTEGER,
      thrombus_present INTEGER,
      lv_systolic_function TEXT,
      -- Assessment
      acvim_stage TEXT,
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (pet_id) REFERENCES pets(pet_id)
    );
  ")

  # Medications
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS medications (
      med_id INTEGER PRIMARY KEY AUTOINCREMENT,
      pet_id INTEGER NOT NULL,
      drug_name TEXT NOT NULL,
      dose_mg REAL,
      frequency TEXT,
      route TEXT DEFAULT 'PO',
      start_date DATE,
      end_date DATE,
      reason TEXT,
      off_label INTEGER DEFAULT 0,
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (pet_id) REFERENCES pets(pet_id)
    );
  ")

  # Sleeping respiratory rate log
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS srr_log (
      srr_id INTEGER PRIMARY KEY AUTOINCREMENT,
      pet_id INTEGER NOT NULL,
      log_date DATE NOT NULL,
      log_time TIME,
      srr_brpm INTEGER NOT NULL,
      activity_before TEXT,
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (pet_id) REFERENCES pets(pet_id)
    );
  ")

  # CHF episodes
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS chf_episodes (
      episode_id INTEGER PRIMARY KEY AUTOINCREMENT,
      pet_id INTEGER NOT NULL,
      episode_date DATE NOT NULL,
      severity TEXT,
      symptoms TEXT,
      trigger TEXT,
      hospitalized INTEGER DEFAULT 0,
      er_visit INTEGER DEFAULT 0,
      treatment TEXT,
      outcome TEXT,
      days_since_last INTEGER,
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (pet_id) REFERENCES pets(pet_id)
    );
  ")

  return(con)
}

#' Close database connection safely
close_db <- function(con) {
  if (!is.null(con) && dbIsValid(con)) {
    dbDisconnect(con)
  }
}

# ---- CRUD helpers ----

insert_record <- function(con, table, data) {
  dbAppendTable(con, table, data)
}

get_records <- function(con, table, pet_id = NULL, order_by = NULL) {
  query <- paste0("SELECT * FROM ", table)
  if (!is.null(pet_id)) {
    query <- paste0(query, " WHERE pet_id = ", pet_id)
  }
  if (!is.null(order_by)) {
    query <- paste0(query, " ORDER BY ", order_by)
  }
  dbGetQuery(con, query)
}

delete_record <- function(con, table, id_col, id_val) {
  dbExecute(con, paste0("DELETE FROM ", table, " WHERE ", id_col, " = ?"),
            params = list(id_val))
}
