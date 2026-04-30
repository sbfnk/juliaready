#' Backend-agnostic wrappers around Julia eval / call / import
#'
#' These thin wrappers exist so consumer packages can call into Julia
#' without directly depending on JuliaConnectoR. If `juliaready` ever
#' switches backend, consumer code keeps working.
#'
#' @name wrappers
NULL

#' Evaluate Julia code
#' @param code A string of Julia code.
#' @return The result, converted to R where reasonable; otherwise a
#'   `JuliaProxy` object.
#' @export
eval_julia <- function(code) {
  JuliaConnectoR::juliaEval(code)
}

#' Call a Julia function by (qualified) name
#'
#' The function name may be module-qualified (e.g. `"Distributions.mean"`).
#' Module qualification is recommended after `using` so that constructor
#' names resolve unambiguously.
#'
#' @param name Function name, optionally module-qualified.
#' @param ... Arguments passed to the Julia function.
#' @return The Julia function's return value, converted to R where
#'   reasonable.
#' @export
call_julia <- function(name, ...) {
  JuliaConnectoR::juliaCall(name, ...)
}

#' Import a Julia module
#'
#' Returns a list/environment-like object of the module's exported names,
#' callable as R functions. Equivalent to `juliaImport`.
#'
#' @param module Name of the Julia module, e.g. `"Distributions"`.
#' @return A `JuliaModuleImport` object.
#' @export
import_julia <- function(module) {
  JuliaConnectoR::juliaImport(module)
}
