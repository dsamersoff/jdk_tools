#!/bin/sh

VERSION="2.04 2020-09-04"

# Load configuration
source $JENKINS_HOME/specjbb_scripts/jobscripts/config.sh
if [ -f $JENKINS_HOME/specjbb_scripts/jobscripts/${JOB_NAME}/config.sh ]
then
  source $JENKINS_HOME/specjbb_scripts/jobscripts/${JOB_NAME}/config.sh
fi

if [ "x$1" = "x" ]
then
  echo "Error: No workspace specified e.g. jdk14"
  exit 7
fi

_jdk_workspace=$1

# Setup environment on the remote machine
cd $JENKINS_HOME/specjbb_scripts

tar czf - runscripts | ssh ${JBB_REMOTE} "mkdir -p ${JBB_RUN_ROOT}/${JOB_NAME}; cd ${JBB_RUN_ROOT}/${JOB_NAME} && tar xzvf -"
scp $JENKINS_HOME/specjbb_scripts/bin/specjbb.py $JBB_REMOTE:${JBB_RUN_ROOT}/${JOB_NAME}

if [ -f $JENKINS_HOME/specjbb_scripts/jobscripts/${JOB_NAME}/options.sh ]
then
    echo "Warning: Overriding default options.sh file with JOB specific one"
    scp $JENKINS_HOME/specjbb_scripts/jobscripts/${JOB_NAME}/options.sh $JBB_REMOTE:${JBB_RUN_ROOT}/${JOB_NAME}/runscripts
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

echo "Copying ${_jdk} to ${JBB_REMOTE}:${JBB_RUN_ROOT}/${JOB_NAME}/${_jdk_name}"

cd ${_jdk}/..
tar czf - ${_jdk_name} | ssh ${JBB_REMOTE} "cd ${JBB_RUN_ROOT}/${JOB_NAME} && tar xzf -"

# Create a run script on the remote side, that sets some environment variables
cat  | ssh ${JBB_REMOTE} "cd ${JBB_RUN_ROOT}/${JOB_NAME} && tee runme_tmp.sh" << EOM 
export JAVA_HOME=${JBB_RUN_ROOT}/${JOB_NAME}/${_jdk_name}
export JBB_HOME=${JBB_HOME} 
export JOB_NAME=${JOB_NAME}
cd runscripts 
echo ${JOB_NAME} > README.md
/bin/sh ./runme.sh
python3 ${JBB_RUN_ROOT}/${JOB_NAME}/specjbb.py -o ${JOB_NAME}.xlsx
EOM

# Run specjbb
ssh -n $JBB_REMOTE "cd ${JBB_RUN_ROOT}/${JOB_NAME} && sudo /bin/sh ./runme_tmp.sh"

# Copy results back to jenkins machine
scp -r ${JBB_REMOTE}:${JBB_RUN_ROOT}/${JOB_NAME}/runscripts/${JOB_NAME}.xlsx .
