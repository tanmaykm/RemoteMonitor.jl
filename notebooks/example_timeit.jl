addprocs(3)

for w in workers()
    remotecall_wait(()->include("timeit.jl"), w)
end
