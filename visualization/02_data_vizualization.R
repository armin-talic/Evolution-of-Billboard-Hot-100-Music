# ==============================================================================
# FILE 2: DATA VISUALIZATION
# ==============================================================================
library(tidyverse)
library(patchwork)
library(ggridges)
library(ggstream)
library(ggrepel)
library(lubridate)
library(tidytext)
library(viridis)
library(ggtext) 

# Suppress warnings for clean output
options(warn = -1)

# Set working directory
setwd("")

# ------------------------------------------------------------------------------
# STEP 1: LOAD & PRE-FILTER DATA
# ------------------------------------------------------------------------------
master <- read_csv("prep_master_songs.csv", show_col_types = FALSE) %>%
  filter(year <= 2025) 

artist_genre_map <- read_csv("prep_artist_genres.csv", show_col_types = FALSE)

top_10_list <- artist_genre_map %>% 
  count(parent_genre, sort = TRUE) %>% 
  head(10) %>% 
  pull(parent_genre)

song_debuts <- master %>%
  group_by(title, performer) %>%
  summarize(debut_year = min(year, na.rm = TRUE), .groups = "drop")

# ------------------------------------------------------------------------------
# STEP 2: STYLES & THEMES
# ------------------------------------------------------------------------------
infographic_theme <- theme_minimal() +
  theme(
    plot.background = element_rect(fill = "#121212", color = NA),
    panel.background = element_rect(fill = "#121212", color = NA),
    text = element_text(color = "#E0E0E0", family = "sans", size = 22),
    plot.title = element_text(face = "bold", size = 30, color = "white", hjust = 0.5),
    plot.subtitle = element_text(size = 22, color = "#A0A0A0", hjust = 0.5),
    panel.grid = element_blank(), 
    axis.text = element_text(color = "#A0A0A0", size = 20),
    axis.title = element_text(size = 22, face = "bold"),
    legend.position = "none"
  )

decade_styles <- list(
  "1960s" = list(bg = "#151313", txt = "#F4D06F", fill1 = "#FF8811", line1 = "#9DD9D2", grid = "#2B2626", font = "serif"),
  "1970s" = list(bg = "#1A0B2E", txt = "#ffffff", fill1 = "#FF00AA", line1 = "#00FFFF", grid = NA, font = "sans"),
  "1980s" = list(bg = "#000022", txt = "#00ffff", fill1 = "#ff00ff", line1 = "#00ffff", grid = NA, font = "sans"),
  "1990s" = list(bg = "#151515", txt = "#f0e6d2", fill1 = "#9e2a2b", line1 = "#e09f3e", grid = "#2a2a2a", font = "mono"),
  "2000s" = list(bg = "#09090b", txt = "#ffffff", fill1 = "#ff007f", line1 = "#00d2ff", grid = "#1c1c28", font = "sans"),
  "2010s" = list(bg = "#191414", txt = "white",   fill1 = "#1DB954", line1 = "white",   grid = NA, font = "sans"),
  "2020s" = list(bg = "black",   txt = "white",   fill1 = "#ff0050", line1 = "#00f2ea", grid = NA, font = "sans")
)

# ------------------------------------------------------------------------------
# STEP 3: DASHBOARD ENGINE
# ------------------------------------------------------------------------------
create_decade_dashboard <- function(decade_key, master_df, map_df) {
  s <- decade_styles[[decade_key]]
  start_yr <- as.numeric(gsub("s", "", decade_key))
  end_yr <- start_yr + 9
  
  era_data <- master_df %>% filter(year >= start_yr & year <= end_yr)
  
  era_genre_data <- era_data %>% 
    select(-any_of(c("genres", "strGenre", "parent_genre"))) %>% 
    left_join(map_df, by = "performer", relationship = "many-to-many") %>% 
    filter(!is.na(parent_genre), tolower(parent_genre) != "other") %>%
    select(-any_of("genres")) %>%  
    rename(genres = parent_genre)  
  
  grid_x <- if(decade_key %in% c("1970s", "1980s", "2010s", "2020s")) element_blank() else element_line(color = s$grid, linetype = "dotted")
  grid_y <- if(is.na(s$grid)) element_blank() else element_line(color = s$grid, linetype = "dotted")
  
  era_theme <- theme_minimal() + theme(
    plot.background = element_rect(fill = s$bg, color = NA), 
    panel.background = element_rect(fill = s$bg, color = NA),
    text = element_text(color = s$txt, family = s$font, size = 22), 
    panel.grid.major.y = grid_y,
    panel.grid.major.x = grid_x, 
    axis.text = element_text(color = s$txt, size = 20, face = "bold"), 
    axis.title = element_text(color = s$txt, size = 21, face = "bold"), 
    plot.title = element_text(face = "bold", size = 28, hjust = 0.5), 
    plot.subtitle = element_markdown(size = 21, color = s$txt, hjust = 0.5, lineheight = 1.3), 
    legend.position = "none",
    plot.margin = margin(t = 20, r = 20, b = 20, l = 20) 
  )
  
  smart_y_limits <- function(limits) {
    max_val <- limits[2]
    if(is.na(max_val) || max_val <= 0) return(c(0, 100))
    clean_max <- ceiling(max_val / 100) * 100
    if (clean_max == 0) clean_max <- 100
    return(c(0, clean_max))
  }
  
  smart_y_breaks <- function(limits) {
    max_val <- limits[2]
    if(is.na(max_val) || max_val <= 0) return(c(0, 50, 100))
    clean_max <- ceiling(max_val / 100) * 100
    if (clean_max == 0) clean_max <- 100
    return(c(0, clean_max / 2, clean_max))
  }
  
  # T. TITLE BLOCK 
  p_title <- ggplot() + 
    annotate("text", x = 0.5, y = 0.5, label = decade_key, size = 39, fontface = "bold", color = s$txt, family = s$font) + 
    theme_void() + 
    theme(plot.background = element_rect(fill = s$bg, color = NA), plot.margin = margin(t = 30, b = 10))
  
  # D. TOP ARTIST
  leaders_data <- era_data %>% group_by(year, performer) %>% summarize(wks = sum(weeks_on_chart, na.rm = TRUE), .groups = "drop") %>% group_by(year) %>% slice_max(wks, n = 1, with_ties = FALSE)
  artist_subtitle <- "Artist maintaining the highest cumulative weeks on the chart per year"
  
  p_year_leaders <- ggplot(leaders_data, aes(x = year, y = wks)) + 
    geom_col(alpha = 0.9, fill = s$fill1) + 
    geom_text(aes(label = str_wrap(performer, width = 8), y = wks + max(leaders_data$wks)*0.05), 
              vjust = 0, fontface = "bold", size = 7, color = s$txt, lineheight = 0.8) + 
    scale_y_continuous(limits = smart_y_limits, breaks = smart_y_breaks) + 
    scale_x_continuous(breaks = seq(start_yr, end_yr, by = 2)) +
    era_theme + theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    labs(title = "TOP ARTIST BY YEAR", subtitle = artist_subtitle, x = "Year", y = "Chart Weeks")
  
  # A. CHURN 
  era_churn_data <- era_data %>% 
    group_by(year) %>% 
    summarize(Hits = n_distinct(paste(title, performer)),
              Artists = n_distinct(performer), .groups = "drop")
  
  churn_subtitle_html <- paste0("Volume of total unique songs vs. individual artists on the billboard <br>",
                                "<span style='color:", s$fill1, "; font-size:34px;'>&#9632;</span> Artists &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
                                "<span style='color:", s$line1, "; font-size:34px;'>&#9632;</span> Hits")
  
  p_churn <- ggplot(era_churn_data, aes(x = year)) +
    geom_col(aes(y = Artists), fill = s$fill1, alpha = 0.3) +
    geom_line(aes(y = Hits), color = s$line1, linewidth = 2) + 
    geom_point(aes(y = Hits), color = s$line1, size = 4) +
    scale_y_continuous(limits = smart_y_limits, breaks = smart_y_breaks) + 
    scale_x_continuous(breaks = seq(start_yr, end_yr, by = 2)) +
    era_theme + labs(title = "CHART CHURN", subtitle = churn_subtitle_html, x = "Year", y = "Count")
  
  # B. VELOCITY 
  low_col <- if(decade_key == "1990s") s$grid else s$line1
  high_col <- if(decade_key == "1990s") s$line1 else s$fill1
  
  vel_subtitle_html <- paste0("Density of songs by peak rank and total lifespan <br>",
                              "<span style='color:", low_col, "; font-size:34px;'>&#9632;</span> **Min** &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; ",
                              "<span style='color:", high_col, "; font-size:34px;'>&#9632;</span> **Max**")
  
  p_velocity <- ggplot(era_data, aes(x = peak_pos, y = weeks_on_chart)) + 
    geom_bin2d(bins = 20) + scale_fill_gradient(low = low_col, high = high_col) + 
    scale_x_reverse(limits = c(100, 1)) + 
    scale_y_continuous(limits = smart_y_limits, breaks = smart_y_breaks) +
    era_theme + labs(title = "CHART VELOCITY", subtitle = vel_subtitle_html, x = "Peak Rank", y = "Total Weeks")
  
  # E. WAVE 
  top_3_local <- era_genre_data %>% count(genres, sort=T) %>% head(3) %>% pull(genres)
  
  third_col <- case_when(
    decade_key == "1960s" ~ "#F4D06F",
    decade_key == "1970s" ~ "#FFFF00",
    decade_key == "1980s" ~ "#00FF00",
    decade_key == "1990s" ~ "#9e2a2b",
    decade_key == "2000s" ~ "#B026FF",
    decade_key == "2010s" ~ "#888888",
    decade_key == "2020s" ~ "#B200FF",
    TRUE ~ "white"
  )
  wave_colors <- setNames(c(low_col, high_col, third_col), top_3_local)
  
  wave_subtitle_html <- paste0("Market share evolution of the era's dominant genres <br>", 
                               paste0("<span style='color:", wave_colors[top_3_local], "; font-size: 39px;'>&#9679;</span> **", top_3_local, "**", collapse = " &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; "))
  
  p_stream <- era_genre_data %>% filter(genres %in% top_3_local) %>% count(year, genres) %>%
    ggplot(aes(x = year, y = n, fill = genres)) + 
    geom_stream(type = "mirror", bw = 0.5, color = "#121212", linewidth = 0.2) + 
    scale_fill_manual(values = wave_colors) + 
    scale_x_continuous(breaks = seq(start_yr, end_yr, by = 2)) +
    scale_y_continuous(breaks = NULL) +
    era_theme + labs(title = "GENRES WAVE", subtitle = wave_subtitle_html, x = "Year", y = "")
  
  # C. FREQUENCY / LONGEVITY 
  top_5_local <- era_genre_data %>% count(genres, sort=T) %>% head(5) %>% pull(genres)
  

  era_colors <- setNames(viridis_pal(option = "turbo", begin = 0.2, end = 1)(10), top_10_list)
  
  era_median_all <- median(era_data$weeks_on_chart, na.rm = TRUE)
  
  ridge_subtitle <- "Distribution of total weeks on chart for the most dominant genres"
  
  p_ridge <- ggplot(era_genre_data %>% filter(genres %in% top_5_local), aes(x = weeks_on_chart, y = fct_reorder(genres, weeks_on_chart, .fun = median), fill = genres)) + 
    geom_density_ridges(alpha = 0.85, color = "#121212", scale = 1.2) + 
    geom_vline(xintercept = era_median_all, color = "white", linetype = "dashed", linewidth = 1.5) +
    # UPDATED: Placed higher (y + 1.2)
    annotate("text", x = era_median_all + 0.8, y = length(top_5_local) + 1.2, 
             label = paste("Typical song stays for", round(era_median_all, 1), "weeks"), 
             color = "white", size = 8, fontface = "bold", hjust = 0) + 
    scale_fill_manual(values = era_colors) + 
    scale_x_continuous(limits = c(0, 30)) + 
    # UPDATED: Added 35% empty headroom to strictly prevent text cutoffs
    scale_y_discrete(expand = expansion(mult = c(0.05, 0.35))) + 
    coord_cartesian(clip = "off") +
    era_theme + labs(title = "GENRE LONGEVITY", subtitle = ridge_subtitle, x = "Weeks on Hot 100", y = "")
  
  # ASSEMBLY LAYOUT 
  layout <- "
    11
    23
    45
    66
  "
  
  dashboard <- (p_title + p_year_leaders + p_churn + p_velocity + p_stream + p_ridge) + 
    plot_layout(design = layout, heights = c(0.15, 1, 1, 0.9)) + 
    plot_annotation(theme = theme(plot.background = element_rect(fill = s$bg, color = NA)))
  
  return(dashboard)
}

# ------------------------------------------------------------------------------
# STEP 4: RUN DASHBOARD GENERATORS
# ------------------------------------------------------------------------------
decades <- c("1960s", "1970s", "1980s", "1990s", "2000s", "2010s", "2020s")
for(d in decades) {
  assign(paste0("dashboard_", d), create_decade_dashboard(d, master, artist_genre_map), envir = .GlobalEnv)
}

# ------------------------------------------------------------------------------
# STEP 5: INFOGRAPHIC ASSEMBLY & EXPORT
# ------------------------------------------------------------------------------
options(ragg.max_dim = 100000)

black_gap <- plot_spacer() + theme(plot.background = element_rect(fill = "#000000", color = NA))

grand_infographic <- (
  dashboard_1960s / black_gap /
    dashboard_1970s / black_gap /
    dashboard_1980s / black_gap /
    dashboard_1990s / black_gap /
    dashboard_2000s / black_gap /
    dashboard_2010s / black_gap /
    dashboard_2020s
) + 
  plot_layout(heights = c(1, 0.04, 1, 0.04, 1, 0.04, 1, 0.04, 1, 0.04, 1, 0.04, 1)) +
  plot_annotation(
    title = "Evolution of Mainstream Music<br>Billboard Hot 100", 
    subtitle = "Visualization of culture shifts, genre trends, and artist dominance (1960-2025)",
    theme = theme(
      plot.background = element_rect(fill = "#121212", color = NA),
      plot.title = element_markdown(size = 94, face = "bold", color = "white", hjust = 0.5, lineheight = 1.1, margin = margin(t=60, b=30)),
      plot.subtitle = element_text(size = 44, color = "#A0A0A0", hjust = 0.5, margin = margin(b=100))
    )
  )

ggsave("Billboard_Infographic.png", grand_infographic, width = 32, height = 230, dpi = 300, limitsize = FALSE)

# ==============================================================================
# EXTENDED CHARTS (dbt marts edition)
# ==============================================================================
# This section is self-contained: run it on its own from the repo root.
# It reads the analysis-ready marts exported from the DuckDB warehouse
# (data/marts/*.csv) and saves PNGs into charts/.
# Style: Shrikhand titles, Montserrat body, off-white background, no gridlines.

library(tidyverse)
library(scales)
library(ggrepel)
library(ggridges)
library(showtext)

# ------------------------------------------------------------------------------
# 1. SETUP: fonts and shared theme
# ------------------------------------------------------------------------------
title_font <- "sans"
body_font  <- "sans"
tryCatch({
  font_add_google("Shrikhand", "beatles_font")
  font_add_google("Montserrat", "clean_font")
  title_font <<- "beatles_font"
  body_font  <<- "clean_font"
}, error = function(e) message("Google fonts unavailable, falling back to sans"))
showtext_auto()
showtext_opts(dpi = 150)

bb_bg    <- "#F5F5F5"
bb_text  <- "#111111"
bb_muted <- "#555555"
bb_red   <- "#eb5757"
bb_gold  <- "#f5c518"
bb_blue  <- "#2d9cdb"

theme_bb <- function(base_size = 14) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.background  = element_rect(fill = bb_bg, color = NA),
      panel.background = element_rect(fill = bb_bg, color = NA),
      panel.grid       = element_blank(),
      text             = element_text(color = bb_text, family = body_font),
      axis.text        = element_text(color = bb_text, family = body_font),
      axis.title       = element_text(color = bb_text, face = "bold", family = body_font),
      plot.title       = element_text(family = title_font, size = base_size + 12,
                                      hjust = 0.5, color = "#333333",
                                      margin = margin(t = 6, b = 4)),
      plot.subtitle    = element_text(family = body_font, size = base_size + 1,
                                      hjust = 0.5, color = bb_muted,
                                      margin = margin(b = 14)),
      legend.text      = element_text(color = bb_text, family = body_font),
      legend.title     = element_text(color = bb_text, face = "bold", family = body_font),
      legend.position  = "bottom",
      axis.ticks       = element_line(color = "#cccccc")
    )
}

genre_cols <- c(
  "Rock & Metal"     = "#eb5757",
  "R&B/Soul"         = "#F4A261",
  "Pop"              = "#f5c518",
  "Hip-Hop"          = "#9B5DE5",
  "Country/Folk"     = "#8AB17D",
  "Jazz/Blues"       = "#457B9D",
  "Electronic/Dance" = "#2d9cdb",
  "Latin"            = "#F72585",
  "Reggae/Ska"       = "#2A9D8F",
  "Other"            = "grey60"
)

out_dir <- "charts"
if (!dir.exists(out_dir)) dir.create(out_dir)

save_chart <- function(name, plot, w = 12, h = 7.5) {
  tryCatch({
    ggsave(file.path(out_dir, paste0(name, ".png")), plot,
           width = w, height = h, dpi = 150, bg = bb_bg, device = ragg::agg_png)
    message("saved: ", name)
  }, error = function(e) message("FAILED ", name, ": ", conditionMessage(e)))
}

# ------------------------------------------------------------------------------
# 2. LOAD MARTS
# ------------------------------------------------------------------------------
songs <- read_csv("data/marts/fct_songs.csv", show_col_types = FALSE)
weeks <- read_csv("data/marts/fct_chart_weeks.csv", show_col_types = FALSE)

decade_levels <- paste0(seq(1960, 2020, 10), "s")

song_totals <- songs %>%
  group_by(performer, title) %>%
  summarise(
    debut_year   = min(chart_year),
    weeks_total  = max(weeks_on_chart),
    peak         = min(peak_position),
    parent_genre = first(parent_genre),
    .groups = "drop"
  ) %>%
  mutate(debut_decade = factor(paste0(floor(debut_year / 10) * 10, "s"), levels = decade_levels))

# ------------------------------------------------------------------------------
# 05. Title words: top 5 most common words in song titles
# ------------------------------------------------------------------------------
stop_words_mini <- c("the","a","an","to","of","in","on","and","for","is","it","i","you",
                     "me","my","your","we","us","be","do","don't","it's","i'm","that",
                     "this","what","with","at","no","not","so")
title_words <- song_totals %>%
  mutate(word = str_split(str_to_lower(str_replace_all(title, "[^a-zA-Z' ]", " ")), "\\s+")) %>%
  unnest(word) %>%
  filter(nchar(word) > 1, !word %in% stop_words_mini)
songs_per_year <- song_totals %>% count(debut_year, name = "n_songs")
word_ranks <- title_words %>% count(word, sort = TRUE)
# pin love and time, fill up to 5 with the next most common words.
# "from" is excluded: it is a 1990s chart-listing artifact, not a real title
# word (soundtrack singles were listed as 'Song (From "Movie")').
top5 <- c("love", "time",
          word_ranks %>% filter(!word %in% c("love", "time", "from")) %>%
            slice_head(n = 3) %>% pull(word))

word_yearly <- title_words %>%
  filter(word %in% top5) %>%
  distinct(debut_year, performer, title, word) %>%
  count(debut_year, word) %>%
  complete(debut_year = full_seq(range(song_totals$debut_year), 1), word = top5, fill = list(n = 0)) %>%
  left_join(songs_per_year, by = "debut_year") %>%
  mutate(share = n / n_songs)

word_yearly <- word_yearly %>%
  mutate(group = case_when(word == "love" ~ "love", word == "time" ~ "time",
                           TRUE ~ "other"))
word_cols <- c(love = bb_red, time = bb_blue, other = "grey60")

c05 <- ggplot(word_yearly, aes(debut_year, share, group = word)) +
  geom_line(data = ~ filter(.x, group == "other"), color = "grey72", linewidth = 0.7) +
  geom_line(data = ~ filter(.x, group == "time"), color = word_cols["time"], linewidth = 1.6) +
  geom_line(data = ~ filter(.x, group == "love"), color = word_cols["love"], linewidth = 1.6) +
  geom_text_repel(data = word_yearly %>% group_by(word) %>% filter(debut_year == max(debut_year)) %>% ungroup(),
                  aes(label = word, color = group), direction = "y", hjust = 0, nudge_x = 1.5,
                  segment.color = "grey80", size = 4.2, fontface = "bold",
                  family = body_font, show.legend = FALSE) +
  scale_color_manual(values = word_cols) +
  scale_y_continuous(labels = label_percent(accuracy = 1)) +
  scale_x_continuous(expand = expansion(mult = c(0.02, 0.12))) +
  labs(title = "65 YEARS OF SONG TITLES",
       subtitle = str_wrap("Share of Hot 100 songs per debut year whose title contains the word, for the 5 most common title words.", 95),
       x = NULL, y = "Share of charting songs") +
  theme_bb()
save_chart("Title_Words", c05)

# ------------------------------------------------------------------------------
# 06. Straight in at number one: every song that debuted at #1 (dot timeline)
# ------------------------------------------------------------------------------
debut_no1 <- weeks %>%
  filter(is_new_entry, chart_position == 1) %>%
  arrange(chart_week) %>%
  group_by(chart_year) %>%
  mutate(stack = row_number()) %>%
  ungroup()

first_ever <- debut_no1 %>% slice_min(chart_week, n = 1)

c06 <- ggplot(debut_no1, aes(chart_year, stack)) +
  annotate("segment", x = 1960, xend = 2025, y = 0.4, yend = 0.4, color = "#bbbbbb", linewidth = 0.6) +
  geom_point(color = bb_red, size = 3.6, alpha = 0.9) +
  annotate("text", x = 1972, y = 9, family = body_font, size = 4.4, color = bb_muted, hjust = 0.5,
           lineheight = 1.05,
           label = "For the chart's first 35 years, no song ever\nentered at the top. A 1995 rule change made\nairplay count from week one, and streaming\nlater made instant #1 debuts routine.") +
  geom_text_repel(data = first_ever,
                  aes(label = paste0("First ever: \"", title, "\"\n", performer, ", ", chart_year)),
                  family = body_font, size = 3.8, fontface = "bold", color = bb_text,
                  nudge_y = 3.5, nudge_x = -14, segment.color = "#999999", seed = 2) +
  scale_x_continuous(breaks = seq(1960, 2020, 10), limits = c(1959, 2026)) +
  scale_y_continuous(limits = c(0.4, NA), expand = expansion(mult = c(0, 0.08))) +
  labs(title = "STRAIGHT IN AT NUMBER ONE",
       subtitle = "Every song that debuted at #1 in its very first chart week. One dot = one song, stacked per year.",
       x = NULL, y = NULL) +
  theme_bb() +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())
save_chart("Debut_At_Number_One", c06)

# ------------------------------------------------------------------------------
# 08. Joyplot: which genres have staying power
# ------------------------------------------------------------------------------
genre_stay <- song_totals %>%
  filter(parent_genre != "Other", weeks_total <= 40)
genre_order <- genre_stay %>%
  group_by(parent_genre) %>%
  summarise(med = median(weeks_total), .groups = "drop") %>%
  arrange(med) %>% pull(parent_genre)

c08 <- genre_stay %>%
  mutate(parent_genre = factor(parent_genre, levels = genre_order)) %>%
  ggplot(aes(weeks_total, parent_genre, fill = parent_genre)) +
  geom_density_ridges(scale = 1.9, rel_min_height = 0.005,
                      color = "#333333", alpha = 0.9, show.legend = FALSE) +
  scale_fill_manual(values = genre_cols) +
  scale_x_continuous(breaks = seq(0, 40, 10)) +
  labs(title = "WHICH GENRES HAVE STAYING POWER",
       subtitle = str_wrap("Distribution of total weeks on the Hot 100 per song, by genre, sorted by median chart stay", 95),
       x = "Total weeks on chart", y = NULL) +
  theme_bb()
save_chart("Genre_Staying_Power", c08)

# ------------------------------------------------------------------------------
# 14. The featuring economy: collaborations over time
# ------------------------------------------------------------------------------
c14 <- song_totals %>%
  mutate(collab = str_detect(performer, regex("featuring| feat\\.?| & | x | with |,", ignore_case = TRUE))) %>%
  group_by(debut_year) %>%
  summarise(share = mean(collab), .groups = "drop") %>%
  ggplot(aes(debut_year, share)) +
  geom_area(fill = bb_red, alpha = 0.25) +
  geom_line(color = bb_red, linewidth = 1.5) +
  scale_y_continuous(labels = label_percent(accuracy = 1), limits = c(0, NA),
                     expand = expansion(mult = c(0, 0.08))) +
  labs(title = "COLLABORATION SONGS REACHING THE CHART",
       subtitle = "Share of charting songs credited to more than one act (featuring, &, x, with)",
       x = NULL, y = "Share of charting songs") +
  theme_bb()
save_chart("Collaboration_Songs", c14)

# ------------------------------------------------------------------------------
# 18. Song titles are shrinking: average title length over time
# ------------------------------------------------------------------------------
c18 <- song_totals %>%
  mutate(n_words = str_count(title, "\\S+")) %>%
  group_by(debut_year) %>%
  summarise(avg_words = mean(n_words), .groups = "drop") %>%
  ggplot(aes(debut_year, avg_words)) +
  geom_line(color = bb_gold, linewidth = 1.4) +
  geom_smooth(se = FALSE, color = bb_red, linewidth = 1.1, linetype = "dashed",
              method = "loess", formula = y ~ x) +
  scale_y_continuous(limits = c(0, 4.4), breaks = 0:4, expand = c(0, 0)) +
  labs(title = "SONG TITLES ARE SHRINKING",
       subtitle = str_wrap("Average number of words in Hot 100 song titles per debut year (dashed = smoothed trend)", 95),
       x = NULL, y = "Words per title") +
  theme_bb()
save_chart("Title_Length", c18)

# ------------------------------------------------------------------------------
# 21. The narrowing funnel: new songs per year
# ------------------------------------------------------------------------------
c21 <- song_totals %>%
  count(debut_year) %>%
  filter(debut_year > 1960, debut_year < 2026) %>%
  ggplot(aes(debut_year, n)) +
  annotate("rect", xmin = 1992, xmax = 1998, ymin = 0, ymax = Inf, fill = bb_blue, alpha = 0.12) +
  annotate("text", x = 1995, y = 800, label = "single-release\nrule era", color = bb_blue,
           size = 3.6, lineheight = 0.95, family = body_font) +
  geom_area(fill = bb_red, alpha = 0.25) +
  geom_line(color = bb_red, linewidth = 1.5) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.06))) +
  labs(title = "THE NARROWING FUNNEL",
       subtitle = str_wrap("Number of new songs debuting on the Hot 100 each year. From 1992-1998 only commercially released singles could chart.", 85),
       x = NULL, y = "New songs per year") +
  theme_bb()
save_chart("New_Songs_Funnel", c21)

# ------------------------------------------------------------------------------
# 01. The Hot 100 in numbers: key statistics board
# ------------------------------------------------------------------------------
n_songs      <- nrow(song_totals)
n_artists    <- n_distinct(song_totals$performer)
n_no1        <- song_totals %>% filter(peak == 1) %>% nrow()
avg_weeks    <- mean(song_totals$weeks_total)
longest      <- song_totals %>% slice_max(weeks_total, n = 1, with_ties = FALSE)
# count #1 hits by primary artist: collaboration credits like
# "The Beatles With Billy Preston" (Get Back) belong to the lead act
most_no1     <- song_totals %>%
  filter(peak == 1) %>%
  mutate(primary = str_trim(str_remove(performer, regex(" (featuring|feat\\.?|with) .*$", ignore_case = TRUE)))) %>%
  distinct(primary, title) %>%
  count(primary, sort = TRUE) %>% slice_head(n = 1)
one_hit_pct  <- song_totals %>% count(performer) %>% summarise(p = mean(n == 1)) %>% pull(p)
gt10_pct     <- song_totals %>% count(performer) %>% summarise(p = mean(n > 10)) %>% pull(p)

stats <- tribble(
  ~x, ~y, ~value, ~label,
  1, 2, comma(n_songs),                          "charting songs",
  2, 2, comma(n_artists),                        "different artists",
  3, 2, comma(n_no1),                            "number 1 hits",
  4, 2, paste0(round(avg_weeks, 1), " weeks"),   "average chart stay",
  1, 1, paste0(longest$weeks_total, " weeks"),   paste0("longest run:\n", longest$title, " by ", longest$performer),
  2, 1, as.character(most_no1$n),                paste0("most #1 hits:\n", most_no1$primary),
  3, 1, percent(one_hit_pct, accuracy = 1),      "artists with one song\nreaching the chart",
  4, 1, percent(gt10_pct, accuracy = 0.1),       "artists with more than\n10 songs on the chart"
)

c01 <- ggplot(stats) +
  geom_tile(aes(x, y), width = 0.92, height = 0.86, fill = "white", color = "#dddddd") +
  geom_text(aes(x, y + 0.14, label = value), family = title_font,
            size = 10, color = bb_red) +
  geom_text(aes(x, y - 0.2, label = label), family = body_font,
            size = 4.4, color = bb_muted, lineheight = 0.95, fontface = "bold") +
  scale_x_continuous(limits = c(0.5, 4.5)) +
  scale_y_continuous(limits = c(0.5, 2.5)) +
  labs(title = "THE BILLBOARD HOT 100 IN NUMBERS") +
  theme_void(base_size = 14) +
  theme(plot.background = element_rect(fill = bb_bg, color = NA),
        text = element_text(color = bb_text, family = body_font),
        plot.title = element_text(family = title_font, size = 28, hjust = 0.5, color = "#333333",
                                  margin = margin(t = 8, b = 4)),
        plot.subtitle = element_text(color = bb_muted, hjust = 0.5, size = 15,
                                     margin = margin(b = 10)))
save_chart("Hot100_In_Numbers", c01, w = 13, h = 7)

# ------------------------------------------------------------------------------
# 13. The slow death of the band: solo acts vs groups
# ------------------------------------------------------------------------------
c13 <- songs %>%
  filter(artist_type %in% c("Person", "Group")) %>%
  count(chart_year, artist_type) %>%
  group_by(chart_year) %>% mutate(share = n / sum(n)) %>% ungroup() %>%
  ggplot(aes(chart_year, share, color = artist_type)) +
  geom_line(linewidth = 1.5) +
  scale_color_manual(values = c("Person" = bb_red, "Group" = bb_blue),
                     labels = c("Person" = "Solo artists", "Group" = "Bands & groups"), name = NULL) +
  scale_y_continuous(labels = label_percent(accuracy = 1), limits = c(0, NA)) +
  labs(title = "SOLO ARTISTS VS BANDS",
       subtitle = str_wrap("Share of charting songs by solo artists vs bands and groups. Groups peaked with the rise of bands in the 60s and the band-heavy 90s, then faded as hip-hop and streaming made solo artists the default.", 95),
       x = NULL, y = "Share of charting songs") +
  theme_bb()
save_chart("Solo_Artists_Vs_Bands", c13)

# ------------------------------------------------------------------------------
# 15. The comeback machine: chart re-entries per year
# ------------------------------------------------------------------------------
reentries <- weeks %>%
  arrange(performer, title, chart_week) %>%
  group_by(performer, title) %>%
  mutate(appearance = row_number()) %>%
  ungroup() %>%
  filter(is_new_entry, appearance > 1) %>%
  count(chart_year)

c15b <- ggplot(reentries, aes(chart_year, n)) +
  geom_col(fill = bb_red, width = 0.8) +
  annotate("text", x = 1985, y = 150, family = body_font, size = 4.4, color = bb_muted, hjust = 0.5,
           lineheight = 1.05,
           label = str_wrap("For decades a song that fell off the chart stayed gone. Streaming changed that: every December the Christmas catalog returns, and viral moments resurrect old songs overnight.", 44)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.06))) +
  labs(title = "THE COMEBACK MACHINE",
       subtitle = str_wrap("Number of times per year a song RE-ENTERED the Hot 100 after having left it", 95),
       x = NULL, y = "Chart re-entries per year") +
  theme_bb()
save_chart("Chart_Reentries", c15b)

message("Extended charts saved in ", out_dir, "/")
