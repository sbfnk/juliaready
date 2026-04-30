test_that("eval_julia evaluates and converts simple expressions", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  expect_equal(eval_julia("1 + 1"), 2)
  expect_equal(eval_julia('"hello"'), "hello")
})

test_that("call_julia invokes Julia functions", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  expect_equal(call_julia("+", 2L, 3L), 5L)
})

test_that("import_julia returns a callable proxy", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  Base <- import_julia("Base")
  # Base.length on a vector
  expect_equal(call_julia("Base.length", 1:5), 5L)
})
