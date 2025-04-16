#!/bin/sh

TESTJAVA=/opt/jdk-21
DACAPO=/opt/dacapo/dacapo-chopin.jar
CALLBACK_DIR=/opt/dacapo/dacapo-callback
BENCHES=`${TESTJAVA}/bin/java -jar ${DACAPO} -l`
TODAY=`date '+%y-%m-%d_%H%M%S'`

RUN="perf"
BENCHES="fop"

echo "${BENCHES}" > benchmarks_${TODAY}.lst

if [ "x${RUN}" = "xraw" ]
then
	for b in ${BENCHES} 
	do
            ${TESTJAVA}/bin/java -cp ${DACAPO} Harness -v ${b} 2>&1 | tee ${b}_${TODAY}.log
	done
fi

if [ "x${RUN}" = "xvmstat" ]
then
	for b in ${BENCHES} 
	do
    		${TESTJAVA}/bin/java -cp ${CALLBACK_DIR}:${DACAPO} -Dvmstat.csv=yes -Dvmstat.enable_jfr=no Harness -v -n 5 -c VMStatCallback ${b} 2>&1 | tee ${b}_${TODAY}_cb.log
	done
fi

if [ "x${RUN}" = "xperf" ]
then
	for b in ${BENCHES} 
	do
          ${TESTJAVA}/bin/java -cp ${CALLBACK_DIR}:${DACAPO} -Dperf.lib=${CALLBACK_DIR}/perf_callback.so -Dperf.type=HARDWARE -Dperf.event=1,3 Harness -v -n 5 -c PerfCallback ${b} 2>&1 | tee ${b}_${TODAY}_cb.log
	done
fi

