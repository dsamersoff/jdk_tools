#!/bin/sh

VERSION="2.01 2020-09-03"

_jdk_update_url="http://hg.openjdk.java.net/jdk"

if [ "x${JDK_UPDATE_URL}" != "x" ]
then
  _jdk_update_url="${JDK_UPDATE_URL}"
fi

if [ "x$1" = "x" ]
then
  echo "Error: Workspace is not specified"
  exit 7
fi

_jdk=$1 
_tag=tip

if [ "x$2" != "x" ]
then
  _tag=$2
fi

if [ -d ${_jdk} ]
then
      cd ${_jdk}
      hg update -r ${_tag}
else
      echo "Clone ${_tag} from ${_jdk_update_url}/${_jdk}"
      hg clone -r ${_tag} ${_jdk_update_url}/${_jdk}
fi

echo "Done"