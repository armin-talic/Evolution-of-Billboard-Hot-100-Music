# ==============================================================================
# FILE 1: DATA EXTRACTION (Billboard scrape + MusicBrainz + TheAudioDB)
# ==============================================================================
# This script is the EXTRACT layer only. It fetches raw data and lands it in
# data/raw/ unchanged. All transformation (year/decade/is_new derivation, master
# table construction, genre classification) lives in dbt models — see
# models/staging and models/marts.
library(httr)
library(jsonlite)
library(tidyverse)
library(lubridate)

# Suppress warnings for clean console output
options(warn = -1)

# Run this script from the project root (AI Project Music/) so relative
# data/raw/ paths resolve correctly.
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------------------------
# STEP 1: LOAD RAW BILLBOARD DATA
# ------------------------------------------------------------------------------
url <- "https://raw.githubusercontent.com/utdata/rwd-billboard-data/main/data-out/hot-100-current.csv"
raw_data <- read_csv(url, show_col_types = FALSE)
write_csv(raw_data, "data/raw/billboard_hot100_weekly.csv")

all_artists <- unique(raw_data$performer)

# ------------------------------------------------------------------------------
# STEP 2: MUSICBRAINZ API FETCH 
# ------------------------------------------------------------------------------
cat("\n--- STEP 2: Fetching MusicBrainz API Metadata ---\n")

get_mb_with_relations <- function(artist_name) {
  ua <- user_agent("VinylProject/1.0 (research@example.com)")
  
  Sys.sleep(1.2) # Mandatory API Rate Limit
  search_url <- paste0("https://musicbrainz.org/ws/2/artist?query=artist:", URLencode(artist_name), "&fmt=json")
  
  tryCatch({
    resp <- GET(search_url, ua)
    if (status_code(resp) != 200) return(NULL)
    data <- fromJSON(content(resp, "text", encoding = "UTF-8"))
    
    if (length(data$artists) > 0) {
      art <- data$artists[1, , drop = FALSE]
      mbid <- art$id[1]
      if (is.null(mbid) || is.na(mbid)) return(NULL)
      
      safe_chr <- function(col) if (col %in% names(art) && length(art[[col]]) > 0 && !is.na(art[[col]][1])) as.character(art[[col]][1]) else NA_character_
      
      t1<-NA; t2<-NA; t3<-NA
      if ("tags" %in% names(art) && is.data.frame(art$tags[[1]])) {
        tags <- art$tags[[1]]
        if("count" %in% names(tags)) tags <- tags[order(-as.numeric(tags$count)), ]
        if(nrow(tags)>=1) t1 <- tags$name[1]
        if(nrow(tags)>=2) t2 <- tags$name[2]
        if(nrow(tags)>=3) t3 <- tags$name[3]
      }
      
      # Combine top tags into a single string
      genres_combined <- paste(na.omit(c(t1, t2, t3)), collapse = ", ")
      if(genres_combined == "") genres_combined <- NA_character_
      
      # Call 2: Band Members Lookup
      Sys.sleep(1.2) 
      lookup_url <- paste0("https://musicbrainz.org/ws/2/artist/", mbid, "?inc=artist-rels&fmt=json")
      resp_rel <- GET(lookup_url, ua)
      
      band_members <- NA_character_
      if (status_code(resp_rel) == 200) {
        rel_data <- fromJSON(content(resp_rel, "text", encoding = "UTF-8"))
        if ("relations" %in% names(rel_data) && is.data.frame(rel_data$relations)) {
          rels <- rel_data$relations
          if ("type" %in% names(rels) && "artist" %in% names(rels)) {
            members <- rels[rels$type == "member of band", ]
            if (nrow(members) > 0 && "name" %in% names(members$artist)) {
              band_members <- paste(members$artist$name, collapse = " | ")
            }
          }
        }
      }
      
      return(data.frame(
        performer = artist_name, mb_id = mbid, genres = genres_combined, 
        mb_type = safe_chr("type"), mb_gender = safe_chr("gender"), 
        mb_country = safe_chr("country"), mb_tag_1 = t1, mb_tag_2 = t2, mb_tag_3 = t3,
        mb_band_members = band_members, 
        stringsAsFactors = FALSE
      ))
    }
  }, error = function(e) return(NULL))
  return(NULL)
}

mb_output_file <- "data/raw/musicbrainz_artist_metadata.csv"

if (file.exists(mb_output_file)) {
  mb_cache <- read_csv(mb_output_file, show_col_types = FALSE)
  fetched_mb <- unique(mb_cache$performer)
} else { fetched_mb <- character(0) }

mb_to_fetch <- setdiff(all_artists, fetched_mb)

if (length(mb_to_fetch) > 0) {
  cat("Fetching MusicBrainz for", length(mb_to_fetch), "artists...\n")
  for (i in seq_along(mb_to_fetch)) {
    artist <- mb_to_fetch[i]
    if (i %% 50 == 0 || i == 1) cat(sprintf("[MusicBrainz %d/%d]: %s\n", i, length(mb_to_fetch), artist))
    res <- get_mb_with_relations(artist)
    if (!is.null(res)) {
      write_csv(res, mb_output_file, append = file.exists(mb_output_file))
    } else {

      bad_row <- data.frame(
        performer = artist, mb_id = "FAILED", genres = NA, mb_type = NA, 
        mb_gender = NA, mb_country = NA, mb_tag_1 = NA, mb_tag_2 = NA, mb_tag_3 = NA, 
        mb_band_members = NA
      )
      write_csv(bad_row, mb_output_file, append = file.exists(mb_output_file))
    }
  }
} else { cat("MusicBrainz data is fully fetched.\n") }

# ------------------------------------------------------------------------------
# STEP 3: THEAUDIODB API FETCH 
# ------------------------------------------------------------------------------
cat("\n--- STEP 3: Fetching TheAudioDB API Metadata ---\n")

get_adb_data <- function(artist_name) {
  ua <- user_agent("VinylProject/1.0 (research@example.com)")
  Sys.sleep(0.5) # AudioDB allows faster requests
  
  search_url <- paste0("https://www.theaudiodb.com/api/v1/json/2/search.php?s=", URLencode(artist_name))
  
  tryCatch({
    resp <- GET(search_url, ua)
    if (status_code(resp) == 200) {
      data <- fromJSON(content(resp, "text", encoding = "UTF-8"))
      
      if (!is.null(data$artists) && is.data.frame(data$artists)) {
        art <- data$artists[1, ]
        safe_val <- function(val) if(is.null(val) || is.na(val) || val == "") NA_character_ else as.character(val)
        
        return(data.frame(
          performer = artist_name, strGenre = safe_val(art$strGenre),
          strMood = safe_val(art$strMood), strStyle = safe_val(art$strStyle),
          strGender = safe_val(art$strGender), strCountry = safe_val(art$strCountry),
          intMembers = as.numeric(safe_val(art$intMembers)),
          stringsAsFactors = FALSE
        ))
      }
    }
  }, error = function(e) return(NULL))
  return(NULL)
}

adb_output_file <- "data/raw/theaudiodb_artist_metadata.csv"

if (file.exists(adb_output_file)) {
  adb_cache <- read_csv(adb_output_file, show_col_types = FALSE)
  fetched_adb <- unique(adb_cache$performer)
} else { fetched_adb <- character(0) }

adb_to_fetch <- setdiff(all_artists, fetched_adb)

if (length(adb_to_fetch) > 0) {
  cat("Fetching TheAudioDB for", length(adb_to_fetch), "artists...\n")
  for (i in seq_along(adb_to_fetch)) {
    artist <- adb_to_fetch[i]
    if (i %% 50 == 0 || i == 1) cat(sprintf("[AudioDB %d/%d]: %s\n", i, length(adb_to_fetch), artist))
    res <- get_adb_data(artist)
    if (!is.null(res)) {
      write_csv(res, adb_output_file, append = file.exists(adb_output_file))
    } else {
      bad_row <- data.frame(performer = artist, strGenre = NA, strMood = NA, strStyle = NA, strGender = NA, strCountry = NA, intMembers = NA)
      write_csv(bad_row, adb_output_file, append = file.exists(adb_output_file))
    }
  }
} else { cat("TheAudioDB data is fully fetched.\n") }

cat("\n--- Extraction complete. Raw files written to data/raw/. ---\n")
cat("Run `dbt build` next to generate staging models, genre classification,\n")
cat("and marts from these raw extracts.\n")

