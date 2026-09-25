\name{backup_setup}
\alias{backup_setup}
\title{Back Up an R and RStudio Setup}
\usage{
backup_setup(output_dir = getwd(), include_renviron = FALSE, include_fonts = TRUE)
}
\arguments{
\item{output_dir}{Directory in which to create the backup archive.}
\item{include_renviron}{Whether to include the original \file{.Renviron}. When false, a template is included with likely secrets redacted.}
\item{include_fonts}{Whether to include \file{.ttf} and \file{.otf} files installed in the current Windows user's Fonts directory.}
}
\value{Invisibly, the normalized path to the created archive.}
\description{
Creates a compressed archive containing user-level R configuration, RStudio
settings, custom themes, a source-aware installed-package inventory, and
optionally per-user Windows fonts.
}
\details{
The resulting archive is compressed but is not encrypted. An unredacted
\file{.Renviron} may contain credentials and should be stored securely.
}
\examples{
\dontrun{
backup_setup(include_renviron = TRUE)
backup_setup("D:/R backups", include_renviron = TRUE)
}
}
