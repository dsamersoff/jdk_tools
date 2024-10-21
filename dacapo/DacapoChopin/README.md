## This directory contains the Callback for Dacapo Chopin

This callback performs ```-n ``` iterations in total ```--window``` timed iteration (default is 3), CONVERGE methodology is not supported

At the end of each timed run it prints enhanced VM statistics of memory usage and compilation.

It's also possible to enable JFR recording during benchmark ```  -Dvmstat.enable_jfr=yes ``` default output is ``` vmstat_{benchmark}_{iteration}.jfr ``` but you can set different recording prefix: ```-Dvmstat.jfr_recording_prefix="/tmp/some_name_"```

### Building:

```
make DACAPO=<dacapo_chopin_jar_file>
```

#### Running:

```
   ${TESTJAVA}/bin/java -cp ${CALLBACK_DIR}:${DACAPO} -Dvmstat.enable_jfr=yes Harness -v -n 5 -c VMStatCallback <benchmarks>
```


