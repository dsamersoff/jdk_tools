#!/bin/sh

source $JENKINS_HOME/job_scripts/common/config.sh

if [ "x$1" = "x" ]
then
  echo "Workspace to build shall be specified e.g. jdk14"
  exit 7
fi

_jdk_workspace=$1

# Setup environment on the remote machine
cd $JENKINS_HOME/job_scripts/common

tar czf - runscripts | ssh ${JBB_REMOTE} "mkdir -p ${JBB_RUN_ROOT}/${JBB_RUN_NAME}; cd ${JBB_RUN_ROOT}/${JBB_RUN_NAME} && tar xzvf -"
scp $JENKINS_HOME/job_scripts/common/specjbb.py $JBB_REMOTE:${JBB_RUN_ROOT}/${JBB_RUN_NAME}

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
  echo "No java executable found"
  exit 255
fi  

cd ${_jdk}/..
tar czf - ${_jdk_name} | ssh ${JBB_REMOTE} "cd ${JBB_RUN_ROOT}/${JBB_RUN_NAME} && tar xzvf -"

# Create a run script on the remote side, that sets some environment variables
cat  | ssh ${JBB_REMOTE} "cd ${JBB_RUN_ROOT}/${JBB_RUN_NAME} && tee runme_tmp.sh" << EOM 
export JAVA_HOME=${JBB_RUN_ROOT}/${JBB_RUN_NAME}/${_jdk_name}
export JBB_HOME=${JBB_HOME} 
export JOB_NAME=${JOB_NAME}
cd runscripts 
echo ${JOB_NAME} > README.md
/bin/sh ./runme.sh
EOM

# Run specjbb
ssh -n $JBB_REMOTE "cd ${JBB_RUN_ROOT}/${JBB_RUN_NAME} && sudo /bin/sh ./runme_tmp.sh"

# Gather results and copy it back to jenkins machine
ssh -n $JBB_REMOTE "cd ${JBB_RUN_ROOT}/${JBB_RUN_NAME} && ./specjbb.py -o ${JBB_RUN_NAME}.xlsx"
scp -r ${JBB_REMOTE}:${JBB_RUN_ROOT}/${JBB_RUN_NAME}/${JBB_RUN_NAME}.xlsx .
