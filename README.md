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

Based on UDP messages and OnlineStats.jl. IO in a separate task. Start monitoring by bringing up a simple notebook.
