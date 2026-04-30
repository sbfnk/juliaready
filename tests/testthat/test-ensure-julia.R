test_that("ensure_julia calls init_fn when state is not ready", {
  env <- new.env(parent = emptyenv())
  called <- 0L
  init <- function() {
    called <<- called + 1L
    env$ready <- TRUE
  }
  ensure_julia(env, init)
  expect_equal(called, 1L)
})

test_that("ensure_julia is a no-op when already ready", {
  env <- new.env(parent = emptyenv())
  env$ready <- TRUE
  called <- 0L
  init <- function() {
    called <<- called + 1L
  }
  ensure_julia(env, init)
  expect_equal(called, 0L)
})

test_that("ensure_julia returns invisibly", {
  env <- new.env(parent = emptyenv())
  env$ready <- TRUE
  expect_invisible(ensure_julia(env, function() NULL))
})
