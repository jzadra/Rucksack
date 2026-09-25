test_that("package provenance identifies GitHub installations", {
  package <- data.frame(
    RemoteType = "github",
    RemoteUsername = "r-lib",
    RemoteRepo = "remotes",
    stringsAsFactors = FALSE
  )

  expect_equal(Rucksack:::package_install_source(package), "GitHub")
  expect_equal(Rucksack:::package_field(package, "RemoteUsername"), "r-lib")
})

test_that("legacy GitHub metadata is recognized", {
  package <- data.frame(
    GithubUsername = "r-lib",
    GithubRepo = "remotes",
    stringsAsFactors = FALSE
  )

  expect_equal(Rucksack:::package_install_source(package), "GitHub")
})

test_that("GitHub URLs can supply missing owner and repository fields", {
  package <- data.frame(
    RemoteUrl = "https://github.com/r-lib/remotes.git",
    stringsAsFactors = FALSE
  )

  expect_equal(Rucksack:::package_install_source(package), "GitHub")
  expect_equal(
    Rucksack:::package_github_coordinates(package),
    c(username = "r-lib", repository = "remotes")
  )
})

test_that("Bioconductor and CRAN packages are distinguished", {
  bioconductor_package <- data.frame(
    Repository = "Bioconductor",
    biocViews = "Software",
    stringsAsFactors = FALSE
  )
  cran_package <- data.frame(
    Repository = "CRAN",
    stringsAsFactors = FALSE
  )

  expect_equal(Rucksack:::package_install_source(bioconductor_package), "Bioconductor")
  expect_equal(Rucksack:::package_install_source(cran_package), "CRAN")
})

test_that("missing provenance falls back to CRAN", {
  package <- data.frame(Package = "example", stringsAsFactors = FALSE)
  expect_equal(Rucksack:::package_install_source(package), "CRAN")
})
