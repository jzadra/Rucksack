# Path discovery -----

get_rstudio_config_dir <- function() {
  configured <- Sys.getenv("RSTUDIO_CONFIG_HOME", unset = "")
  if (nzchar(configured)) return(path.expand(configured))

  if (.Platform$OS.type == "windows") {
    return(file.path(Sys.getenv("APPDATA"), "RStudio"))
  }

  xdg_config <- Sys.getenv("XDG_CONFIG_HOME", unset = file.path(path.expand("~"), ".config"))
  file.path(xdg_config, "rstudio")
}

get_r_user_files <- function() {
  r_user_home <- path.expand("~")
  list(
    home = r_user_home,
    profile = Sys.getenv("R_PROFILE_USER", unset = file.path(r_user_home, ".Rprofile")),
    environ = Sys.getenv("R_ENVIRON_USER", unset = file.path(r_user_home, ".Renviron"))
  )
}

get_user_fonts_dir <- function() {
  file.path(Sys.getenv("LOCALAPPDATA"), "Microsoft", "Windows", "Fonts")
}

get_font_loader_path <- function() {
  file.path(Sys.getenv("LOCALAPPDATA"), "Rucksack", "scripts", "load_user_fonts.ps1")
}

get_startup_shortcut_path <- function() {
  file.path(
    Sys.getenv("APPDATA"),
    "Microsoft", "Windows", "Start Menu", "Programs", "Startup",
    "Load User Fonts.lnk"
  )
}

# File handling -----

copy_path <- function(source, destination, overwrite = TRUE) {
  if (dir.exists(source)) {
    dir.create(destination, recursive = TRUE, showWarnings = FALSE)
    children <- list.files(source, all.files = TRUE, no.. = TRUE, full.names = TRUE)
    if (!length(children)) return(TRUE)

    copied <- logical(length(children))
    for (i in seq_along(children)) {
      copied[i] <- copy_path(
        children[i],
        file.path(destination, basename(children[i])),
        overwrite = overwrite
      )
    }
    return(all(copied))
  }

  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  isTRUE(file.copy(source, destination, overwrite = overwrite, copy.mode = TRUE, copy.date = TRUE))
}

font_files <- function(directory) {
  if (!dir.exists(directory)) return(character())
  list.files(directory, pattern = "\\.(ttf|otf)$", full.names = TRUE, ignore.case = TRUE)
}

redact_renviron <- function(source, destination) {
  lines <- readLines(source, warn = FALSE)
  assignment <- grepl("^\\s*[^#=]+=", lines)
  variable_names <- sub("^\\s*([^=]+)=.*$", "\\1", lines)
  secret <- assignment & grepl("key|token|secret|password|pwd", variable_names, ignore.case = TRUE)
  lines[secret] <- paste0(variable_names[secret], "=<REPLACE_ME>")
  writeLines(lines, destination, useBytes = TRUE)
}

# Archive handling -----

validate_archive_members <- function(members) {
  normalized <- gsub("\\\\", "/", members)
  unsafe <- grepl("^/|^[A-Za-z]:|(^|/)\\.\\.(/|$)", normalized)
  if (any(unsafe)) stop("The backup contains an unsafe archive path: ", members[which(unsafe)[1]])
  invisible(TRUE)
}

extract_backup <- function(archive, destination) {
  members <- utils::untar(archive, list = TRUE, tar = "internal")
  validate_archive_members(members)
  utils::untar(archive, exdir = destination, tar = "internal")
}

package_version_string <- function() {
  as.character(utils::packageVersion("Rucksack"))
}

# Package provenance -----

package_field <- function(package, fields) {
  for (field in fields) {
    if (!field %in% names(package)) next
    value <- as.character(package[[field]][1])
    if (!is.na(value) && nzchar(value)) return(value)
  }
  ""
}

package_github_coordinates <- function(package) {
  username <- package_field(package, c("RemoteUsername", "GithubUsername"))
  repository <- package_field(package, c("RemoteRepo", "GithubRepo"))
  if (nzchar(username) && nzchar(repository)) {
    return(c(username = username, repository = repository))
  }

  remote_url <- package_field(package, "RemoteUrl")
  remote_path <- sub("^https?://(www\\.)?github\\.com/", "", remote_url, ignore.case = TRUE)
  remote_path <- sub("^git@github\\.com:", "", remote_path, ignore.case = TRUE)
  remote_path <- sub("\\.git$", "", remote_path, ignore.case = TRUE)
  parts <- strsplit(remote_path, "/", fixed = TRUE)[[1]]
  if (length(parts) >= 2 && !identical(remote_path, remote_url)) {
    return(c(username = parts[1], repository = parts[2]))
  }
  c(username = "", repository = "")
}

package_install_source <- function(package) {
  remote_type <- tolower(package_field(package, "RemoteType"))
  if (identical(remote_type, "github")) return("GitHub")
  if (remote_type %in% c("bioc", "bioconductor")) return("Bioconductor")
  if (identical(remote_type, "cran")) return("CRAN")
  github <- package_github_coordinates(package)
  if (nzchar(github[["username"]]) && nzchar(github[["repository"]])) return("GitHub")

  repository <- package_field(package, "Repository")
  bioc_views <- package_field(package, "biocViews")
  if (grepl("bioconductor", repository, ignore.case = TRUE) || nzchar(bioc_views)) {
    return("Bioconductor")
  }

  if (nzchar(remote_type)) return(remote_type)
  "CRAN"
}
