### A Pluto.jl notebook ###
# v0.15.1

using Markdown
using InteractiveUtils

# ╔═╡ 8b92a6cf-cd6a-4364-9f59-598bcf206ef1
html"<button onclick=present()>Present</button>"

# ╔═╡ 5c402564-e0e1-11eb-105b-951cfa19cacd
md"""
# Julia for Statistics and Data Science

- *Cecile Ane*, *Douglas Bates* & *Claudia Solis-Lemus* all with U. of Wisconsin - Madison

1. What is **Julia**?
    - How does it differ from other languages, particularly **R** and **Python**, used for data science?
    - How do I get started?
2. A deep dive into a shallow function.
3. Motivating example -- `MixedModels.jl` compared to R's `lme4`
4. Some recommended packages for Statistics and Data Science  
5. `RCall.jl` and `PyCall.jl`: to allow you to build on your current skills
"""

# ╔═╡ 7e8e3903-a76d-4310-b5df-8508fdd7dba3
md"""
## What is **Julia**?

- an Open Source language designed for "technical computing".  The motivation is best explained in [this blog post](https://julialang.org/blog/2012/02/why-we-created-julia/) by its creators.
- development of the [language itself](https://github.com/JuliaLang/julia) and most packages, e.g. [DataFrames](https://github.com/JuliaData/DataFrames.jl), takes place on github.
- a few things to notice about [github.com/JuliaLang/julia](https://github.com/JuliaLang/julia)
    - nearly 1100 contributors
    - over 40,000 issues or pull requests
    - over 50,000 commits
    - the most common coding language used in the `julia` repository is Julia
- installation is easiest using binary downloads from [julialang.org](https://julialang.org/downloads)
"""

# ╔═╡ dc65b3ed-2acf-4bf5-be2e-77dde963a7f1
md"""
## Package Ecosystem
- Julia packages are public git repositories (usually on `github.com` or `gitlab.com`) listed in the [General Registry](https://github.com/JuliaRegistries/General)
- see the [Packages tab at julialang.org](https://julialang.org/packages) for links to package exploration tools.  I prefer the one at [JuliaHub](https://juliahub.com/ui/packages)
    + when browsing Julia packages visit the repository and look at the Languages bar on the right hand side.  Most packages are 100% Julia code.  As [Erik Engheim wrote](https://medium.com/codex/is-julia-really-fast-12cd7caef96b), "it's turtles all the way down".
    + [this blog posting](https://julialang.org/blog/2021/08/general-survey/) provides some analysis of the package registry contents
- setting version numbers according to [semantic versioning](https://semver.org/) is strongly encouraged
- often packages are maintained by organizations on github.com, e.g. DataFrames.jl belongs to the JuliaData organization.
"""

# ╔═╡ bb892d27-63f6-4267-bfcc-758e743c31d2
md"""
## Ways to program in Julia
1. Start the App and use the Read-Eval-Print-Loop (REPL) **[demo this]**
    - the REPL has name completion and other conveniences
    - the REPL has "modes"
        + standard Julia input
        + help mode
        + package manager mode
        + shell mode
        + some packages, e.g. `RCall`, enable their own modes
2. An Integrated Development Environment (IDE)
    - [Visual Studio Code](https://code.visualstudio.com/) (with the Julia extension) is the most widely used
3. [Jupyter notebooks](https://jupyter.org) using the [IJulia package](https://github.com/JuliaLang/IJulia.jl)
4. [Pluto](https://github.com/fonsp/Pluto.jl) notebooks, which we are using here.
"""

# ╔═╡ 864522f6-a214-4397-91cb-8d4d670e7638
md"""
## Why Julia?
- allows you to bypass the **two language problem**
    + high-level, *dynamic* languages (R, Python, Matlab/Octave, etc.) allow for ease of use and high productivity
    + often code in these languages is unable to give the performance required for high-throughput, production uses
    + the usual solution is to re-write the performance-critical parts in a low-level, *static* language (C, C++, Fortran) and integrate that with the higher-level code
- language and support system are carefully crafted to provide **both** high level tools and high performance
- recently developed language with the benefit of hindsight and modern tools.
"""

# ╔═╡ d78b2581-31cd-4a08-9c8f-59aedc5c3086
md"""
## Why not Julia?
- recently developed language
    + ecosystem is not as mature as R, Python, etc.
    + don't have time to learn a new language and support system because this proposal is due Friday
"""

# ╔═╡ 0aab07a1-893e-4c8b-ae8d-198146058d2e
md"""
## In what ways is **Julia** similar to **R**?

- Algorithms are expressed as **functions**
- Functions are *generic* - different *methods* can be defined for argument *signatures*
    * in **R** a function must be explicitly designated as a generic function
    * **R** has different systems of generic functions and methods (S3 and S4)
        - S3 method dispatch is on the first argument's class only (single dispatch)
        - S4 allows for **multiple dispatch**
- In Julia all functions are generic and all functions use multiple dispatch
"""

# ╔═╡ 85fcacb1-7ad2-4fb8-9c87-28cfaa0f1404
md"""
## What makes Julia fast?
- The first time a particular method is invoked, it is compiled using a *Just In Time* compiler based on [**LLVM**](https://llvm.org) - the low-level virtual machine
    * good news - the actual execution is fast and subsequent calls are fast
    * bad news - the first call can be slow because of the compilation overhead
        + known informally as the "Time To First Plot" problem
- Ease of programming and ease of compilation are often antithetical goals
    * ease of programming emphasizes generality provided by languages with dynamic types
    * ease of compilation requires very specific, usually static, types b/c that's what the processor works with
- In Julia methods are often defined for general, abstract argument types but compilation takes place for specific, concrete types.

Time for a deep dive (notebook named `2compilation.jl`)
"""

# ╔═╡ Cell order:
# ╟─8b92a6cf-cd6a-4364-9f59-598bcf206ef1
# ╟─5c402564-e0e1-11eb-105b-951cfa19cacd
# ╟─7e8e3903-a76d-4310-b5df-8508fdd7dba3
# ╟─dc65b3ed-2acf-4bf5-be2e-77dde963a7f1
# ╟─bb892d27-63f6-4267-bfcc-758e743c31d2
# ╟─864522f6-a214-4397-91cb-8d4d670e7638
# ╟─d78b2581-31cd-4a08-9c8f-59aedc5c3086
# ╟─0aab07a1-893e-4c8b-ae8d-198146058d2e
# ╟─85fcacb1-7ad2-4fb8-9c87-28cfaa0f1404
