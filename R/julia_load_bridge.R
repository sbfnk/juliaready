#' Load Julia bridge (.jl) files from a package's `inst/julia/` directory
#'
#' Reads each file as a single string, wraps it in `begin ... end`, and
#' evaluates via `JuliaCall::julia_eval()`. The `begin ... end` wrapper
#' avoids a `julia_eval` failure mode where multiple top-level
#' `function ... end` blocks in one string can crash R, and avoids
#' Julia's `include()` world-age issues that have been observed when
#' loading user-supplied `.jl` files via JuliaCall.
#'
#' Files are looked up via `system.file("julia", file, package = package)`,
#' so they must live under `inst/julia/` of the calling package.
#'
#' @param package Name of the calling R package (used as the `package`
#'   argument to `system.file()`).
#' @param files Character vector of `.jl` filenames (no directory).
#' @param verbose If `TRUE`, print a message per loaded file.
#' @return Invisibly the character vector of paths that were loaded.
#' @export
#' @examples
#' \dontrun{
#' julia_load_bridge("ringbpjl",
#'   c("dist_lookup.jl", "simulate.jl", "generation_time.jl"))
#' }
julia_load_bridge <- function(package, files, verbose = FALSE) {
  loaded <- character()
  for (f in files) {
    path <- system.file("julia", f, package = package)
    if (!nzchar(path) || !file.exists(path)) {
      stop("Bridge file not found: inst/julia/", f,
           " in package '", package, "'", call. = FALSE)
    }
    if (verbose) message("Loading Julia bridge: ", f)
    code <- paste(readLines(path), collapse = "\n")
    JuliaCall::julia_eval(paste0("begin\n", code, "\nend"))
    loaded <- c(loaded, path)
  }
  invisible(loaded)
}
