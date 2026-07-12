library(tidyverse)
library(httr)
library(jsonlite)
library(stringr) # Needed for regex cleaning

# Run from the project root; song list comes from the warehouse marts export
master <- read_csv("data/raw/billboard_hot100_weekly.csv", show_col_types = FALSE) %>%
  distinct(performer, title)

# Grab 3 obscure songs, plus add 1 famous "Control" song to prove the API works
test_master <- head(master, 3) %>%
  add_row(performer = "The Beatles", title = "Hey Jude")

# API key is loaded from the environment — never commit it to source.
API_KEY <- Sys.getenv("GETSONGBPM_API_KEY")

get_song_bpm_alternative <- function(artist, title) {
  Sys.sleep(1.5) 
  
  # --- THE FIX: Clean the strings ---
  # This removes anything inside parentheses (e.g., "(Choir of 40 Voices)")
  clean_artist <- str_trim(str_remove_all(artist, "\\s*\\([^\\)]+\\)"))
  clean_title  <- str_trim(str_remove_all(title, "\\s*\\([^\\)]+\\)"))
  
  message(sprintf("Searching: %s - %s", clean_artist, clean_title))
  
  query_string <- paste0("song:", clean_title, " artist:", clean_artist)
  safe_query <- URLencode(query_string)
  
  url <- paste0("https://api.getsongbpm.com/search/?api_key=", API_KEY, "&type=both&lookup=", safe_query)
  
  tryCatch({
    response <- GET(url)
    
    if (status_code(response) == 200) {
      parsed <- fromJSON(content(response, "text", encoding = "UTF-8"))
      
      if (!is.null(parsed$search) && length(parsed$search) > 0) {
        bpm <- as.numeric(parsed$search$tempo[1])
        message(sprintf(" -> Success! BPM: %s", bpm))
        return(bpm)
      }
    }
    message(" -> No BPM found.")
    return(NA_real_)
    
  }, error = function(e) {
    message(" -> Connection error.")
    return(NA_real_)
  })
}

# Run the test
test_with_bpm <- test_master %>%
  mutate(bpm = map2_dbl(performer, title, get_song_bpm_alternative))

# View results
print(test_with_bpm %>% select(performer, title, bpm))