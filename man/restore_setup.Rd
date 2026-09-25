\name{restore_setup}
\alias{restore_setup}
\title{Restore an R and RStudio Setup}
\usage{
restore_setup(
  archive,
  dry_run = FALSE,
  restore_rstudio = TRUE,
  restore_fonts = TRUE,
  install_packages = FALSE,
  repos = "https://cloud.r-project.org"
)
}
\arguments{
\item{archive}{Path to a backup created by \code{backup_setup()}.}
\item{dry_run}{Whether to report proposed actions without changing anything.}
\item{restore_rstudio}{Whether RStudio settings should be restored.}
\item{restore_fonts}{Whether per-user Windows fonts should be restored.}
\item{install_packages}{Whether packages missing from the current R library should be installed from their recorded CRAN, Bioconductor, or GitHub source. Current versions are installed; historical versions are not pinned.}
\item{repos}{CRAN-compatible repository used when installing packages.}
}
\value{Invisibly, the backup manifest.}
\description{
Restores user-level R configuration, RStudio settings and themes, and
optionally per-user Windows fonts and missing R packages. Existing files are
preserved in a dated directory under the destination R user home.
}
\details{
On Windows, fonts are copied to the current user's Fonts directory, registered
under HKCU, loaded with \code{AddFontResource()}, and announced with
\code{WM_FONTCHANGE}. A persistent loader is installed at
\file{\%LOCALAPPDATA\%/Rucksack/scripts/load_user_fonts.ps1}, and the
current-user Startup shortcut \file{Load User Fonts.lnk} runs it after each
login. The loader is also run immediately during restoration. None of these
actions occur during a dry run. The system Fonts directory is not modified,
and administrator rights are not required.

When package installation is requested, Rucksack uses \code{install.packages()}
for CRAN packages, \code{BiocManager::install()} for Bioconductor packages,
and \code{remotes::install_github()} for GitHub packages. GitHub packages are
installed from the current default branch rather than the recorded commit SHA.
}
\examples{
\dontrun{
restore_setup("R-setup-COMPUTER-20260918-120000.tar.gz", dry_run = TRUE)
restore_setup("R-setup-COMPUTER-20260918-120000.tar.gz")
}
}
