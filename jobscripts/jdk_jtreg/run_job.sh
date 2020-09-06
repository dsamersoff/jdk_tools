#!/bin/sh

VERSION="2.01 2020-09-06"

# Load configuration
source $JENKINS_HOME/specjbb_scripts/jobscripts/config.sh
if [ -f $JENKINS_HOME/specjbb_scripts/jobscripts/${JOB_NAME}/config.sh ]
then
    source $JENKINS_HOME/specjbb_scripts/jobscripts/${JOB_NAME}/config.sh
fi

if [ "x$1" = "x" ]
then
    echo "Error: Workspace to build and test is not specified e.g. jdk14"
    exit 7
fi

if [ "x$2" = "x" ]
then
    echo "Error: Directory to start (under test/hotspot/jtreg) is not specified at e.g. Runtime/Dictionary"
    exit 7
fi

export JT_JAVA="${JTREG_JDK}/bin/java"

_jdk_workspace=$1
_test_dir=$2

# JTREG job shouldn't perform update to produce stable results
# /bin/sh -xe $JENKINS_HOME/specjbb_scripts/buildscripts/jdk_update.sh ${_jdk_workspace}

cd ${JDK_WORKSPACE_ROOT}/${_jdk_workspace}
/bin/sh -xe $JENKINS_HOME/specjbb_scripts/buildscripts/jdk_build.sh --fastdebug 
make CONF=fastdebug images test-bundles

if [ $? -ne 0 ]
then
    echo "Error: Build failed, exiting"
    exit 255
fi  

# Guess jdk image and copy it to remote machine
_testjava=${JDK_WORKSPACE_ROOT}/${_jdk_workspace}/build/linux-aarch64-server-fastdebug/images/jdk

echo "TESTJAVA: ${_testjava}"

if  echo ${_testjava} | grep -q "images"
then
    echo "Warning! NATIVEPATH set to EXPLODED"
    _nativepath="${_testjava}/../../support/test/hotspot/jtreg/native/lib"
else
    _nativepath="${_testjava}/../support/test/hotspot/jtreg/native/lib"
fi

if [ ! -d ${_nativepath} ]
then
    echo "Native test lib not found. Run make test-bundles"
    exit
fi

cd ${JDK_WORKSPACE_ROOT}/${_jdk_workspace}/${JTREG_TEST_ROOT}/${_test_dir}

${JTREG_HOME}/bin/jtreg \
   -J-Djavatest.maxOutputSize=9000000 \
   -verbose:all \
   -ignore:run \
   -vmoption:-Xmx2048m\
   -reportDir:${WORKSPACE}/JTreport \
   -workDir:${WORKSPACE}/JTwork \
   -timeoutFactor:6 \
   -nativepath:${_nativepath} \
   -jdk "${_testjava}"  \
   .
   
