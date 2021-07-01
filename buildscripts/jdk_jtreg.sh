#!/bin/sh

PP=`pwd`

if [ "x$1" = "xclean" ] 
then
	find . -type d -a \( -name "JTwork" -o -name "JTreport" \) | xargs rm -rf 
	exit
fi

if [ "x$1" = "xrerun" ] 
then
     STATUS="-status:fail,error"
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


if [ "x$COMPJAVA" = "x" ]
then
  JAVA_FAMILY=`${TESTJAVA}/bin/java -version 2>&1 >/dev/null | sed -n -e 's/.*version "1\.8\..*/jdk8/p' -e 's/.*version "\(1[0-9]\)\..*/jdk\1/p'`

  if [ "x$JAVA_FAMILY" = "x" ]
  then
    echo "ERROR: Could not determine version of 'java' executable. Exiting."
    exit 1
  else
    echo "JAVA Family is $JAVA_FAMILY"
  fi

  COMPJAVA="/opt/${JAVA_FAMILY}"
fi

echo "COMPILE JAVA: ${COMPJAVA}"

if [ ! -x $COMPJAVA/bin/java ]
then
   echo "ERROR: Could not find java to compile tests. Exiting."
   exit 1
fi

# run:
#    make test-bundles

if  echo $TESTJAVA | grep -q "images" 
then
   echo "Warning! NATIVEPATH set to EXPLODED" 
   export NATIVEPATH="${TESTJAVA}/../../support/test/hotspot/jtreg/native/lib"
else
   export NATIVEPATH="${TESTJAVA}/../support/test/hotspot/jtreg/native/lib"
fi

if [ ! -d ${NATIVEPATH} ]
then
   echo "Native test lib not found. Run make test-bundles"
   exit
fi

# Add this option to speedup test compilation
# At the cost of possible version missmatch 

/opt/jtreg/bin/jtreg \
   -J-Djavatest.maxOutputSize=9000000 \
   -verbose:all \
   -ignore:run \
   -vmoption:-Xmx2048m\
   -reportDir:/tmp/jtreg-dms/JTreport \
   -workDir:/tmp/jtreg-dms/JTwork \
   -timeoutFactor:6 \
   -compilejdk:${COMPJAVA} \
   -nativepath:${NATIVEPATH} \
   -jdk "${TESTJAVA}" \
   ${STATUS} \
   ${PP} 
