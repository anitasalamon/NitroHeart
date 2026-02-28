# NitroHeart v2 — Creative Vision

> "Design is not just what it looks like. Design is how it works." — Steve Jobs

---

## The Problem with v1

The current app is a **medical records database wearing a UI**. It works, but it feels like a spreadsheet. 15+ form fields on one screen. Nine sidebar items all competing for attention. No emotional connection. No story. A pet owner opens it and thinks "this is work" instead of "this helps me understand my cat."

The goal for v2: **make it feel like a health companion, not a clinical tool.**

---

## Design Philosophy: Three Rules

### 1. Summaries first, raw data later
Apple Health never dumps a table of numbers. It shows a trend, a score, a status badge. The data is there if you drill in — but the *story* comes first.

### 2. Every screen answers one question: "How is my cat doing?"
If an element doesn't help answer that question, it doesn't belong on the screen.

### 3. Warm, not clinical
Rounded corners. Soft shadows. Calming colors. Reassuring language. "Worth discussing with your vet" instead of "ABNORMAL." This app is for anxious pet parents — it should comfort, not alarm.

---

## The New Color Palette: "Sage & Warmth"

| Role | Color | Hex | Where |
|------|-------|-----|-------|
| Primary | Sage Green | `#7EB8A8` | Headers, buttons, active states |
| Secondary | Warm Sand | `#F5E6D3` | Card backgrounds, dividers |
| Accent | Soft Coral | `#E8967A` | Alerts, important badges |
| Text | Charcoal | `#2D3436` | Body text, headings |
| Text Secondary | Warm Gray | `#6B7B7D` | Labels, captions |
| Background | Warm White | `#FAFAF7` | Page background |
| Success | Muted Teal | `#5BA89D` | Healthy/normal status |
| Warning | Amber Gold | `#E5A84B` | "Watch this" indicators |
| Danger | Soft Coral | `#E8967A` | Urgent alerts (not scary red) |

**Typography:** Inter (body), Nunito (headings) via Google Fonts
**Framework:** `bslib` (Bootstrap 5) replacing `shinydashboard`
**Charts:** `echarts4r` for interactive, animated visualizations

---

## The New Architecture: 4 Tabs, Not 9

Current sidebar is overwhelming. Simplify to:

### Tab 1: Dashboard (the hero screen)
What you see when you open the app:

```
+------------------------------------------------------+
|  [Nitro's photo]   NITRO — Ragdoll Mix, 1yr          |
|  Stage B2  |  IRIS CKD Stage 2  |  SRR: 24 bpm OK   |
+------------------------------------------------------+
|                                                      |
|  [ Wellness Score: 72/100 ]    <-- radial gauge      |
|                                                      |
+-------------------+----------------------------------+
| Latest Labs       | SRR Trend (7-day sparkline)      |
| BUN: 53 (H)       | ~~~~~~~~~~~~~/~~~~~~~~~~         |
| Creat: 2.7 (H)    |        normal zone               |
| SDMA: 13 (OK)     +----------------------------------+
| K+: 4.3 (OK)      | Next Steps                       |
| Last: Feb 18       | - SRR check due today            |
+-------------------+ - Recheck labs in 4 weeks         |
| Active Meds: 6     | - Rapamycin response echo due    |
| Days on Bexacat:47 +----------------------------------+
+-------------------+
```

**Key elements:**
- Pet photo + name + breed — emotional anchor
- ACVIM stage + IRIS CKD stage — auto-calculated badges
- Wellness Score (0-100) — radial gauge synthesizing all data
- Value boxes with sparklines for critical metrics
- "Next Steps" card — actionable, not just data
- No forms on this screen. This is for *reading*, not *entering*.

### Tab 2: Health Log (all data entry lives here)
One unified entry point with smart sections:

- **Upload PDF** (primary action — big button at top)
- **Quick Log** — SRR (tap-to-count timer), weight, appetite/energy rating
- **Full Entry** — expandable accordion sections for labs, echo, medications
- **Timeline View** — scrollable history of all entries, filterable

The PDF upload is the star — most data comes in that way. Manual entry is the fallback, not the default.

### Tab 3: Insights (the science brain)
This is where NitroHeart differentiates from every other pet app:

- **Trend Analysis** — interactive charts (echarts4r) for any lab value over time
- **ACVIM Stage Calculator** — enter echo values, get staging with explanation
- **IRIS CKD Calculator** — creatinine + SDMA + UPC + BP → staging with SDMA up-staging rule
- **Drug Interaction Checker** — enter meds, see flags (red/yellow/green)
- **Risk Dashboard** — CHF probability based on LA/Ao, cTnI, wall thickness
- **ATE Risk Indicator** — based on LA size, SEC, sex
- **Vet Report Generator** — one-click PDF export of all data for vet visits

### Tab 4: Learn (Science Corner)
Curated, contextual education:

- **"What does this mean?"** — plain-language explainers for every metric
- **Research News** — latest HCM publications and clinical trials
- **Emerging Therapies** — rapamycin (Felicyn), mavacamten, SGLT2i updates
- **Genetics** — what MYBPC3 testing means, the Kaplan 2025 GWAS findings, why single-gene tests aren't enough
- **Community Q&A** — eventually, a space for pet owners to share experiences

---

## Science-Based Features: The Details

### ACVIM Stage Calculator
Auto-classifies based on echo measurements:

| Input | Threshold |
|-------|-----------|
| LV wall thickness (IVSd) | >= 6mm = HCM diagnosis |
| LA/Ao ratio | < 1.6 = B1, >= 1.8 = B2 |
| LA diameter | >= 18mm = significant |
| CHF history | Yes = Stage C |
| Refractory CHF | Yes = Stage D |

Visual output: a progress-bar-style indicator showing A → B1 → B2 → C → D with the cat's current position highlighted. Track changes over time.

### IRIS CKD Calculator
| Stage | Creatinine | SDMA | Description |
|-------|-----------|------|-------------|
| 1 | < 1.6 | < 18 | Non-azotemic, CKD detected by other markers |
| 2 | 1.6-2.8 | 18-25 | Mild azotemia |
| 3 | 2.9-5.0 | 25-38 | Moderate azotemia |
| 4 | > 5.0 | > 38 | Severe azotemia |

**SDMA up-staging rule:** If SDMA is persistently above the range for the creatinine-based stage, up-stage the cat. This catches kidney disease ~17 months before creatinine alone.

**Proteinuria substaging:** UPC < 0.2 (non-proteinuric), 0.2-0.4 (borderline), > 0.4 (proteinuric)

### Drug Interaction Checker
Critical flags to build in:

| Drug A | Drug B | Risk |
|--------|--------|------|
| Atenolol | Diltiazem | CONTRAINDICATED — severe bradycardia risk |
| Benazepril | Spironolactone | Monitor K+ — both raise potassium |
| Clopidogrel | NSAIDs | AVOID — GI bleeding risk in cats |
| ACE-I (any) | Sacubitril/valsartan | CONTRAINDICATED — angioedema risk |
| Furosemide | Advancing CKD | Monitor renal values closely |
| Atenolol | CHF onset | Reduce dose 50%, don't stop abruptly |

Also flag: clopidogrel resistance (16% homozygous, 51% heterozygous in cats — CYP2C polymorphism).

### SRR Tracker (upgraded)
- **Tap-to-count timer** — tap each breath for 30 or 60 seconds, auto-calculates rate
- **Thresholds:** < 30 bpm normal, 30-35 elevated (vet check), > 35 urgent
- **7-day rolling average** trend line with zone coloring
- **Contextual notes** — was there a med change? stressful event?
- **Share with vet** — export SRR log as PDF or CSV

### Risk Dashboard (composite view)
Combine published thresholds into a visual risk panel:

- **CHF risk:** LA/Ao >= 2.5 → 88.7% sensitivity for CHF
- **Prognosis:** cTnI > 0.7 ng/mL → median survival 40 days vs 1,274 days
- **ATE risk factors:** male, SEC present, LA enlargement, LA dysfunction
- **Extreme hypertrophy:** LV wall > 9mm = independent poor prognosis

### Rapamycin Response Tracker
For cats on Felicyn-CA1 (FDA conditionally approved March 2025):
- Track LV wall thickness over time (the primary endpoint in RAPACAT trial)
- Expected response: modest reduction from baseline
- Visual: wall thickness trend with before/after rapamycin annotation

---

## Micro-Interactions & Delight

Small things that make users come back:

- **Greeting:** "Good morning! Here's how Nitro is doing today."
- **Milestone celebrations:** "7-day SRR logging streak!" with subtle confetti animation
- **Smart alerts:** "Nitro's creatinine has trended up over the last 3 readings — worth discussing at next vet visit."
- **Medication reminders:** "Bexacat due today" countdown
- **Empty states:** Friendly illustrations, not blank screens. "No SRR logged today — it only takes 30 seconds."
- **Smooth transitions:** Charts animate on load (echarts4r built-in). Cards have subtle hover shadows (300ms ease).
- **Skeleton loading:** Gray placeholder shapes while data loads (waiter package).

---

## Tech Stack for v2

| Layer | Current (v1) | Proposed (v2) |
|-------|-------------|---------------|
| UI Framework | shinydashboard | **bslib** (Bootstrap 5) |
| Charts | ggplot2 (static) | **echarts4r** (interactive, animated) |
| Forms | Raw Shiny inputs | **shinyWidgets** (toggles, pickers) |
| Fonts | System default | **Inter + Nunito** (Google Fonts) |
| Loading | None | **waiter** (skeleton screens) |
| Animations | None | **shinyjs** (confetti, transitions) |
| Theme | Blue/gray corporate | **Sage & Warmth** palette |
| PDF parsing | pdftotext + Claude | Same (this works well) |
| Database | SQLite | Same (works for single-user) |

---

## What Makes NitroHeart Different From Everything Else

Competitive landscape:
- **PetDesk / Pawprint / VitusVet** — generic pet records, vet appointment booking. No cardiac-specific features.
- **Cardalis App** — SRR tracking only, dog-focused, no lab/echo integration.
- **EchoVet / AxisVet** — for veterinary professionals, not pet owners.

**NitroHeart's unique position:**
1. **Cat-specific cardiac health tracker** — nothing else exists
2. **All-in-one:** echo + labs + SRR + meds + staging in one place
3. **Science-based calculators:** ACVIM staging, IRIS CKD, drug interactions
4. **AI-powered PDF upload** — drop a vet report, get structured data
5. **Built by someone who lives this** — Anita + Nitro's real story

This isn't a generic pet app. This is **the app that veterinary cardiologists wish existed.**

---

## Implementation Priority

### Phase 1: Beautiful Dashboard (Week 1)
- Migrate from shinydashboard to bslib
- New color palette + typography
- Dashboard tab with value boxes + sparklines
- Pet photo upload

### Phase 2: Science Brain (Week 2)
- ACVIM Stage Calculator
- IRIS CKD Calculator
- SRR tap-to-count timer
- Trend charts with echarts4r

### Phase 3: Intelligence (Week 3)
- Drug interaction checker
- Risk dashboard
- Smart alerts ("creatinine trending up")
- Vet report PDF export

### Phase 4: Community & Learn (Week 4+)
- Science Corner with research news
- Diet tracker
- Genetic risk profile
- Community data (anonymous comparisons)
