### A Pluto.jl notebook ###
# v0.15.1

using Markdown
using InteractiveUtils

# ╔═╡ f64b7897-2e6e-4654-bb84-43bf3807f771
html"<button onclick='present()'>presentation mode</button>"

# ╔═╡ 4752d352-f864-11eb-3cdc-eff915ddae6e
md"""
# Some packages for Data Science
- My personal recommendations of Julia packages that can be useful to Data Scientists
    - Some packages are mature - some aren't
    - Some packages have volunteer maintainers - others are developed within companies
    - Most data science packages are still at the "volunteer maintainer" stage
- Areas I will mention
    - Data manipulation
    - Exploratory/presentation graphics
    - Model fitting (ML, Bayesian inference)
## Data manipulation
- For column-oriented tables, [DataFrames](https://github.com/JuliaData/DataFrames.jl) is the workhorse.
    - has reached a 1.0.0 release
    - has a mini-language for split-apply-combine types of operations
    - provides various types of joins of tables - a lot of work has gone into performance enhancements here
    - language, while consistent, can be a bit awkward
- I prefer the [DataFrameMacros](https://github.com/jkrumbiegel/DataFrameMacros.jl) language in combination with [Chain](https://github.com/jkrumbiegel/Chain.jl)
- The [Tables](https://github.com/JuliaData/Tables.jl) package provides a clearing house for various representations of column-oriented or row-oriented table representations.
    - provides a general formulation of `rowtable` (`Vector` of `NamedTuple`s) or `columntable` (`NamedTuple` of `Vector`s) and acts as a hub for transfers between them.
        + e.g. suppose I read a csv file using the [CSV](https://github.com/JuliaData/CSV.jl) package, how do I create a DataFrame from the result or from an [Arrow](https://github.com/JuliaData/Arrow.jl.git) table or write it out to an [SQLite](https://github.com/JuliaDatabases/SQLite.jl.git) table or ...?
- Many of the JuliaData packages are primarily written by Jacob Quinn who has an amazing [tutorial](https://www.youtube.com/watch?v=uLhXgt_gKJc) on microservices from JuliaCon 2020.
## Exploratory/presentation graphics
- There are many graphics systems in Julia.
- I prefer the ones based on [Makie](https://github.com/JuliaPlots/Makie.jl.git) - check out the gallery at [BeautifulMakie](https://lazarusa.github.io/BeautifulMakie/).
    - the calls to produce graphics elements and to lay them out are common to all the back ends (that's what Makie provides)
    - the actual display requires a back end package like [CairoMakie](https://github.com/JuliaPlots/Makie.jl.git), which we have used, or [GLMakie](https://github.com/JuliaPlots/Makie.jl.git), based on OpenGL
    - a higher-level (but still experimental) approach is available in [AlgebraOfGraphics](https://github.com/JuliaPlots/AlgebraOfGraphics.jl.git)
## Model fitting
- For machine learning many people like [Flux](https://github.com/FluxML/Flux.jl.git) (I haven't used it myself).  See also [MLJ](https://github.com/alan-turing-institute/MLJ.jl.git)
- [Turing](https://github.com/TuringLang/Turing.jl.git) is a popular framework for Bayesian inference. [Soss](https://github.com/cscherrer/Soss.jl.git) and associated packages like [MeasureTheory](https://github.com/cscherrer/MeasureTheory.jl.git) are interesting alternatives still under development.
- Many of these packages benefit from extensive development in Julia on topics like Automatic Differentiation.
- Some basic statistics tools under the [JuliaStats group](https://github.com/JuliaStats/) include [Distributions](https://github.com/JuliaStats/Distributions.jl.git), [StatsModels](https://github.com/JuliaStats/StatsModels.jl.git), and [StatsBase](https://github.com/JuliaStats/StatsBase.jl.git)
    - the organization here is not as good as I would like it to be but it is dependent on volunteers
"""

# ╔═╡ Cell order:
# ╟─f64b7897-2e6e-4654-bb84-43bf3807f771
# ╟─4752d352-f864-11eb-3cdc-eff915ddae6e
