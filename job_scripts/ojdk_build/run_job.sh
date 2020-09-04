#!/bin/sh
source $JENKINS_HOME/job_scripts/common/config.sh

if [ "x$1" = "x" ]
then
  echo "Workspace to build shall be specified e.g. jdk14"
  exit 7
fi

cd ${JDK_WORKSPACE_ROOT}
/bin/sh -xe $JENKINS_HOME/job_scripts/common/buildscripts/jdk_update.sh $1

cd ${JDK_WORKSPACE_ROOT}/$1
/bin/sh -xe $JENKINS_HOME/job_scripts/common/buildscripts/jdk_build.sh --product 
make CONF=release images
