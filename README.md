# juliaready

Robust Julia setup for R packages that wrap a Julia simulation engine via [JuliaCall](https://cran.r-project.org/package=JuliaCall).

`juliaready` captures the patterns you have to learn the hard way when building an R package that calls Julia: which Julia binary to use when several are installed, how to install Julia packages without segfaulting on stale precompile caches, and how to load `.jl` bridge files in a way that survives Julia's world-age rules. It is small, opinionated, and meant to replace ~100 lines of brittle boilerplate per consuming package with ~5.

## Why

If you have written an R-with-Julia-backend package before, you have probably hit some of these:

- **Multiple Julia installations.** A `julia` in `PATH` (homebrew, system) is not necessarily the one JuliaCall will actually use (it may pick a juliaup-managed version). Running setup work against the wrong binary populates the wrong depot, so JuliaCall still sees a cold cache.
- **JuliaCall + stale precompile = R segfault.** If JuliaCall's embedded Julia tries to `using <pkg>` against a missing or stale precompile cache, R can hard-crash with no usable error.
- **`include()` world-age bugs.** Loading user `.jl` files via `include()` from `julia_eval` interacts badly with method dispatch.
- **`julia_eval` choking on multi-`function`-block strings.** You need to wrap the contents in `begin ... end` for it to parse reliably.

`juliaready` does the right thing by default for all of these.

## Installation

```r
# install.packages("remotes")
remotes::install_github("sbfnk/juliaready")
```

You also need [Julia](https://julialang.org/) installed; [juliaup](https://github.com/JuliaLang/juliaup) is recommended.

## Usage in a consuming R package

```r
# In your package's R/zzz.R (or similar):

.mypkg_env <- new.env(parent = emptyenv())

#' @export
setup_mypkg <- function(install = TRUE) {
  juliaready::julia_ready(
    packages  = c("EpiBranch", "Distributions", "Random"),
    github    = c(EpiBranch = "epiforecasts/EpiBranch.jl"),
    state_env = .mypkg_env,
    install   = install
  )
  juliaready::julia_load_bridge(
    package = "mypkg",
    files   = c("dist_lookup.jl", "simulate.jl")
  )
}

.ensure_julia <- function() {
  juliaready::ensure_julia(.mypkg_env, setup_mypkg)
}
```

Then in any function that touches Julia:

```r
my_function <- function(...) {
  .ensure_julia()
  JuliaCall::julia_call("my_julia_func", ...)
}
```

## API

- **`julia_bin()`** — resolve the Julia binary JuliaCall would use, without starting JuliaCall. Honours `JULIA_HOME`, juliaup, and `PATH`.
- **`julia_ready(packages, github, state_env, install, verbose)`** — ensure the named Julia packages are installed and precompiled in a subprocess, then start JuliaCall and `using` them. Idempotent.
- **`julia_load_bridge(package, files, verbose)`** — read `inst/julia/<file>` from the calling package, wrap in `begin ... end`, and `julia_eval` it.
- **`ensure_julia(state_env, init_fn)`** — lazy-init guard. Call from the top of any function that will use Julia.

## What this package deliberately does *not* do

- It does not pin a specific Julia version. If your package needs that, install via [juliaup](https://github.com/JuliaLang/juliaup) and pass `JULIA_HOME` yourself, or wrap `julia_ready()` with a version check.
- It does not auto-initialise on `.onLoad`. Eager init in `.onLoad` interacts badly with other compiled backends (notably Stan) and can crash R during package attach. Use `ensure_julia()` instead.
- It does not provide a Julia REPL or evaluation API. That is `JuliaCall`'s job.

## Status

Experimental. Extracted from working code in [ringbpjl](https://github.com/sbfnk/ringbp.jl); planned migrations of [EpiAwareR](https://github.com/sbfnk/EpiAwareR) and [forecastbaselines](https://github.com/epiforecasts/forecastbaselines) will exercise the API on real consumers.

## License

MIT
