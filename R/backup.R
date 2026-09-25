#' Back up an R and RStudio setup
#'
#' Creates a compressed archive containing user-level R configuration,
#' RStudio settings, a source-aware installed-package inventory, custom
#' RStudio themes, and optionally per-user Windows fonts.
#'
#' @param output_dir Directory in which to create the backup archive.
#' @param include_renviron Whether to include the original `.Renviron`. When
#'   `FALSE`, a template is included with likely secrets redacted.
#' @param include_fonts Whether to include `.ttf` and `.otf` files installed in
#'   the current Windows user's Fonts directory.
#'
#' @return Invisibly, the normalized path to the created archive.
#' @export
#'
#' @examples
#' \dontrun{
#' backup_setup(include_renviron = TRUE)
#' backup_setup("D:/R backups", include_renviron = TRUE)
#' }
backup_setup <- function(output_dir = getwd(), include_renviron = FALSE, include_fonts = TRUE) {
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  computer <- Sys.getenv("COMPUTERNAME", unset = Sys.info()[["nodename"]])
  computer <- gsub("[^A-Za-z0-9._-]", "_", computer)
  archive_name <- sprintf("R-setup-%s-%s.tar.gz", computer, format(Sys.time(), "%Y%m%d-%H%M%S"))
  archive_path <- file.path(output_dir, archive_name)
  stage <- tempfile("Rucksack-backup-")
  dir.create(file.path(stage, "payload"), recursive = TRUE)
  dir.create(file.path(stage, "inventory"), recursive = TRUE)
  on.exit(unlink(stage, recursive = TRUE, force = TRUE), add = TRUE)

  r_user <- get_r_user_files()
  rstudio_dir <- get_rstudio_config_dir()
  manifest <- list(
    schema_version = 4L,
    Rucksack_version = package_version_string(),
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    source_computer = computer,
    source_r_user_home = normalizePath(r_user$home, winslash = "/", mustWork = FALSE),
    source_rstudio_config = normalizePath(rstudio_dir, winslash = "/", mustWork = FALSE),
    renviron_included = isTRUE(include_renviron),
    fonts = NULL,
    items = list()
  )

  add_item <- function(source, archive_relative, destination_key, destination_relative,
                       restore_mode = "replace") {
    if (!file.exists(source) && !dir.exists(source)) return(invisible(FALSE))
    target <- file.path(stage, archive_relative)
    if (!copy_path(source, target)) stop("Could not copy: ", source)

    manifest$items[[length(manifest$items) + 1L]] <<- list(
      archive_path = archive_relative,
      destination_key = destination_key,
      destination_relative = destination_relative,
      item_type = if (dir.exists(source)) "directory" else "file",
      restore_mode = restore_mode,
      source_at_backup = normalizePath(source, winslash = "/", mustWork = FALSE)
    )
    invisible(TRUE)
  }

  add_item(r_user$profile, "payload/home/.Rprofile", "RProfileUser", ".Rprofile")
  if (file.exists(r_user$environ)) {
    if (include_renviron) {
      add_item(r_user$environ, "payload/home/.Renviron", "REnvironUser", ".Renviron")
    } else {
      template <- file.path(stage, "payload", "home", ".Renviron.template")
      dir.create(dirname(template), recursive = TRUE, showWarnings = FALSE)
      redact_renviron(r_user$environ, template)
      manifest$items[[length(manifest$items) + 1L]] <- list(
        archive_path = "payload/home/.Renviron.template",
        destination_key = "RUserHome",
        destination_relative = ".Renviron.template",
        item_type = "file",
        restore_mode = "replace",
        source_at_backup = normalizePath(r_user$environ, winslash = "/", mustWork = FALSE)
      )
    }
  }

  for (item in c("rstudio-prefs.json", "keybindings", "snippets", "themes")) {
    restore_mode <- if (identical(item, "themes")) "merge" else "replace"
    add_item(
      file.path(rstudio_dir, item),
      file.path("payload", "rstudio", item),
      "RStudioConfig",
      item,
      restore_mode
    )
  }

  if (include_fonts && .Platform$OS.type == "windows") {
    user_fonts_dir <- get_user_fonts_dir()
    fonts <- font_files(user_fonts_dir)
    if (length(fonts)) {
      archive_fonts_dir <- file.path(stage, "fonts")
      dir.create(archive_fonts_dir, recursive = TRUE, showWarnings = FALSE)
      copied <- file.copy(fonts, archive_fonts_dir, overwrite = TRUE, copy.mode = TRUE, copy.date = TRUE)
      if (!all(copied)) stop("Could not copy one or more per-user fonts")
      manifest$fonts <- list(
        archive_path = "fonts",
        source_at_backup = normalizePath(user_fonts_dir, winslash = "/", mustWork = FALSE),
        files = basename(fonts)
      )
    }
  }

  provenance_fields <- c(
    "Repository", "RemoteType", "RemoteHost", "RemoteUsername", "RemoteRepo",
    "RemoteSubdir", "RemoteRef", "RemoteSha", "RemoteUrl", "GithubUsername",
    "GithubRepo", "GithubRef", "GithubSHA1", "biocViews"
  )
  packages <- as.data.frame(
    installed.packages(fields = provenance_fields),
    stringsAsFactors = FALSE
  )
  inventory_fields <- c("Package", "Version", "LibPath", "Priority", provenance_fields)
  packages <- packages[, intersect(inventory_fields, names(packages)), drop = FALSE]
  packages$InstallSource <- vapply(
    seq_len(nrow(packages)),
    function(i) package_install_source(packages[i, , drop = FALSE]),
    character(1)
  )
  write.csv(packages, file.path(stage, "inventory", "r-packages.csv"), row.names = FALSE, na = "")
  writeLines(capture.output(sessionInfo()), file.path(stage, "inventory", "r-session-info.txt"))
  writeLines(c(
    paste0("R_USER_HOME=", normalizePath(r_user$home, winslash = "/", mustWork = FALSE)),
    paste0("R_PROFILE_USER=", normalizePath(r_user$profile, winslash = "/", mustWork = FALSE)),
    paste0("R_ENVIRON_USER=", normalizePath(r_user$environ, winslash = "/", mustWork = FALSE)),
    paste0("RSTUDIO_CONFIG=", normalizePath(rstudio_dir, winslash = "/", mustWork = FALSE)),
    paste0("R_HOME=", R.home()),
    paste0("R_LIBS_USER=", Sys.getenv("R_LIBS_USER")),
    paste0("LIB_PATH=", .libPaths())
  ), file.path(stage, "inventory", "r-paths.txt"))

  for (script in c("install_user_fonts.ps1", "load_user_fonts.ps1")) {
    script_source <- system.file("scripts", script, package = "Rucksack")
    if (!nzchar(script_source)) stop("The bundled Windows font script could not be found: ", script)
    if (!file.copy(script_source, file.path(stage, script), overwrite = TRUE)) {
      stop("Could not add the Windows font script to the backup: ", script)
    }
  }
  saveRDS(manifest, file.path(stage, "manifest.rds"), compress = "xz")

  archive_contents <- list.files(stage, all.files = TRUE, no.. = TRUE)
  old_dir <- setwd(stage)
  tryCatch(
    utils::tar(archive_path, files = archive_contents, compression = "gzip", tar = "internal"),
    finally = setwd(old_dir)
  )

  message("Created: ", normalizePath(archive_path, winslash = "/", mustWork = TRUE))
  if (!include_renviron && file.exists(r_user$environ)) {
    warning(".Renviron was saved as a redacted template. The archive is compressed, not encrypted.", call. = FALSE)
  }
  invisible(archive_path)
}
