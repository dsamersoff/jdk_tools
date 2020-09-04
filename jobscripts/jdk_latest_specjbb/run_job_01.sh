#!/bin/sh

VERSION="2.01 2020-09-04"

# Load configuration
source $JENKINS_HOME/specjbb_scripts/jobscripts/config.sh
if [ -f $JENKINS_HOME/specjbb_scripts/jobscripts/${JOB_NAME}/config.sh ]
then
  source $JENKINS_HOME/specjbb_scripts/jobscripts/${JOB_NAME}/config.sh
fi

if [ "x$1" = "x" ]
then
  echo "Workspace to build shall be specified e.g. jdk14"
  exit 7
fi

_jdk_workspace=$1

cd ${JDK_WORKSPACE_ROOT}
/bin/sh -xe $JENKINS_HOME/specjbb_scripts/buildscripts/jdk_update.sh ${_jdk_workspace}

cd ${JDK_WORKSPACE_ROOT}/${_jdk_workspace}
/bin/sh -xe $JENKINS_HOME/specjbb_scripts/buildscripts/jdk_build.sh --product 
make CONF=release images
