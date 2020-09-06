#!/bin/sh

VERSION="2.04 2020-09-04"

# Load configuration
source $JENKINS_HOME/specjbb_scripts/jobscripts/config.sh
if [ -f $JENKINS_HOME/specjbb_scripts/jobscripts/${JOB_NAME}/config.sh ]
then
  echo "Warning: Loading job-specific config"
  source $JENKINS_HOME/specjbb_scripts/jobscripts/${JOB_NAME}/config.sh
fi

if [ "x$1" = "x" ]
then
  echo "Error: No workspace specified e.g. jdk14"
  exit 7
fi

_jdk_workspace=$1
_jbb_remote="${JBB_REMOTE_USER}@${JBB_REMOTE_HOST}"
_cwd=`pwd`

# Setup environment on the remote machine
cd $JENKINS_HOME/specjbb_scripts
tar czf - runscripts | ssh ${_jbb_remote} "mkdir -p ${JBB_REMOTE_ROOT}/${BUILD_TAG}; cd ${JBB_REMOTE_ROOT}/${BUILD_TAG} && tar xzvf -"

if [ -f $JENKINS_HOME/specjbb_scripts/jobscripts/${BUILD_TAG}/options.sh ]
then
    echo "Warning: Overriding default options.sh file with JOB specific one"
    scp $JENKINS_HOME/specjbb_scripts/jobscripts/${BUILD_TAG}/options.sh $_jbb_remote:${JBB_REMOTE_ROOT}/${BUILD_TAG}/runscripts
fi    

# Guess jdk image and copy it to remote machine
if [ -f ${JDK_WORKSPACE_ROOT}/${_jdk_workspace}/build/linux-aarch64-server-release/images/jdk/bin/java ]
then
   _jdk=${JDK_WORKSPACE_ROOT}/${_jdk_workspace}/build/linux-aarch64-server-release/images/jdk
   _jdk_name="jdk"
else
  _jdk=${JDK_WORKSPACE_ROOT}/${_jdk_workspace}
  _jdk_name=${JDK_WORKSPACE}
fi 
  
if [ ! -f ${_jdk}/bin/java ]
then 
  echo "Error: No java executable found"
  exit 255
fi  

echo "Copying ${_jdk} to ${_jbb_remote}:${JBB_REMOTE_ROOT}/${BUILD_TAG}/${_jdk_name}"

cd ${_jdk}/..
tar czf - ${_jdk_name} | ssh ${_jbb_remote} "cd ${JBB_REMOTE_ROOT}/${BUILD_TAG} && tar xzf -"

# Create a run script on the remote side, that sets some environment variables
cat  | ssh ${_jbb_remote} "cd ${JBB_REMOTE_ROOT}/${BUILD_TAG} && tee runme_tmp.sh" << EOM 
export JAVA_HOME=${JBB_REMOTE_ROOT}/${BUILD_TAG}/${_jdk_name}
export JBB_HOME=${JBB_HOME} 
export BUILD_TAG=${BUILD_TAG}
cd runscripts 
echo ${BUILD_TAG} > README.md
/bin/sh ./runme.sh
EOM

# Run specjbb
ssh -n $_jbb_remote "cd ${JBB_REMOTE_ROOT}/${BUILD_TAG} && sudo /bin/sh ./runme_tmp.sh"

# Copy results back to jenkins machine
ssh ${_jbb_remote} "cd ${JBB_REMOTE_ROOT}/${BUILD_TAG} && tar czf - runscripts" | tar xzvf -
python3 $JENKINS_HOME/specjbb_scripts/bin/specjbb.py -o ${BUILD_TAG}.xlsx

# Remove run directory on remote machine
if [ "x${JBB_REMOTE_CLEANUP}" = "xYes" ]
then
   echo "Warning! Removing remote run dir ${JBB_REMOTE_ROOT}/${BUILD_TAG}"
   ssh -n $_jbb_remote "cd ${JBB_REMOTE_ROOT} && sudo chown -R ${JBB_REMOTE_USER} ${BUILD_TAG}"
   ssh -n $_jbb_remote "cd ${JBB_REMOTE_ROOT} && rm -rf ${BUILD_TAG}"
fi

echo "ALL Done. Check ${_cwd}"

