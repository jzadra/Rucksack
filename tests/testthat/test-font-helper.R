test_that("font installer performs per-user installation and persistence setup", {
  installer <- system.file("scripts", "install_user_fonts.ps1", package = "Rucksack")
  contents <- paste(readLines(installer, warn = FALSE), collapse = "\n")

  expect_match(contents, "Microsoft\\Windows\\Fonts", fixed = TRUE)
  expect_match(contents, "HKCU:", fixed = TRUE)
  expect_match(contents, "Rucksack\\scripts", fixed = TRUE)
  expect_match(contents, "load_user_fonts.ps1", fixed = TRUE)
  expect_match(contents, "GetFolderPath('Startup')", fixed = TRUE)
  expect_match(contents, "Load User Fonts.lnk", fixed = TRUE)
  expect_match(contents, "-ExecutionPolicy Bypass", fixed = TRUE)
  expect_false(grepl("C:\\\\Windows\\\\Fonts", contents, ignore.case = TRUE))
})

test_that("persistent font loader loads fonts and broadcasts WM_FONTCHANGE", {
  loader <- system.file("scripts", "load_user_fonts.ps1", package = "Rucksack")
  contents <- paste(readLines(loader, warn = FALSE), collapse = "\n")

  expect_match(contents, "Microsoft\\Windows\\Fonts", fixed = TRUE)
  expect_match(contents, "'.ttf', '.otf'", fixed = TRUE)
  expect_match(contents, "AddFontResource", fixed = TRUE)
  expect_match(contents, "SendMessageTimeout", fixed = TRUE)
  expect_match(contents, "0x001D", fixed = TRUE)
  expect_false(grepl("C:\\\\Windows\\\\Fonts", contents, ignore.case = TRUE))
})
