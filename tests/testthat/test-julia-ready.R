test_that("julia_ready is a no-op when state is already ready", {
  env <- new.env(parent = emptyenv())
  env$ready <- TRUE
  # Should not touch Julia at all
  expect_silent(julia_ready(packages = "Distributions", state_env = env,
                            verbose = FALSE))
})

test_that("julia_ready loads Distributions in a fresh state_env", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  env <- new.env(parent = emptyenv())
  julia_ready(packages = c("Distributions", "Random"),
              state_env = env, verbose = FALSE)
  expect_true(isTRUE(env$ready))
  # Verify packages are actually loaded
  expect_equal(JuliaCall::julia_eval("isdefined(Main, :Distributions)"), TRUE)
})
