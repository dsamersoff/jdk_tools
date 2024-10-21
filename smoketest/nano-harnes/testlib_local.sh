# Include this file, don't run

start_run_local() {
    if [ "x${TESTJAVA}" != "x" ]; then
        echo -n "java: ${TESTJAVA} " | tee -a $_testlog
        ${TESTJAVA}/bin/java -version 2>&1 >/dev/null | tee -a $_testlog
    fi
}

finish_run_local() {
    echo
}

do_java() {
    $TESTJAVA/bin/java $*
}

java_family() {
    java_family="unknown"
    if [ "x${TESTJAVA}" != "x" ]; then
        java_family=`${TESTJAVA}/bin/java -version 2>&1 >/dev/null | sed -n -e 's/.*version "1\.8\..*/jdk8/p' -e 's/.*version "\([1-9][0-9]\)[\.-].*/jdkX/p'`
    fi
    echo ${java_family}
}
