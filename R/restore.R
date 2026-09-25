#' Preview restoration of an R and RStudio setup
#'
#' Reports the files, themes, fonts, and optional packages that would be
#' restored without changing the destination computer.
#'
#' @param archive Path to a backup created by [backup_setup()].
#' @param restore_rstudio Whether RStudio settings should be restored.
#' @param restore_fonts Whether per-user Windows fonts should be restored.
#' @param install_packages Whether missing packages should be reported by their
#'   recorded installation source.
#' @param repos Repository used to determine the requested package installation.
#'
#' @return Invisibly, the backup manifest.
#' @export
#'
#' @examples
#' \dontrun{
#' preview_restore("R-setup-COMPUTER-20260918-120000.tar.gz")
#' }
preview_restore <- function(archive, restore_rstudio = TRUE, restore_fonts = TRUE,
                            install_packages = FALSE, repos = "https://cloud.r-project.org") {
  restore_setup(
    archive = archive,
    dry_run = TRUE,
    restore_rstudio = restore_rstudio,
    restore_fonts = restore_fonts,
    install_packages = install_packages,
    repos = repos
  )
}

#' Restore an R and RStudio setup
#'
#' Restores user-level R configuration, RStudio settings and themes, and
#' optionally per-user Windows fonts and missing R packages. Existing files
#' are preserved in a dated directory under the destination R user home.
#'
#' @param archive Path to a backup created by [backup_setup()].
#' @param dry_run Whether to report proposed actions without changing anything.
#' @param restore_rstudio Whether RStudio settings should be restored.
#' @param restore_fonts Whether per-user Windows fonts should be restored.
#' @param install_packages Whether packages missing from the current R library
#'   should be installed from their recorded CRAN, Bioconductor, or GitHub
#'   source. Current versions are installed; historical versions are not pinned.
#' @param repos CRAN-compatible repository used when installing packages.
#'
#' @return Invisibly, the backup manifest.
#' @export
#'
#' @examples
#' \dontrun{
#' restore_setup("R-setup-COMPUTER-20260918-120000.tar.gz", dry_run = TRUE)
#' restore_setup("R-setup-COMPUTER-20260918-120000.tar.gz")
#' }
restore_setup <- function(archive, dry_run = FALSE, restore_rstudio = TRUE,
                          restore_fonts = TRUE, install_packages = FALSE,
                          repos = "https://cloud.r-project.org") {
  archive <- normalizePath(archive, winslash = "/", mustWork = TRUE)
  extract_dir <- tempfile("Rucksack-restore-")
  dir.create(extract_dir, recursive = TRUE)
  on.exit(unlink(extract_dir, recursive = TRUE, force = TRUE), add = TRUE)
  extract_backup(archive, extract_dir)

  manifest_path <- file.path(extract_dir, "manifest.rds")
  if (!file.exists(manifest_path)) stop("This archive does not contain manifest.rds")
  manifest <- readRDS(manifest_path)
  r_user <- get_r_user_files()
  backup_dir <- file.path(r_user$home, paste0("R-setup-pre-restore-", format(Sys.time(), "%Y%m%d-%H%M%S")))

  resolve_destination <- function(item) {
    switch(
      item$destination_key,
      RUserHome = file.path(r_user$home, item$destination_relative),
      RProfileUser = r_user$profile,
      REnvironUser = r_user$environ,
      RStudioConfig = file.path(get_rstudio_config_dir(), item$destination_relative),
      NULL
    )
  }

  for (item in manifest$items) {
    if (!restore_rstudio && identical(item$destination_key, "RStudioConfig")) next
    destination <- resolve_destination(item)
    if (is.null(destination)) {
      warning("Unknown destination key skipped: ", item$destination_key, call. = FALSE)
      next
    }

    source <- file.path(extract_dir, item$archive_path)
    if (!file.exists(source) && !dir.exists(source)) {
      warning("Missing archive item skipped: ", item$archive_path, call. = FALSE)
      next
    }

    message(if (dry_run) "Would restore: " else "Restoring: ", destination)
    if (dry_run) next

    if (file.exists(destination) || dir.exists(destination)) {
      previous <- file.path(backup_dir, item$destination_key, item$destination_relative)
      if (!copy_path(destination, previous)) stop("Could not preserve existing item: ", destination)
    }

    restore_mode <- item$restore_mode
    if (is.null(restore_mode)) restore_mode <- "replace"
    source_is_dir <- dir.exists(source)
    if (source_is_dir && file.exists(destination) && !dir.exists(destination)) unlink(destination, force = TRUE)
    if (!source_is_dir && dir.exists(destination)) unlink(destination, recursive = TRUE, force = TRUE)
    if (source_is_dir && identical(restore_mode, "replace") && dir.exists(destination)) {
      unlink(destination, recursive = TRUE, force = TRUE)
    }
    if (!copy_path(source, destination, overwrite = TRUE)) stop("Could not restore: ", destination)
  }

  restore_backup_fonts(
    extract_dir = extract_dir,
    backup_dir = backup_dir,
    dry_run = dry_run,
    restore_fonts = restore_fonts
  )

  if (install_packages) restore_backup_packages(extract_dir, dry_run, repos)

  if (!dry_run && dir.exists(backup_dir)) {
    message("Previous files: ", normalizePath(backup_dir, winslash = "/"))
  }
  invisible(manifest)
}

restore_backup_fonts <- function(extract_dir, backup_dir, dry_run, restore_fonts) {
  source_dir <- file.path(extract_dir, "fonts")
  fonts <- font_files(source_dir)
  if (!restore_fonts || !length(fonts)) return(invisible(FALSE))

  destination_dir <- get_user_fonts_dir()
  loader_destination <- get_font_loader_path()
  shortcut_destination <- get_startup_shortcut_path()
  if (dry_run) {
    message("Would copy ", length(fonts), " per-user font(s) to: ", destination_dir)
    for (font in fonts) message("  ", basename(font))
    message("Would register the fonts under: HKCU\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts")
    message("Would install the persistent font loader: ", loader_destination)
    message("Would create the current-user Startup shortcut: ", shortcut_destination)
    message("Would run the loader now using AddFontResource() and broadcast WM_FONTCHANGE")
    return(invisible(TRUE))
  }

  if (.Platform$OS.type != "windows") {
    warning("The archive contains Windows per-user fonts, but font installation was skipped on this operating system.", call. = FALSE)
    return(invisible(FALSE))
  }

  for (font in fonts) {
    existing <- file.path(destination_dir, basename(font))
    if (file.exists(existing)) {
      preserved <- file.path(backup_dir, "WindowsUserFonts", basename(font))
      if (!copy_path(existing, preserved)) stop("Could not preserve existing font: ", existing)
    }
  }

  persistent_files <- c(
    loader = loader_destination,
    startup_shortcut = shortcut_destination
  )
  for (item in names(persistent_files)) {
    existing <- persistent_files[[item]]
    if (file.exists(existing)) {
      preserved <- file.path(backup_dir, "RucksackFontLoader", item, basename(existing))
      if (!copy_path(existing, preserved)) stop("Could not preserve existing font-loader file: ", existing)
    }
  }

  helper <- file.path(extract_dir, "install_user_fonts.ps1")
  loader_source <- file.path(extract_dir, "load_user_fonts.ps1")
  if (!file.exists(helper) || !file.exists(loader_source)) {
    helper <- system.file("scripts", "install_user_fonts.ps1", package = "Rucksack")
    loader_source <- system.file("scripts", "load_user_fonts.ps1", package = "Rucksack")
  }
  if (!nzchar(helper) || !file.exists(helper)) stop("The per-user font installer could not be found")
  if (!nzchar(loader_source) || !file.exists(loader_source)) stop("The persistent font loader could not be found")
  powershell <- Sys.which("powershell.exe")
  if (!nzchar(powershell)) stop("powershell.exe was not found; per-user fonts could not be installed")
  status <- system2(
    powershell,
    args = c(
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", shQuote(helper),
      "-FontSourceDirectory", shQuote(source_dir),
      "-LoaderSource", shQuote(loader_source)
    )
  )
  if (status != 0L) stop("The per-user font installer failed with exit status ", status)
  invisible(TRUE)
}

restore_backup_packages <- function(extract_dir, dry_run, repos) {
  package_file <- file.path(extract_dir, "inventory", "r-packages.csv")
  if (!file.exists(package_file)) return(invisible(FALSE))

  packages <- read.csv(package_file, stringsAsFactors = FALSE)
  if ("Priority" %in% names(packages)) {
    packages <- packages[is.na(packages$Priority) | packages$Priority == "", , drop = FALSE]
  }
  packages <- packages[!duplicated(packages$Package), , drop = FALSE]
  packages <- packages[!packages$Package %in% rownames(installed.packages()), , drop = FALSE]
  if (!nrow(packages)) return(invisible(TRUE))

  packages$InstallSource <- vapply(
    seq_len(nrow(packages)),
    function(i) package_install_source(packages[i, , drop = FALSE]),
    character(1)
  )

  if (dry_run) {
    report_package_restore(packages)
    return(invisible(TRUE))
  }

  cran_packages <- packages$Package[packages$InstallSource == "CRAN"]
  unsupported <- !packages$InstallSource %in% c("CRAN", "Bioconductor", "GitHub")
  if (any(unsupported)) {
    warning(
      "No supported remote installer was recorded for: ",
      paste(packages$Package[unsupported], collapse = ", "),
      ". Rucksack will try the configured CRAN-compatible repository.",
      call. = FALSE
    )
    cran_packages <- c(cran_packages, packages$Package[unsupported])
  }
  if (length(cran_packages)) install.packages(unique(cran_packages), repos = repos)

  bioc_packages <- packages$Package[packages$InstallSource == "Bioconductor"]
  if (length(bioc_packages)) install_bioconductor_packages(bioc_packages, repos)

  github_packages <- packages[packages$InstallSource == "GitHub", , drop = FALSE]
  if (nrow(github_packages)) install_github_packages(github_packages, repos)
  invisible(TRUE)
}

report_package_restore <- function(packages) {
  cran_packages <- packages$Package[packages$InstallSource == "CRAN"]
  if (length(cran_packages)) {
    message("Would install current CRAN versions: ", paste(cran_packages, collapse = ", "))
  }

  bioc_packages <- packages$Package[packages$InstallSource == "Bioconductor"]
  if (length(bioc_packages)) {
    message("Would install current Bioconductor versions: ", paste(bioc_packages, collapse = ", "))
  }

  github_packages <- packages[packages$InstallSource == "GitHub", , drop = FALSE]
  if (nrow(github_packages)) {
    message("Would install current versions from GitHub default branches:")
    for (i in seq_len(nrow(github_packages))) {
      github <- package_github_coordinates(github_packages[i, , drop = FALSE])
      subdir <- package_field(github_packages[i, , drop = FALSE], "RemoteSubdir")
      remote <- paste0(github[["username"]], "/", github[["repository"]])
      if (nzchar(subdir)) remote <- paste0(remote, "/", subdir)
      message("  ", github_packages$Package[i], ": ", remote)
    }
  }

  unsupported <- !packages$InstallSource %in% c("CRAN", "Bioconductor", "GitHub")
  if (any(unsupported)) {
    message(
      "Would try the configured CRAN-compatible repository for packages with unsupported recorded remotes: ",
      paste(packages$Package[unsupported], collapse = ", ")
    )
  }
}

install_github_packages <- function(packages, repos) {
  if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes", repos = repos)
  if (!requireNamespace("remotes", quietly = TRUE)) {
    warning("The remotes package could not be installed; GitHub packages were skipped.", call. = FALSE)
    return(invisible(FALSE))
  }

  for (i in seq_len(nrow(packages))) {
    package <- packages[i, , drop = FALSE]
    github <- package_github_coordinates(package)
    if (!nzchar(github[["username"]]) || !nzchar(github[["repository"]])) {
      warning("GitHub provenance is incomplete for ", package$Package, "; the package was skipped.", call. = FALSE)
      next
    }

    arguments <- list(
      repo = paste0(github[["username"]], "/", github[["repository"]]),
      upgrade = "never"
    )
    subdir <- package_field(package, "RemoteSubdir")
    host <- package_field(package, "RemoteHost")
    if (nzchar(subdir)) arguments$subdir <- subdir
    if (nzchar(host)) arguments$host <- host

    tryCatch(
      do.call(remotes::install_github, arguments),
      error = function(error) {
        warning("Could not install GitHub package ", package$Package, ": ", conditionMessage(error), call. = FALSE)
      }
    )
  }
  invisible(TRUE)
}

install_bioconductor_packages <- function(packages, repos) {
  if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager", repos = repos)
  if (!requireNamespace("BiocManager", quietly = TRUE)) {
    warning("BiocManager could not be installed; Bioconductor packages were skipped.", call. = FALSE)
    return(invisible(FALSE))
  }

  tryCatch(
    BiocManager::install(packages, ask = FALSE, update = FALSE),
    error = function(error) {
      warning("Could not install one or more Bioconductor packages: ", conditionMessage(error), call. = FALSE)
    }
  )
  invisible(TRUE)
}
