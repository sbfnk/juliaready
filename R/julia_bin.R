#' Find the Julia binary that JuliaCall would use
#'
#' Resolves the Julia binary without starting JuliaCall, so it can be
#' used to run subprocess work (precompile, install) that should target
#' the same Julia depot JuliaCall will subsequently use.
#'
#' Detection order:
#'   1. `JuliaCall:::julia_locate()` — JuliaCall's own logic, which honours
#'      `JULIA_HOME` and discovery via `juliaup` / PATH.
#'   2. `Sys.which("julia")` — fallback to PATH.
#'
#' This matters on systems with multiple Julia installations (e.g. a
#' homebrew Julia in PATH alongside a juliaup-managed one). Using
#' `Sys.which()` alone may return the wrong one.
#'
#' @return Absolute path to the Julia executable, or `""` if not found.
#' @export
julia_bin <- function() {
  bindir <- tryCatch(JuliaCall:::julia_locate(), error = function(e) NULL)
  if (!is.null(bindir) && nzchar(bindir)) {
    exe <- if (.Platform$OS.type == "windows") "julia.exe" else "julia"
    bin <- file.path(bindir, exe)
    if (file.exists(bin)) return(bin)
  }
  Sys.which("julia")
}

#' Run a Julia command in a subprocess
#'
#' Uses `julia --startup-file=no -e <code>` against the Julia binary
#' returned by [julia_bin()]. Returning to a subprocess (rather than
#' calling JuliaCall::julia_eval()) is what lets us safely trigger
#' package installation and precompilation without risking the
#' JuliaCall + stale-cache segfault.
#'
#' @param code Julia code to evaluate.
#' @param check If `TRUE`, error on non-zero exit. If `FALSE`, return
#'   `TRUE`/`FALSE` for success/failure.
#' @param bin Julia binary path; defaults to [julia_bin()].
#' @return When `check = FALSE`, a logical. When `check = TRUE`, invisible
#'   `TRUE` on success (errors otherwise).
#' @noRd
julia_subprocess <- function(code, check = TRUE, bin = julia_bin()) {
  if (!nzchar(bin) || !file.exists(bin)) {
    stop("Julia not found. Install Julia (juliaup recommended: ",
         "https://github.com/JuliaLang/juliaup) or set JULIA_HOME.",
         call. = FALSE)
  }
  # R sets LD_LIBRARY_PATH (or DYLD_LIBRARY_PATH on macOS) to point at its
  # own libR / libstdc++ / BLAS, and these inherit into subprocesses. Julia
  # picks them up and segfaults during heavy work like Pkg.precompile().
  # Strip these for the subprocess call and restore afterwards.
  poison_vars <- c("LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH", "DYLD_FALLBACK_LIBRARY_PATH")
  saved <- vapply(poison_vars, function(v) Sys.getenv(v, unset = NA),
                  character(1))
  on.exit({
    for (v in poison_vars) {
      old <- saved[[v]]
      if (is.na(old)) {
        Sys.unsetenv(v)
      } else {
        do.call(Sys.setenv, setNames(list(old), v))
      }
    }
  }, add = TRUE)
  for (v in poison_vars) Sys.unsetenv(v)

  res <- suppressWarnings(system2(
    bin,
    args = c("--startup-file=no", "-e", shQuote(code)),
    stdout = if (check) "" else FALSE,
    stderr = if (check) "" else FALSE
  ))
  status <- if (is.numeric(res)) res else attr(res, "status")
  ok <- is.null(status) || status == 0
  if (check && !ok) {
    stop("Julia subprocess failed (exit ", status, "). Code:\n", code,
         call. = FALSE)
  }
  if (check) invisible(TRUE) else ok
}
