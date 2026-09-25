# Rucksack

<img src="man/figures/logo.png" align="right" height="139" alt="Rucksack logo" />

[![R-CMD-check](https://github.com/jzadra/Rucksack/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/jzadra/Rucksack/actions/workflows/R-CMD-check.yaml)

`Rucksack` carries a user-level R and RStudio setup between computers.

Install the local source package with:

```r
install.packages("Rucksack_0.3.0.tar.gz", repos = NULL, type = "source")
```

Rtools is not required because the package contains no compiled R code.

Install the development version from GitHub with:

```r
remotes::install_github("jzadra/Rucksack")
```

```r
Rucksack::backup_setup(include_renviron = TRUE)
```

```r
Rucksack::preview_restore("R-setup-COMPUTER-20260918-120000.tar.gz")
Rucksack::restore_setup("R-setup-COMPUTER-20260918-120000.tar.gz")
```

To preview and then install packages missing from the destination system:

```r
Rucksack::preview_restore(
  "R-setup-COMPUTER-20260918-120000.tar.gz",
  install_packages = TRUE
)

Rucksack::restore_setup(
  "R-setup-COMPUTER-20260918-120000.tar.gz",
  install_packages = TRUE
)
```

Rucksack records available installation provenance. Missing CRAN packages are
installed from the configured repository, Bioconductor packages through
`BiocManager`, and GitHub packages from their recorded owner and repository.
Restoration installs the current available version rather than the backed-up
version or GitHub commit.

Close RStudio and perform the actual restore from a plain R session so RStudio
does not overwrite newly restored preferences when it exits.

Backups can contain:

- `.Rprofile` and `.Renviron`
- RStudio preferences, snippets, keybindings, and custom themes
- Actual per-user Windows `.ttf` and `.otf` font files
- An installed-package inventory and R session information
- The Windows font installer and persistent font loader

On Windows, fonts are restored to `%LOCALAPPDATA%\Microsoft\Windows\Fonts`, registered under HKCU, loaded into the active font table, and announced with `WM_FONTCHANGE`. Rucksack installs the persistent loader at `%LOCALAPPDATA%\Rucksack\scripts\load_user_fonts.ps1` and creates the current-user Startup shortcut `Load User Fonts.lnk`, ensuring the fonts are loaded again after each login. Administrator rights are not required and `C:\Windows\Fonts` is never modified.

A backup containing an unredacted `.Renviron` may contain credentials. The archive is compressed, not encrypted.
