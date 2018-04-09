using TimerOutputs
using RemoteMonitor

nest1() = sleep(0.25)
nest2() = (sleep(0.25); @remotetimeit "nest1" nest1())
nest3() = (sleep(0.25); @remotetimeit "nest2" nest2())
nest4() = (sleep(0.25); @remotetimeit "nest3" nest3())
nest5() = (sleep(0.25); @remotetimeit "nest4" nest4())
nest6() = (sleep(0.25); @remotetimeit "nest5" nest5())

start_timeit_sender()
start_sender()

nest6()

stop_timeit_sender()
stop_sender()
