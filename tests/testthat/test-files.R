test_that("copy_path overwrites files", {
  directory <- tempfile("Rucksack-test-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  source <- file.path(directory, "source.txt")
  destination <- file.path(directory, "destination.txt")
  writeLines("new", source)
  writeLines("old", destination)

  expect_true(Rucksack:::copy_path(source, destination, overwrite = TRUE))
  expect_equal(readLines(destination), "new")
})

test_that("copy_path recursively copies directories", {
  directory <- tempfile("Rucksack-test-")
  source <- file.path(directory, "source")
  destination <- file.path(directory, "destination")
  dir.create(file.path(source, "nested"), recursive = TRUE)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  writeLines("content", file.path(source, "nested", "file.txt"))

  expect_true(Rucksack:::copy_path(source, destination))
  expect_equal(readLines(file.path(destination, "nested", "file.txt")), "content")
})

test_that("font_files returns only supported font files", {
  directory <- tempfile("Rucksack-fonts-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  file.create(file.path(directory, c("regular.ttf", "bold.OTF", "notes.txt")))

  expect_setequal(
    basename(Rucksack:::font_files(directory)),
    c("regular.ttf", "bold.OTF")
  )
})
