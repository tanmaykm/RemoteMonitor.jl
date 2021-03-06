# RemoteMonitor

[![Build Status](https://travis-ci.org/tanmaykm/RemoteMonitor.jl.svg?branch=master)](https://travis-ci.org/tanmaykm/RemoteMonitor.jl)
[![Coverage Status](https://coveralls.io/repos/tanmaykm/RemoteMonitor.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/tanmaykm/RemoteMonitor.jl?branch=master)
[![codecov.io](http://codecov.io/github/tanmaykm/RemoteMonitor.jl/coverage.svg?branch=master)](http://codecov.io/github/tanmaykm/RemoteMonitor.jl?branch=master)

Tool to remotely monitor Julia processes and events. Track performace of internal functions, count/plot events, tail logs.

Goals:
- lightweight
- decoupled
- minimal configuration
- extensible
- does not interfere with task context switching

Based on UDP messages, uses OnlineStats.jl and TimerOutputs.jl. IO in a separate task. Start monitoring by bringing up a simple notebook.

## Example

Julia examples to accompany are [here](notebooks) to serve as a simple examples.

- Tracking parallel Julia (tasks and processes)
    - [Tracker.ipynb](notebooks/Tracker.ipynb)
    - [example_map.jl](notebooks/example_pmap.jl)
    - [mcpi.jl](notebooks/mcpi.jl)
- Using `TimerOutputs`
    - [TimeIt.ipynb](notebooks/TimeIt.ipynb)
    - [example_timeit.jl](notebooks/example_timeit.jl)
    - [timeit.jl](notebooks/timeit.jl)
