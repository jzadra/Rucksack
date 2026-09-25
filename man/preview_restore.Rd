\name{preview_restore}
\alias{preview_restore}
\title{Preview Restoration of an R and RStudio Setup}
\usage{
preview_restore(
  archive,
  restore_rstudio = TRUE,
  restore_fonts = TRUE,
  install_packages = FALSE,
  repos = "https://cloud.r-project.org"
)
}
\arguments{
\item{archive}{Path to a backup created by \code{backup_setup()}.}
\item{restore_rstudio}{Whether RStudio settings should be restored.}
\item{restore_fonts}{Whether per-user Windows fonts should be restored.}
\item{install_packages}{Whether missing packages should be reported by their recorded installation source.}
\item{repos}{Repository used for the requested package installation.}
}
\value{Invisibly, the backup manifest.}
\description{
Reports the files, themes, fonts, and optional packages that would be restored
without changing the destination computer.
}
\examples{
\dontrun{
preview_restore("R-setup-COMPUTER-20260918-120000.tar.gz")
}
}
