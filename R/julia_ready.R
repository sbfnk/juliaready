#' Ensure Julia and required Julia packages are ready
#'
#' Performs the steps needed to make Julia and a set of Julia packages
#' loadable from R via JuliaCall. Specifically:
#'
#' 1. Locates the Julia binary (see [julia_bin()]).
#' 2. For each required package, checks it loads in a Julia subprocess.
#'    If a package is missing and `install = TRUE`, installs it (from a
#'    GitHub URL if listed in `github`, otherwise from the General
#'    registry). Any precompilation triggered by `using <pkg>` happens
#'    in the subprocess, avoiding the segfault that occurs when
#'    JuliaCall's embedded Julia tries to precompile a stale or missing
#'    cache.
#' 3. Initialises JuliaCall (`JuliaCall::julia_setup()`).
#' 4. Loads each package via JuliaCall (now safe because caches are warm).
#'
#' Idempotent: if `state_env$ready` is already `TRUE`, returns immediately.
#'
#' @param packages Character vector of Julia package names to ensure are
#'   loaded (e.g. `c("EpiBranch", "Distributions")`).
#' @param github Named character vector of GitHub URLs for packages not in
#'   the General registry. Names must match entries in `packages`. Values
#'   may be a full URL or a `"owner/repo"` shorthand. Optional `subdir`
#'   can be supplied as `"owner/repo:subdir"`.
#' @param state_env An environment used to track initialisation state. The
#'   caller (typically a wrapping R package) supplies its own environment
#'   so multiple consuming packages do not interfere with each other.
#' @param install If `FALSE`, fail rather than installing missing packages.
#' @param verbose If `TRUE`, print progress messages.
#' @return Invisibly `TRUE`.
#' @export
#' @examples
#' \dontrun{
#' # In a consuming package's setup function:
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
         "https://github.com/JuliaLang/juliaup) or set JULIA_HOME.",
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
  # After a fresh install, large dependency trees can leave the depot in a
  # state where JuliaCall::julia_setup() segfaults. A second pass through
  # Pkg.precompile() in subprocess stabilises the depot so the in-process
  # JuliaCall load below is safe.
  if (installed_anything) {
    if (verbose) message("Stabilising Julia depot (Pkg.precompile)...")
    julia_subprocess("import Pkg; Pkg.precompile()", bin = bin)
  }

  suppressWarnings(JuliaCall::julia_setup())
  for (pkg in packages) {
    JuliaCall::julia_eval(sprintf("using %s", pkg))
  }

  state_env$ready <- TRUE
  invisible(TRUE)
}

#' Build the Julia code to install a package, registry or GitHub.
#' @noRd
.install_code <- function(pkg, github) {
  if (pkg %in% names(github)) {
    spec <- github[[pkg]]
    # Accept "owner/repo", "owner/repo:subdir", or full URL
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
