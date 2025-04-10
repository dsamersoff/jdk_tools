## This directory contains Callbacks for Dacapo Chopin

### Building:

make sure that JAVA_HOME points to correct JDK

```
make DACAPO=<dacapo_chopin_jar_file>
```

### VMStatCallback

This callback performs ```-n ``` iterations in total ```--window``` timed iteration (default is 3), CONVERGE methodology is not supported

At the end of each timed run it prints enhanced VM statistics of memory usage and compilation.

It's also possible to enable JFR recording during benchmark ```  -Dvmstat.enable_jfr=yes ``` default output is ``` vmstat_{benchmark}_{iteration}.jfr ``` but you can set different recording prefix: ```-Dvmstat.jfr_recording_prefix="/tmp/some_name_"```

#### Running:

```
   ${TESTJAVA}/bin/java -cp ${CALLBACK_DIR}:${DACAPO} -Dvmstat.enable_jfr=yes Harness -v -n 5 -c VMStatCallback <benchmarks>
```

### PerfCallback

This callback can measure and display perf counters, one counter per run. For possible perf.type and perf.event values check ./linux/perf_event.h
**Perf counter access requires root privileges**

#### Running:

```
   ${TESTJAVA}/bin/java -cp ${CALLBACK_DIR}:${DACAPO} -Dperf.lib=${CALLBACK_DIR}/perf_callback.so -Dperf.type=HARDWARE -Dperf.event=1 Harness -v -n 5 -c PerfCallback <benchmark>
```
