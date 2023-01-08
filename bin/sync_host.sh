#!/bin/sh

_sync_sources="no"
_sync_tests="yes"
_test_host=""
_test_java=""

_rsync="/usr/bin/rsync"

[ "xTESTHOST" != "x" ] && _test_host="${TESTHOST}"
[ "xTESTJAVA" != "x" ] && _test_java="${TESTJAVA}"

for parm in "$@"
do
   case $parm in
            --host=*) _test_host=`echo $parm | sed -e s/.*=//` ;;
            --jdk=*) _test_java=`echo $parm | sed -e s/.*=//` ;;
            --sources) _sync_sources="yes" ;;
            --no-tests) _sync_tests="no"  ;;
               *) _test_host="$parm" ;;
   esac
done



[ "x_test_host" = "x" ] && echo "TESTHOST must be set" && exit 1
[ "x_test_java" = "x" ] && echo "TESTJAVA must be set" && exit 1
[ -d "${_test_java}/modules/java.base" ] && echo "TESTJAVA points to exploded" && exit 1

echo "Sync ${_test_java} to *${_test_host}*"

${_rsync} -v -rl --update --delete --delete-during --safe-links --exclude "man" --exclude "legal" ${_test_java} ${_test_host}:/export/ojdk

[ "${_sync_sources}" = "no" -a "${_sync_tests}" = "no" ] && exit 0

_src=`echo ${_test_java} | sed -e 's/build.*//'`
[ ! -d "${_src}/src/hotspot" ] && echo "_test_java must be inside jdk sources" && exit 1


if [ "${_sync_sources}" = "yes" ] 
then
  ${_rsync} -v -rl --update --delete --delete-during --safe-links --exclude "build" --exclude ".git" ${_test_java} ${_test_host}:/export/ojdk
fi

if [ "${_sync_tests}" = "yes" ] 
then
  [ ! -d "${_test_java}/../../support/test/hotspot/jtreg/native" ] && echo "No native test bundles" && exit 1

  ${_rsync} -v -rl --update --delete --delete-during --safe-links --exclude "build" --exclude ".git" ${_src}/test ${_test_host}:/export/ojdk
  ${_rsync} -v -rl --update --delete --delete-during --safe-links --exclude "build" --exclude ".git" ${_test_java}/../../support/test/hotspot/jtreg/native ${_test_host}:/export/ojdk
fi
