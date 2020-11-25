#!/bin/sh

PP=`pwd`

if [ "x$1" = "xclean" ] 
then
	find . -type d -a \( -name "JTwork" -o -name "JTreport" \) | xargs rm -rf 
	exit
fi

if [ "x$1" != "x" ] 
then
	 PP=$*
fi	 

if [ "x$TESTJAVA" = "x" ]
then
  echo "WARNING! TESTJAVA have to be set. Using default"
  TESTJAVA=`testjava`
fi  

echo "TESTJAVA: ${TESTJAVA}"
export JT_JAVA=/opt/jdk/bin/java

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
#   -compilejdk:/opt/jdk \

/export/dsamersoff/jtreg/bin/jtreg \
   -J-Djavatest.maxOutputSize=9000000 \
   -verbose:all \
   -ignore:run \
   -vmoption:-Xmx2048m\
   -reportDir:/tmp/jtreg-dms/JTreport \
   -workDir:/tmp/jtreg-dms/JTwork \
   -timeoutFactor:6 \
   -nativepath:${NATIVEPATH} \
   -jdk "${TESTJAVA}" \
   ${PP} 
