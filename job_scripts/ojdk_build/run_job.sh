#!/bin/sh
source $JENKINS_HOME/scripts/`uname -n`_config.sh

cd ${JDK_WORKSPACE_ROOT}
/bin/sh -xe $JENKINS_HOME/scripts/specjbb_scripts/buildscripts/jdk_update.sh ${JDK_WORKSPACE}

cd ${JDK_WORKSPACE_ROOT}/${JDK_WORKSPACE}
/bin/sh -xe $JENKINS_HOME/scripts/specjbb_scripts/buildscripts/jdk_build.sh --product 
make CONF=release images
