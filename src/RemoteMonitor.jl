__precompile__(true)
module RemoteMonitor

import Base: show, reset

using OnlineStats, DataStructures, TimerOutputs

export @timetrack, statetrack, logmsg, @remotetimeit
export pids, events, entries, reset, show
export start_sender, stop_sender, start_listener, stop_listener, stop_timeit_sender, start_timeit_sender
export Collector, StatsCollector, StateCollector, WindowCollector, TimeStatsCollector, LogsCollector, AnyStateCollector, TimeItCollector

const enabled = Ref(false)
const listenon = Ref(true)
const daemon = Task[]

const MonKey = Tuple{Int,Symbol}
abstract type Collector end
const EventChannel = Channel{Any}(1024)
const NoOpEvent = (:noop, 0, :noop, 0)
const RegisteredCollectors = Dict{Symbol, Collector}()
register(spec::Tuple) = register(spec[1], spec[2])
register(name::Symbol, collector) = RegisteredCollectors[name] = collector
register(collector::Collector) = RegisteredCollectors[collector.cmd] = collector
unregister(collector::Collector) = unregister(collector.cmd)
unregister(cmd::Symbol) = try delete!(RegisteredCollectors, cmd) end

#----------------------------------------------------------
# Generic collectors
#----------------------------------------------------------
struct StatsCollector{T<:Series} <: Collector
    cmd::Symbol
    data::Dict{MonKey,T}
    startvalfn::Function
    StatsCollector{T}(cmd, startvalfn) where {T<:Series} = new(cmd, Dict{MonKey,T}(), startvalfn)
end
assimilate(collector::StatsCollector{T}, pid::Int, event::Symbol, val) where {T} = (fit!(get!(collector.startvalfn, collector.data, (pid,event)), val); nothing)

struct StateCollector{T} <: Collector
    cmd::Symbol
    data::Dict{MonKey,T}
    StateCollector{T}(cmd) where {T} = new(cmd, Dict{MonKey,T}())
end
assimilate(collector::StateCollector{T}, pid::Int, event::Symbol, val) where {T} = (collector.data[(pid,event)] = val; nothing)

struct WindowCollector{T} <: Collector
    cmd::Symbol
    data::Dict{MonKey,CircularBuffer{T}}
    sz::Int
    WindowCollector{T}(cmd, sz) where {T} = new(cmd, Dict{MonKey,CircularBuffer{T}}(), sz)
end
assimilate(collector::WindowCollector{T}, pid::Int, event::Symbol, val) where {T} = (push!(get!(()->CircularBuffer{T}(collector.sz), collector.data, (pid,event)), val); nothing)

#----------------------------------------------------------
# TimeStat collector
#----------------------------------------------------------
const TTimeStat = typeof(Series(Mean(), Variance(), Extrema(), Sum()))
TimeStatsCollector() = StatsCollector{TTimeStat}(:time, ()->Series(Mean(), Variance(), Extrema(), Sum()))

timesend(event::Symbol, timeval::Float64) = put!(EventChannel, (:time, myid(), event, timeval))
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

function show(io::IO, ::MIME{Symbol("text/plain")}, entries::Dict{MonKey, TTimeStat})
    for (k,v) in entries
        print_with_color(:red, io, "▦ $(k[1]) - $(k[2]): ", bold=true)
        println(io, v)
    end
end

#----------------------------------------------------------
# Log collector
#----------------------------------------------------------
LogsCollector(sz=100) = WindowCollector{String}(:log, sz)
logmsg(thread::Symbol, msgs...) = RemoteMonitor.enabled[] && put!(EventChannel, (:log, myid(), thread, join(map(string, msgs))))

function show(io::IO, ::MIME{Symbol("text/plain")}, entries::Dict{MonKey,CircularBuffer{String}})
    for (k,v) in entries
        print_with_color(:red, io, "▦ $(k[1]) - $(k[2]):\n", bold=true)
        for msg in v
            println(io, msg)
        end
    end
end

#----------------------------------------------------------
# Generic State Collector
#----------------------------------------------------------
AnyStateCollector() = StateCollector{Any}(:state)
statetrack(event::Symbol, val) = RemoteMonitor.enabled[] && put!(EventChannel, (:state, myid(), event, val))

function show(io::IO, ::MIME{Symbol("text/plain")}, entries::Dict{MonKey,Any})
    for (k,v) in entries
        print_with_color(:red, io, "▦ $(k[1]) - $(k[2]): ", bold=true)
        println(io, v)
    end
end

#----------------------------------------------------------
# TimeIt collector
#----------------------------------------------------------
TimeItCollector() = (:timeit, StateCollector{TimerOutput}(:timeit))

const continue_timeit_send = Ref(false)
const timeit_sender_task = Task[]
const to = TimerOutput()
macro remotetimeit(name, expr)
    quote
        @timeit(to,string($(esc(name))),$(esc(expr)))
    end
end

function stop_timeit_sender()
    global continue_timeit_send
    if continue_timeit_send[] && !isempty(timeit_sender_task)
        t = pop!(timeit_sender_task)
        continue_timeit_send[] = false
        wait(t)
    end
    nothing
end

function start_timeit_sender(name=:timeit, cmd=:timeit, interval=2)
    global continue_timeit_send
    if isempty(timeit_sender_task)
        push!(timeit_sender_task, @schedule begin
            continue_timeit_send[] = true
            while continue_timeit_send[]
                sleep(interval)
                put!(RemoteMonitor.EventChannel, (cmd, myid(), name, to))
            end
        end)
    end
end

function show(io::IO, ::MIME{Symbol("text/plain")}, entries::Dict{MonKey,TimerOutput})
    for (k,v) in entries
        print_with_color(:red, io, "▦ $(k[1]) - $(k[2]):\n", bold=true)
        println(v)
    end
end

#----------------------------------------------------------
# Data accessors
#----------------------------------------------------------
entries(name::Symbol, qualifiers...) = _entries(RegisteredCollectors[name].data, qualifiers...)
_entries(coll::T, pid::Int64) where {T} = filter((k,v)->(k[1]==pid), coll)
_entries(coll::T, event::Symbol) where {T} = filter((k,v)->(k[2]==event), coll)
_entries(coll::T, pid::Int64, event::Symbol) where {T} = filter((k,v)->(k==(pid,event)), coll)

pids(name::Symbol) = _pids(RegisteredCollectors[name].data)
events(name::Symbol) = _events(RegisteredCollectors[name].data)
reset(name::Symbol) = _reset(RegisteredCollectors[name].data)
reset() = (reset.(collect(keys(RegisteredCollectors))); nothing)
_pids(coll) = Set([pid for (pid,event) in keys(coll)])
_events(coll) = Set([event for (pid,event) in keys(coll)])
_reset(coll::Dict{MonKey, T}) where {T} = (empty!(coll); nothing)


#----------------------------------------------------------
# Daemons
#----------------------------------------------------------
function process_vals(bytes)
    cmd, pid, event, val = deserialize(IOBuffer(bytes))
    cmd::Symbol
    pid::Int
    event::Symbol

    for coll in values(RegisteredCollectors)
        if coll.cmd === cmd
            assimilate(coll, pid, event, val)
        end
    end
    nothing
end

start_listener(collectors...) = (register.(collectors); start_listener())
function start_listener()
    if listenon[] && isempty(daemon)
        t = @schedule begin
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
        push!(daemon, t)
    end
    nothing
end

function stop_listener()
    if listenon[]
        listenon[] = false

        if !isempty(daemon)
            t = shift!(daemon)

            if !istaskdone(t)
                iob = IOBuffer()
                serialize(iob, NoOpEvent)
                sender = UDPSocket()
                send(sender, srvraddr, srvrport, take!(iob))
                wait(t)
            end
        end
    end
    nothing
end

function start_sender()
    enabled[] = true
    if isempty(daemon)
        t = @schedule begin
            sender = UDPSocket()
            iob = IOBuffer()
            toaddr = srvraddr::IPv4
            toport = srvrport::Int

            while enabled[] || isready(EventChannel)
                try
                    while enabled[] || isready(EventChannel)
                        serialize(iob, take!(EventChannel))
                        send(sender, toaddr, toport, take!(iob))
                    end
                catch ex
                    @show ex
                end
            end
            close(sender)
        end
        push!(daemon, t)
    end
    nothing
end

function stop_sender()
    if enabled[]
        enabled[] = false

        if !isempty(daemon)
            t = shift!(daemon)

            if !istaskdone(t)
                put!(EventChannel, NoOpEvent)
                wait(t)
                while isready(EventChannel)
                    take!(EventChannel)
                end
            end
        end
    end
    nothing
end

function __init__()
    global srvraddr = IPv4(get(ENV, "REMOTE_MONITOR_IP", "127.0.0.1"))
    global srvrport = parse(Int, get(ENV, "REMOTE_MONITOR_PORT", "9876"))
end

end # module
