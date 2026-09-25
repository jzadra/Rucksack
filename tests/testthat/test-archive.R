test_that("safe archive members are accepted", {
  expect_invisible(Rucksack:::validate_archive_members(c(
    "manifest.rds",
    "payload/home/.Rprofile",
    "payload/rstudio/themes/custom.rstheme"
  )))
})

test_that("unsafe archive members are rejected", {
  expect_error(Rucksack:::validate_archive_members("../outside.txt"), "unsafe archive path")
  expect_error(Rucksack:::validate_archive_members("C:/outside.txt"), "unsafe archive path")
  expect_error(Rucksack:::validate_archive_members("/outside.txt"), "unsafe archive path")
})
