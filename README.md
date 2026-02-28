# NitroHeart

**A community-driven database and health tracker for cats with hypertrophic cardiomyopathy (HCM).**

Named after Nitro, a Ragdoll diagnosed with advanced juvenile HCM at 10 months old. His parents tested N/N (negative) for the MYBPC3 R820W mutation — proving that the single-gene test used by most breeders misses the majority of HCM cases. NitroHeart was built so that no pet owner has to fight this disease alone, piecing together lab results from scattered PDFs across multiple clinics.

## What NitroHeart Does

**For individual pet owners:**
- Track lab values over time (BUN, creatinine, potassium, electrolytes) with trend visualization and reference ranges
- Log echocardiogram measurements (IVSd, LVFWd, LA/Ao, LVOT Vmax, FS%) across visits
- Monitor sleeping respiratory rate (SRR) with threshold alerts
- Manage complex medication regimens with timeline views
- Record CHF episodes to identify patterns and triggers
- Store genetic test results

**For the community:**
- Anonymized aggregate data across breeds, ages, and ACVIM stages
- Medication outcome tracking — what combinations work
- Breed-specific HCM statistics
- A growing dataset that could power future genetic research

## Why This Matters

Feline HCM afflicts 1 in 7 cats. The genetics are poorly understood — a 2025 multi-omics study of 138 cats (Kaplan et al., G3) found that no single variant or combination explained HCM in the majority of cases. Current genetic screening tests only detect one mutation (MYBPC3 R820W in Ragdolls, A31P in Maine Coons), missing most affected cats.

Pet owners managing HCM face:
- Scattered medical records across emergency clinics, specialists, and primary vets
- No centralized way to visualize lab trends critical for monitoring diuretic-induced kidney injury
- Limited data on off-label treatments (SGLT2 inhibitors, rapamycin/Felycin-CA1, mavacamten)
- No community database to learn from others' experiences

## Tech Stack

- **R Shiny** — Interactive web application
- **SQLite** — Local database storage
- **ggplot2** — Publication-quality trend visualizations

## Running Locally

```r
# Install dependencies
install.packages(c("shiny", "shinydashboard", "DBI", "RSQLite",
                    "dplyr", "ggplot2", "lubridate", "DT", "shinyWidgets"))

# Launch the app
shiny::runApp("app.R")
```

## Roadmap

- [ ] MVP: Pet profile, lab tracker, medication log, SRR monitor
- [ ] Community database with anonymized aggregate views
- [ ] PDF parsing for veterinary lab reports (IDEXX format)
- [ ] Genetic data integration (WGS from Kaplan et al. 2025)
- [ ] Predictive risk model for HCM development based on genetic + clinical data

## Citation

If you use NitroHeart data in research, please cite:
> Salamon A. NitroHeart: A community database for feline hypertrophic cardiomyopathy. 2026. https://github.com/anitasalamon/NitroHeart

## Related Literature

- Kaplan JL, Rivas VN, et al. "Unraveling the genetics of feline hypertrophic cardiomyopathy: a multiomics study of 138 cats." G3, 2025. https://doi.org/10.1093/g3journal/jkaf153
- Meurs et al. 2007. MYBPC3 R820W variant in Ragdoll cats.
- Stern JA et al. Felycin-CA1 (rapamycin) for feline HCM.

## License

MIT License

## About the Author

**Anita Salamon, PhD** — Computational biologist specializing in cardiovascular disease. PhD from University of Virginia (Owens Lab), with expertise in multi-omics analysis, RNA-seq pipelines, and machine learning for biomedical data. NitroHeart combines her scientific training with the lived experience of managing a cat with advanced HCM.
