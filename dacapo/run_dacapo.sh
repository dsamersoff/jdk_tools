#!/bin/sh
TESTJAVA=/opt/jdk-21
DACAPO=/opt/dacapo/dacapo-chopin.jar
CALLBACK_DIR=/opt/dacapo/dacapo-callback
BENCHES=`${TESTJAVA}/bin/java -jar ${DACAPO} -l`
TODAY=`date '+%y-%m-%d_%H%M%S'`
CPU=0

RUN="perf"
# BENCHES="fop"
NUMA="numactl --cpunodebind=${CPU} --localalloc "
# NUMA="taskset -c 16,17,18,19 "

echo "${BENCHES}" > benchmarks_${TODAY}.lst

if [ "x${RUN}" = "xraw" ]
then
    for b in ${BENCHES}
    do
            ${NUMA} ${TESTJAVA}/bin/java -cp ${DACAPO} Harness -v ${b} 2>&1 | tee ${b}_${TODAY}.log
    done
fi

if [ "x${RUN}" = "xvmstat" ]
then
    for b in ${BENCHES}
    do
        ${NUMA} ${TESTJAVA}/bin/java -cp ${CALLBACK_DIR}:${DACAPO} -Dvmstat.csv=yes -Dvmstat.enable_jfr=no Harness -v -n 5 -c VMStatCallback ${b} 2>&1 | tee ${b}_${TODAY}_cb.log
    done
fi

if [ "x${RUN}" = "xperf" ]
then
    for b in ${BENCHES}
    do
        ${NUMA} ${TESTJAVA}/bin/java -cp ${CALLBACK_DIR}:${DACAPO} -Dperf.lib=${CALLBACK_DIR}/perf_callback.so -Dperf.type=RAW -Dperf.event=17,2,5 Harness -v -n 5 -c PerfCallback ${b} 2>&1 | tee ${b}_${TODAY}_cb.log
    done
fi

