# use this in combination with ExampleTracker.ipynb to get started

addprocs(2)

using RemoteMonitor

@everywhere include("mcpi.jl")

# fire off a parallel request (`pmap`) from the master
estimate_pi(10^5, 10^4)
