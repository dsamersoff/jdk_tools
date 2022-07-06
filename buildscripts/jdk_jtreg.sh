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

echo "TESTJAVA: ${TESTJAVA}"
export JT_JAVA=/opt/jdk/bin/java


JAVA_FAMILY=`${TESTJAVA}/bin/java -version 2>&1 >/dev/null | sed -n -e 's/.*version "1\.8\..*/jdk8/p' -e 's/.*version "\(1[0-9]\)[\.-].*/jdk\1/p'`

if [ "x$JAVA_FAMILY" = "x" ]
then
   echo "ERROR: Could not determine version of 'java' executable. Exiting."
   exit 1
else
   echo "JAVA Family is $JAVA_FAMILY"
fi

if [ "x$COMPJAVA" = "x" ]
then
  COMPJAVA="/opt/${JAVA_FAMILY}"
fi

echo "COMPILE JAVA: ${COMPJAVA}"

if [ ! -x $COMPJAVA/bin/javac ]
then
   echo "WARNING: Could not find java to compile tests"
   echo "WARNING: Compiling using ${TESTJAVA}/bin/javac"
else
   jtreg_options="${jtreg_options} -compilejdk:${COMPJAVA}" 
fi

# run:
#    make test-bundles

# JDK8 doesn't support native path
if [ "x$JAVA_FAMILY" != "xjdk8" ]
then
  if [ "x$NATIVEPATH" = "x" ]
  then
    np_prefix=".."
    np_kind="hotspot"

    if  echo $TESTJAVA | grep -q "images" 
    then
      echo "Warning! NATIVEPATH set to EXPLODED" 
      np_prefix="../.."
    fi

    if pwd | grep -q "test/jdk" 
    then
      echo "Warning! NATIVEPATH set for JDK" 
      np_kind="jdk"
    fi

    NATIVEPATH="${TESTJAVA}/${np_prefix}/support/test/${np_kind}/jtreg/native/lib"
  fi

  if [ ! -d ${NATIVEPATH} ]
  then
    echo "Native path ${NATIVEPATH} is not a directory. Run make test-bundles"
    exit 1
  fi

  jtreg_options="${jtreg_options} -nativepath:${NATIVEPATH}" 
fi

jtreg_options="${jtreg_options} -retain:fail,error"

jtreg_options="${jtreg_options} \
   -J-Djavatest.maxOutputSize=9000000 \
   -verbose:all \
   -ignore:run \
   -vmoption:-Xmx2048m\
   -reportDir:/root/jtreg-dms/JTreport \
   -workDir:/root/jtreg-dms/JTwork \
   -timeoutFactor:8 \
"
 
eval /opt/jtreg/bin/jtreg ${jtreg_options} -jdk "${TESTJAVA}" ${STATUS} ${PP} 
