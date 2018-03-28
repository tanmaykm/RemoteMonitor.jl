__precompile__(true)
module RemoteMonitor

import Base: show, reset

using OnlineStats

export @timetrack, statetrack
export pids, events, entries, reset, show
export start_sender, start_listener, stop_listener

const enabled = Ref(true)
const listenon = Ref(true)

const TTimeStat = Series{0,Tuple{Mean,Variance,Extrema{Float64},Sum{Float64}},EqualWeight}
const TIMES = Dict{Tuple{Int64,Symbol},TTimeStat}()
const STATES = Dict{Tuple{Int64,Symbol}, String}()

const EVTCHAN = Channel{Any}(1024)

timesend(event::Symbol, timeval::Float64) = put!(EVTCHAN, (:time, myid(), event, timeval))
macro timetrack(event, expr)
    quote
        t1 = time()
        v = $(esc(expr))
        RemoteMonitor.enabled[] && timesend($(esc(event)), (time() - t1))
        v
    end
end
macro timetrack(expr)
    funcname = "$(current_module())_$(expr.args[1].args[1])"
    expr.args[2] = :(@timetrack Symbol($funcname) $(expr.args[2]))
    quote
        $(esc(expr))
    end
end

statetrack(event::Symbol, val) = put!(EVTCHAN, (:state, myid(), event, string(val)))

entries(coll::T, pid::Int64) where {T} = filter((k,v)->(k[1]==pid), coll)
entries(coll::T, event::Symbol) where {T} = filter((k,v)->(k[2]==event), coll)
entries(coll::T, pid::Int64, event::Symbol) where {T} = filter((k,v)->(k==(pid,event)), coll)

pids(coll) = Set([pid for (pid,event) in keys(coll)])
events(coll) = Set([event for (pid,event) in keys(coll)])
reset(coll::Dict{Tuple{Int64,Symbol}, T}) where {T<:Union{TTimeStat,String}} = empty!(coll)

macro get!(h, key0, default)
    return quote
        get!(()->$(esc(default)), $(esc(h)), $(esc(key0)))
    end
end
function val_stat(pub)
    (pub in keys(TIMES)) || (TIMES[pub] = Series(Mean(), Variance(), Extrema(), Sum()))
    TIMES[pub]
end

function show(io::IO, ::MIME{Symbol("text/plain")}, entries::Dict{Tuple{Int64,Symbol}, T}) where {T<:Union{TTimeStat,String}}
    for (k,v) in entries
        print_with_color(:red, io, "▦ $(k[1]) - $(k[2]): ", bold=true)
        println(io, v)
    end
end


set_stat!(pid, event, val) = fit!(get!(()->Series(Mean(), Variance(), Extrema(), Sum()), TIMES, (pid,event)), val)
set_state!(pid, event, val) = STATES[(pid,event)] = val

function process_vals(bytes)
    cmd, pid, event, val = deserialize(IOBuffer(bytes))
    cmd::Symbol
    pid::Int
    event::Symbol
    if cmd === :time
        set_stat!(pid, event, val)
    elseif cmd === :state
        set_state!(pid, event, val)
    end
    nothing
end

function start_sender()
    sender = UDPSocket()
    iob = IOBuffer()
    toaddr = srvraddr::IPv4
    toport = srvrport::Int

    while true
        msg = take!(EVTCHAN)
        serialize(iob, msg)
        send(sender, toaddr, toport, take!(iob))
    end
end

function start_listener()
    udpsock = UDPSocket()
    bind(udpsock, srvraddr, srvrport)
    while listenon[]
        try
            while listenon[]
                bytes = recv(udpsock)
                process_vals(bytes)
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

function __init__()
    global srvraddr = IPv4(get(ENV, "REMOTE_MONITOR_IP", "127.0.0.1"))
    global srvrport = parse(Int, get(ENV, "REMOTE_MONITOR_PORT", "9876"))
end

end # module
