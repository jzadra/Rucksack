# Rucksack 0.3.0

- Added package installation provenance to the backup inventory.
- Added source-aware restoration for CRAN, Bioconductor, and GitHub packages.
- GitHub restoration uses the repository's current default branch rather than the backed-up commit.
- Added source-specific package reporting during dry runs.

# Rucksack 0.2.0

- Added a persistent per-user Windows font loader.
- Added the current-user Startup shortcut `Load User Fonts.lnk`.
- Restores font availability immediately and after subsequent Windows logins.
- Expanded dry-run reporting to cover file copying, registry changes, font loading, `WM_FONTCHANGE`, loader installation, and Startup shortcut creation.
- Retained compatibility with older backups that do not contain the persistent loader.

# Rucksack 0.1.0

- Initial package release.
- Added portable R and RStudio configuration backups.
- Added custom RStudio theme backup and restoration.
- Added non-administrator Windows per-user font backup, registration, loading, and font-change notification.
