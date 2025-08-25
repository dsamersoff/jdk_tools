#!/bin/bash
# Script for running SPECjbb2015, supports JDK11 or later

VERSION="3.01 2025-08-23"

NUM_OF_RUNS=1
[ "x$1" != "x" ] && NUM_OF_RUNS=$1

script_path=$(cd "$(dirname "$0")"; pwd)

# For options look at options.sh
. $script_path/options.sh

# Run TX + BE, optionally with numa
# Parameters: GroupID, SocketID
function run_group() {
    gnum=$1
    cpunode=$2

    [ "x$NUMA" = "xYes" ] && THE_NUMA_CMD="${NUMA_CMD}=$cpunode"

    GROUPID=Group$gnum
    echo -e "\nStarting JVMs from $GROUPID:"

    # Injector
    JVMID=tiJVM$gnum
    TI_NAME=$GROUPID.TxInjector.$JVMID
    DEBUG_OPTS_TI="${DEBUG_OPTS}:${TI_NAME}.gc.log"

    echo "    Start $TI_NAME"
    CMD_TI="$JAVA $JAVA_OPTS_TI $DEBUG_OPTS_TI $SPEC_OPTS_TI -jar ${JBB_HOME}/specjbb2015.jar -m TXINJECTOR -G=$GROUPID -J=$JVMID"
    echo $THE_NUMA_CMD $CMD_TI > ${TI_NAME}.cmdline.txt
    $THE_NUMA_CMD $CMD_TI > $TI_NAME.log 2>&1 &

    echo -e "\t$TI_NAME PID = $!"

    # Backend
    JVMID=beJVM$gnum
    BE_NAME=$GROUPID.Backend.$JVMID
    DEBUG_OPTS_BE="${DEBUG_OPTS}:${BE_NAME}.gc.log"

    echo "    Start $BE_NAME"
    CMD_BE="$JAVA $JAVA_OPTS_BE $DEBUG_OPTS_BE $SPEC_OPTS_BE -jar ${JBB_HOME}/specjbb2015.jar -m BACKEND -G=$GROUPID -J=$JVMID"
    echo $THE_NUMA_CMD $CMD_BE > ${BE_NAME}.cmdline.txt
    $THE_NUMA_CMD $CMD_BE > $BE_NAME.log 2>&1 &

    echo -e "\t$BE_NAME PID = $!"
}

echo "RunMe $VERSION Numa: $NUMA GROUPS: $GROUP_COUNT ($TI_VMS_COUNT)"
echo "Using JDK: $JAVA_HOME"
echo "JAVA Family is $JAVA_FAMILY"
echo "JBB: $JBB_HOME"

if [ "$VALIDATE_ENV" == "Yes" ]
then
    if ps ax | grep -v grep | grep -q specjbb
    then
        echo "ERROR: SPECjbb is already running."
        exit 1
    fi

    if pgrep -c java >/dev/null
    then
        echo "Warning! java is already running. Results might suffer."
    fi

    if pgrep -c docker >/dev/null
    then
        echo "Warning! DOCKER is running. Results might suffer."
    fi
fi

for ((n=1; $n<=$NUM_OF_RUNS; n=$n+1)); do

    # Create result directory
    timestamp=$(date '+%y-%m-%d_%H%M%S')
    result=./$timestamp
    mkdir $result

    # Copy current config to the result directory
    cp -r ${JBB_HOME}/config $result

    cd $result

    # Save run configuration
    cp /proc/meminfo .
    cp /proc/cpuinfo .
    cp /proc/version .

    if [ -e $script_path/options.txt ]
    then
        cp $script_path/options.txt .
    fi

    cp $script_path/options.sh .
    cp $script_path/README.md .

    echo "Run $n: $timestamp"

    if [ $GROUP_COUNT -ge 1 ]
    then
        echo "Launching SPECjbb2015 in MultiJVM mode..."
        echo
        echo "Start Controller JVM"
        $JAVA $JAVA_OPTS_CTL $SPEC_OPTS_CTL -jar ${JBB_HOME}/specjbb2015.jar -m MULTICONTROLLER 2>controller.log > controller.out &
        CTRL_PID=$!
        echo "Controller PID = $CTRL_PID"
        sleep 5

        # Support 1, 2, 4 groups
        run_group 0 0
        if [ $GROUP_COUNT -ge 2 ]
        then
            run_group 1 1
        fi
        if [ $GROUP_COUNT -ge 4 ]
	    then
            run_group 2 0
            run_group 3 1
        fi

        echo
        echo "SPECjbb2015 is running..."
        echo "Monitoring $result/controller.out for progress"
        tail --pid=${CTRL_PID} -f ./controller.out
        echo
        echo "Controller has stopped"

    else
        echo "Launching SPECjbb2015 in CompositeJVM mode..."
        [ "x$NUMA" = "xYes" ] && NUMA_CMD="${NUMA_CMD}=0"
        NAME="Composite"
        DEBUG_OPTS="${DEBUG_OPTS}:${NAME}.gc.log"
        CMD="$JAVA $JAVA_OPTS $DEBUG_OPTS $SPEC_OPTS -jar ${JBB_HOME}/specjbb2015.jar -m COMPOSITE"
        echo $NUMA_CMD $CMD > ${NAME}.cmdline.txt
        $NUMA_CMD $CMD > $NAME.log 2>&1 &

        PID=$!
        echo -e "\t$NAME PID = $PID"
        echo
        echo "SPECjbb2015 is running..."
        echo "Monitoring $result/${NAME}.log for progress"
        tail --pid=${BE_PID} -f ./${NAME}.log
    fi

    echo "SPECjbb2015 has finished"
    echo

    cd ..

done

exit 0
