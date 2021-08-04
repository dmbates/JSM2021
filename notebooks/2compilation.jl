### A Pluto.jl notebook ###
# v0.15.1

using Markdown
using InteractiveUtils

# ╔═╡ 6c3f0006-ed5f-11eb-1d6a-97e055036aaf
using BenchmarkTools, CairoMakie, LoopVectorization, MethodAnalysis

# ╔═╡ c5a55de6-fe87-4e26-976e-b211a7c9ee55
using PlutoUI, ANSIColoredPrinters, DualNumbers, Random

# ╔═╡ 28cbb4dd-c5f1-4c39-b25a-6b974124a5fc
md"""
# Far too much detail on a logistic function in Julia

First load some packages we will use
"""

# ╔═╡ d8008b16-836a-4ed0-9b94-8fca75563c64
CairoMakie.activate!(type="svg")   # use Scalable Vector Graphics backend

# ╔═╡ d08dada6-ea60-4430-8f80-cc40b70bff5d
md"Next there is a bit of opaque code borrowed from a [presentation](https://github.com/c42f/JuliaBrisbaneMeetup) by Chris Foster that allows us to see intermediate code representations in Pluto.  Pluto is somewhat picky about output and the stock versions of these macros don't play nicely with Pluto. Feel free to ignore these details."

# ╔═╡ 0acb3853-031e-43f5-b338-27dcf71d9c7c
begin
	function img(path, scale=50)
		LocalResource("./$path", "style"=>"width:$scale%;margin:auto;display:block")
	end
	macro DumpAST(ex)
		quote
			Dump(Base.remove_linenums!($(QuoteNode(ex))))
		end
	end
	function Sprint(args...; kws...)
		Text(sprint(args...; kws...))
	end
	nothing
end

# ╔═╡ 523f7fb8-45d5-4cd6-adb0-66e514134546
begin
	function color_print(f)
		io = IOBuffer()
		f(IOContext(io, :color=>true))
		html_str = sprint(
			io2->show(
				io2, MIME"text/html"(),
				HTMLPrinter(io, root_class="documenter-example-output"),
			),
		)
		HTML("$html_str")
	end
# Hacky style setup for ANSIColoredPrinters. css taken from ANSIColoredPrinters example.
# Not sure why we need to modify the font size...
HTML("""
<style>
html .content pre {
    font-family: "JuliaMono", "Roboto Mono", "SFMono-Regular", "Menlo", "Consolas",
        "Liberation Mono", "DejaVu Sans Mono", monospace;
}

html pre.documenter-example-output {
    line-height: 125%;
	font-size: 60%
}

html span.sgr1 {
    font-weight: bolder;
}

html span.sgr2 {
    font-weight: lighter;
}

html span.sgr3 {
    font-style: italic;
}

html span.sgr4 {
    text-decoration: underline;
}

html span.sgr7 {
    color: #fff;
    background-color: #222;
}

html.theme--documenter-dark span.sgr7 {
    color: #1f2424;
    background-color: #fff;
}

html span.sgr8,
html span.sgr8 span,
html span span.sgr8 {
    color: transparent;
}

html span.sgr9 {
    text-decoration: line-through;
}


html span.sgr30 {
    color: #111;
}

html span.sgr31 {
    color: #944;
}

html span.sgr32 {
    color: #073;
}

html span.sgr33 {
    color: #870;
}

html span.sgr34 {
    color: #15a;
}

html span.sgr35 {
    color: #94a;
}

html span.sgr36 {
    color: #08a;
}

html span.sgr37 {
    color: #ddd;
}

html span.sgr40 {
    background-color: #111;
}

html span.sgr41 {
    background-color: #944;
}

html span.sgr42 {
    background-color: #073;
}

html span.sgr43 {
    background-color: #870;
}

html span.sgr44 {
    background-color: #15a;
}

html span.sgr45 {
    background-color: #94a;
}

html span.sgr46 {
    background-color: #08a;
}

html span.sgr47 {
    background-color: #ddd;
}

html span.sgr90 {
    color: #888;
}

html span.sgr91 {
    color: #d57;
}

html span.sgr92 {
    color: #2a5;
}

html span.sgr93 {
    color: #d94;
}

html span.sgr94 {
    color: #08d;
}

html span.sgr95 {
    color: #b8d;
}

html span.sgr96 {
    color: #0bc;
}

html span.sgr97 {
    color: #eee;
}


html span.sgr100 {
    background-color: #888;
}

html span.sgr101 {
    background-color: #d57;
}

html span.sgr102 {
    background-color: #2a5;
}

html span.sgr103 {
    background-color: #d94;
}

html span.sgr104 {
    background-color: #08d;
}

html span.sgr105 {
    background-color: #b8d;
}

html span.sgr106 {
    background-color: #0bc;
}

html span.sgr107 {
    background-color: #eee;
}

</style>""")
end

# ╔═╡ 7d9eb363-9872-41bb-9e88-61f0022da1d7
begin
	
# hacks to make code_llvm, code_native, code_warntype work in Pluto.

	macro code_warntype_(args...)
		code = macroexpand(@__MODULE__, :(@code_warntype $(args...)))
		@assert code.head == :call
		insert!(code.args, 2, :io)
		esc(quote # non-hygenic :(
			color_print() do io
		    	$code
			end
		end)
	end
	
	macro code_llvm_(args...)
		code = macroexpand(@__MODULE__, :(@code_llvm $(args...)))
		@assert code.head == :call
		insert!(code.args, 2, :io)
		esc(quote # non-hygenic :(
			color_print() do io
		   		$code
			end
		end)
	end
	
	macro code_native_(args...)
		code = macroexpand(@__MODULE__, :(@code_native $(args...)))
		@assert code.head == :call
		insert!(code.args, 2, :io)
		esc(quote # non-hygenic :(
			color_print() do io
		    	$code
			end
		end)
	end
	
	nothing
end

# ╔═╡ eb2cb49d-de84-4021-88b0-9915ed4c3e41
md"""
## Purpose of this notebook
- Take a very simple function definition and follow the compilation process for a method.
- Show broadcasting of scalar function definitions to arrays and other iterators.
- Show benchmarking of scalar, broadcast and mutating methods.
- Code like that shown below is actually used in GLM.jl and MixedModels.jl when fitting GLMs or GLMMs.  Contrast with what is done in [lme4](https://github.com/lme4/lme4/blob/master/src/glmFamily.cpp#L121) (which ends up calling code from [libRmath](https://github.com/wch/r-source/blob/trunk/src/nmath/plogis.c#L38)).


The *inverse link function* for the logit link is the *logistic*, $μ = g^{-1}(η) = \frac{1}{1+e^{-η}}$.  One way to write this in Julia is
"""

# ╔═╡ 0f96b7b1-b9fd-48c4-a418-c066e815be1c
logistic1(η) = 1 / (1 + exp(-η))  # a slightly better version is given below

# ╔═╡ 67f68fff-cb3b-4ab2-89d8-cd323dd6545f
md"""
- This type of function definition is handy for "one-liners".  More general function definitions will be shown below.
- Notice that we are not defining a function, per se, but a *method* for a *generic* function.  Users of `R` may be familiar with generic functions and methods.
- **All functions in Julia are generic**
- When this is the first method for a function name (or, more formally, a *function binding*), the declaration also creates the generic function.
- We call these *implementation methods*, in contrast to *method instances* shown below.  They are the code or the implementation of the idea of *logistic* for some types of arguments.
- In this case there is only one argument, which has not been given a type, hence it gets the default type `Any`.
"""

# ╔═╡ 26bff24b-3205-4020-9e1c-315b6823730f
methods(logistic1)  # returns the "implementation" methods - only one at this point

# ╔═╡ 2e88ea1d-b055-4167-910d-f57b329e861a
md"Some calls to `logistic1` with various number types"

# ╔═╡ 35007adb-1867-4118-8a4c-e4bffa8b837a
logistic1(1.3)  	     # Float64

# ╔═╡ 8d21ff62-141b-4c6c-8111-d92e33bf1365
logistic1(1.3f0)         # Float32

# ╔═╡ b3f16743-788c-4bb5-8c5e-7648704a44ad
logistic1(Float16(1.3))  # Float16

# ╔═╡ a5307015-eb3e-4929-a9ce-94dc7044aaf3
logistic1(big"1.3")      # BigFloat

# ╔═╡ 4a539b63-9f0f-4c37-938d-1aad9724406f
logistic1(1.3 + 0.0im)   # Complex numbers

# ╔═╡ 5764820f-ebfe-4fde-8e5c-3a03072376c3
logistic1(Dual(1.3, 1))  # Dual numbers, used in Automatic Differentiation

# ╔═╡ e88eaf23-709e-41ac-8cff-89255a18bcfc
md"""
Although we have only one implementation method, each of these calls with a different number type as its argument creates its own `MethodInstance`.
"""

# ╔═╡ bc9597c6-e82a-471a-95f8-a6cac4e40759
methodinstances(logistic1)

# ╔═╡ 257fcc63-a75e-4787-8eaa-6d05f8966181
md"""
- Each `MethodInstance` is compiled separately to assembler code
- The steps are
    + *lower* the code to a simpler form, sometimes called [single static assignment](https://en.wikipedia.org/wiki/Static_single_assignment_form) - essentially this converts expressions and control flow to baby steps.
    + perform *type inference* to infer the type of the value at each of these baby steps.
    + perform some other convenient transformations such as *inlining* simple function calls, then produce the *llvm* code.
    + compile the *llvm* code to native assembler code.

- We can examine the result of each stage using functions `code_lowered`, `code_typed` or `code_warntype`, `code_llvm` and `code_native`.
    + the arguments are the generic name and a `tuple` of argument types to the generic
    + in practice, we often use macros with similar names to which we can pass a sample call and have it infer the types
"""

# ╔═╡ f69b1ad4-01a2-4de8-9fcd-1e77ce8e5e46
code_lowered(logistic1, (Float64,))  # function call form of code_lowered

# ╔═╡ a386c48f-0217-434d-9f7c-bbb786afcb8f
@code_lowered logistic1(1.3)         # macro call which infers the types of args

# ╔═╡ 46b439fe-8af6-43df-95be-968b4319a49f
# use @code_warntype (no trailing underscore) in the REPL
@code_warntype_ logistic1(1.3)

# ╔═╡ d6f8cfa3-8e97-446f-aacf-232fa2f8d673
#@code_llvm in the REPL
@code_llvm_ logistic1(1.3)

# ╔═╡ eac0800b-b985-4f86-ae0f-924e0f62f7ce
#@code_native in the REPL
@code_native_ logistic1(1.3)

# ╔═╡ d1c33f7a-4970-41b8-a6dc-077c015cd4b6
md"""
- For another data type the code_lowered will look essentially the same but the others will change.
- In practice, we don't usually examine this output, except for `@code_warntype` when something seems to be unusually slow, which can be because type inference has failed.
"""

# ╔═╡ 7c7453b5-4186-4df3-abb7-20cf2afb6161
@code_warntype_ logistic1(1.3f0)

# ╔═╡ ce63eb1f-be0a-43c3-93de-313aca45a155
@code_llvm_ logistic1(1.3f0)

# ╔═╡ 7d99a317-d5e6-46b7-a9ba-16d3817a19f9
@code_warntype_ logistic1(Dual(1.3, 1.0))

# ╔═╡ 13246aed-c0fb-4c42-ae98-012a07f93fc8
@code_llvm_ logistic1(Dual(1.3, 1.0))

# ╔═╡ 3dc537e1-1b00-476a-8ca5-a602c73cc44e
md"""
## Generalizing the definition
- Often there are convenience functions in Julia, with trivial methods that can be inlined, to express a general concept.
- Two of interest here are `inv`, which returns the multiplicative inverse, and `one`, which returns the multiplicative identity.
- Rewrite the implementation using these
"""

# ╔═╡ dad92360-4bb0-4d78-b6c2-bc865f6fb8fd
logistic(η) = inv(one(η) + exp(-η))

# ╔═╡ 3f12a642-b6fd-4ffd-a726-78f92f35d472
md"""
We can verify our previous results with this new definition
"""

# ╔═╡ e8068a65-a054-45e4-b80e-1d9affe8ce26
logistic(1.3)

# ╔═╡ 18308a79-ebaf-4ed3-9841-a385a851ccd2
logistic(1.3) == logistic1(1.3)

# ╔═╡ fb40ddf8-616a-4175-bc75-83e85b2f9ad8
md"""
- We can try other types as before but it gets tedious writing all these comparisons
- It would be better to iterate over a collection of values of different types. However, we can't store these in a vector or `Array` because elements of an `Array` must be the same type.
- In Julia a *Tuple* is an ordered collection of possibly heterogeneous elements
- We can apply a function or operator to the elements of an Array or of a Tuple by [fused dot broadcasting](https://docs.julialang.org/en/v1/manual/arrays/#man-array-and-vectorized-operators-and-functions).
- In its simplest form you just add a dot to the end of a function name in a call to apply it to an iterator.
"""

# ╔═╡ 0c5bf3df-2dc0-4ab2-b84b-aef442677e78
vals = logistic.((1.3, 1.3f0, big"1.3", Dual(1.3, 1.0), 1.3+0.0im)) # a Tuple

# ╔═╡ 44744591-ee45-4ba9-9aac-c5f8bcb67a63
md"""
The printing is a bit misleading here.  Pluto is trying too hard to make things line up.  The first value really is a `Float64` and the third value really is a `BigFloat`.
"""

# ╔═╡ 5eb416ae-d43c-4034-b2c7-ee0959be4ae1
first(vals)

# ╔═╡ 411c5fab-2b63-456c-ab5f-5c331dfb337f
vals[3]

# ╔═╡ 8afdceb1-d99e-4212-9192-ad533edad354
begin
	inputs = (1.3, 1.3f0, big"1.3", Dual(1.3, 1.0), 1.3+0.0im)
	all(logistic.(inputs) .== logistic1.(inputs))
end

# ╔═╡ b435de57-0a26-4a87-881a-1016f79e1b3b
md"The last expression could be written using a macro, `@.`, that adds dots everywhere they are needed (macros are often a form of *syntactic sugar*)."

# ╔═╡ 3dd434f8-5425-4368-9d85-13ccc5c19d44
all(@. logistic(inputs) == logistic1(inputs))

# ╔═╡ 7fccb6fa-3a96-4480-a229-1a4c4d477f9f
md"""
- We could even apply `logistic` to a square matrix, because `exp(A)` produces the matrix exponential. 
- Whether that would be particularly meaningful is not certain.
"""

# ╔═╡ 004dd11e-5698-4470-8b23-3eeef2218d25
begin
	rng = MersenneTwister(12321) # initialize a random number generator
	A = randn(rng, (3, 3))       # matrix of standard normal random variates
end

# ╔═╡ 8b6fab32-5c31-4a22-94d3-4d9a2c6e0415
logistic(A)

# ╔═╡ 6fa75bb1-d949-408a-991f-716d4c29b640
logistic1(A)   # fails at the addition step in the denominator

# ╔═╡ d9e16371-995e-4fa0-b758-edba9241b538
md"""
- The llvm code from, say `logistic(::Float64)` will be the same as for `logistic1(::Float64)`.  It just skips one step of promoting `1` to `Float64` for addition.
- At the llvm stage of compilation all the trivial function calls have been inlined.
"""

# ╔═╡ 3c4298d0-af51-460e-bd39-8eb91c1cb053
@code_llvm_ logistic(1.3)

# ╔═╡ 52533a32-40a9-4dce-bb99-952d49483ddb
md"""
## A plot of the function
- Let's produce a simple plot using a vector of `Float32` values over the range, say, -6 to 6. (Usually 32-bit floats are sufficient for plotting and they can sometimes be processed faster.)
- We use dot-broadcasting to evaluate μ for the sequence of η values.
"""

# ╔═╡ 251928bb-bca3-41e4-b006-7b67027c2b37
begin
	η = -6.0f0:0.02f0:6.0f0      # a sequence from -6 to +6 in steps of 0.02
	μ = logistic.(η)
	lines(η, μ, axis=(xlabel="η", ylabel="μ"))
end

# ╔═╡ 02fc6678-c3b3-4c03-bcf2-8cd7bb5bbe9d
typeof(μ)

# ╔═╡ 73e1eae5-0215-421e-8c3b-83411b0339d3
md"""
## Evaluations of μ from η when fitting a GLM
- We could use dot-broadcasting to evaluate μ from η at each iteration when fitting a GLM or GLMM
- In our current form each evaluation will allocate a new μ vector.  At some point the vectors that are no longer used will need to be freed.  This is called *garbage collection* and can sometimes take a substantial fraction of the execution time.
- The `BenchmarkTools` package provides macros to time many evaluations of an expression and produce a summary of execution time and GC time.
"""

# ╔═╡ b619f1ab-b88d-4e5b-9d35-133bc4d9f12f
@benchmark logistic.(η)

# ╔═╡ 4cb90e1a-ee5c-409a-b39d-96423605dd75
md"""
- Sometimes there can be a huge range in the timings and in the fraction of time spent in GC.
- We should compare a single evaluation, which we do by picking an η value in the middle of the range.
"""

# ╔═╡ dfc3aba6-9224-4a6b-82da-7e0765ecaeb8
@benchmark logistic(η[321])

# ╔═╡ 27059732-fb53-40e3-b9a5-056d3b8c17d4
md"""
- This is actually rather slow in part because of the cautious way `StepRange` values are calculated.
- We will collect the values in a vector `ηv` and use that instead
"""

# ╔═╡ 02a8237d-0e2a-4973-8d1f-69312f25bf0b
begin
	ηv = collect(η)
	@benchmark logistic.($ηv)
end

# ╔═╡ e0b91e52-23cd-4eb8-addf-c62af1e38286
(typeof(η), typeof(ηv))

# ╔═╡ 7924d72d-c8d6-46b3-81f4-f8245f0c34bf
@benchmark logistic($ηv[321])

# ╔═╡ 4ae3b20f-7a1c-4729-a854-941e8df088b8
md"""
- There are 601 values and, on my computer, about 5 ns per value so a total of 3 μs for the vector is reasonable.
- We still have the allocation overhead, even though we already have a μ vector allocated.
    + In Julia functions can *mutate* their arguments and overwrite, say, the values of an `Array` or similar structure.
    + By convention, a `!` is appended to the name of such functions and the argument(s) to be modified is/are the first in the argument list.
    + Here we will use templated types to ensure that the arguments are compatible.
"""

# ╔═╡ 19237137-1937-495f-a28c-7ca716b81f95
function logistic1!(y::AbstractArray{T}, x::AbstractArray{T}) where {T}
	return @. y = inv(one(T) + exp(-x))
end

# ╔═╡ bcf5d9cc-8dc4-4591-b64b-67e35e0a7045
@benchmark logistic1!($μ, $ηv)

# ╔═╡ defbf223-8452-49ae-a8bd-76ea74bb10b7
md"""
- Not a huge time saving at the low end or the mean or the median but no GC and hence much greater consistency in times.
- It happens that this form can be further enhanced using a type of parallelization called *single instruction, multiple data* (SIMD), available on modern CPUs.
- The [LoopVectorization package](https://github.com/JuliaSIMD/LoopVectorization.jl) by Chris Elrod has a lot of people excited about these methods.
- In cases to which it applies, you just wrap a loop (explicit or implicit) in `@turbo`.
"""

# ╔═╡ 6fe48e39-ee1d-477f-b753-775cb6524d62
function logistic!(y::AbstractArray{T}, x::AbstractArray{T}) where {T<:AbstractFloat}
	return @turbo @. y = inv(one(T) + exp(-x))
end

# ╔═╡ 40ef2dea-9c1a-4493-8998-e61c1ec70875
@benchmark logistic!($μ, $ηv)

# ╔═╡ 489b22a1-e4c0-4e3a-a2c9-4c474521c221
md"""
- This is over 10 times faster than the version without `@turbo` on my computer
- In fact it is close to 16 times faster, which is about what is expected because it is operating on 16 Float32 values at a time (the processor supports avx512).
"""

# ╔═╡ dbb725b1-cf34-4a35-8ef6-15e6035173a7
with_terminal() do
	versioninfo()
end

# ╔═╡ e24a79ae-c7f1-4ac5-99ac-e34072beb164
md"""
- when fitting a GLM, η and μ would usually be double precision floating point vectors
- for comparison with the `Float32` results we keep the same length (601) of η and μ
"""

# ╔═╡ 30f6f5f5-cd81-4802-bbf4-fea630ca1dec
begin
	glmη = randn(rng, 601)   # sample of size 1000 from standard normal dist'n
	glmμ = similar(glmη)     # uninitialized array of similar type and size
	@benchmark logistic!($glmμ, $glmη)
end

# ╔═╡ 9f4443ca-2d3a-4e63-be26-8549485913af
md"""
## Summary
- Julia programming consists of defining *types* (which we didn't do here), *generic functions* (just a name, really), and *implementation methods* for a *signature* of argument types in a call to a generic.
- all Julia functions are generic
- method dispatch is by *multiple dispatch* (as opposed to *single dispatch*). It takes into account the entire argument signature when determining which method to use.
- Just-In-Time (JIT) compilation is performed on *method instances* where the argument types are all *concrete* types
- it is not uncommon to write *mutating* methods that overwrite the contents of one or more arguments.
- there are many tools to examine the compilation process if you wish.  Most of the time it is not necessary to do so.
- there are also tools to benchmark, profile, etc. evaluation of expressions, to create test suites and check the test coverage, ...
- the ability to compile method instances is a result of designing the language from the ground up to be able to do so. As Sir Jamie says:
"""

# ╔═╡ 8ef8dac4-a2bf-4d46-8818-3c68eed48c10
Resource("https://github.com/dmbates/JSM2021/blob/main/notebooks/assets/5hs27j.jpg?raw=true")

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
ANSIColoredPrinters = "a4c015fc-c6ff-483c-b24f-f7ea428134e9"
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
DualNumbers = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
LoopVectorization = "bdcacae8-1622-11e9-2a5c-532679323890"
MethodAnalysis = "85b6ec6f-f7df-4429-9514-a64bcd9ee824"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[compat]
ANSIColoredPrinters = "~0.0.1"
BenchmarkTools = "~1.1.1"
CairoMakie = "~0.6.3"
DualNumbers = "~0.6.5"
LoopVectorization = "~0.12.59"
MethodAnalysis = "~0.4.4"
PlutoUI = "~0.7.9"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[ANSIColoredPrinters]]
git-tree-sha1 = "574baf8110975760d391c710b6341da1afa48d8c"
uuid = "a4c015fc-c6ff-483c-b24f-f7ea428134e9"
version = "0.0.1"

[[AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "485ee0867925449198280d4af84bdb46a2a404d0"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.0.1"

[[AbstractTrees]]
git-tree-sha1 = "03e0550477d86222521d254b741d470ba17ea0b5"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.3.4"

[[Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "84918055d15b3114ede17ac6a7182f68870c16f7"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.1"

[[Animations]]
deps = ["Colors"]
git-tree-sha1 = "e81c509d2c8e49592413bfb0bb3b08150056c79d"
uuid = "27a7e980-b3e6-11e9-2bcd-0b925532e340"
version = "0.4.1"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[ArrayInterface]]
deps = ["IfElse", "LinearAlgebra", "Requires", "SparseArrays", "Static"]
git-tree-sha1 = "a71d224f61475b93c9e196e83c17c6ac4dedacfa"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "3.1.18"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[Automa]]
deps = ["Printf", "ScanByte", "TranscodingStreams"]
git-tree-sha1 = "d50976f217489ce799e366d9561d56a98a30d7fe"
uuid = "67c07d97-cdcb-5c2c-af73-a7f9c32a568b"
version = "0.8.2"

[[AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "a4d07a1c313392a77042855df46c5f534076fab9"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.0"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Statistics", "UUIDs"]
git-tree-sha1 = "c31ebabde28d102b602bada60ce8922c266d205b"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.1.1"

[[Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[CEnum]]
git-tree-sha1 = "215a9aa4a1f23fbd05b92769fdd62559488d70e9"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.1"

[[Cairo]]
deps = ["Cairo_jll", "Colors", "Glib_jll", "Graphics", "Libdl", "Pango_jll"]
git-tree-sha1 = "d0b3f8b4ad16cb0a2988c6788646a5e6a17b6b1b"
uuid = "159f3aea-2a34-519c-b102-8c37f9878175"
version = "1.0.5"

[[CairoMakie]]
deps = ["Base64", "Cairo", "Colors", "FFTW", "FileIO", "FreeType", "GeometryBasics", "LinearAlgebra", "Makie", "SHA", "StaticArrays"]
git-tree-sha1 = "7d37b0bd71e7f3397004b925927dfa8dd263439c"
uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
version = "0.6.3"

[[Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "f2202b55d816427cd385a9a4f3ffb226bee80f99"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+0"

[[Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "f53ca8d41e4753c41cdafa6ec5f7ce914b34be54"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "0.10.13"

[[ColorBrewer]]
deps = ["Colors", "JSON", "Test"]
git-tree-sha1 = "61c5334f33d91e570e1d0c3eb5465835242582c4"
uuid = "a2cac450-b92f-5266-8821-25eda20663c8"
version = "0.4.0"

[[ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random", "StaticArrays"]
git-tree-sha1 = "ed268efe58512df8c7e224d2e170afd76dd6a417"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.13.0"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "42a9b08d3f2f951c9b283ea427d96ed9f1f30343"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.5"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "dc7dedc2c2aa9faf59a55c622760a25cbefbe941"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.31.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[DataAPI]]
git-tree-sha1 = "ee400abb2298bd13bfc3df1c412ed228061a2385"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.7.0"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "4437b64df1e0adccc3e5d1adbc3ac741095e4677"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.9"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[Distributions]]
deps = ["FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns"]
git-tree-sha1 = "3889f646423ce91dd1055a76317e9a1d3a23fff1"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.11"

[[DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "a32185f5428d3986f47c2ab78b1f216d5e6cc96f"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.5"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "fe385ec95ac5533650fb9b1ba7869e9bc28cdd0a"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.5"

[[EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "92d8f9f208637e8d2d28c664051a00569c01493d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.1.5+1"

[[EllipsisNotation]]
deps = ["ArrayInterface"]
git-tree-sha1 = "8041575f021cba5a099a456b4163c9a08b566a02"
uuid = "da5c29d0-fa7d-589e-88eb-ea29b0a81949"
version = "1.1.0"

[[Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b3bfd02e98aedfa5cf885665493c5598c350cd2f"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.2.10+0"

[[FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "f985af3b9f4e278b1d24434cbb546d6092fca661"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.4.3"

[[FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3676abafff7e4ff07bbd2c42b3d8201f31653dcc"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.9+8"

[[FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "256d8e6188f3f1ebfa1a5d17e072a0efafa8c5bf"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.10.1"

[[FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays"]
git-tree-sha1 = "25b9cc23ba3303de0ad2eac03f840de9104c9253"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.12.0"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[FreeType]]
deps = ["CEnum", "FreeType2_jll"]
git-tree-sha1 = "cabd77ab6a6fdff49bfd24af2ebe76e6e018a2b4"
uuid = "b38be410-82b0-50bf-ab77-7b57e271db43"
version = "4.0.0"

[[FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[FreeTypeAbstraction]]
deps = ["ColorVectorSpace", "Colors", "FreeType", "GeometryBasics", "StaticArrays"]
git-tree-sha1 = "d51e69f0a2f8a3842bca4183b700cf3d9acce626"
uuid = "663a7486-cb36-511b-a19d-713bb74d65c9"
version = "0.9.1"

[[FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "15ff9a14b9e1218958d3530cc288cf31465d9ae2"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.3.13"

[[Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "47ce50b742921377301e15005c96e979574e130b"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.1+0"

[[Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "2c1cf4df419938ece72de17f368a021ee162762e"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.0"

[[Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[GridLayoutBase]]
deps = ["GeometryBasics", "InteractiveUtils", "Match", "Observables"]
git-tree-sha1 = "d44945bdc7a462fa68bb847759294669352bd0a4"
uuid = "3955a311-db13-416c-9275-1d80ed98e5e9"
version = "0.5.7"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "8a954fed8ac097d5be04921d595f741115c1b2ad"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+0"

[[Hwloc]]
deps = ["Hwloc_jll"]
git-tree-sha1 = "92d99146066c5c6888d5a3abc871e6a214388b91"
uuid = "0e44f5e4-bd66-52a0-8798-143a42290a1d"
version = "2.0.0"

[[Hwloc_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3395d4d4aeb3c9d31f5929d32760d8baeee88aaf"
uuid = "e33a78d0-f292-5ffc-b300-72abe9b543c8"
version = "2.5.0+0"

[[IfElse]]
git-tree-sha1 = "28e837ff3e7a6c3cdb252ce49fb412c8eb3caeef"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.0"

[[ImageCore]]
deps = ["AbstractFFTs", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Graphics", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "Reexport"]
git-tree-sha1 = "75f7fea2b3601b58f24ee83617b528e57160cbfd"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.9.1"

[[ImageIO]]
deps = ["FileIO", "Netpbm", "PNGFiles", "TiffImages", "UUIDs"]
git-tree-sha1 = "d067570b4d4870a942b19d9ceacaea4fb39b69a1"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.5.6"

[[IndirectArrays]]
git-tree-sha1 = "c2a145a145dc03a7620af1444e0264ef907bd44f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "0.5.1"

[[Inflate]]
git-tree-sha1 = "f5fc07d4e706b84f72d54eedcc1c13d92fb0871c"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.2"

[[IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d979e54b71da82f3a65b62553da4fc3d18c9004c"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2018.0.3+2"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[Interpolations]]
deps = ["AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "1470c80592cf1f0a35566ee5e93c5f8221ebc33a"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.13.3"

[[IntervalSets]]
deps = ["Dates", "EllipsisNotation", "Statistics"]
git-tree-sha1 = "3cc368af3f110a767ac786560045dceddfc16758"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.5.3"

[[Isoband]]
deps = ["isoband_jll"]
git-tree-sha1 = "f9b6d97355599074dc867318950adaa6f9946137"
uuid = "f1662d9f-8043-43de-a69a-05efc1cc6ff4"
version = "0.1.1"

[[IterTools]]
git-tree-sha1 = "05110a2ab1fc5f932622ffea2a003221f4782c18"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.3.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "81690084b6198a2e1da36fcfda16eeca9f9f24e4"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.1"

[[KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTW", "Interpolations", "StatsBase"]
git-tree-sha1 = "591e8dc09ad18386189610acafb970032c519707"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.3"

[[LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[LaTeXStrings]]
git-tree-sha1 = "c7f1c695e06c01b95a67f0cd1d34994f3e7db104"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.2.1"

[[LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "761a393aeccd6aa92ec3515e428c26bf99575b3b"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+0"

[[Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[LogExpFunctions]]
deps = ["DocStringExtensions", "LinearAlgebra"]
git-tree-sha1 = "7bd5f6565d80b6bf753738d2bc40a5dfea072070"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.2.5"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[LoopVectorization]]
deps = ["ArrayInterface", "DocStringExtensions", "IfElse", "LinearAlgebra", "OffsetArrays", "Polyester", "Requires", "SLEEFPirates", "Static", "StrideArraysCore", "ThreadingUtilities", "UnPack", "VectorizationBase"]
git-tree-sha1 = "2daac7e480432fd48fb05805772ba018053b935e"
uuid = "bdcacae8-1622-11e9-2a5c-532679323890"
version = "0.12.59"

[[MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "c253236b0ed414624b083e6b72bfe891fbd2c7af"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2021.1.1+1"

[[Makie]]
deps = ["Animations", "Artifacts", "Base64", "ColorBrewer", "ColorSchemes", "ColorTypes", "Colors", "Contour", "Distributions", "DocStringExtensions", "FFMPEG", "FileIO", "FixedPointNumbers", "Formatting", "FreeType", "FreeTypeAbstraction", "GeometryBasics", "GridLayoutBase", "ImageIO", "IntervalSets", "Isoband", "KernelDensity", "LaTeXStrings", "LinearAlgebra", "MakieCore", "Markdown", "Match", "MathTeXEngine", "Observables", "Packing", "PlotUtils", "PolygonOps", "Printf", "Random", "Serialization", "Showoff", "SignedDistanceFields", "SparseArrays", "StaticArrays", "Statistics", "StatsBase", "StatsFuns", "StructArrays", "UnicodeFun"]
git-tree-sha1 = "5761bfd21ad271efd7e134879e39a2289a032fc8"
uuid = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
version = "0.15.0"

[[MakieCore]]
deps = ["Observables"]
git-tree-sha1 = "7bcc8323fb37523a6a51ade2234eee27a11114c8"
uuid = "20f20a25-4f0e-4fdf-b5d1-57303727442b"
version = "0.1.3"

[[ManualMemory]]
git-tree-sha1 = "71c64ebe61a12bad0911f8fc4f91df8a448c604c"
uuid = "d125e4d3-2237-4719-b19c-fa641b8a4667"
version = "0.1.4"

[[MappedArrays]]
git-tree-sha1 = "18d3584eebc861e311a552cbb67723af8edff5de"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.0"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[Match]]
git-tree-sha1 = "5cf525d97caf86d29307150fcba763a64eaa9cbe"
uuid = "7eb4fadd-790c-5f42-8a69-bfa0b872bfbf"
version = "1.1.0"

[[MathTeXEngine]]
deps = ["AbstractTrees", "Automa", "DataStructures", "FreeTypeAbstraction", "GeometryBasics", "LaTeXStrings", "REPL", "Test"]
git-tree-sha1 = "69b565c0ca7bf9dae18498b52431f854147ecbf3"
uuid = "0a4f8689-d25c-4efe-a92b-7142dfc1aa53"
version = "0.1.2"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[MethodAnalysis]]
deps = ["AbstractTrees"]
git-tree-sha1 = "40c1181bf7943b176c4a11edd67e72ab81fa3b1d"
uuid = "85b6ec6f-f7df-4429-9514-a64bcd9ee824"
version = "0.4.4"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "4ea90bd5d3985ae1f9a908bd4500ae88921c5ce7"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.0"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "b34e3bc3ca7c94914418637cb10cc4d1d80d877d"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.3"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[NaNMath]]
git-tree-sha1 = "bfe47e760d60b82b66b61d2d44128b62e3a369fb"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.5"

[[Netpbm]]
deps = ["FileIO", "ImageCore"]
git-tree-sha1 = "18efc06f6ec36a8b801b23f076e3c6ac7c3bf153"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.0.2"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[Observables]]
git-tree-sha1 = "fe29afdef3d0c4a8286128d4e45cc50621b1e43d"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.4.0"

[[OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "4f825c6da64aebaa22cc058ecfceed1ab9af1c7e"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.10.3"

[[Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7937eda4681660b4d6aeeecc2f7e1c81c8ee4e2f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+0"

[[OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "15003dcb7d8db3c6c857fda14891a539a8f2705a"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.10+0"

[[OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "4dd403333bcf0909341cfe57ec115152f937d7d8"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.1"

[[PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "520e28d4026d16dcf7b8c8140a3041f0e20a9ca8"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.3.7"

[[Packing]]
deps = ["GeometryBasics"]
git-tree-sha1 = "f4049d379326c2c7aa875c702ad19346ecb2b004"
uuid = "19eb6ba3-879d-56ad-ad62-d5c202156566"
version = "0.4.1"

[[PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "0fa5e78929aebc3f6b56e1a88cf505bb00a354c4"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.8"

[[Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9bc1871464b12ed19297fbc56c4fb4ba84988b0d"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.47.0+0"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "c8abc88faa3f7a3950832ac5d6e690881590d6dc"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "1.1.0"

[[Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "a7a7e1a88853564e551e4eba8650f8c38df79b37"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.1.1"

[[PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "501c20a63a34ac1d015d5304da0e645f42d91c9f"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.0.11"

[[PlutoUI]]
deps = ["Base64", "Dates", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "Suppressor"]
git-tree-sha1 = "44e225d5837e2a2345e69a1d1e01ac2443ff9fcb"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.9"

[[Polyester]]
deps = ["ArrayInterface", "IfElse", "ManualMemory", "Requires", "Static", "StrideArraysCore", "ThreadingUtilities", "VectorizationBase"]
git-tree-sha1 = "4b692c8ce1912bae5cd3b90ba22d1b54eb581195"
uuid = "f517fe37-dbe3-4b94-8317-1923a5111588"
version = "0.3.7"

[[PolygonOps]]
git-tree-sha1 = "c031d2332c9a8e1c90eca239385815dc271abb22"
uuid = "647866c9-e3ac-4575-94e7-e3d426903924"
version = "0.1.1"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "afadeba63d90ff223a6a48d2009434ecee2ec9e8"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.7.1"

[[QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "12fbe86da16df6679be7521dfb39fbc861e1dc7b"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.1"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Ratios]]
git-tree-sha1 = "37d210f612d70f3f7d57d488cb3b6eff56ad4e41"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.0"

[[Reexport]]
git-tree-sha1 = "5f6c21241f0f655da3952fd60aa18477cf96c220"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.1.0"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[SIMD]]
git-tree-sha1 = "9ba33637b24341aba594a2783a502760aa0bff04"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.3.1"

[[SLEEFPirates]]
deps = ["IfElse", "Static", "VectorizationBase"]
git-tree-sha1 = "bfdf9532c33db35d2ce9df4828330f0e92344a52"
uuid = "476501e8-09a2-5ece-8869-fb82de89a1fa"
version = "0.6.25"

[[ScanByte]]
deps = ["Libdl", "SIMD"]
git-tree-sha1 = "9cc2955f2a254b18be655a4ee70bc4031b2b189e"
uuid = "7b38b023-a4d7-4c5e-8d43-3f3097f304eb"
version = "0.3.0"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[SignedDistanceFields]]
deps = ["Random", "Statistics", "Test"]
git-tree-sha1 = "d263a08ec505853a5ff1c1ebde2070419e3f28e9"
uuid = "73760f76-fbc4-59ce-8f25-708e95d2df96"
version = "0.4.0"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[SpecialFunctions]]
deps = ["ChainRulesCore", "LogExpFunctions", "OpenSpecFun_jll"]
git-tree-sha1 = "a50550fa3164a8c46747e62063b4d774ac1bcf49"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "1.5.1"

[[StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[Static]]
deps = ["IfElse"]
git-tree-sha1 = "62701892d172a2fa41a1f829f66d2b0db94a9a63"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.3.0"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "1b9a0f17ee0adde9e538227de093467348992397"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.7"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
git-tree-sha1 = "1958272568dc176a1d881acb797beb909c785510"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.0.0"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "2f6792d523d7448bbe2fec99eca9218f06cc746d"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.8"

[[StatsFuns]]
deps = ["LogExpFunctions", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "30cd8c360c54081f806b1ee14d2eecbef3c04c49"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.8"

[[StrideArraysCore]]
deps = ["ArrayInterface", "ManualMemory", "Requires", "ThreadingUtilities", "VectorizationBase"]
git-tree-sha1 = "e1c37dd3022ba6aaf536541dd607e8d5fb534377"
uuid = "7792a7ef-975c-4747-a70f-980b88e8d1da"
version = "0.1.17"

[[StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "000e168f5cc9aded17b6999a560b7c11dda69095"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.0"

[[SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[Suppressor]]
git-tree-sha1 = "a819d77f31f83e5792a76081eee1ea6342ab8787"
uuid = "fd094767-a336-5f1f-9728-57cf17d0bbfb"
version = "0.2.0"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "8ed4a3ea724dac32670b062be3ef1c1de6773ae8"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.4.4"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[ThreadingUtilities]]
deps = ["ManualMemory"]
git-tree-sha1 = "03013c6ae7f1824131b2ae2fc1d49793b51e8394"
uuid = "8290d209-cae3-49c0-8002-c8c24d57dab5"
version = "0.4.6"

[[TiffImages]]
deps = ["ColorTypes", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "OffsetArrays", "OrderedCollections", "PkgVersion", "ProgressMeter"]
git-tree-sha1 = "03fb246ac6e6b7cb7abac3b3302447d55b43270e"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.4.1"

[[TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "7c53c35547de1c5b9d46a4797cf6d8253807108c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.5"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[VectorizationBase]]
deps = ["ArrayInterface", "Hwloc", "IfElse", "Libdl", "LinearAlgebra", "Static"]
git-tree-sha1 = "a4bc1b406dcab1bc482ce647e6d3d53640defee3"
uuid = "3d5dd08c-fd9d-11e8-17fa-ed2836048c2f"
version = "0.20.25"

[[WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "59e2ad8fd1591ea019a5259bd012d7aee15f995c"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "0.5.3"

[[XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[isoband_jll]]
deps = ["Libdl", "Pkg"]
git-tree-sha1 = "a1ac99674715995a536bbce674b068ec1b7d893d"
uuid = "9a68df92-36a6-505f-a73e-abb412b6bfb4"
version = "0.2.2+0"

[[libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "c45f4e40e7aafe9d086379e5578947ec8b95a8fb"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+0"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"
"""

# ╔═╡ Cell order:
# ╟─28cbb4dd-c5f1-4c39-b25a-6b974124a5fc
# ╠═6c3f0006-ed5f-11eb-1d6a-97e055036aaf
# ╠═c5a55de6-fe87-4e26-976e-b211a7c9ee55
# ╠═d8008b16-836a-4ed0-9b94-8fca75563c64
# ╟─d08dada6-ea60-4430-8f80-cc40b70bff5d
# ╟─0acb3853-031e-43f5-b338-27dcf71d9c7c
# ╟─523f7fb8-45d5-4cd6-adb0-66e514134546
# ╟─7d9eb363-9872-41bb-9e88-61f0022da1d7
# ╟─eb2cb49d-de84-4021-88b0-9915ed4c3e41
# ╠═0f96b7b1-b9fd-48c4-a418-c066e815be1c
# ╟─67f68fff-cb3b-4ab2-89d8-cd323dd6545f
# ╠═26bff24b-3205-4020-9e1c-315b6823730f
# ╟─2e88ea1d-b055-4167-910d-f57b329e861a
# ╠═35007adb-1867-4118-8a4c-e4bffa8b837a
# ╠═8d21ff62-141b-4c6c-8111-d92e33bf1365
# ╠═b3f16743-788c-4bb5-8c5e-7648704a44ad
# ╠═a5307015-eb3e-4929-a9ce-94dc7044aaf3
# ╠═4a539b63-9f0f-4c37-938d-1aad9724406f
# ╠═5764820f-ebfe-4fde-8e5c-3a03072376c3
# ╟─e88eaf23-709e-41ac-8cff-89255a18bcfc
# ╠═bc9597c6-e82a-471a-95f8-a6cac4e40759
# ╟─257fcc63-a75e-4787-8eaa-6d05f8966181
# ╠═f69b1ad4-01a2-4de8-9fcd-1e77ce8e5e46
# ╠═a386c48f-0217-434d-9f7c-bbb786afcb8f
# ╠═46b439fe-8af6-43df-95be-968b4319a49f
# ╠═d6f8cfa3-8e97-446f-aacf-232fa2f8d673
# ╠═eac0800b-b985-4f86-ae0f-924e0f62f7ce
# ╟─d1c33f7a-4970-41b8-a6dc-077c015cd4b6
# ╠═7c7453b5-4186-4df3-abb7-20cf2afb6161
# ╠═ce63eb1f-be0a-43c3-93de-313aca45a155
# ╠═7d99a317-d5e6-46b7-a9ba-16d3817a19f9
# ╠═13246aed-c0fb-4c42-ae98-012a07f93fc8
# ╟─3dc537e1-1b00-476a-8ca5-a602c73cc44e
# ╠═dad92360-4bb0-4d78-b6c2-bc865f6fb8fd
# ╟─3f12a642-b6fd-4ffd-a726-78f92f35d472
# ╠═e8068a65-a054-45e4-b80e-1d9affe8ce26
# ╠═18308a79-ebaf-4ed3-9841-a385a851ccd2
# ╟─fb40ddf8-616a-4175-bc75-83e85b2f9ad8
# ╠═0c5bf3df-2dc0-4ab2-b84b-aef442677e78
# ╟─44744591-ee45-4ba9-9aac-c5f8bcb67a63
# ╠═5eb416ae-d43c-4034-b2c7-ee0959be4ae1
# ╠═411c5fab-2b63-456c-ab5f-5c331dfb337f
# ╠═8afdceb1-d99e-4212-9192-ad533edad354
# ╟─b435de57-0a26-4a87-881a-1016f79e1b3b
# ╠═3dd434f8-5425-4368-9d85-13ccc5c19d44
# ╟─7fccb6fa-3a96-4480-a229-1a4c4d477f9f
# ╠═004dd11e-5698-4470-8b23-3eeef2218d25
# ╠═8b6fab32-5c31-4a22-94d3-4d9a2c6e0415
# ╠═6fa75bb1-d949-408a-991f-716d4c29b640
# ╟─d9e16371-995e-4fa0-b758-edba9241b538
# ╠═3c4298d0-af51-460e-bd39-8eb91c1cb053
# ╟─52533a32-40a9-4dce-bb99-952d49483ddb
# ╠═251928bb-bca3-41e4-b006-7b67027c2b37
# ╠═02fc6678-c3b3-4c03-bcf2-8cd7bb5bbe9d
# ╟─73e1eae5-0215-421e-8c3b-83411b0339d3
# ╠═b619f1ab-b88d-4e5b-9d35-133bc4d9f12f
# ╟─4cb90e1a-ee5c-409a-b39d-96423605dd75
# ╠═dfc3aba6-9224-4a6b-82da-7e0765ecaeb8
# ╟─27059732-fb53-40e3-b9a5-056d3b8c17d4
# ╠═02a8237d-0e2a-4973-8d1f-69312f25bf0b
# ╠═e0b91e52-23cd-4eb8-addf-c62af1e38286
# ╠═7924d72d-c8d6-46b3-81f4-f8245f0c34bf
# ╟─4ae3b20f-7a1c-4729-a854-941e8df088b8
# ╠═19237137-1937-495f-a28c-7ca716b81f95
# ╠═bcf5d9cc-8dc4-4591-b64b-67e35e0a7045
# ╟─defbf223-8452-49ae-a8bd-76ea74bb10b7
# ╠═6fe48e39-ee1d-477f-b753-775cb6524d62
# ╠═40ef2dea-9c1a-4493-8998-e61c1ec70875
# ╟─489b22a1-e4c0-4e3a-a2c9-4c474521c221
# ╠═dbb725b1-cf34-4a35-8ef6-15e6035173a7
# ╟─e24a79ae-c7f1-4ac5-99ac-e34072beb164
# ╠═30f6f5f5-cd81-4802-bbf4-fea630ca1dec
# ╟─9f4443ca-2d3a-4e63-be26-8549485913af
# ╟─8ef8dac4-a2bf-4d46-8818-3c68eed48c10
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
