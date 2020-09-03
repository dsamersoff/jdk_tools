#!/bin/bash

VERSION="2.05 2020-08-27"

###############################################################################
# Sample script for running SPECjbb2015 in MultiJVM mode.
# 
# This sample script demonstrates running the Controller, TxInjector(s) and 
# Backend(s) in separate JVMs on the same server.
###############################################################################

# Number of successive runs
if [ "x$1" == "x" ]
then	
  NUM_OF_RUNS=4
else
  NUM_OF_RUNS=$1
fi

script_path=$(cd "$(dirname "$0")"; pwd)

# For options look at options.sh
. $script_path/options.sh

# Functions

# Run TX + BE, with numa
# Parameters GroupID, SocketID

function run_group() {
    gnum=$1
    cpunode=$2

    GROUPID=Group$gnum
    echo -e "\nStarting JVMs from $GROUPID:"

    JVMID=tiJVM$gnum
    TI_NAME=$GROUPID.TxInjector.$JVMID
    DEBUG_OPTS_TI="-Xlog:gc=debug,heap*=debug,phases*=debug,gc+age=debug:${TI_NAME}.gc.log"

    echo "    Start $TI_NAME"
    CMD_TI="$JAVA $JAVA_OPTS_TI $DEBUG_OPTS_TI $SPEC_OPTS_TI -jar ${JBB_HOME}/specjbb2015.jar -m TXINJECTOR -G=$GROUPID -J=$JVMID $MODE_ARGS_TI" 
    echo $CMD_TI > ${TI_NAME}.cmdline.txt

    if [ "x$NUMA" = "xYes" ]
    then
      numactl --cpunodebind=$cpunode --localalloc $CMD_TI > $TI_NAME.log 2>&1 &
    else  
      $CMD_TI > $TI_NAME.log 2>&1 &
    fi  
    echo -e "\t$TI_NAME PID = $!"

    sleep 5 

    JVMID=beJVM$gnum
    BE_NAME=$GROUPID.Backend.$JVMID
    DEBUG_OPTS_BE="-Xlog:gc=debug,heap*=debug,phases*=debug,gc+age=debug:${BE_NAME}.gc.log"

    echo "    Start $BE_NAME"
    CMD_BE="$JAVA $JAVA_OPTS_BE $DEBUG_OPTS_BE $SPEC_OPTS_BE -jar ${JBB_HOME}/specjbb2015.jar -m BACKEND -G=$GROUPID -J=$JVMID $MODE_ARGS_BE"
    echo $CMD_BE > ${BE_NAME}.cmdline.txt

    if [ "x$NUMA" = "xYes" ]
    then
      numactl --cpunodebind=$cpunode --localalloc $CMD_BE > $BE_NAME.log 2>&1 &
    else
      $CMD_BE > $BE_NAME.log 2>&1 &
    fi  

    echo -e "\t$BE_NAME PID = $!"
    sleep 5 
}

###############################################################################
# This benchmark requires a JDK7 compliant Java VM.  If such a JVM is not on
# your path already you must set the JAVA environment variable to point to
# where the 'java' executable can be found.
#
# If you are using a JDK9 (or later) Java VM, see the FAQ at:
#                       https://spec.org/jbb2015/docs/faq.html
# and the Known Issues document at:
#                       https://spec.org/jbb2015/docs/knownissues.html
###############################################################################

echo "RunMe $VERSION Numa: $NUMA Pages: $PAGES ($mem_max/$mem_young) GROUPS: $GROUP_COUNT"

nn=`id -u`
if [ ${nn} != "0" ]; then
    echo "ERROR: Should be run as root. Exiting."
    exit 1
fi

if ps ax | grep -v grep | grep -q specjbb ; then
    echo "SPECjbb is already running. Exiting"
    exit 1
fi	
if pgrep -c java >/dev/null; then
    echo "Warning! java is already running. Results might suffer"
fi	

if pgrep -c docker >/dev/null; then
    echo "Warning! DOCKER is running. Results might suffer"
fi	

JAVA="$JAVA_HOME/bin/java"

which $JAVA > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Could not find a 'java' executable. Please set the JAVA environment variable or update the PATH."
    exit 1
fi

if [ -e $script_path/set_system.sh ]; then
   echo -e "\nSet system configuration"
   echo "FILE: $script_path/set_system.sh"
   . $script_path/set_system.sh
   echo ""
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

  if [ -e $script_path/options.txt ]; then
     cp $script_path/options.txt .
  fi

  cp $script_path/options.sh .
  cp $script_path/set_system.sh .
  cp $script_path/README.md .

  echo "Run $n: $timestamp"

  # Support 1, 2 and 4 groups on 2 sockets
  # - 4 groups on 1 socket and 3 groups doesn't have sence
  # - run composite for 0 groups

  if [ $GROUP_COUNT -ge 1 ]
  then 	  
     echo "Launching SPECjbb2015 in MultiJVM mode..."
     echo
     echo "Start Controller JVM"
     $JAVA $JAVA_OPTS_C $SPEC_OPTS_C -jar ${JBB_HOME}/specjbb2015.jar -m MULTICONTROLLER $MODE_ARGS_C 2>controller.log > controller.out &
     CTRL_PID=$!
     echo "Controller PID = $CTRL_PID"
     sleep 5

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
     echo "Please monitor $result/controller.out for progress"
     wait $CTRL_PID
     echo
     echo "Controller has stopped"

  else
    echo "Launching SPECjbb2015 in CompositeJVM mode..."
    if [ "x$NUMA" = "xYes" ]
    then
      echo "Warning! Composite will be bound to socket 0"
    fi
    echo
    BE_NAME="Composite"
    DEBUG_OPTS_BE="-Xlog:gc=debug,heap*=debug,phases*=debug,gc+age=debug:${BE_NAME}.gc.log"
    CMD_BE="$JAVA $JAVA_OPTS_BE $DEBUG_OPTS_BE $SPEC_OPTS_C $SPEC_OPTS_BE -jar ${JBB_HOME}/specjbb2015.jar -m COMPOSITE $MODE_ARGS_BE"
    echo $CMD_BE > ${BE_NAME}.cmdline.txt
    if [ "x$NUMA" = "xYes" ]
    then
      numactl --cpunodebind=0 --localalloc $CMD_BE > $BE_NAME.log 2>&1 &
    else
      $CMD_BE > $BE_NAME.log 2>&1 &
    fi  
    BE_PID=$!
    echo -e "\t$BE_NAME PID = $BE_PID"
    echo
    echo "SPECjbb2015 is running..."
    echo "Please monitor $result/${BE_NAME}.log for progress"
    wait $BE_PID
  fi       

  echo "SPECjbb2015 has finished"
  echo
  
  cd ..

done

exit 0
