__precompile__(true)
module RemoteMonitor

using OnlineStats

export @timetrack, get_stats_keys, get_stats, get_stat, print_stats, start_listener, stop_listener, reset_stats, stats_keys, stats_pids, stats_events

const listenon = Ref(true)

const TTimeStat = Series{0,Tuple{Mean,Variance,Extrema{Float64},Sum{Float64}},EqualWeight}
const TIMESTATS = Dict{Tuple{Int64,Symbol},TTimeStat}()

function __init__()
    global sender = UDPSocket()
    global srvraddr = IPv4(get(ENV, "REMOTE_MONITOR_IP", "127.0.0.1"))
    global srvrport = parse(Int, get(ENV, "REMOTE_MONITOR_PORT", "9876"))
end     

function timesend(event, timeval)
   iob = IOBuffer()
   serialize(iob, (myid(), event, timeval))
   send(sender, srvraddr, srvrport, take!(iob))
   nothing
end 
    
macro timetrack(event, expr)
    quote
        t1 = time()
        v = $(esc(expr))
        timesend($(esc(event)), (time() - t1))
        v
    end
end

function get_stat(pub)
    (pub in keys(TIMESTATS)) || (TIMESTATS[pub] = Series(Mean(), Variance(), Extrema(), Sum()))
    TIMESTATS[pub]
end
get_stats(pid::Int64) = filter((k,v)->(k[1]==pid), TIMESTATS)
get_stats(event::Symbol) = filter((k,v)->(k[2]==event), TIMESTATS)
get_stats() = TIMESTATS

stats_keys() = collect(keys(TIMESTATS))
stats_pids() = Set([pid for (pid,event) in keys(TIMESTATS)])
stats_events() = Set([event for (pid,event) in keys(TIMESTATS)])

function print_stats(stats, io=STDOUT)
    for (k,v) in stats
        println("$(k[1]) - $(k[2])")
        println(v)
    end
end

function set_stat!(bytes::Vector{UInt8})
    pid,event,val = deserialize(IOBuffer(bytes))
    fit!(get_stat((pid,event)), val)
    nothing
end

function reset_stats()
    empty!(TIMESTATS)
    nothing
end

function start_listener()
    udpsock = UDPSocket()
    bind(udpsock, srvraddr, srvrport)
    while listenon[]
        try
            while listenon[]
                set_stat!(recv(udpsock))
            end
        catch ex
            @show ex
        end
    end
    close(udpsock)
end

function stop_listener()
    listenon[] = false
    nothing
end

end # module
