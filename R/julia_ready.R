#' Ensure Julia and required Julia packages are ready
#'
#' Performs the steps needed to make Julia and a set of Julia packages
#' callable from R via JuliaConnectoR:
#'
#' 1. Locates the Julia binary (see [julia_bin()]).
#' 2. For each required package, checks it loads in a Julia subprocess.
#'    If a package is missing and `install = TRUE`, installs it (from a
#'    GitHub URL if listed in `github`, otherwise from the General
#'    registry). Subprocess work avoids any interaction with the running
#'    JuliaConnectoR server.
#' 3. Starts (or attaches to) the JuliaConnectoR server.
#' 4. Loads each package via `juliaEval("using <pkg>")`, so dotted
#'    constructor names like `EpiBranch.NegBin` resolve correctly.
#'
#' Idempotent: if `state_env$ready` is already `TRUE`, returns immediately.
#'
#' @param packages Character vector of Julia package names to ensure are
#'   loaded (e.g. `c("EpiBranch", "Distributions")`).
#' @param github Named character vector of GitHub URLs for packages not in
#'   the General registry. Names must match entries in `packages`. Values
#'   may be a full URL, an `"owner/repo"` shorthand, or `"owner/repo:subdir"`.
#' @param state_env An environment used to track initialisation state. The
#'   caller (typically a wrapping R package) supplies its own environment
#'   so multiple consuming packages do not interfere with each other.
#' @param install If `FALSE`, fail rather than installing missing packages.
#' @param verbose If `TRUE`, print progress messages.
#' @return Invisibly `TRUE`.
#' @export
#' @examples
#' \dontrun{
#' .my_pkg_env <- new.env(parent = emptyenv())
#' julia_ready(
#'   packages = c("EpiBranch", "Distributions", "Random"),
#'   github   = c(EpiBranch = "epiforecasts/EpiBranch.jl"),
#'   state_env = .my_pkg_env
#' )
#' }
julia_ready <- function(packages,
                        github = character(),
                        state_env = new.env(parent = emptyenv()),
                        install = TRUE,
                        verbose = TRUE) {
  if (isTRUE(state_env$ready)) return(invisible(TRUE))

  bin <- julia_bin()
  if (!nzchar(bin) || !file.exists(bin)) {
    stop("Julia not found. Install Julia (juliaup recommended: ",
         "https://github.com/JuliaLang/juliaup) or set JULIA_BINDIR.",
         call. = FALSE)
  }

  installed_anything <- FALSE
  for (pkg in packages) {
    code <- sprintf("using %s", pkg)
    ok <- julia_subprocess(code, check = FALSE, bin = bin)
    if (!ok) {
      if (!install) {
        stop("Julia package '", pkg, "' is not installed and ",
             "install = FALSE.", call. = FALSE)
      }
      if (verbose) message("Installing Julia package: ", pkg, " ...")
      install_code <- .install_code(pkg, github)
      julia_subprocess(install_code, bin = bin)
      installed_anything <- TRUE
    }
  }

  # After fresh installs of large dependency trees, Julia's depot can be
  # in a state where the next `using` does heavy precompile work. Run a
  # subprocess `Pkg.precompile()` once so the JuliaConnectoR server
  # doesn't spend its first call doing it.
  if (installed_anything) {
    if (verbose) message("Precompiling Julia depot...")
    julia_subprocess("import Pkg; Pkg.precompile()", bin = bin)
  }

  # Tell JuliaConnectoR which Julia binary to use, then load packages.
  Sys.setenv(JULIACONNECTOR_JULIABIN = bin)
  for (pkg in packages) {
    JuliaConnectoR::juliaEval(sprintf("using %s", pkg))
  }

  state_env$ready <- TRUE
  invisible(TRUE)
}

#' Build the Julia code to install a package, registry or GitHub.
#' @noRd
.install_code <- function(pkg, github) {
  if (pkg %in% names(github)) {
    spec <- github[[pkg]]
    if (startsWith(spec, "http://") || startsWith(spec, "https://")) {
      url <- spec
      subdir <- NULL
    } else if (grepl(":", spec)) {
      parts <- strsplit(spec, ":", fixed = TRUE)[[1]]
      url <- paste0("https://github.com/", parts[1])
      subdir <- parts[2]
    } else {
      url <- paste0("https://github.com/", spec)
      subdir <- NULL
    }
    pkgspec <- if (is.null(subdir)) {
      sprintf('Pkg.PackageSpec(url="%s")', url)
    } else {
      sprintf('Pkg.PackageSpec(url="%s", subdir="%s")', url, subdir)
    }
    sprintf('import Pkg; Pkg.add(%s); using %s', pkgspec, pkg)
  } else {
    sprintf('import Pkg; Pkg.add("%s"); using %s', pkg, pkg)
  }
}
