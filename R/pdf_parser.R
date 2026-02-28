# NitroHeart PDF Parser
# Extracts lab values, echo data, and clinical info from veterinary PDF reports
# Strategy: Try rule-based parsing for known formats (IDEXX), fall back to Claude API

library(httr2)
library(jsonlite)

# ============================================================================
# PDF TEXT EXTRACTION (uses system pdftotext from poppler-utils)
# ============================================================================

#' Extract text from a PDF file using pdftotext
#' @param pdf_path Path to the PDF file
#' @return Character vector of text (one element per page), or NULL on failure
extract_pdf_text <- function(pdf_path) {
  # Use pdftotext (poppler-utils) to extract text, preserving layout
  tmp_out <- tempfile(fileext = ".txt")
  on.exit(unlink(tmp_out), add = TRUE)

  exit_code <- system2("pdftotext", args = c("-layout", shQuote(pdf_path), tmp_out),
                        stdout = FALSE, stderr = FALSE)
  if (exit_code != 0) return(NULL)

  text <- tryCatch(
    readLines(tmp_out, warn = FALSE),
    error = function(e) return(NULL)
  )
  if (is.null(text)) return(NULL)

  # Return as a single string (pdftotext -layout gives us the whole document)
  paste(text, collapse = "\n")
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

#' Parse a veterinary PDF and extract structured data
#' @param pdf_path Path to the uploaded PDF file
#' @param api_key Anthropic API key (optional, for Claude fallback)
#' @return List with extracted data: pet_info, lab_results, echo_results, medications, notes
parse_vet_pdf <- function(pdf_path, api_key = NULL) {
  # Extract text from PDF
  full_text <- tryCatch(
    extract_pdf_text(pdf_path),
    error = function(e) return(NULL)
  )

  if (is.null(full_text) || nchar(full_text) == 0) {
    return(list(success = FALSE, error = "Could not read PDF file. Make sure pdftotext (poppler-utils) is installed."))
  }

  # Try to detect format
  format <- detect_pdf_format(full_text)

  result <- NULL

  # Try rule-based parsing for known formats
  if (format == "idexx") {
    result <- parse_idexx(full_text)
  }

  # If rule-based failed or format unknown, try Claude API
  if (is.null(result) || !result$success) {
    if (!is.null(api_key) && nchar(api_key) > 0) {
      result <- parse_with_claude(full_text, api_key)
    } else if (is.null(result)) {
      result <- list(
        success = FALSE,
        error = "Unrecognized PDF format. Add an Anthropic API key in Settings to enable AI-powered parsing."
      )
    }
  }

  result$raw_text <- full_text
  result$format_detected <- format
  return(result)
}

# ============================================================================
# FORMAT DETECTION
# ============================================================================

detect_pdf_format <- function(text) {
  text_lower <- tolower(text)
  if (grepl("idexx|vetconnect", text_lower)) return("idexx")
  if (grepl("antech", text_lower)) return("antech")
  if (grepl("clinical summary|discharge instructions", text_lower)) return("clinical_summary")
  return("unknown")
}

# ============================================================================
# IDEXX RULE-BASED PARSER
# ============================================================================

parse_idexx <- function(text) {
  result <- list(
    success = TRUE,
    format = "idexx",
    pet_info = list(),
    lab_results = list(),
    notes = list()
  )

  lines <- strsplit(text, "\n")[[1]]

  # --- Extract pet info from header ---
  # pdftotext -layout: "         NITRO SALAMON"
  pet_name_match <- grep("^\\s+[A-Z]+\\s+[A-Z]+\\s*$", lines, value = TRUE)
  pet_name_match <- pet_name_match[!grepl("TEST|RESULT|REFERENCE|GENERATED|PAGE|IDEXX", pet_name_match, ignore.case = TRUE)]
  if (length(pet_name_match) > 0) {
    parts <- strsplit(trimws(pet_name_match[1]), "\\s+")[[1]]
    if (length(parts) >= 1) result$pet_info$name <- parts[1]
  }

  species_line <- grep("SPECIES:", lines, value = TRUE, ignore.case = TRUE)
  if (length(species_line) > 0) {
    species_raw <- trimws(sub(".*SPECIES:\\s*", "", species_line[1], ignore.case = TRUE))
    species_raw <- sub("\\s{2,}.*", "", species_raw)  # stop at wide gap (next column)
    result$pet_info$species <- species_raw
  }

  breed_line <- grep("BREED:", lines, value = TRUE, ignore.case = TRUE)
  if (length(breed_line) > 0) {
    # Extract breed, stopping at next field (e.g., city, state)
    breed_raw <- trimws(sub(".*BREED:\\s*", "", breed_line[1], ignore.case = TRUE))
    breed_raw <- sub("\\s{2,}.*", "", breed_raw)  # stop at wide gap (next column)
    result$pet_info$breed <- breed_raw
  }

  gender_line <- grep("GENDER:", lines, value = TRUE, ignore.case = TRUE)
  if (length(gender_line) > 0) {
    sex_raw <- trimws(sub(".*GENDER:\\s*", "", gender_line[1], ignore.case = TRUE))
    sex_raw <- sub("\\s{2,}.*", "", sex_raw)
    result$pet_info$sex <- sex_raw
  }

  age_line <- grep("AGE:", lines, value = TRUE, ignore.case = TRUE)
  if (length(age_line) > 0) {
    age_raw <- trimws(sub(".*AGE:\\s*", "", age_line[1], ignore.case = TRUE))
    age_raw <- sub("\\s{2,}.*", "", age_raw)
    result$pet_info$age <- age_raw
  }

  # --- Extract collection date ---
  date_line <- grep("COLLECTION DATE:", lines, value = TRUE, ignore.case = TRUE)
  if (length(date_line) > 0) {
    date_str <- trimws(sub(".*COLLECTION DATE:\\s*", "", date_line[1], ignore.case = TRUE))
    date_str <- sub("\\s{2,}.*", "", date_str)  # stop at next column
    result$lab_results$lab_date <- tryCatch(
      as.character(as.Date(date_str, format = "%m/%d/%y")),
      error = function(e) date_str
    )
  }

  # --- Extract lab values using pattern matching ---
  # pdftotext -layout format: "TEST_NAME              RESULT              REF_LOW - REF_HIGH UNIT     [H/L]"
  # Values are separated by large whitespace gaps

  # Trim lines for matching but keep original for column extraction
  tlines <- trimws(lines)

  lab_map <- list(
    # Kidney
    list(pattern = "^BUN\\b", field = "bun"),
    list(pattern = "^Creatinine\\b", field = "creatinine"),
    list(pattern = "^IDEXX SDMA\\b", field = "sdma"),
    # Electrolytes
    list(pattern = "^Sodium\\b", field = "sodium"),
    list(pattern = "^Potassium\\b", field = "potassium"),
    list(pattern = "^Chloride\\b", field = "chloride"),
    list(pattern = "^Calcium\\b", field = "calcium"),
    list(pattern = "^Phosphorus\\b", field = "phosphorus"),
    # Liver
    list(pattern = "^ALT\\b", field = "alt"),
    list(pattern = "^AST\\b", field = "ast"),
    list(pattern = "^ALP\\b", field = "alp"),
    list(pattern = "^GGT\\b", field = "ggt"),
    list(pattern = "^Bilirubin\\s*-\\s*Total\\b", field = "bilirubin_total"),
    # Metabolic
    list(pattern = "^Glucose\\b", field = "glucose"),
    list(pattern = "^Total Protein\\b", field = "total_protein"),
    list(pattern = "^Albumin\\b(?!:)", field = "albumin"),
    list(pattern = "^Globulin\\b", field = "globulin"),
    list(pattern = "^Cholesterol\\b", field = "cholesterol"),
    list(pattern = "^Fructosamine\\b", field = "fructosamine"),
    # Hematology
    list(pattern = "^Hematocrit\\b", field = "hematocrit"),
    list(pattern = "^WBC\\b", field = "wbc"),
    list(pattern = "^Platelets\\b", field = "platelets"),
    # Thyroid
    list(pattern = "^Total T4\\b", field = "total_t4"),
    # Urinalysis
    list(pattern = "^Specific Gravity\\b", field = "usg")
  )

  for (mapping in lab_map) {
    for (i in seq_along(tlines)) {
      if (grepl(mapping$pattern, tlines[i], perl = TRUE, ignore.case = TRUE)) {
        # Split on 2+ whitespace to get columns
        tokens <- unlist(strsplit(tlines[i], "\\s{2,}"))
        tokens <- tokens[nchar(tokens) > 0]
        if (length(tokens) >= 2) {
          val_str <- trimws(tokens[2])
          # Remove footnote markers like superscript letters (a, b, c, d)
          val_str <- sub("^[a-d]\\s*", "", val_str)
          # Handle "<" values (e.g., "< 50" -> "50")
          val_str <- sub("^[<>]\\s*", "", val_str)
          # Remove commas in numbers (e.g., "2,239")
          val_str <- gsub(",", "", val_str)
          # Remove H/L flags
          val_str <- sub("\\s*[HL]$", "", val_str)
          # Try to parse as numeric
          val <- suppressWarnings(as.numeric(val_str))
          if (!is.na(val)) {
            result$lab_results[[mapping$field]] <- val
          }
        }
        break
      }
    }
  }

  # --- Extract UPC (spans multiple lines in pdftotext layout) ---
  # Look for "Urine Protein:" followed by "Creatinine Ratio" with a numeric value
  upc_idx <- grep("^Urine Protein:", tlines)
  for (idx in upc_idx) {
    # Check if this or a nearby line also says "Creatinine Ratio"
    context <- paste(tlines[idx:min(idx + 2, length(tlines))], collapse = " ")
    if (grepl("Creatinine Ratio", context)) {
      # Find the numeric value - check the line with the result
      for (j in idx:(min(idx + 2, length(tlines)))) {
        tokens <- unlist(strsplit(tlines[j], "\\s{2,}"))
        tokens <- tokens[nchar(tokens) > 0]
        for (tok in tokens) {
          val <- suppressWarnings(as.numeric(trimws(tok)))
          if (!is.na(val) && val < 10) {  # UPC values are typically < 10
            result$lab_results$upc <- val
            break
          }
        }
        if (!is.null(result$lab_results$upc)) break
      }
    }
  }

  # --- Extract Urine Protein dipstick ---
  # In urinalysis section: "Urine Protein" (no colon) with value like "1+", "2+", "NEGATIVE"
  urine_prot_idx <- grep("^Urine Protein\\b", tlines)
  for (idx in urine_prot_idx) {
    # Skip lines that are part of UPC or the reflex comment
    context <- tlines[idx]
    next_line <- if (idx < length(tlines)) tlines[idx + 1] else ""
    if (grepl("Creatinine|ordered|mg/dL", context, ignore.case = TRUE)) next
    if (grepl("Creatinine Ratio", next_line, ignore.case = TRUE)) next

    tokens <- unlist(strsplit(tlines[idx], "\\s{2,}"))
    tokens <- tokens[nchar(tokens) > 0]
    if (length(tokens) >= 2) {
      val_raw <- trimws(tokens[2])
      if (grepl("^(NEGATIVE|TRACE|[0-3]\\+)", val_raw, ignore.case = TRUE)) {
        result$lab_results$urine_protein_dipstick <- val_raw
        break
      }
    }
  }

  # --- Extract clinic info ---
  vet_line <- grep("ATTENDING VET:", lines, value = TRUE, ignore.case = TRUE)
  if (length(vet_line) > 0) {
    vet_raw <- trimws(sub(".*ATTENDING VET:\\s*", "", vet_line[1], ignore.case = TRUE))
    vet_raw <- sub("\\s{2,}.*", "", vet_raw)
    result$lab_results$vet_name <- vet_raw
  }

  # Extract clinic from the address block
  # IDEXX reports have "SVP - CLINIC NAME" or "CLINIC NAME" near the PET OWNER line
  clinic_lines <- grep("(SVP\\s*-|CVCA|VETERINARY|VET\\s+CENTER|ANIMAL\\s+HOSPITAL)", lines, value = TRUE, ignore.case = TRUE)
  clinic_lines <- clinic_lines[!grepl("ATTENDING VET:|SPECIES:|Generated by|PET OWNER:", clinic_lines, ignore.case = TRUE)]
  if (length(clinic_lines) > 0) {
    clinic_raw <- trimws(clinic_lines[1])
    clinic_raw <- sub("\\s{2,}.*", "", clinic_raw)  # stop at next column
    result$lab_results$clinic <- clinic_raw
  } else {
    # Try extracting from PET OWNER line which often has clinic in middle column
    owner_line <- grep("PET OWNER:", lines, value = TRUE, ignore.case = TRUE)
    if (length(owner_line) > 0) {
      tokens <- unlist(strsplit(owner_line[1], "\\s{3,}"))
      tokens <- trimws(tokens[nchar(trimws(tokens)) > 0])
      # The clinic name is typically in the second column
      if (length(tokens) >= 2) {
        clinic_candidate <- tokens[2]
        if (!grepl("LAB ID|ORDER ID|PET OWNER", clinic_candidate, ignore.case = TRUE)) {
          result$lab_results$clinic <- clinic_candidate
        }
      }
    }
  }

  # Check if we actually extracted anything
  numeric_fields <- Filter(is.numeric, result$lab_results)
  if (length(numeric_fields) == 0) {
    result$success <- FALSE
    result$error <- "IDEXX format detected but could not extract lab values. Try Claude AI parser."
  }

  return(result)
}

# ============================================================================
# CLAUDE API PARSER
# ============================================================================

parse_with_claude <- function(text, api_key) {
  prompt <- paste0('You are a veterinary medical records parser. Extract structured data from this veterinary PDF text.

Return a JSON object with these fields (use null for values not found):

{
  "pet_info": {
    "name": "string",
    "species": "string",
    "breed": "string",
    "sex": "string",
    "age": "string",
    "weight_kg": number
  },
  "lab_date": "YYYY-MM-DD",
  "clinic": "string",
  "vet_name": "string",
  "lab_results": {
    "bun": number,
    "creatinine": number,
    "sdma": number,
    "upc": number,
    "usg": number,
    "sodium": number,
    "potassium": number,
    "chloride": number,
    "calcium": number,
    "phosphorus": number,
    "alt": number,
    "ast": number,
    "alp": number,
    "ggt": number,
    "bilirubin_total": number,
    "glucose": number,
    "total_protein": number,
    "albumin": number,
    "globulin": number,
    "cholesterol": number,
    "fructosamine": number,
    "hematocrit": number,
    "wbc": number,
    "platelets": number,
    "total_t4": number
  },
  "echo_results": {
    "ivsd": number,
    "edd": number,
    "lvfwd": number,
    "fs_pct": number,
    "ao": number,
    "la": number,
    "la_ao_ratio": number,
    "lvot_vmax": number,
    "lvot_pg": number,
    "sam_present": boolean,
    "mitral_regurg": "string",
    "sec_present": boolean,
    "thrombus_present": boolean,
    "lv_systolic_function": "string",
    "acvim_stage": "string"
  },
  "medications": [
    {
      "drug_name": "string",
      "dose_mg": number,
      "frequency": "string",
      "notes": "string"
    }
  ],
  "clinical_notes": "string summarizing key findings"
}

Only include echo_results if echocardiographic data is present.
Only include medications if medication lists are present.
For lab values, extract the RESULT value, not the reference range.
Convert dates to YYYY-MM-DD format.

--- VETERINARY DOCUMENT TEXT ---
', text)

  tryCatch({
    resp <- request("https://api.anthropic.com/v1/messages") |>
      req_headers(
        "x-api-key" = api_key,
        "anthropic-version" = "2023-06-01",
        "content-type" = "application/json"
      ) |>
      req_body_json(list(
        model = "claude-haiku-4-5-20251001",
        max_tokens = 4096,
        messages = list(
          list(role = "user", content = prompt)
        )
      )) |>
      req_timeout(60) |>
      req_perform()

    body <- resp_body_json(resp)
    response_text <- body$content[[1]]$text

    # Extract JSON from response (may be wrapped in markdown code blocks)
    json_str <- response_text
    if (grepl("```json", json_str)) {
      json_str <- sub(".*```json\\s*", "", json_str)
      json_str <- sub("\\s*```.*", "", json_str)
    } else if (grepl("```", json_str)) {
      json_str <- sub(".*```\\s*", "", json_str)
      json_str <- sub("\\s*```.*", "", json_str)
    }

    parsed <- fromJSON(json_str, simplifyVector = FALSE)

    return(list(
      success = TRUE,
      format = "claude_ai",
      pet_info = parsed$pet_info %||% list(),
      lab_results = c(
        list(
          lab_date = parsed$lab_date,
          clinic = parsed$clinic,
          vet_name = parsed$vet_name
        ),
        parsed$lab_results
      ),
      echo_results = parsed$echo_results,
      medications = parsed$medications,
      clinical_notes = parsed$clinical_notes
    ))
  },
  error = function(e) {
    return(list(
      success = FALSE,
      error = paste("Claude API error:", e$message)
    ))
  })
}

# ============================================================================
# HELPER: Convert parsed result to database-ready data frames
# ============================================================================

#' Convert parsed PDF data to a data frame ready for lab_results table
#' @param parsed Result from parse_vet_pdf()
#' @param pet_id The pet_id to associate with
#' @return Data frame with one row for lab_results table
parsed_to_lab_df <- function(parsed, pet_id) {
  lr <- parsed$lab_results
  if (is.null(lr)) return(NULL)

  data.frame(
    pet_id = pet_id,
    lab_date = lr$lab_date %||% as.character(Sys.Date()),
    clinic = lr$clinic %||% "",
    vet_name = lr$vet_name %||% "",
    bun = lr$bun,
    creatinine = lr$creatinine,
    sdma = lr$sdma,
    upc = lr$upc,
    usg = lr$usg,
    sodium = lr$sodium,
    potassium = lr$potassium,
    chloride = lr$chloride,
    calcium = lr$calcium,
    phosphorus = lr$phosphorus,
    alt = lr$alt,
    ast = lr$ast,
    alp = lr$alp,
    ggt = lr$ggt,
    bilirubin_total = lr$bilirubin_total,
    glucose = lr$glucose,
    total_protein = lr$total_protein,
    albumin = lr$albumin,
    globulin = lr$globulin,
    cholesterol = lr$cholesterol,
    fructosamine = lr$fructosamine,
    hematocrit = lr$hematocrit,
    wbc = lr$wbc,
    platelets = lr$platelets,
    total_t4 = lr$total_t4,
    notes = parsed$clinical_notes %||% paste("Auto-extracted from PDF.", parsed$format_detected),
    stringsAsFactors = FALSE
  )
}

#' Convert parsed echo data to a data frame
parsed_to_echo_df <- function(parsed, pet_id) {
  er <- parsed$echo_results
  if (is.null(er)) return(NULL)

  data.frame(
    pet_id = pet_id,
    echo_date = parsed$lab_results$lab_date %||% as.character(Sys.Date()),
    clinic = parsed$lab_results$clinic %||% "",
    vet_name = parsed$lab_results$vet_name %||% "",
    ivsd = er$ivsd,
    edd = er$edd,
    lvfwd = er$lvfwd,
    fs_pct = er$fs_pct,
    ao = er$ao,
    la = er$la,
    la_ao_ratio = er$la_ao_ratio,
    lvot_vmax = er$lvot_vmax,
    lvot_pg = er$lvot_pg,
    sam_present = as.integer(isTRUE(er$sam_present)),
    mitral_regurg = er$mitral_regurg,
    sec_present = as.integer(isTRUE(er$sec_present)),
    thrombus_present = as.integer(isTRUE(er$thrombus_present)),
    lv_systolic_function = er$lv_systolic_function,
    acvim_stage = er$acvim_stage,
    notes = paste("Auto-extracted from PDF.", parsed$format_detected),
    stringsAsFactors = FALSE
  )
}

# Null coalescing operator
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
