#!/bin/sh

source $JENKINS_HOME/scripts/`uname -n`_config.sh

cd $JENKINS_HOME/scripts/specjbb_scripts

tar czf - runscripts | ssh ${JBB_REMOTE} "mkdir -p ${JBB_RUN_ROOT}/${JBB_RUN_NAME}; cd ${JBB_RUN_ROOT}/${JBB_RUN_NAME} && tar xzvf -"
scp $JENKINS_HOME/scripts/specjbb_scripts/bin/specjbb.py $JBB_REMOTE:${JBB_RUN_ROOT}/${JBB_RUN_NAME}

_jdk=${JDK_WORKSPACE_ROOT}/${JDK_WORKSPACE}
_jdk_name=${JDK_WORKSPACE}

if [ -f ${JDK_WORKSPACE_ROOT}/${JDK_WORKSPACE}/build/linux-aarch64-server-release/images/jdk/bin/java ]
then
   _jdk=${JDK_WORKSPACE_ROOT}/${JDK_WORKSPACE}/build/linux-aarch64-server-release/images/jdk
   _jdk_name="jdk"
fi 
  
if [ ! -f ${_jdk}/bin/java ]
then 
  echo "No java executable found"
  exit 255
fi  

cd ${_jdk}/..
tar czf - ${_jdk_name} | ssh ${JBB_REMOTE} "cd ${JBB_RUN_ROOT}/${JBB_RUN_NAME} && tar xzvf -"

cat  | ssh ${JBB_REMOTE} "cd ${JBB_RUN_ROOT}/${JBB_RUN_NAME} && tee runme_tmp.sh" << EOM 
export JAVA_HOME=${JBB_RUN_ROOT}/${JBB_RUN_NAME}/${_jdk_name}
export JBB_HOME=${JBB_HOME} 
cd runscripts 
/bin/sh ./runme.sh 1  
EOM

ssh -n $JBB_REMOTE "cd ${JBB_RUN_ROOT}/${JBB_RUN_NAME} && sudo /bin/sh ./runme_tmp.sh"
ssh -n $JBB_REMOTE "cd ${JBB_RUN_ROOT}/${JBB_RUN_NAME} && /usr/bin/env python3 ./specjbb.py -o ${JBB_RUN_NAME}.xlsx"
scp -r ${JBB_REMOTE}:${JBB_RUN_ROOT}/${JBB_RUN_NAME}/${JBB_RUN_NAME}.xlsx .
