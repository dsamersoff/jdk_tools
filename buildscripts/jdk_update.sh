#!/bin/sh

VERSION="2.01 2020-09-03"

_jdk_update_url="http://hg.openjdk.java.net/jdk"

if [ "x${JDK_UPDATE_URL}" != "x" ]
then
  _jdk_update_url="${JDK_UPDATE_URL}"
fi

for jdk in "$@"
do
   if [ -d ${jdk} ]
   then
      cd ${jdk}
      hg update
   else
      hg clone ${_jdk_update_url}/${jdk}
   fi
done

