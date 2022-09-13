#!/bin/sh

PP=`pwd`
jtreg_options=""

if [ "x$1" = "xclean" ] 
then
	find . -type d -a \( -name "JTwork" -o -name "JTreport" \) | xargs rm -rf 
	exit
fi

if [ "x$1" = "xrerun" ] 
then
   jtreg_options="${jtreg_options} -status:fail,error"
   shift
fi

if [ "x$1" = "xcontinue" ] 
then
   jtreg_options="${jtreg_options} -status:notRun"
   shift
fi

if [ "x$1" != "x" ] 
then
      PP=$*
else
      PP="."	
fi	 

if [ "x$TESTJAVA" = "x" ]
then
  echo "WARNING! TESTJAVA have to be set. Using default"
  TESTJAVA=`testjava`
fi  

if [ "x${COMPJAVA}" = "x" ]
then
  JAVA_FAMILY=`${TESTJAVA}/bin/java -version 2>&1 >/dev/null | sed -n -e 's/.*version "1\.8\..*/jdk8/p' -e 's/.*version "\([1-9][0-9]\)[\.-].*/jdk\1/p'`

  if [ "x$JAVA_FAMILY" = "x" ]
  then
     echo "ERROR: Could not determine version of 'java' executable. Exiting."
     exit 1
  fi

  COMPJAVA="/opt/${JAVA_FAMILY}"
fi

if [ ! -x $COMPJAVA/bin/javac ]
then
  echo "WARNING: Could not find java to compile tests, usint ${TESTJAVA}"
  COMPJAVA="${TESTJAVA}"
fi

jtreg_options="${jtreg_options} -compilejdk:${COMPJAVA}" 

[ "x$JTWORK" = "x" ] && JTWORK="/tmp/jtreg-dms"
[ "x$JTREPORT" = "x" ] && JTREPORT=${JTWORK}

jtreg_options="${jtreg_options} -reportDir:${JTREPORT}/JTreport -workDir:${JTWORK}/JTwork"

echo "TESTJAVA: ${TESTJAVA}"
echo "JAVA Family is $JAVA_FAMILY"
echo "COMPILE JAVA: ${COMPJAVA}"
echo "JTREG OUT: JTwork: ${JTWORK} JTreport: ${JTREPORT}"


# run:
#    make test-bundles

# JDK8 doesn't support native path
if [ "x$JAVA_FAMILY" != "xjdk8" ]
then
  # JTREG requires JDK11 or later
  export JT_JAVA=${COMPJAVA}

  if [ "x$NATIVEPATH" = "x" ]
  then
    np_kind="hotspot"
    if pwd | grep -q "test/jdk" 
    then
      echo "Warning! NATIVEPATH set for JDK" 
      np_kind="jdk"
    fi

    if  echo $TESTJAVA | grep -q "images" 
    then
      NATIVEPATH="${TESTJAVA}/../test/${np_kind}/jtreg/native"
    else
      echo "Warning! Native test will fail in exploded mode. Run make images test-bundles" 
      NATIVEPATH="None"
    fi
  fi

  if [ "x${NATIVEPATH}" != "xNone" ]
  then
    if [ ! -d ${NATIVEPATH} ]
    then
      echo "Native path ${NATIVEPATH} is not a directory. Run make test-bundles"
      exit 1
    fi
    jtreg_options="${jtreg_options} -nativepath:${NATIVEPATH}"
  fi

fi

jtreg_options="${jtreg_options} -retain:fail,error"

jtreg_options="${jtreg_options} \
   -J-Djavatest.maxOutputSize=9000000 \
   -verbose:all \
   -ignore:run \
   -vmoption:-Xmx2048m\
   -timeoutFactor:8 
"
 
eval /opt/jtreg/bin/jtreg ${jtreg_options} -jdk "${TESTJAVA}" ${STATUS} ${PP} 
