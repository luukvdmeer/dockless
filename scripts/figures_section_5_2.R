# -------------------------------------------------------------------
# This script reproduces all figures in section 5.2 of the thesis.

# NOTE: first, the analysis script should be ran!
# -------------------------------------------------------------------

require(dockless)
require(ggplot2)
require(dplyr)
require(tibble)
require(tidyr)
require(sf)
require(tsibble)
require(feats)
require(lubridate)

## -------------------------- time plot -----------------------------

# Add model information to each data frame of distance data
f = function(x, y) {
  x$model = y
  return(x)
}

model_vector = as.factor(c(1,2,3,4))
data = mapply(
  f,
  distancedata_modelpoints,
  model_vector, SIMPLIFY = FALSE
)

# Bind all data frames together
newdata = do.call(rbind, data)

# Function to find start and end times of weekends
weekend = function(x) {
  saturdaystart = x %>%
    mutate(saturday = lubridate::wday(.$time, week_start = 1) == 6) %>%
    filter(saturday) %>%
    filter(lubridate::hour(.$time) == 0 & lubridate::minute(.$time) == 0) %>%
    select(-saturday)

  sundayend = x %>%
    mutate(sunday = lubridate::wday(.$time, week_start = 1) == 7) %>%
    filter(sunday) %>%
    filter(lubridate::hour(.$time) == 23 & lubridate::minute(.$time) == 45) %>%
    select(-sunday)

  if(nrow(sundayend) == (nrow(saturdaystart)-1)) {
    sundayend = rbind(sundayend, x[nrow(x),])
  } else if (nrow(saturdaystart) == (nrow(sundayend)-1)) {
    saturdaystart = rbind(x[1,], saturdaystart)
  }

  weekend = bind_cols(saturdaystart, sundayend) %>%
    select(time, time1)
}

# Plot
timeplot = ggplot() +
  geom_rect(
    data = weekend(newdata[newdata$model == 1, ]),
    mapping = aes(
      xmin = time,
      xmax = time1,
      ymin = -Inf,
      ymax = Inf
    ),
    fill = 'darkgrey',
    alpha = 0.3
  ) +
  geom_line(
    data = newdata,
    mapping = aes(x = time, y = distance)
  ) +
  labs(
    x = 'Time',
    y = 'Distance to the nearest bike (m)'
  ) +
  scale_x_datetime(
    date_breaks = '1 weeks',
    date_labels = c('Oct 15', 'Sep 17', 'Sep 24', 'Oct 1', 'Oct 8')
  ) +
  theme(
    text = element_text(family = 'sans')
  ) +
  facet_grid(
    model ~ .,
    scale = 'free_y',
    labeller = as_labeller(
      c(
        '1' = 'Bayview',
        '2' = 'Downtown',
        '3' = 'Residential',
        '4' = 'Presidio'
      )
    )
  )

# Color the facet backgrounds
# Code retrieved from https://github.com/tidyverse/ggplot2/issues/2096
timegrid = ggplot_gtable(ggplot_build(timeplot))
stripr = which(grepl('strip-r', timegrid$layout$name))
colors = dockless_colors(categorical = TRUE)
k = 1
for (i in stripr) {
  j = which(grepl('rect', timegrid$grobs[[i]]$grobs[[1]]$childrenOrder))
  timegrid$grobs[[i]]$grobs[[1]]$children[[j]]$gp$fill = colors[k]
  k = k + 1
}

grid::grid.draw(timegrid)

## ------------------- residual time plot ---------------------------

# Get the residuals from each model as a vector
residuals = lapply(models, function(x) as.vector(x$residuals))

# Combine those vectors
residuals_combined = do.call('c', residuals)

# Add as column to newdata
newdata$residuals = residuals_combined

# Plot
residual_timeplot = ggplot(
  data = newdata,
  mapping = aes(x = time, y = residuals)
) +
  geom_line() +
  labs(
    x = 'Time',
    y = 'Residuals'
  ) +
  scale_x_datetime(
    date_breaks = '1 weeks',
    date_labels = c('Oct 15', 'Sep 17', 'Sep 24', 'Oct 1', 'Oct 8')
  ) +
  theme(
    text = element_text(family = 'sans')
  ) +
  facet_grid(
    model ~ .,
    labeller = as_labeller(
      c(
        '1' = 'Bayview',
        '2' = 'Downtown',
        '3' = 'Residential',
        '4' = 'Presidio'
      )
    )
  )

# Color the facet backgrounds
# Code retrieved from https://github.com/tidyverse/ggplot2/issues/2096
residual_timegrid = ggplot_gtable(ggplot_build(residual_timeplot))
stripr = which(grepl('strip-r', residual_timegrid$layout$name))
colors = dockless_colors(categorical = TRUE)
k = 1
for (i in stripr) {
  j = which(grepl('rect', residual_timegrid$grobs[[i]]$grobs[[1]]$childrenOrder))
  residual_timegrid$grobs[[i]]$grobs[[1]]$children[[j]]$gp$fill = colors[k]
  k = k + 1
}

grid::grid.draw(residual_timegrid)

## ------------------ residual autocorrelation ----------------------

# Get the residuals from each model as a vector
acfdata = newdata %>%
  tsibble::as_tsibble(key = id(model)) %>%
  feats::ACF(value = residuals, lag.max = 672, na.action = na.pass)

# Plot
residual_acfplot = ggplot(
  data = acfdata,
  mapping = aes(x = lag, y = acf)
) +
  geom_hline(
    mapping = aes(yintercept = 1.96 / sqrt(nrow(newdata %>% filter(model == 1)))),
    linetype = 'dashed',
    col = 'orange',
    lwd = 1
  ) +
  geom_hline(
    mapping = aes(yintercept = -1.96 / sqrt(nrow(newdata %>% filter(model == 1)))),
    linetype = 'dashed',
    col = 'orange',
    lwd = 1
  ) +
  geom_hline(
    mapping = aes(yintercept = mean(acfdata$acf, na.rm = TRUE))
  ) +
  geom_segment(
    mapping = aes(xend = lag, yend = mean(acfdata$acf, na.rm = TRUE))
  ) +
  labs(
    x = 'Time lag',
    y = 'Autocorrelation'
  ) +
  scale_x_continuous(
    breaks = seq(0, nrow(acfdata), 96)
  ) +
  theme(
    text = element_text(family = 'sans')
  ) +
  facet_grid(
    model ~ .,
    labeller = as_labeller(
      c(
        '1' = 'Bayview',
        '2' = 'Downtown',
        '3' = 'Residential',
        '4' = 'Presidio'
      )
    )
  )

# Color the facet backgrounds
# Code retrieved from https://github.com/tidyverse/ggplot2/issues/2096
residual_acfgrid = ggplot_gtable(ggplot_build(residual_acfplot))
stripr = which(grepl('strip-r', residual_acfgrid$layout$name))
colors = dockless_colors(categorical = TRUE)
k = 1
for (i in stripr) {
  j = which(grepl('rect', residual_acfgrid$grobs[[i]]$grobs[[1]]$childrenOrder))
  residual_acfgrid$grobs[[i]]$grobs[[1]]$children[[j]]$gp$fill = colors[k]
  k = k + 1
}

grid::grid.draw(residual_acfgrid)

## -------------------- residual histograms -------------------------

# Plot
residual_histogram = ggplot(
  data = newdata,
  mapping = aes(x = residuals)
) +
  geom_histogram(
    fill = 'black',
    binwidth = 0.1
  ) +
  geom_rug(
    sides = 'b',
    col = 'darkgrey'
  ) +
  labs(
    x = 'Residuals',
    y = 'Count'
  ) +
  theme(
    text = element_text(family = 'sans')
  ) +
  facet_grid(
    . ~ model,
    scale = 'free',
    labeller = as_labeller(
      c(
        '1' = 'Bayview',
        '2' = 'Downtown',
        '3' = 'Residential',
        '4' = 'Presidio'
      )
    )
  )

# Color the facet backgrounds
# Code retrieved from https://github.com/tidyverse/ggplot2/issues/2096)
residual_histogrid = ggplot_gtable(ggplot_build(residual_histogram))
stripr = which(grepl('strip-', residual_histogrid$layout$name))
colors = dockless_colors(categorical = TRUE)
k = 1
for (i in stripr) {
  j = which(grepl('rect', residual_histogrid$grobs[[i]]$grobs[[1]]$childrenOrder))
  residual_histogrid$grobs[[i]]$grobs[[1]]$children[[j]]$gp$fill = colors[k]
  k = k + 1
}

grid::grid.draw(residual_histogrid)
