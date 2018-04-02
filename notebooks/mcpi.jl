# use this in combination with ExampleTracker.ipynb to get started
using RemoteMonitor

@timetrack function darts_in_circle(N)
    n = 0
    for i in 1:N
        if rand()^2 + rand()^2 < 1
            n += 1
        end
    end
    logmsg(:worker_task, "n = ", n)
    n
end

@timetrack function estimate_pi(N, loops)
    n = sum(pmap((x)->darts_in_circle(N), 1:loops))
    logmsg(:main_task, "estimated pi = ", 4*n/(loops*N))
    4 * n / (loops * N)
end

# start the RemoteMonitor sender task
start_sender()
