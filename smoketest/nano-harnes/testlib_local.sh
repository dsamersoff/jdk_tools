#!/bin/false
# Nano harness part
# Test bench specific code
# Include this file, don't run

_javac="unknown"
_jar="unknown"
_java="unknown"

# Could be: use, ignore, rebuild
_use_precompiled="use"
[ "x${NANOHAR_USE_PRECOMPILED}" != "x" ] && _use_precompiled="${NANOHAR_USE_PRECOMPILED}"
_precompiled="precompiled.tar.gz"

if [ "x${TESTJAVA}" = "x" ]; then
    echo "TESTJAVA is not set. Exiting"
    exit 1
fi

[ -f ${TESTJAVA}/bin/java ] && _java=${TESTJAVA}/bin/java
[ -f ${TESTJAVA}/bin/javac ] && _javac=${TESTJAVA}/bin/javac
[ -f ${TESTJAVA}/bin/jar ] && _jar=${TESTJAVA}/bin/jar

if [ ! -f "${_rt}/${_precompiled}" ]; then
    if [ "$_javac" = "unknown" ]; then
        if [ ! -f ${TESTJAVA}/bin/javac ]; then
            if [ "x${COMPJAVA}" = "x" ] ; then
                echo "TESTJAVA ${TESTJAVA} doesn't point to JDK with javac. COMPJAVA is required. Exiting"
                exit 1
            fi
            [ -f ${COMPJAVA}/bin/javac ] && _javac=${COMPJAVA}/bin/javac
            [ -f ${COMPJAVA}/bin/jar ] && _jar=${COMPJAVA}/bin/jar
        fi
    fi
fi

java_family() {
    java_family=`${TESTJAVA}/bin/java -version 2>&1 >/dev/null | sed -n -e 's/.*version "1\.8\..*/jdk8/p' -e 's/.*version "\([1-9][0-9]\)[\.-].*/jdkX/p'`
    l_echo ${java_family}
}

start_run_local() {
    set -o pipefail
    echo  "JAVA: ${_java} " | tee -a $_testlog
    echo  "JAVAC: ${_javac} " | tee -a $_testlog
    echo  "JAR: ${_jar} " | tee -a $_testlog
    ${TESTJAVA}/bin/java -version 2>&1 >/dev/null | tee -a "${_testlog}"
}

finish_run_local() {
    echo
}

extract_precompiled_if_exist() {
    if [ "${_use_precompiled}" != "use" ]; then
        return 1
    fi

    if [ -f "${_rt}/${_precompiled}" ]; then
       echo "Extracting ${_precompiled}" | tee -a $_testlog
       (
          cd "$_tmpdir/.."
          tar xvf ${_rt}/${_precompiled} --xattrs | tee -a "${_test_tools_log}"
       )
       return 0
    fi

    return 1
}

build_precompiled() {
    if [ "${_use_precompiled}" = "ignore" ]; then
        return 1
    fi

    if [ "${_use_precompiled}" = "rebuild" ]; then
        rm -f "${_rt}/${_precompiled}"
    fi

    if [ ! -f "${_rt}/${_precompiled}" ]; then
        # To update precompiled, test folder have to be writable

        echo "Building ${_precompiled}" | tee -a $_testlog
        (
            cd "$_tmpdir/.."
            tar czvf "${_rt}/${_precompiled}" --xattrs `basename $_tmpdir` | tee -a "${_test_tools_log}"
        )
    fi
 }

do_java() {
    set -o pipefail
    $TESTJAVA/bin/java $*
}

do_javac() {
    set -o pipefail
    [ "${_javac}" = "unknown" ] && exit 1
    echo "${_javac} $*" | tee -a "${_test_tools_log}"
    $_javac $* 2>&1 | tee -a "${_test_tools_log}"
    if [ $? -ne 0 ]; then
        l_echo "$_javac can't do $*. Exiting."
        exit 1
    fi
}

do_jar() {
   set -o pipefail
   [ "${_jar}" = "unknown" ] && exit 1
   echo "${_jar} $*" | tee -a "${_test_tools_log}"
   $_jar $* 2>&1 | tee -a "${_test_tools_log}"
}