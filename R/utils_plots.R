# NitroHeart Plotting Utilities
# Consistent, publication-quality visualizations for health data

library(ggplot2)
library(scales)

# NitroHeart color palette
nh_colors <- list(
  primary = "#2563EB",
  danger = "#DC2626",
  warning = "#F59E0B",
  success = "#16A34A",
  muted = "#94A3B8",
  bg_normal = "#DCFCE7",
  bg_warning = "#FEF3C7",
  bg_danger = "#FEE2E2",
  text = "#1E293B"
)

#' Plot lab value trend over time with reference range
#' @param data Data frame with columns: lab_date, value
#' @param analyte_name Display name of the analyte
#' @param ref_low Lower reference range
#' @param ref_high Upper reference range
#' @param unit Unit of measurement
#' @return ggplot object
plot_lab_trend <- function(data, analyte_name, ref_low, ref_high, unit = "") {
  if (nrow(data) == 0) return(NULL)

  data$lab_date <- as.Date(data$lab_date)
  y_label <- if (unit != "") paste0(analyte_name, " (", unit, ")") else analyte_name

  p <- ggplot(data, aes(x = lab_date, y = value)) +
    # Reference range band
    annotate("rect",
             xmin = min(data$lab_date) - 7, xmax = max(data$lab_date) + 7,
             ymin = ref_low, ymax = ref_high,
             fill = nh_colors$bg_normal, alpha = 0.5) +
    # Reference lines
    geom_hline(yintercept = ref_low, linetype = "dashed", color = nh_colors$muted, linewidth = 0.5) +
    geom_hline(yintercept = ref_high, linetype = "dashed", color = nh_colors$muted, linewidth = 0.5) +
    # Data line and points
    geom_line(color = nh_colors$primary, linewidth = 1) +
    geom_point(aes(color = value >= ref_low & value <= ref_high), size = 3.5) +
    scale_color_manual(values = c("TRUE" = nh_colors$primary, "FALSE" = nh_colors$danger),
                       guide = "none") +
    # Labels
    labs(
      title = analyte_name,
      x = NULL,
      y = y_label
    ) +
    # Theme
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(face = "bold", color = nh_colors$text, size = 16),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      axis.text = element_text(color = nh_colors$text)
    ) +
    scale_x_date(labels = date_format("%b %d\n%Y"))

  # Add value labels
  p <- p + geom_text(aes(label = round(value, 1)),
                      vjust = -1.2, size = 3.5, color = nh_colors$text)

  # Expand y range to fit labels
  y_range <- range(c(data$value, ref_low, ref_high), na.rm = TRUE)
  y_pad <- diff(y_range) * 0.15
  p <- p + coord_cartesian(ylim = c(y_range[1] - y_pad, y_range[2] + y_pad))

  return(p)
}

#' Plot sleeping respiratory rate over time
#' @param data Data frame with columns: log_date, srr_brpm
#' @return ggplot object
plot_srr_trend <- function(data) {
  if (nrow(data) == 0) return(NULL)

  data$log_date <- as.Date(data$log_date)
  data$status <- cut(data$srr_brpm,
                     breaks = c(-Inf, 35, 60, Inf),
                     labels = c("Normal", "Elevated", "Emergency"))

  ggplot(data, aes(x = log_date, y = srr_brpm)) +
    # Threshold zones
    annotate("rect", xmin = min(data$log_date) - 1, xmax = max(data$log_date) + 1,
             ymin = 0, ymax = 35, fill = nh_colors$bg_normal, alpha = 0.4) +
    annotate("rect", xmin = min(data$log_date) - 1, xmax = max(data$log_date) + 1,
             ymin = 35, ymax = 60, fill = nh_colors$bg_warning, alpha = 0.4) +
    annotate("rect", xmin = min(data$log_date) - 1, xmax = max(data$log_date) + 1,
             ymin = 60, ymax = max(data$srr_brpm, 80) + 10, fill = nh_colors$bg_danger, alpha = 0.4) +
    # Threshold lines
    geom_hline(yintercept = 35, linetype = "dashed", color = nh_colors$warning) +
    geom_hline(yintercept = 60, linetype = "dashed", color = nh_colors$danger) +
    # Data
    geom_line(color = nh_colors$primary, linewidth = 0.8) +
    geom_point(aes(color = status), size = 3) +
    scale_color_manual(values = c("Normal" = nh_colors$success,
                                  "Elevated" = nh_colors$warning,
                                  "Emergency" = nh_colors$danger)) +
    labs(
      title = "Sleeping Respiratory Rate",
      x = NULL,
      y = "Breaths per minute",
      color = "Status"
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(face = "bold", color = nh_colors$text, size = 16),
      panel.grid.minor = element_blank(),
      legend.position = "bottom"
    ) +
    scale_x_date(labels = date_format("%b %d"))
}

#' Plot medication timeline
#' @param data Data frame with columns: drug_name, start_date, end_date
#' @return ggplot object
plot_medication_timeline <- function(data) {
  if (nrow(data) == 0) return(NULL)

  data$start_date <- as.Date(data$start_date)
  data$end_date <- as.Date(ifelse(is.na(data$end_date), Sys.Date(), data$end_date),
                           origin = "1970-01-01")
  data$drug_label <- paste0(data$drug_name, " ", data$dose_mg, "mg ", data$frequency)

  # Order by start date
  data <- data[order(data$start_date), ]
  data$drug_label <- factor(data$drug_label, levels = rev(unique(data$drug_label)))

  ggplot(data, aes(y = drug_label)) +
    geom_segment(aes(x = start_date, xend = end_date, yend = drug_label,
                     color = ifelse(off_label == 1, "Off-label", "Standard")),
                 linewidth = 6, lineend = "round") +
    scale_color_manual(values = c("Standard" = nh_colors$primary, "Off-label" = "#8B5CF6"),
                       name = "") +
    labs(
      title = "Medication Timeline",
      x = NULL,
      y = NULL
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(face = "bold", color = nh_colors$text, size = 16),
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      axis.text.y = element_text(size = 11)
    ) +
    scale_x_date(labels = date_format("%b %Y"))
}
