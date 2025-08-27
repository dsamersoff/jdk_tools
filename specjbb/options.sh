#!/bin/bash
OPT_VERSION="3.02 2025-08-23"

# JAVA_HOME and JBB_HOME
JAVA_HOME="/opt/jdk-21"
JBB_HOME="/opt/specjbb2015-1.03a"

# Check active users, docker presence and other conditions that may affect results
# To run under jenkins you may need to disable this check
VALIDATE_ENV=Yes

# Use or not numactl
# 1 or 2 sockets supported
# GROUPS 0 CPU_BIND Yes means composite run bound to 1 socket
CPU_BIND=Yes

# Set OS parameters using sysctl
SET_SYSTEM=Yes

# Multivm setup, ignored in composite mode

# Number of Groups (TxInjectors mapped to Backend) to expect
# Number of TxInjectors is set to 1
# Support 0, 1, 2, 4 groups. 0 means composite
# Note: 4 groups on 1 socket and 3 groups doesn't have sense
GROUP_COUNT=2

# Tuning
# For controller in MVM mode
SPEC_OPTS="\
    -Dspecjbb.comm.connect.timeouts.connect=700000 \
    -Dspecjbb.comm.connect.timeouts.read=700000 \
    -Dspecjbb.comm.connect.timeouts.write=700000 \
    -Dspecjbb.customerDriver.threads.probe=80 \
    -Dspecjbb.forkjoin.workers.Tier1=80 \
    -Dspecjbb.forkjoin.workers.Tier2=1 \
    -Dspecjbb.forkjoin.workers.Tier3=16 \
    -Dspecjbb.heartbeat.period=100000 \
    -Dspecjbb.heartbeat.threshold=1000000 \
"

# For Backend in MVM mode
JAVA_OPTS="\
    -server \
    -Xms124g \
    -Xmx124g \
    -Xmn114g \
    -XX:SurvivorRatio=20 \
    -XX:MaxTenuringThreshold=15 \
    -XX:+UseLargePages \
    -XX:LargePageSizeInBytes=2m \
    -XX:+UseParallelGC \
    -XX:+AlwaysPreTouch \
    -XX:-UseAdaptiveSizePolicy \
    -XX:-UsePerfData \
    -XX:ParallelGCThreads=40 \
    -XX:+UseTransparentHugePages \
    -XX:+UseCompressedOops \
    -XX:ObjectAlignmentInBytes=32 \
"

# JDK8  DEBUG_OPTS="-XX:+PrintGC -XX:+PrintGCDetails -Xloggc"
DEBUG_OPTS="-Xlog:gc=debug,heap*=debug,phases*=debug,gc+age=debug"

SYSCTL_OPTS="\
    net.ipv4.conf.lo.accept_local=1 \
    vm.swappiness=0 \
    kernel.shmmax=16777216 \
"

SYSFILE_OPTS="\
    /sys/kernel/mm/transparent_hugepage/enabled=always \
    /sys/kernel/mm/transparent_hugepage/defrag=always \
    /proc/sys/kernel/numa_balancing=0 \
"


#--------- MVM mode only settings

# Benchmark options for Controller JVM
SPEC_OPTS_CTL="\
    ${SPEC_OPTS} \
    -Dspecjbb.group.count=$GROUP_COUNT \
    -Dspecjbb.txi.pergroup.count=1 \
"

SPEC_OPTS_TI="\
"

SPEC_OPTS_BE="\
"

# Controller java options
JAVA_OPTS_CTL="\
        -XX:+UseParallelGC \
        -XX:ParallelGCThreads=3 \
        -Xms2g  \
        -Xmx2g  \
        -Xmn1536m \
"

# Injector java options
JAVA_OPTS_TI="\
        -XX:+UseParallelGC \
        -XX:ParallelGCThreads=3 \
        -Xms2g  \
        -Xmx2g  \
        -Xmn1536m \
"

# Backend java options
JAVA_OPTS_BE="\
        ${JAVA_OPTS} \
"

# ----- Validation and options pre-processing ----------------
# Nothing to edit below this line
# ---------------------------------

if [ "x$CPU_BIND" = "xYes" ]
then
    NUMA_CMD="/usr/bin/numactl --localalloc --cpunodebind"
fi

# Parameter Validation
JAVA="$JAVA_HOME/bin/java"
JAVA_FAMILY=`$JAVA -version 2>&1 >/dev/null | sed -n -e 's/.*version "1\.8\..*/JDK_8/p' -e 's/.*version "[1-9][0-9]\..*/JDK_X/p'`
if [ "$JAVA_FAMILY" == "" ]
then
    echo "ERROR: Could not determine version of 'java' executable. Exiting."
    exit 1
fi

if [ ! -e "$JBB_HOME/config" ]
then
    echo "ERROR: Can't stat '$JBB_HOME/config' check JBB_HOME."
    exit 1
fi

# Set system parameters
if [ $SET_SYSTEM = "Yes" ]
then
        nn=`id -u`
        if [ ${nn} != "0" ]
        then
            echo "ERROR: Should be run as root."
            exit 1
        fi

        for opt in $SYSCTL_OPTS
        do
            sysctl -w $opt
        done

        for opt in $SYSFILE_OPTS
        do
            filename=`echo $opt | sed -n -e 's/=.*$//p'`
            value=`echo $opt | sed -n -e 's/.*=//p'`
            echo $value | tee $filename
        done
fi

# ----- Reporting ----------------
echo "VERSION: $OPT_VERSION" > options.txt
echo "JBB_HOME: $JBB_HOME" >> options.txt
echo "JAVA_HOME: $JAVA_HOME" >> options.txt
echo "JAVA_FAMILY: $JAVA_FAMILY" >> options.txt
echo "GROUP_COUNT: $GROUP_COUNT" >> options.txt
echo "CPU_BIND: $CPU_BIND" >> options.txt
echo "$SPEC_OPTS"  | sed -e 's/ \+/\nSPEC_OPTS: /g' >> options.txt
echo "$JAVA_OPTS"  | sed -e 's/ \+/\nJAVA_OPTS: /g' >> options.txt
echo "DEBUG_OPTS: $DEBUG_OPTS" >> options.txt
echo "$SYSCTL_OPTS" | sed -e 's/ \+/\nSYSCTL_OPTS: /g' >> options.txt
echo "$SYSFILE_OPTS" | sed -e 's/ \+/\nSYSFILE_OPTS: /g' >> options.txt
echo "USING JAVA:"
$JAVA_HOME/bin/java -version >> options.txt 2>&1

# END of OPTIONS
