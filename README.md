# JSM2021
Materials for a [presentation](https://ww2.amstat.org/meetings/jsm/2021/onlineprogram/ActivityDetails.cfm?SessionID=220619) at the Joint Statistical Meetings 2021

- [*Cécile Ané*](http://pages.stat.wisc.edu/~ane/), [*Claudia Solis-Lemus*](https://crsl4.github.io/pages/about.html), and [*Douglas Bates*](http://pages.stat.wisc.edu/~bates/)

Resources:
- The place to begin learning about the Julia language is https://julialang.org
- This is also where Julia can be [downloaded](https://julialang.org/downloads) for different computer types and operating systems.
- This presentation uses "Pluto" notebooks, which are Julia source files (a `.jl` file extension) with structured comments.
    * Start julia and run
    ```julia
    using Pluto # you may get a prompt about installing the Pluto package, if so accept the installation
    Pluto.run()
    ```
    * At this point you are switched to a browser.  Use the `Open File` box to select the notebook file.
    * These Pluto notebooks have a `Presentation Mode` button that makes subsections and sections appear as slides.  You can skip it if you are just reading them.
- A notebook such as `1intro.jl` has a companion file `1intro.jl.html` which can be viewed in a browser. Although the `html` file itself is not interactive, there is a button on the top left that provides instructions (similar to those above) for downloading and installing Julia and Pluto and running the notebook.
- One section of the talk, on using the `RCall` package, will be presented as a Jupyter notebook to be able to display plots from R.
- A good source for information on Julia packages is https://juliahub.com/ui/Packages
- The chapter [*Why Julia*](https://storopoli.io/Bayesian-Julia/pages/1_why_Julia/) in *Bayesian Statistics using Julia and Turing* provides a good narrative introduction to important features of Julia for Statistics and Data Science.
- [*Julius Krumbiegel's blog*](https://jkrumbiegel.com) provides short, accessible articles on some of the great data science tools he develops.
