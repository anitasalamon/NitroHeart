# NitroHeart v2 — Feline HCM Health Companion
# Built with bslib (Bootstrap 5) for a modern, warm experience

library(shiny)
library(bslib)
library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(lubridate)
library(DT)
library(shinyWidgets)
library(shinyjs)

# Source modules
source("R/utils_db.R")
source("R/utils_plots.R")
source("R/reference_ranges.R")
source("R/pdf_parser.R")
source("R/calculators.R")

# ============================================================================
# THEME
# ============================================================================
nh_theme <- bs_theme(
  version = 5,
  bg = "#FAFAF7",
  fg = "#2D3436",
  primary = "#7EB8A8",
  secondary = "#F5E6D3",
  success = "#5BA89D",
  warning = "#E5A84B",
  danger = "#E8967A",
  info = "#6BA3BE",
  base_font = font_google("Inter"),
  heading_font = font_google("Nunito"),
  font_scale = 1.0,
  `enable-rounded` = TRUE
)

# ============================================================================
# UI
# ============================================================================
ui <- page_navbar(
  title = tags$span(
    icon("heart-pulse", style = "color: #E8967A;"),
    tags$span("NitroHeart", style = "font-weight: 700; margin-left: 8px; color: #2D3436;")
  ),
  id = "main_nav",
  theme = nh_theme,
  fillable = FALSE,
  header = tagList(
    useShinyjs(),
    tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"))
  ),

  # ====================================================================
  # TAB 1: DASHBOARD
  # ====================================================================
  nav_panel(
    title = "Dashboard",
    icon = icon("gauge-high"),
    # Global pet selector
    div(class = "container-fluid", style = "max-width: 1200px; margin: 0 auto; padding-top: 1rem;",
      fluidRow(
        column(9),
        column(3, uiOutput("global_pet_selector"))
      ),
      # Pet Hero Card
      uiOutput("dashboard_hero"),
      # Value Boxes
      uiOutput("dashboard_metrics"),
      # Bottom row: SRR trend + alerts
      fluidRow(
        column(7,
          card(
            card_header("Sleeping Respiratory Rate — Last 30 Days"),
            card_body(plotOutput("dash_srr_plot", height = "260px")),
            full_screen = TRUE
          )
        ),
        column(5,
          card(
            card_header("Alerts & Next Steps"),
            card_body(uiOutput("dashboard_alerts"))
          )
        )
      )
    )
  ),

  # ====================================================================
  # TAB 2: HEALTH LOG
  # ====================================================================
  nav_panel(
    title = "Health Log",
    icon = icon("file-medical"),
    div(class = "container-fluid", style = "max-width: 1200px; margin: 0 auto; padding-top: 1rem;",
      navset_card_tab(
        id = "healthlog_tabs",

        # --- Upload PDF ---
        nav_panel(
          title = "Upload PDF",
          icon = icon("cloud-arrow-up"),
          layout_column_wrap(
            width = 1/2,
            card(
              card_header("Upload Veterinary Records"),
              card_body(
                uiOutput("upload_pet_select"),
                fileInput("pdf_upload", "Upload PDF",
                          accept = ".pdf",
                          placeholder = "Drag & drop or click to browse"),
                p(style = "color: #6B7B7D; font-size: 0.85rem; margin-top: -8px;",
                  "Supported: IDEXX lab reports, clinical summaries, echo reports"),
                accordion(
                  open = FALSE,
                  accordion_panel(
                    "AI-Powered Parsing (Optional)",
                    icon = icon("wand-magic-sparkles"),
                    p(style = "color: #6B7B7D; font-size: 0.85rem;",
                      "IDEXX reports work without an API key. For other formats, add your Anthropic key."),
                    passwordInput("api_key", "Anthropic API Key",
                                  placeholder = "sk-ant-..."),
                    p(style = "font-size: 0.8rem; color: #6B7B7D;",
                      "Your key is never stored. Get one at console.anthropic.com")
                  )
                ),
                br(),
                actionButton("parse_pdf", "Extract Data from PDF",
                             class = "btn-primary btn-lg", style = "width: 100%;",
                             icon = icon("wand-magic-sparkles")),
                br(), br(),
                uiOutput("parse_status")
              )
            ),
            card(
              card_header("Extracted Data Preview"),
              card_body(
                uiOutput("parse_preview"),
                uiOutput("parse_save_buttons")
              )
            )
          )
        ),

        # --- Quick Log (SRR) ---
        nav_panel(
          title = "Quick Log",
          icon = icon("stopwatch"),
          layout_column_wrap(
            width = 1/2,
            card(
              card_header("Log Sleeping Respiratory Rate"),
              card_body(
                p(style = "color: #6B7B7D; font-size: 0.9rem;",
                  "Count breaths for 15 seconds and multiply by 4. One rise + fall of chest = 1 breath."),
                fluidRow(
                  column(6, dateInput("srr_date", "Date", value = Sys.Date())),
                  column(6, timeInput("srr_time", "Time", value = Sys.time()))
                ),
                numericInput("srr_value", "Sleeping Respiratory Rate (breaths/min)",
                             value = NULL, min = 0, max = 120),
                selectInput("srr_activity", "Activity Before",
                            choices = c("Sleeping", "Resting/relaxed", "Just woke up",
                                        "Post-play", "Post-medication")),
                textAreaInput("srr_notes", "Notes (optional)", rows = 2),
                actionButton("save_srr", "Log SRR", class = "btn-primary", style = "width: 100%;",
                             icon = icon("check"))
              )
            ),
            card(
              card_header("Reference: Sleeping Respiratory Rate"),
              card_body(
                div(class = "alert-card alert-good",
                    tags$strong("Normal:"), " < 30 breaths/min"),
                div(class = "alert-card alert-watch",
                    tags$strong("Elevated:"), " 30-35 breaths/min — worth monitoring"),
                div(class = "alert-card alert-urgent",
                    tags$strong("Urgent:"), " > 35 breaths/min — contact your vet"),
                hr(),
                p(style = "color: #6B7B7D; font-size: 0.85rem;",
                  "Measure when your cat is calmly sleeping (not purring). Consistency matters more ",
                  "than any single reading. Try to measure at the same time each day.")
              )
            )
          )
        ),

        # --- Lab Results ---
        nav_panel(
          title = "Labs",
          icon = icon("vial"),
          layout_column_wrap(
            width = 1/2,
            card(
              card_header("Add Lab Results"),
              card_body(style = "max-height: 600px; overflow-y: auto;",
                dateInput("lab_date", "Lab Date", value = Sys.Date()),
                fluidRow(
                  column(6, textInput("lab_clinic", "Clinic")),
                  column(6, textInput("lab_vet", "Veterinarian"))
                ),
                hr(),
                h6("Kidney Panel", style = "color: #7EB8A8; font-weight: 600;"),
                fluidRow(
                  column(6, numericInput("lab_bun", "BUN (mg/dL)", value = NULL, min = 0)),
                  column(6, numericInput("lab_creat", "Creatinine (mg/dL)", value = NULL, min = 0, step = 0.1))
                ),
                fluidRow(
                  column(6, numericInput("lab_sdma", "SDMA (ug/dL)", value = NULL, min = 0)),
                  column(6, numericInput("lab_upc", "UPC", value = NULL, min = 0, step = 0.1))
                ),
                hr(),
                h6("Electrolytes", style = "color: #7EB8A8; font-weight: 600;"),
                fluidRow(
                  column(4, numericInput("lab_potassium", "K+", value = NULL, min = 0, step = 0.1)),
                  column(4, numericInput("lab_sodium", "Na+", value = NULL, min = 0)),
                  column(4, numericInput("lab_chloride", "Cl-", value = NULL, min = 0))
                ),
                fluidRow(
                  column(6, numericInput("lab_calcium", "Calcium", value = NULL, min = 0, step = 0.1)),
                  column(6, numericInput("lab_phosphorus", "Phosphorus", value = NULL, min = 0, step = 0.1))
                ),
                hr(),
                h6("Liver & Metabolic", style = "color: #7EB8A8; font-weight: 600;"),
                fluidRow(
                  column(4, numericInput("lab_alt", "ALT", value = NULL, min = 0)),
                  column(4, numericInput("lab_alp", "ALP", value = NULL, min = 0)),
                  column(4, numericInput("lab_glucose", "Glucose", value = NULL, min = 0))
                ),
                fluidRow(
                  column(6, numericInput("lab_t4", "Total T4", value = NULL, min = 0, step = 0.1)),
                  column(6, numericInput("lab_fructosamine", "Fructosamine", value = NULL, min = 0))
                ),
                hr(),
                h6("Hematology", style = "color: #7EB8A8; font-weight: 600;"),
                fluidRow(
                  column(4, numericInput("lab_hct", "Hematocrit %", value = NULL, min = 0)),
                  column(4, numericInput("lab_wbc", "WBC", value = NULL, min = 0, step = 0.1)),
                  column(4, numericInput("lab_plt", "Platelets", value = NULL, min = 0))
                ),
                textAreaInput("lab_notes", "Notes", rows = 2),
                actionButton("save_lab", "Save Lab Results", class = "btn-primary",
                             style = "width: 100%;", icon = icon("check"))
              )
            ),
            card(
              card_header("Lab History"),
              card_body(
                DTOutput("lab_history_table")
              ),
              full_screen = TRUE
            )
          )
        ),

        # --- Echo ---
        nav_panel(
          title = "Echo",
          icon = icon("wave-square"),
          layout_column_wrap(
            width = 1/2,
            card(
              card_header("Add Echo Results"),
              card_body(style = "max-height: 600px; overflow-y: auto;",
                dateInput("echo_date", "Echo Date", value = Sys.Date()),
                fluidRow(
                  column(6, textInput("echo_clinic", "Clinic")),
                  column(6, textInput("echo_vet", "Cardiologist"))
                ),
                hr(),
                h6("LV Measurements", style = "color: #7EB8A8; font-weight: 600;"),
                fluidRow(
                  column(4, numericInput("echo_ivsd", "IVSd (mm)", value = NULL, min = 0, step = 0.1)),
                  column(4, numericInput("echo_edd", "EDD (mm)", value = NULL, min = 0, step = 0.1)),
                  column(4, numericInput("echo_lvfwd", "LVFWd (mm)", value = NULL, min = 0, step = 0.1))
                ),
                numericInput("echo_fs", "Fractional Shortening (%)", value = NULL, min = 0, max = 100),
                hr(),
                h6("Atrial Measurements", style = "color: #7EB8A8; font-weight: 600;"),
                fluidRow(
                  column(4, numericInput("echo_ao", "Ao (cm)", value = NULL, min = 0, step = 0.01)),
                  column(4, numericInput("echo_la", "LA (cm)", value = NULL, min = 0, step = 0.01)),
                  column(4, numericInput("echo_la_ao", "LA/Ao", value = NULL, min = 0, step = 0.01))
                ),
                hr(),
                h6("Flow & Obstruction", style = "color: #7EB8A8; font-weight: 600;"),
                fluidRow(
                  column(6, numericInput("echo_lvot", "LVOT Vmax (m/s)", value = NULL, min = 0, step = 0.1)),
                  column(6, numericInput("echo_lvot_pg", "LVOT PG (mmHg)", value = NULL, min = 0))
                ),
                checkboxInput("echo_sam", "SAM present"),
                hr(),
                h6("Qualitative Findings", style = "color: #7EB8A8; font-weight: 600;"),
                fluidRow(
                  column(6, selectInput("echo_mr", "Mitral Regurg",
                                        choices = c("None", "Mild", "Moderate", "Severe"))),
                  column(6, selectInput("echo_lv_fn", "LV Systolic Function",
                                        choices = c("Normal", "Mildly reduced", "Moderately reduced", "Severely reduced")))
                ),
                fluidRow(
                  column(6, checkboxInput("echo_sec", "Spontaneous Echo Contrast")),
                  column(6, checkboxInput("echo_thrombus", "Thrombus present"))
                ),
                selectInput("echo_acvim", "ACVIM Stage", choices = c("", "B1", "B2", "C", "D")),
                textAreaInput("echo_notes", "Notes", rows = 2),
                actionButton("save_echo", "Save Echo", class = "btn-primary",
                             style = "width: 100%;", icon = icon("check"))
              )
            ),
            card(
              card_header("Echo History"),
              card_body(
                DTOutput("echo_history_table")
              ),
              full_screen = TRUE
            )
          )
        ),

        # --- Medications ---
        nav_panel(
          title = "Medications",
          icon = icon("pills"),
          layout_column_wrap(
            width = 1/2,
            card(
              card_header("Add Medication"),
              card_body(
                selectInput("med_drug", "Medication", choices = c(
                  "-- Select --" = "",
                  "Diuretics" = "",
                  "Furosemide (Lasix)" = "Furosemide",
                  "Spironolactone" = "Spironolactone",
                  "Hydrochlorothiazide" = "Hydrochlorothiazide",
                  "Cardiac" = "",
                  "Pimobendan (Vetmedin)" = "Pimobendan",
                  "Atenolol" = "Atenolol",
                  "Diltiazem" = "Diltiazem",
                  "Antithrombotics" = "",
                  "Clopidogrel (Plavix)" = "Clopidogrel",
                  "Rivaroxaban" = "Rivaroxaban",
                  "Novel / Off-label" = "",
                  "Bexagliflozin (Bexacat)" = "Bexagliflozin",
                  "Velagliflozin (Senvelgo)" = "Velagliflozin",
                  "Felycin-CA1 (rapamycin)" = "Felycin-CA1",
                  "Supplements" = "",
                  "Potassium" = "Potassium",
                  "Gabapentin" = "Gabapentin",
                  "Other" = "Other"
                )),
                conditionalPanel(
                  condition = "input.med_drug == 'Other'",
                  textInput("med_drug_other", "Drug Name")
                ),
                fluidRow(
                  column(6, numericInput("med_dose", "Dose (mg)", value = NULL, min = 0, step = 0.1)),
                  column(6, textInput("med_freq", "Frequency", placeholder = "e.g., q12h"))
                ),
                fluidRow(
                  column(6, dateInput("med_start", "Start Date", value = Sys.Date())),
                  column(6, dateInput("med_end", "End Date (blank if ongoing)", value = NULL))
                ),
                textInput("med_reason", "Reason", placeholder = "e.g., CHF management"),
                checkboxInput("med_offlabel", "Off-label use"),
                textAreaInput("med_notes", "Notes", rows = 2),
                actionButton("save_med", "Save Medication", class = "btn-primary",
                             style = "width: 100%;", icon = icon("check"))
              )
            ),
            card(
              card_header("Active Medications"),
              card_body(
                DTOutput("active_meds_table"),
                hr(),
                h6("Full History"),
                DTOutput("all_meds_table")
              ),
              full_screen = TRUE
            )
          )
        ),

        # --- CHF Episodes ---
        nav_panel(
          title = "CHF Episodes",
          icon = icon("triangle-exclamation"),
          layout_column_wrap(
            width = 1/2,
            card(
              card_header(tags$span(style = "color: #E8967A;", "Log CHF Episode")),
              card_body(
                dateInput("chf_date", "Episode Date", value = Sys.Date()),
                selectInput("chf_severity", "Severity", choices = c(
                  "Mild - responded to extra furosemide at home",
                  "Moderate - required ER visit but stabilized",
                  "Severe - hospitalization required",
                  "Critical - ICU / oxygen therapy"
                )),
                textAreaInput("chf_symptoms", "Symptoms", rows = 2,
                              placeholder = "e.g., tachypnea, open-mouth breathing"),
                textInput("chf_trigger", "Possible Trigger",
                          placeholder = "e.g., missed medication, stress"),
                fluidRow(
                  column(6, checkboxInput("chf_er", "ER/Emergency visit")),
                  column(6, checkboxInput("chf_hospitalized", "Hospitalized"))
                ),
                textAreaInput("chf_treatment", "Treatment Given", rows = 2),
                textInput("chf_outcome", "Outcome"),
                textAreaInput("chf_notes", "Notes", rows = 2),
                actionButton("save_chf", "Log Episode", class = "btn-danger",
                             style = "width: 100%;", icon = icon("triangle-exclamation"))
              )
            ),
            card(
              card_header("CHF Episode History"),
              card_body(
                DTOutput("chf_history_table"),
                hr(),
                plotOutput("chf_timeline_plot", height = "200px")
              ),
              full_screen = TRUE
            )
          )
        ),

        # --- My Pet ---
        nav_panel(
          title = "My Pet",
          icon = icon("paw"),
          layout_column_wrap(
            width = 1/2,
            card(
              card_header("Pet Information"),
              card_body(
                textInput("pet_name", "Pet Name", placeholder = "e.g., Nitro"),
                selectInput("pet_breed", "Breed", choices = c(
                  "", "Ragdoll", "Maine Coon", "Sphynx", "Persian", "British Shorthair",
                  "Bengal", "Siamese", "Domestic Shorthair", "Domestic Longhair",
                  "Domestic Mediumhair", "Other"
                )),
                fluidRow(
                  column(6, selectInput("pet_sex", "Sex", choices = c("", "Male Neutered", "Male Intact",
                                                                       "Female Spayed", "Female Intact"))),
                  column(6, textInput("pet_color", "Color"))
                ),
                fluidRow(
                  column(6, dateInput("pet_dob", "Date of Birth", value = NULL)),
                  column(6, numericInput("pet_weight", "Weight (kg)", value = NULL, min = 0, max = 20, step = 0.1))
                ),
                dateInput("pet_dx_date", "Date of HCM Diagnosis", value = NULL),
                hr(),
                h6("Genetic Testing", style = "color: #7EB8A8; font-weight: 600;"),
                selectInput("pet_mybpc3", "MYBPC3 R820W Result", choices = c(
                  "Not tested", "N/N (Negative)", "N/HCMrd (Heterozygous)",
                  "HCMrd/HCMrd (Homozygous)"
                )),
                p(style = "color: #6B7B7D; font-size: 0.8rem;",
                  "Note: The R820W test detects only ONE variant. A negative result does NOT rule out ",
                  "genetic HCM. (Kaplan et al., G3, 2025)"),
                hr(),
                textInput("pet_breeder", "Breeder (optional)"),
                textInput("pet_microchip", "Microchip # (optional)"),
                textInput("owner_name", "Your Name (private)"),
                textInput("owner_email", "Email (private)"),
                br(),
                actionButton("save_pet", "Save Pet Profile", class = "btn-primary btn-lg",
                             style = "width: 100%;", icon = icon("check"))
              )
            ),
            card(
              card_header("Registered Pets"),
              card_body(
                uiOutput("pet_save_status"),
                DTOutput("pets_table")
              )
            )
          )
        )
      )
    )
  ),

  # ====================================================================
  # TAB 3: INSIGHTS
  # ====================================================================
  nav_panel(
    title = "Insights",
    icon = icon("brain"),
    div(class = "container-fluid", style = "max-width: 1200px; margin: 0 auto; padding-top: 1rem;",
      navset_card_tab(
        id = "insights_tabs",

        # --- Trend Charts ---
        nav_panel(
          title = "Trends",
          icon = icon("chart-line"),
          fluidRow(
            column(4,
              selectInput("lab_analyte", "Select Analyte",
                          choices = setNames(feline_reference_ranges$db_column,
                                             paste0(feline_reference_ranges$analyte, " (",
                                                    feline_reference_ranges$unit, ")")),
                          selected = "creatinine")
            ),
            column(8,
              uiOutput("lab_clinical_note")
            )
          ),
          card(
            card_body(plotOutput("lab_trend_plot", height = "380px")),
            full_screen = TRUE
          ),
          br(),
          card(
            card_header("Echo Trends"),
            card_body(plotOutput("echo_trend_plot", height = "320px")),
            full_screen = TRUE
          ),
          br(),
          card(
            card_header("Medication Timeline"),
            card_body(plotOutput("med_timeline_plot", height = "350px")),
            full_screen = TRUE
          )
        ),

        # --- ACVIM Calculator ---
        nav_panel(
          title = "ACVIM Stage",
          icon = icon("heart"),
          layout_column_wrap(
            width = 1/2,
            card(
              card_header("ACVIM Stage Calculator"),
              card_body(
                p(style = "color: #6B7B7D; font-size: 0.9rem;",
                  "Enter echocardiographic measurements to calculate ACVIM staging. ",
                  "Based on the 2020 ACVIM Consensus Statement (Luis Fuentes et al., JVIM)."),
                hr(),
                h6("Echo Measurements", style = "color: #7EB8A8; font-weight: 600;"),
                fluidRow(
                  column(6, numericInput("calc_ivsd", "IVSd (mm)", value = NULL, min = 0, step = 0.1)),
                  column(6, numericInput("calc_lvfwd", "LVFWd (mm)", value = NULL, min = 0, step = 0.1))
                ),
                fluidRow(
                  column(6, numericInput("calc_la_ao", "LA/Ao ratio", value = NULL, min = 0, step = 0.01)),
                  column(6, numericInput("calc_la_mm", "LA diameter (mm)", value = NULL, min = 0, step = 0.1))
                ),
                hr(),
                h6("Clinical History", style = "color: #7EB8A8; font-weight: 600;"),
                checkboxInput("calc_chf", "History of congestive heart failure"),
                checkboxInput("calc_ate", "History of arterial thromboembolism"),
                checkboxInput("calc_refractory", "Refractory CHF (not responding to standard therapy)"),
                br(),
                actionButton("calc_acvim_btn", "Calculate Stage", class = "btn-primary btn-lg",
                             style = "width: 100%;", icon = icon("calculator"))
              )
            ),
            card(
              card_header("Result"),
              card_body(
                uiOutput("acvim_result"),
                hr(),
                h6("ACVIM Staging Reference", style = "font-weight: 600;"),
                div(class = "stage-badge stage-a", style = "margin: 4px;", "A — At Risk"),
                div(class = "stage-badge stage-b1", style = "margin: 4px;", "B1 — Subclinical, Low Risk"),
                div(class = "stage-badge stage-b2", style = "margin: 4px;", "B2 — Subclinical, High Risk"),
                div(class = "stage-badge stage-c", style = "margin: 4px;", "C — Heart Failure"),
                div(class = "stage-badge stage-d", style = "margin: 4px;", "D — Refractory CHF"),
                br(), br(),
                p(style = "color: #6B7B7D; font-size: 0.85rem;",
                  tags$strong("Key thresholds:"), " LV wall >= 6mm = HCM diagnosis. ",
                  "LA/Ao >= 1.8 or LA >= 18mm = Stage B2. ",
                  "Wall > 9mm = extreme hypertrophy (independent poor prognosis).")
              )
            )
          )
        ),

        # --- IRIS CKD Calculator ---
        nav_panel(
          title = "IRIS CKD",
          icon = icon("droplet"),
          layout_column_wrap(
            width = 1/2,
            card(
              card_header("IRIS CKD Stage Calculator"),
              card_body(
                p(style = "color: #6B7B7D; font-size: 0.9rem;",
                  "Feline chronic kidney disease staging. Includes the SDMA up-staging rule ",
                  "(SDMA elevates ~17 months before creatinine)."),
                hr(),
                numericInput("calc_creat", "Creatinine (mg/dL)", value = NULL, min = 0, step = 0.1),
                numericInput("calc_sdma", "SDMA (ug/dL)", value = NULL, min = 0),
                numericInput("calc_upc", "UPC (Urine Protein:Creatinine)", value = NULL, min = 0, step = 0.01),
                numericInput("calc_bp", "Systolic Blood Pressure (mmHg)", value = NULL, min = 0),
                br(),
                actionButton("calc_iris_btn", "Calculate Stage", class = "btn-primary btn-lg",
                             style = "width: 100%;", icon = icon("calculator"))
              )
            ),
            card(
              card_header("Result"),
              card_body(
                uiOutput("iris_result")
              )
            )
          )
        ),

        # --- Drug Interactions ---
        nav_panel(
          title = "Drug Interactions",
          icon = icon("shield-halved"),
          card(
            card_header("Drug Interaction Checker"),
            card_body(
              p(style = "color: #6B7B7D; font-size: 0.9rem;",
                "Checks current medications for known interactions. Based on Tufts CardioRush ",
                "Formulary and CEG Feline Formulary."),
              uiOutput("interaction_results")
            ),
            full_screen = TRUE
          )
        )
      )
    )
  ),

  # ====================================================================
  # TAB 4: LEARN
  # ====================================================================
  nav_panel(
    title = "Learn",
    icon = icon("book-medical"),
    div(class = "container-fluid", style = "max-width: 900px; margin: 0 auto; padding-top: 1rem;",
      h3("Understanding Feline HCM", style = "margin-bottom: 1.5rem;"),
      accordion(
        open = "About HCM",
        accordion_panel(
          "About HCM",
          icon = icon("heart"),
          p("Hypertrophic cardiomyopathy (HCM) is the most common inherited cardiac disease in cats, ",
            "affecting approximately 1 in 7 cats. It causes abnormal thickening of the heart muscle, ",
            "which can lead to heart failure, blood clots, and sudden death."),
          p(tags$strong("ACVIM Stages:"), " The disease progresses through stages A (at risk) through D ",
            "(refractory heart failure). Many cats live years at stages B1-B2 with proper management."),
          p(tags$strong("Key monitoring:"), " Regular echocardiograms, bloodwork (kidney function is ",
            "closely linked), and daily sleeping respiratory rate counts at home.")
        ),
        accordion_panel(
          "Genetics & Testing",
          icon = icon("dna"),
          p("The most well-known genetic test is for the ", tags$strong("MYBPC3 R820W"), " mutation in Ragdoll cats. ",
            "However, this single-gene test misses most cases of HCM."),
          p("The ", tags$strong("Kaplan et al. (2025)"), " GWAS study of 138 cats identified variants in ",
            "multiple genes beyond MYBPC3, including TTN, MYH6, VCL, JPH2, ANKRD1, and BRAF — ",
            "many of which are also implicated in human cardiomyopathy."),
          p(tags$strong("Bottom line:"), " A negative genetic test does NOT mean your cat won't develop HCM. ",
            "Regular echocardiographic screening remains essential for at-risk breeds.")
        ),
        accordion_panel(
          "Emerging Therapies",
          icon = icon("flask"),
          h6("Rapamycin (Felicyn-CA1)", style = "color: #7EB8A8; font-weight: 600;"),
          p("FDA conditionally approved March 2025 — the ", tags$strong("first drug shown to reverse feline HCM"),
            " at the structural level. The RAPACAT trial showed decreased LV wall thickness with low-dose ",
            "rapamycin (0.3 mg/kg weekly). The HALT pivotal study (300 cats) is ongoing."),
          h6("Cardiac Myosin Inhibitors", style = "color: #7EB8A8; font-weight: 600;"),
          p(tags$strong("Mavacamten"), " reduced LVOT obstruction in cats without affecting heart rate (unlike beta-blockers). ",
            tags$strong("Aficamten"), " and ", tags$strong("CK-586"), " also show promise. None are FDA-approved for cats yet."),
          h6("SGLT2 Inhibitors", style = "color: #7EB8A8; font-weight: 600;"),
          p(tags$strong("Bexagliflozin (Bexacat)"), " is FDA-approved for feline diabetes but being studied for ",
            "cardiorenal benefits. Causes less RAAS activation than furosemide — a potential mechanistic advantage ",
            "for cats with both heart disease and kidney disease.")
        ),
        accordion_panel(
          "The Cardiorenal Connection",
          icon = icon("droplet"),
          p("Many HCM cats develop concurrent kidney disease. The kidneys and heart are deeply linked:"),
          tags$ul(
            tags$li("Furosemide (essential for CHF) can worsen kidney function"),
            tags$li("ACE inhibitors protect both heart and kidneys but need monitoring"),
            tags$li("SDMA is an earlier marker than creatinine — elevates ~17 months sooner"),
            tags$li("IRIS CKD staging helps guide medication adjustments")
          ),
          p("This is why NitroHeart tracks both cardiac and renal values together — they can't be ",
            "managed in isolation.")
        ),
        accordion_panel(
          "Monitoring at Home",
          icon = icon("house"),
          h6("Sleeping Respiratory Rate (SRR)", style = "color: #7EB8A8; font-weight: 600;"),
          p("The single most important thing you can do at home. A consistently elevated SRR (> 30-35 brpm) ",
            "can detect CHF days before an emergency. Count for 15 seconds, multiply by 4."),
          h6("What to Watch For", style = "color: #7EB8A8; font-weight: 600;"),
          tags$ul(
            tags$li("Open-mouth breathing (always an emergency in cats)"),
            tags$li("Hiding, decreased appetite, lethargy"),
            tags$li("Sudden hind-limb paralysis (sign of blood clot — call vet immediately)"),
            tags$li("Increased sleeping respiratory rate over several days")
          )
        )
      ),
      br(),
      card(
        card_header("About NitroHeart"),
        card_body(
          p("NitroHeart was built because managing feline HCM shouldn't require a PhD in ",
            "cardiovascular science."),
          p("When Nitro, a Ragdoll, was diagnosed with advanced juvenile HCM at 10 months old, ",
            "his medical records were scattered across emergency clinics, specialists, and primary vets. ",
            "Lab values that showed critical kidney trends were buried in separate PDFs. ",
            "There was no way to visualize what was happening over time."),
          p("Both of Nitro's parents tested N/N (negative) for the MYBPC3 R820W mutation — proof that ",
            "a single-gene test misses most cases of HCM."),
          p(style = "color: #6B7B7D; font-size: 0.9rem; margin-top: 1rem;",
            "Built with love for Nitro by Anita Salamon, PhD"),
          p(style = "color: #6B7B7D; font-size: 0.85rem;",
            "Computational biologist | University of Virginia | Gary Owens Lab")
        )
      )
    )
  )
)

# ============================================================================
# SERVER
# ============================================================================
server <- function(input, output, session) {

  # Auto-theme ggplot2 plots to match bslib
  thematic::thematic_shiny()

  # Initialize database
  db <- init_db("nitroheart.sqlite")
  onStop(function() close_db(db))

  # Reactive: pet list
  pets_rv <- reactiveVal(get_records(db, "pets"))

  pet_choices <- reactive({
    p <- pets_rv()
    if (nrow(p) == 0) return(c("No pets registered" = ""))
    setNames(p$pet_id, p$name)
  })

  # Global pet selector
  output$global_pet_selector <- renderUI({
    selectInput("global_pet_id", NULL, choices = pet_choices(), width = "100%")
  })

  # Upload tab pet selector
  output$upload_pet_select <- renderUI({
    selectInput("upload_pet_id", "Select Pet", choices = pet_choices())
  })

  # Reactive: all data for selected pet
  pet_data <- reactive({
    req(input$global_pet_id)
    pid <- as.integer(input$global_pet_id)
    list(
      info = {
        p <- pets_rv()
        if (nrow(p) > 0) p[p$pet_id == pid, ] else data.frame()
      },
      labs = get_records(db, "lab_results", pet_id = pid, order_by = "lab_date"),
      echos = get_records(db, "echo_results", pet_id = pid, order_by = "echo_date"),
      meds = get_records(db, "medications", pet_id = pid, order_by = "start_date"),
      srr = get_records(db, "srr_log", pet_id = pid, order_by = "log_date, log_time"),
      chf = get_records(db, "chf_episodes", pet_id = pid, order_by = "episode_date")
    )
  })

  # ====================================================================
  # DASHBOARD
  # ====================================================================

  output$dashboard_hero <- renderUI({
    pd <- pet_data()
    info <- pd$info

    if (nrow(info) == 0) {
      return(div(class = "pet-hero fade-in",
        div(class = "empty-state",
          div(class = "empty-icon", icon("paw")),
          h4("Welcome to NitroHeart"),
          p("Register your cat to get started. Go to Health Log > My Pet."),
          actionButton("go_register", "Register Your Cat", class = "btn-primary btn-lg",
                       icon = icon("paw"))
        )
      ))
    }

    # Calculate ACVIM stage from latest echo
    echos <- pd$echos
    acvim <- NULL
    if (nrow(echos) > 0) {
      latest_echo <- echos[nrow(echos), ]
      has_chf <- nrow(pd$chf) > 0
      acvim <- calculate_acvim_stage(
        ivsd = latest_echo$ivsd,
        lvfwd = latest_echo$lvfwd,
        la_ao = latest_echo$la_ao_ratio,
        chf_history = has_chf
      )
    }

    # Calculate IRIS CKD stage from latest labs
    labs <- pd$labs
    iris <- NULL
    if (nrow(labs) > 0) {
      latest_lab <- labs[nrow(labs), ]
      iris <- calculate_iris_stage(
        creatinine = latest_lab$creatinine,
        sdma = latest_lab$sdma,
        upc = latest_lab$upc
      )
    }

    # Active meds count
    meds <- pd$meds
    active_meds <- if (nrow(meds) > 0) {
      meds[is.na(meds$end_date) | meds$end_date == "" | meds$end_date >= Sys.Date(), ]
    } else data.frame()

    # Pet age
    age_str <- ""
    if (nrow(info) > 0 && !is.na(info$dob) && info$dob != "") {
      age_days <- as.numeric(Sys.Date() - as.Date(info$dob))
      if (age_days > 365) age_str <- paste0(floor(age_days / 365), " years")
      else age_str <- paste0(floor(age_days / 30), " months")
    }

    div(class = "pet-hero fade-in",
      div(style = "display: flex; align-items: center; gap: 1.5rem; flex-wrap: wrap;",
        # Pet photo placeholder
        div(class = "pet-photo-placeholder", icon("cat")),
        # Pet info
        div(style = "flex: 1;",
          div(class = "pet-name", info$name),
          div(class = "pet-subtitle",
            paste(c(info$breed, info$sex, age_str,
                    if (!is.na(info$weight_kg)) paste0(info$weight_kg, " kg")),
                  collapse = " | ")
          )
        ),
        # Staging badges
        div(style = "display: flex; gap: 8px; flex-wrap: wrap;",
          if (!is.null(acvim)) {
            div(class = paste0("stage-badge stage-", tolower(acvim$stage)),
                icon("heart-pulse"), paste("ACVIM", acvim$stage))
          },
          if (!is.null(iris)) {
            div(class = paste0("stage-badge iris-", iris$stage),
                icon("droplet"), paste("IRIS CKD", iris$stage))
          },
          div(class = "stage-badge", style = "background: #E0F2FE; color: #1E40AF;",
              icon("pills"), paste(nrow(active_meds), "active meds"))
        )
      )
    )
  })

  output$dashboard_metrics <- renderUI({
    pd <- pet_data()
    labs <- pd$labs
    srr <- pd$srr

    if (nrow(labs) == 0 && nrow(srr) == 0) {
      return(div(style = "margin: 1rem 0;",
        div(class = "alert-card alert-watch",
          icon("info-circle"), " Upload your cat's lab results or start logging SRR to see health metrics here."
        )
      ))
    }

    # Latest lab values
    latest <- if (nrow(labs) > 0) labs[nrow(labs), ] else list()
    # Latest SRR
    last_srr <- if (nrow(srr) > 0) srr$srr_brpm[nrow(srr)] else NULL
    avg_srr <- if (nrow(srr) > 0) round(mean(srr$srr_brpm, na.rm = TRUE)) else NULL

    # Helper to create value box with status color
    make_vbox <- function(title, value, ref_col = NULL, unit = "") {
      if (is.null(value) || is.na(value)) return(NULL)
      display_val <- paste0(value, if (unit != "") paste0(" ", unit))
      # Determine status
      theme_color <- "light"
      flag <- ""
      if (!is.null(ref_col)) {
        ref <- feline_reference_ranges[feline_reference_ranges$db_column == ref_col, ]
        if (nrow(ref) > 0) {
          if (value > ref$ref_high) { theme_color <- "danger"; flag <- " (H)" }
          else if (value < ref$ref_low) { theme_color <- "warning"; flag <- " (L)" }
          else { theme_color <- "success" }
        }
      }
      value_box(
        title = title,
        value = paste0(display_val, flag),
        theme = theme_color,
        showcase = if (theme_color == "danger") icon("arrow-up") else if (theme_color == "success") icon("check") else icon("minus")
      )
    }

    boxes <- list()
    if (nrow(labs) > 0) {
      boxes <- c(boxes, list(
        make_vbox("BUN", latest$bun, "bun", "mg/dL"),
        make_vbox("Creatinine", latest$creatinine, "creatinine", "mg/dL"),
        make_vbox("SDMA", latest$sdma, "sdma", "ug/dL"),
        make_vbox("Potassium", latest$potassium, "potassium", "mmol/L")
      ))
    }
    if (!is.null(last_srr)) {
      srr_theme <- if (last_srr <= 30) "success" else if (last_srr <= 35) "warning" else "danger"
      boxes <- c(boxes, list(
        value_box(
          title = "Last SRR",
          value = paste(last_srr, "bpm"),
          theme = srr_theme,
          showcase = icon("lungs")
        )
      ))
    }

    # Filter out NULLs
    boxes <- Filter(Negate(is.null), boxes)
    if (length(boxes) == 0) return(NULL)

    div(style = "margin: 1rem 0;",
      layout_column_wrap(
        width = "200px",
        !!!boxes
      )
    )
  })

  # Dashboard SRR plot
  output$dash_srr_plot <- renderPlot({
    pd <- pet_data()
    srr <- pd$srr
    if (nrow(srr) == 0) {
      plot.new()
      text(0.5, 0.5, "No SRR data yet. Start logging to see trends.",
           cex = 1.2, col = "#6B7B7D")
      return()
    }
    plot_srr_trend(srr)
  })

  # Dashboard alerts
  output$dashboard_alerts <- renderUI({
    pd <- pet_data()
    labs <- pd$labs
    echos <- pd$echos
    srr <- pd$srr
    meds <- pd$meds

    alerts <- list()

    # Check latest labs for concerning values
    if (nrow(labs) > 0) {
      latest <- labs[nrow(labs), ]
      lab_date <- as.Date(latest$lab_date)
      days_since <- as.numeric(Sys.Date() - lab_date)

      if (!is.na(latest$creatinine) && latest$creatinine > 2.3) {
        alerts <- c(alerts, list(
          div(class = "alert-card alert-watch",
              icon("droplet"), tags$strong(" Creatinine elevated "),
              paste0("(", latest$creatinine, " mg/dL on ", format(lab_date, "%b %d"), ")"),
              " — worth discussing with your vet")
        ))
      }
      if (!is.na(latest$potassium) && (latest$potassium < 3.7 || latest$potassium > 5.2)) {
        status <- if (latest$potassium < 3.7) "low" else "high"
        alerts <- c(alerts, list(
          div(class = "alert-card alert-watch",
              icon("bolt"), tags$strong(paste(" Potassium", status)),
              paste0(" (", latest$potassium, " mmol/L)"))
        ))
      }
      if (days_since > 90) {
        alerts <- c(alerts, list(
          div(class = "next-step-item",
              div(class = "step-icon", style = "background: #E5A84B; color: white;", icon("calendar")),
              div(paste0("Labs are ", days_since, " days old. Consider rechecking.")))
        ))
      }
    }

    # Check SRR
    if (nrow(srr) > 0) {
      recent_srr <- srr[srr$log_date >= as.character(Sys.Date() - 7), ]
      if (nrow(recent_srr) > 0) {
        avg_recent <- mean(recent_srr$srr_brpm, na.rm = TRUE)
        if (avg_recent > 35) {
          alerts <- c(alerts, list(
            div(class = "alert-card alert-urgent",
                icon("lungs"), tags$strong(" SRR elevated this week "),
                paste0("(avg ", round(avg_recent), " bpm) — contact your vet"))
          ))
        }
      }
      last_srr_date <- max(as.Date(srr$log_date))
      if (Sys.Date() - last_srr_date > 3) {
        alerts <- c(alerts, list(
          div(class = "next-step-item",
              div(class = "step-icon", style = "background: #7EB8A8; color: white;", icon("stopwatch")),
              div("SRR check due — last logged ", format(last_srr_date, "%b %d")))
        ))
      }
    } else {
      alerts <- c(alerts, list(
        div(class = "next-step-item",
            div(class = "step-icon", style = "background: #7EB8A8; color: white;", icon("stopwatch")),
            div("Start logging sleeping respiratory rate — it takes 30 seconds"))
      ))
    }

    # Check drug interactions
    if (nrow(meds) > 0) {
      active <- meds[is.na(meds$end_date) | meds$end_date == "" | meds$end_date >= Sys.Date(), ]
      if (nrow(active) > 0) {
        has_ckd <- nrow(labs) > 0 && !is.na(labs[nrow(labs), ]$creatinine) && labs[nrow(labs), ]$creatinine > 1.6
        interactions <- check_drug_interactions(active$drug_name, has_ckd = has_ckd, has_chf = nrow(pd$chf) > 0)
        if (nrow(interactions) > 0) {
          critical <- interactions[interactions$severity == "contraindicated", ]
          if (nrow(critical) > 0) {
            alerts <- c(alerts, list(
              div(class = "alert-card alert-urgent",
                  icon("shield-halved"), tags$strong(" Drug interaction alert: "),
                  critical$description[1])
            ))
          }
        }
      }
    }

    if (length(alerts) == 0) {
      alerts <- list(
        div(class = "alert-card alert-good",
            icon("check-circle"), tags$strong(" Looking good! "),
            "No urgent alerts at this time.")
      )
    }

    do.call(tagList, alerts)
  })

  # Navigate to registration
  observeEvent(input$go_register, {
    updateNavbarPage(session, "main_nav", selected = "Health Log")
    updateTabsetPanel(session, "healthlog_tabs", selected = "My Pet")
  })

  # ====================================================================
  # PDF UPLOAD & PARSING
  # ====================================================================
  parsed_data <- reactiveVal(NULL)

  observeEvent(input$parse_pdf, {
    req(input$pdf_upload)
    req(input$upload_pet_id)

    parsed_data(NULL)
    output$parse_status <- renderUI({
      div(style = "color: #7EB8A8; text-align: center; padding: 10px;",
          icon("spinner", class = "fa-spin"), " Extracting data from PDF...")
    })

    result <- parse_vet_pdf(
      pdf_path = input$pdf_upload$datapath,
      api_key = input$api_key
    )

    if (result$success) {
      parsed_data(result)
      output$parse_status <- renderUI({
        div(style = "color: #5BA89D; text-align: center; padding: 10px;",
            icon("check-circle"),
            paste("Data extracted successfully!",
                  if (result$format_detected == "idexx") "(IDEXX rule-based parser)"
                  else if (result$format == "claude_ai") "(Claude AI parser)"
                  else ""))
      })
    } else {
      output$parse_status <- renderUI({
        div(style = "color: #E8967A; text-align: center; padding: 10px;",
            icon("circle-exclamation"), " ", result$error)
      })
    }
  })

  output$parse_preview <- renderUI({
    pd <- parsed_data()
    if (is.null(pd)) {
      return(div(class = "empty-state",
                 div(class = "empty-icon", icon("file-pdf")),
                 p("Upload a PDF and click 'Extract Data' to see results here")))
    }

    lr <- pd$lab_results
    er <- pd$echo_results

    tags_list <- list(
      div(style = "display: flex; gap: 1.5rem; flex-wrap: wrap; margin-bottom: 1rem;",
        tags$span(icon("calendar"), " ", lr$lab_date %||% "Unknown"),
        tags$span(icon("hospital"), " ", lr$clinic %||% "Unknown"),
        tags$span(icon("user-doctor"), " ", lr$vet_name %||% "Unknown")
      ),
      hr()
    )

    # Lab values preview
    if (!is.null(lr)) {
      lab_fields <- c("bun", "creatinine", "sdma", "potassium", "sodium", "chloride",
                       "calcium", "phosphorus", "alt", "ast", "alp", "glucose",
                       "total_protein", "albumin", "hematocrit", "wbc", "platelets",
                       "total_t4", "fructosamine", "upc")
      lab_names <- c("BUN", "Creatinine", "SDMA", "Potassium", "Sodium", "Chloride",
                      "Calcium", "Phosphorus", "ALT", "AST", "ALP", "Glucose",
                      "Total Protein", "Albumin", "Hematocrit", "WBC", "Platelets",
                      "Total T4", "Fructosamine", "UPC")

      rows <- list()
      for (i in seq_along(lab_fields)) {
        v <- lr[[lab_fields[i]]]
        if (!is.null(v) && !is.na(v)) {
          ref <- feline_reference_ranges[feline_reference_ranges$db_column == lab_fields[i], ]
          flag <- ""
          color <- "#2D3436"
          if (nrow(ref) > 0 && is.numeric(v)) {
            if (v > ref$ref_high) { flag <- " (H)"; color <- "#E8967A" }
            else if (v < ref$ref_low) { flag <- " (L)"; color <- "#E5A84B" }
            else { color <- "#5BA89D" }
          }
          rows[[length(rows) + 1]] <- tags$tr(
            tags$td(style = "padding: 6px 12px;", lab_names[i]),
            tags$td(style = paste0("padding: 6px 12px; font-weight: 600; color:", color, ";"),
                    paste0(v, flag))
          )
        }
      }

      if (length(rows) > 0) {
        tags_list <- c(tags_list, list(
          h6(icon("vial"), " Lab Results", style = "color: #7EB8A8; font-weight: 600;"),
          tags$table(style = "width: 100%; border-collapse: collapse;",
                     tags$tbody(rows))
        ))
      }
    }

    do.call(tagList, tags_list)
  })

  output$parse_save_buttons <- renderUI({
    pd <- parsed_data()
    if (is.null(pd)) return(NULL)
    tagList(
      hr(),
      layout_column_wrap(
        width = 1/2,
        actionButton("save_parsed_labs", "Save Lab Results",
                     class = "btn-success", style = "width: 100%;", icon = icon("vial")),
        actionButton("save_parsed_echo", "Save Echo Results",
                     class = "btn-success", style = "width: 100%;", icon = icon("wave-square"))
      ),
      br(),
      uiOutput("save_parsed_status")
    )
  })

  observeEvent(input$save_parsed_labs, {
    req(parsed_data(), input$upload_pet_id)
    lab_df <- parsed_to_lab_df(parsed_data(), as.integer(input$upload_pet_id))
    if (!is.null(lab_df)) {
      insert_record(db, "lab_results", lab_df)
      output$save_parsed_status <- renderUI({
        div(style = "color: #5BA89D; text-align: center; padding: 10px;",
            icon("check-circle"), " Lab results saved!")
      })
    }
  })

  observeEvent(input$save_parsed_echo, {
    req(parsed_data(), input$upload_pet_id)
    echo_df <- parsed_to_echo_df(parsed_data(), as.integer(input$upload_pet_id))
    if (!is.null(echo_df)) {
      insert_record(db, "echo_results", echo_df)
      output$save_parsed_status <- renderUI({
        div(style = "color: #5BA89D; text-align: center; padding: 10px;",
            icon("check-circle"), " Echo results saved!")
      })
    } else {
      output$save_parsed_status <- renderUI({
        div(style = "color: #E5A84B; text-align: center; padding: 10px;",
            icon("info-circle"), " No echo data found in this PDF")
      })
    }
  })

  # ====================================================================
  # PET PROFILE
  # ====================================================================
  observeEvent(input$save_pet, {
    req(input$pet_name)
    new_pet <- data.frame(
      name = input$pet_name,
      breed = input$pet_breed,
      color = input$pet_color,
      sex = input$pet_sex,
      dob = as.character(input$pet_dob),
      weight_kg = input$pet_weight,
      diagnosis_date = as.character(input$pet_dx_date),
      acvim_stage = "",
      breeder = input$pet_breeder,
      microchip = input$pet_microchip,
      genetic_test_mybpc3 = input$pet_mybpc3,
      genetic_test_date = "",
      genetic_notes = "",
      owner_name = input$owner_name,
      owner_email = input$owner_email,
      share_anonymized = 0L,
      stringsAsFactors = FALSE
    )
    insert_record(db, "pets", new_pet)
    pets_rv(get_records(db, "pets"))
    output$pet_save_status <- renderUI({
      div(style = "color: #5BA89D; font-weight: 600; text-align: center; padding: 10px;",
          icon("check-circle"), paste(input$pet_name, "saved!"))
    })
  })

  output$pets_table <- renderDT({
    p <- pets_rv()
    if (nrow(p) == 0) return(datatable(data.frame(Message = "No pets registered yet")))
    datatable(p[, c("pet_id", "name", "breed", "sex", "dob", "diagnosis_date")],
              colnames = c("ID", "Name", "Breed", "Sex", "DOB", "Dx Date"),
              options = list(pageLength = 5, dom = 't'), rownames = FALSE)
  })

  # ====================================================================
  # LAB RESULTS
  # ====================================================================
  observeEvent(input$save_lab, {
    req(input$global_pet_id)
    new_lab <- data.frame(
      pet_id = as.integer(input$global_pet_id),
      lab_date = as.character(input$lab_date),
      clinic = input$lab_clinic,
      vet_name = input$lab_vet,
      bun = input$lab_bun, creatinine = input$lab_creat,
      sdma = input$lab_sdma, upc = input$lab_upc,
      sodium = input$lab_sodium, potassium = input$lab_potassium,
      chloride = input$lab_chloride, calcium = input$lab_calcium,
      phosphorus = input$lab_phosphorus, alt = input$lab_alt,
      alp = input$lab_alp, glucose = input$lab_glucose,
      total_t4 = input$lab_t4, fructosamine = input$lab_fructosamine,
      hematocrit = input$lab_hct, wbc = input$lab_wbc,
      platelets = input$lab_plt, notes = input$lab_notes,
      stringsAsFactors = FALSE
    )
    insert_record(db, "lab_results", new_lab)
    showNotification("Lab results saved!", type = "message")
  })

  output$lab_trend_plot <- renderPlot({
    pd <- pet_data()
    labs <- pd$labs
    col <- input$lab_analyte
    req(col)

    if (nrow(labs) == 0 || all(is.na(labs[[col]]))) {
      plot.new()
      text(0.5, 0.5, "No data yet. Add lab results to see trends.",
           cex = 1.2, col = "#6B7B7D")
      return()
    }

    ref <- feline_reference_ranges[feline_reference_ranges$db_column == col, ]
    plot_data <- data.frame(lab_date = labs$lab_date, value = labs[[col]])
    plot_data <- plot_data[!is.na(plot_data$value), ]
    if (nrow(plot_data) == 0) {
      plot.new()
      text(0.5, 0.5, "No data for this analyte.", cex = 1.2, col = "#6B7B7D")
      return()
    }
    plot_lab_trend(plot_data, ref$analyte, ref$ref_low, ref$ref_high, ref$unit)
  })

  output$lab_clinical_note <- renderUI({
    req(input$lab_analyte)
    ref <- feline_reference_ranges[feline_reference_ranges$db_column == input$lab_analyte, ]
    if (nrow(ref) > 0) {
      div(style = "font-size: 0.85rem; color: #6B7B7D; padding: 8px 0;",
          icon("info-circle"),
          paste0(" Reference: ", ref$ref_low, " - ", ref$ref_high, " ", ref$unit, ". "),
          ref$clinical_note)
    }
  })

  output$lab_history_table <- renderDT({
    pd <- pet_data()
    labs <- pd$labs
    if (nrow(labs) == 0) return(datatable(data.frame(Message = "No lab results yet")))
    labs <- labs[order(labs$lab_date, decreasing = TRUE), ]
    show_cols <- c("lab_date", "clinic", "bun", "creatinine", "sdma", "potassium",
                   "sodium", "chloride", "alt", "glucose", "hematocrit")
    show_cols <- intersect(show_cols, names(labs))
    datatable(labs[, show_cols], options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  # ====================================================================
  # ECHO
  # ====================================================================
  observeEvent(input$save_echo, {
    req(input$global_pet_id)
    new_echo <- data.frame(
      pet_id = as.integer(input$global_pet_id),
      echo_date = as.character(input$echo_date),
      clinic = input$echo_clinic, vet_name = input$echo_vet,
      ivsd = input$echo_ivsd, edd = input$echo_edd,
      lvfwd = input$echo_lvfwd, fs_pct = input$echo_fs,
      ao = input$echo_ao, la = input$echo_la,
      la_ao_ratio = input$echo_la_ao,
      lvot_vmax = input$echo_lvot, lvot_pg = input$echo_lvot_pg,
      sam_present = as.integer(input$echo_sam),
      mitral_regurg = input$echo_mr,
      sec_present = as.integer(input$echo_sec),
      thrombus_present = as.integer(input$echo_thrombus),
      lv_systolic_function = input$echo_lv_fn,
      acvim_stage = input$echo_acvim,
      notes = input$echo_notes,
      stringsAsFactors = FALSE
    )
    insert_record(db, "echo_results", new_echo)
    showNotification("Echo results saved!", type = "message")
  })

  output$echo_trend_plot <- renderPlot({
    pd <- pet_data()
    echos <- pd$echos
    if (nrow(echos) == 0) {
      plot.new()
      text(0.5, 0.5, "No echo data yet.", cex = 1.2, col = "#6B7B7D")
      return()
    }
    echos$echo_date <- as.Date(echos$echo_date)
    par(mfrow = c(1, 3))
    for (m in list(
      list(col = "ivsd", name = "IVSd (mm)", thresh = 6),
      list(col = "lvfwd", name = "LVFWd (mm)", thresh = 6),
      list(col = "la_ao_ratio", name = "LA/Ao", thresh = 1.5)
    )) {
      vals <- echos[[m$col]]
      if (all(is.na(vals))) next
      plot_data <- data.frame(echo_date = echos$echo_date, value = vals)
      plot_data <- plot_data[!is.na(plot_data$value), ]
      if (nrow(plot_data) > 0) {
        p <- ggplot(plot_data, aes(x = echo_date, y = value)) +
          geom_hline(yintercept = m$thresh, linetype = "dashed", color = "#E8967A") +
          geom_line(color = "#7EB8A8", linewidth = 1) +
          geom_point(size = 3, color = "#7EB8A8") +
          geom_text(aes(label = round(value, 2)), vjust = -1.2, size = 3.5) +
          labs(title = m$name, x = NULL, y = NULL) +
          theme_minimal(base_size = 13) +
          theme(plot.title = element_text(face = "bold"))
        print(p)
      }
    }
  })

  output$echo_history_table <- renderDT({
    pd <- pet_data()
    echos <- pd$echos
    if (nrow(echos) == 0) return(datatable(data.frame(Message = "No echo data yet")))
    echos <- echos[order(echos$echo_date, decreasing = TRUE), ]
    show_cols <- c("echo_date", "ivsd", "lvfwd", "la_ao_ratio", "lvot_vmax", "fs_pct",
                   "sam_present", "sec_present", "acvim_stage", "clinic")
    show_cols <- intersect(show_cols, names(echos))
    datatable(echos[, show_cols], options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  # ====================================================================
  # MEDICATIONS
  # ====================================================================
  observeEvent(input$save_med, {
    req(input$global_pet_id, input$med_drug)
    drug <- if (input$med_drug == "Other") input$med_drug_other else input$med_drug
    new_med <- data.frame(
      pet_id = as.integer(input$global_pet_id),
      drug_name = drug, dose_mg = input$med_dose,
      frequency = input$med_freq,
      start_date = as.character(input$med_start),
      end_date = as.character(input$med_end),
      reason = input$med_reason,
      off_label = as.integer(input$med_offlabel),
      notes = input$med_notes,
      stringsAsFactors = FALSE
    )
    insert_record(db, "medications", new_med)
    showNotification("Medication saved!", type = "message")
  })

  output$med_timeline_plot <- renderPlot({
    pd <- pet_data()
    meds <- pd$meds
    if (nrow(meds) == 0) {
      plot.new()
      text(0.5, 0.5, "No medications logged yet.", cex = 1.2, col = "#6B7B7D")
      return()
    }
    plot_medication_timeline(meds)
  })

  output$active_meds_table <- renderDT({
    pd <- pet_data()
    meds <- pd$meds
    if (nrow(meds) == 0) return(datatable(data.frame(Message = "No medications")))
    active <- meds[is.na(meds$end_date) | meds$end_date == "" | meds$end_date >= Sys.Date(), ]
    if (nrow(active) == 0) return(datatable(data.frame(Message = "No active medications")))
    datatable(active[, c("drug_name", "dose_mg", "frequency", "start_date", "off_label")],
              colnames = c("Drug", "Dose (mg)", "Frequency", "Started", "Off-label"),
              options = list(dom = 't'), rownames = FALSE)
  })

  output$all_meds_table <- renderDT({
    pd <- pet_data()
    meds <- pd$meds
    if (nrow(meds) == 0) return(datatable(data.frame(Message = "No medications")))
    meds <- meds[order(meds$start_date, decreasing = TRUE), ]
    datatable(meds[, c("drug_name", "dose_mg", "frequency", "start_date", "end_date", "reason")],
              colnames = c("Drug", "Dose", "Freq", "Start", "End", "Reason"),
              options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  # ====================================================================
  # SLEEPING RESPIRATORY RATE
  # ====================================================================
  observeEvent(input$save_srr, {
    req(input$global_pet_id, input$srr_value)
    new_srr <- data.frame(
      pet_id = as.integer(input$global_pet_id),
      log_date = as.character(input$srr_date),
      log_time = format(input$srr_time, "%H:%M"),
      srr_brpm = as.integer(input$srr_value),
      activity_before = input$srr_activity,
      notes = input$srr_notes,
      stringsAsFactors = FALSE
    )
    insert_record(db, "srr_log", new_srr)
    showNotification("SRR logged!", type = "message")
  })

  # ====================================================================
  # CHF EPISODES
  # ====================================================================
  observeEvent(input$save_chf, {
    req(input$global_pet_id)
    new_chf <- data.frame(
      pet_id = as.integer(input$global_pet_id),
      episode_date = as.character(input$chf_date),
      severity = input$chf_severity,
      symptoms = input$chf_symptoms,
      trigger = input$chf_trigger,
      hospitalized = as.integer(input$chf_hospitalized),
      er_visit = as.integer(input$chf_er),
      treatment = input$chf_treatment,
      outcome = input$chf_outcome,
      notes = input$chf_notes,
      stringsAsFactors = FALSE
    )
    insert_record(db, "chf_episodes", new_chf)
    showNotification("CHF episode logged.", type = "warning")
  })

  output$chf_history_table <- renderDT({
    pd <- pet_data()
    chf <- pd$chf
    if (nrow(chf) == 0) return(datatable(data.frame(Message = "No CHF episodes logged")))
    chf <- chf[order(chf$episode_date, decreasing = TRUE), ]
    datatable(chf[, c("episode_date", "severity", "symptoms", "er_visit", "hospitalized", "treatment", "outcome")],
              colnames = c("Date", "Severity", "Symptoms", "ER", "Hosp.", "Treatment", "Outcome"),
              options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  output$chf_timeline_plot <- renderPlot({
    pd <- pet_data()
    chf <- pd$chf
    if (nrow(chf) == 0) {
      plot.new()
      text(0.5, 0.5, "No CHF episodes logged.", cex = 1.2, col = "#6B7B7D")
      return()
    }
    chf$episode_date <- as.Date(chf$episode_date)
    chf$sev_num <- as.numeric(factor(chf$severity, levels = unique(chf$severity)))
    ggplot(chf, aes(x = episode_date, y = 1)) +
      geom_point(aes(size = sev_num), color = "#E8967A", alpha = 0.7) +
      geom_text(aes(label = format(episode_date, "%b %d")), vjust = -1.5, size = 3) +
      scale_size_continuous(range = c(4, 10), guide = "none") +
      labs(title = "CHF Episodes", x = NULL, y = NULL) +
      theme_minimal(base_size = 13) +
      theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(),
            panel.grid.major.y = element_blank(),
            plot.title = element_text(face = "bold"))
  })

  # ====================================================================
  # ACVIM CALCULATOR
  # ====================================================================
  observeEvent(input$calc_acvim_btn, {
    result <- calculate_acvim_stage(
      ivsd = input$calc_ivsd,
      lvfwd = input$calc_lvfwd,
      la_ao = input$calc_la_ao,
      la_mm = input$calc_la_mm,
      chf_history = input$calc_chf,
      ate_history = input$calc_ate,
      refractory_chf = input$calc_refractory
    )

    output$acvim_result <- renderUI({
      div(class = "fade-in",
        div(style = "text-align: center; margin: 2rem 0;",
          div(class = paste0("stage-badge stage-", tolower(result$stage)),
              style = "font-size: 1.5rem; padding: 12px 28px;",
              paste("Stage", result$stage)),
          h5(result$label, style = "margin-top: 1rem; font-weight: 600;"),
          p(style = "color: #6B7B7D; max-width: 400px; margin: 0 auto;", result$description)
        ),
        if (!is.null(result$b2_criteria)) {
          div(style = "margin-top: 1rem;",
            h6("B2 Criteria Met:", style = "font-weight: 600;"),
            tags$ul(lapply(result$b2_criteria, tags$li))
          )
        },
        if (!is.null(result$risk_factors) && length(result$risk_factors) > 0) {
          div(class = "alert-card alert-watch", style = "margin-top: 1rem;",
            icon("triangle-exclamation"), " ",
            paste(result$risk_factors, collapse = "; "))
        }
      )
    })
  })

  # ====================================================================
  # IRIS CKD CALCULATOR
  # ====================================================================
  observeEvent(input$calc_iris_btn, {
    result <- calculate_iris_stage(
      creatinine = input$calc_creat,
      sdma = input$calc_sdma,
      upc = input$calc_upc,
      systolic_bp = input$calc_bp
    )

    output$iris_result <- renderUI({
      if (is.null(result)) {
        return(div(class = "empty-state",
                   p("Enter creatinine or SDMA to calculate staging.")))
      }

      div(class = "fade-in",
        div(style = "text-align: center; margin: 2rem 0;",
          div(class = paste0("stage-badge iris-", result$stage),
              style = "font-size: 1.5rem; padding: 12px 28px;",
              result$label),
          p(style = "color: #6B7B7D; margin-top: 0.5rem;", result$description)
        ),
        if (isTRUE(result$upstaged)) {
          div(class = "alert-card alert-watch",
              icon("arrow-up"), " ", tags$strong("Up-staged by SDMA: "),
              result$upstage_note)
        },
        if (!is.null(result$proteinuria)) {
          div(style = "margin-top: 1rem;",
            h6("Proteinuria Substaging", style = "font-weight: 600;"),
            div(class = "stage-badge", style = paste0("background:", result$proteinuria$color, "22; color:", result$proteinuria$color, ";"),
                result$proteinuria$status)
          )
        },
        if (!is.null(result$bp_status)) {
          div(style = "margin-top: 1rem;",
            h6("Blood Pressure Substaging", style = "font-weight: 600;"),
            div(class = "stage-badge", style = paste0("background:", result$bp_status$color, "22; color:", result$bp_status$color, ";"),
                paste(result$bp_status$status, "- Target organ damage risk:", result$bp_status$risk))
          )
        },
        hr(),
        h6("IRIS CKD Staging Reference (Feline)", style = "font-weight: 600;"),
        tags$table(style = "width: 100%; font-size: 0.85rem;",
          tags$thead(tags$tr(
            tags$th("Stage"), tags$th("Creatinine"), tags$th("SDMA"), tags$th("Description")
          )),
          tags$tbody(
            tags$tr(tags$td("1"), tags$td("< 1.6"), tags$td("< 18"), tags$td("Non-azotemic")),
            tags$tr(tags$td("2"), tags$td("1.6-2.8"), tags$td("18-25"), tags$td("Mild azotemia")),
            tags$tr(tags$td("3"), tags$td("2.9-5.0"), tags$td("25-38"), tags$td("Moderate azotemia")),
            tags$tr(tags$td("4"), tags$td("> 5.0"), tags$td("> 38"), tags$td("Severe azotemia"))
          )
        )
      )
    })
  })

  # ====================================================================
  # DRUG INTERACTIONS
  # ====================================================================
  output$interaction_results <- renderUI({
    pd <- pet_data()
    meds <- pd$meds
    labs <- pd$labs

    if (nrow(meds) == 0) {
      return(div(class = "empty-state",
                 div(class = "empty-icon", icon("pills")),
                 p("Add medications in the Health Log to check for interactions.")))
    }

    active <- meds[is.na(meds$end_date) | meds$end_date == "" | meds$end_date >= Sys.Date(), ]
    if (nrow(active) == 0) {
      return(div(class = "empty-state", p("No active medications to check.")))
    }

    has_ckd <- nrow(labs) > 0 && !is.na(labs[nrow(labs), ]$creatinine) && labs[nrow(labs), ]$creatinine > 1.6
    interactions <- check_drug_interactions(active$drug_name, has_ckd = has_ckd, has_chf = nrow(pd$chf) > 0)

    result_ui <- list(
      h6(paste("Active Medications:", paste(active$drug_name, collapse = ", ")),
         style = "font-weight: 600; margin-bottom: 1rem;")
    )

    if (nrow(interactions) == 0) {
      result_ui <- c(result_ui, list(
        div(class = "alert-card alert-good",
            icon("check-circle"), tags$strong(" No known interactions found"),
            " among current medications.")
      ))
    } else {
      for (i in seq_len(nrow(interactions))) {
        row <- interactions[i, ]
        result_ui <- c(result_ui, list(
          div(class = paste0("interaction-", row$severity),
            tags$strong(paste(row$drug_a, "+", row$drug_b)),
            tags$span(style = "float: right; font-weight: 600; text-transform: uppercase; font-size: 0.75rem;",
                      toupper(gsub("_", " ", row$severity))),
            p(style = "margin: 4px 0 0 0; font-size: 0.9rem;", row$description),
            p(style = "margin: 4px 0 0 0; font-size: 0.85rem; color: #6B7B7D;",
              icon("lightbulb"), " ", row$recommendation)
          )
        ))
      }
    }

    # Clopidogrel note
    if ("Clopidogrel" %in% active$drug_name) {
      result_ui <- c(result_ui, list(
        hr(),
        div(class = "alert-card alert-watch",
            icon("dna"), " ", tags$strong("Clopidogrel Resistance Note: "),
            clopidogrel_resistance_note)
      ))
    }

    do.call(tagList, result_ui)
  })
}

# ============================================================================
# RUN
# ============================================================================
shinyApp(ui = ui, server = server)
