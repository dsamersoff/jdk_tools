#!/bin/sh

VERSION="2.04 2022-09-22"

_os=`uname`
_ws=`pwd | sed -e 's,.*/,,'`

# Defaults, building fastdebug
_flavor="fastdebug"
_boot_jdk="default"

_jdk_collection_root="/opt:/ws:/ws/bellsoft"
_cross_root="/opt/crossroot"

_pch="--disable-precompiled-headers"

_nowerror_cmd11="--disable-warnings-as-errors"
_nowerror_cmd8="--with-extra-cxxflags='-Wno-error' --with-extra-cflags='-Wno-error'"
_nowerror=""

_headless_cmd11="--enable-headless-only" 
_headless="" 

_variants=""
_confname=""
_features=""

# make build-microbenchmark will build build/$PROFILE/images/test/micro/benchmarks.jar
# make test TEST="micro:java.lang.invoke"

_jmh="no"
_target="default"

for parm in "$@"
do
   case $parm in
            --product) _flavor="product"  ;;
            --fastdebug) _flavor="fastdebug" ;;
            --jvmci) _features="jvmci" ;;
            --headless) _headless="${_headless_cmd11}" ;; 
            --multivm) _variants="server,client,minimal" ;; 
            --short-conf-name) _confname="short" ;;
            --with-conf-name=*) _confname=`echo $parm | sed -e s/.*=//` ;;
            --target=*) _target=`echo $parm | sed -e s/.*=//` ;;
            --with-jmh=*) _jmh=`echo $parm | sed -e s/.*=//` ;;
            --with-boot-jdk=*) _boot_jdk=`echo $parm | sed -e s/.*=//` ;;
            --no-werror) _nowerror="yes"  ;;
               *) echo "Undefined parameter $parm. Try --help for help"; exit  ;;
   esac
done

[ "x${_confname}" = "xshort" ] && _confname="${_flavor}"

_acceptable_boot_versions="default"

# Try to guess correct boot jdk
# it should be jdk11 jdk14 etc under _jdk_collection_root
if [ "x$JDK_COLLECTION_ROOT" != "x" ]
then
  _jdk_collection_root="$JDK_COLLECTION_ROOT"
fi

if [ -f ./make/autoconf/version-numbers ]
then
  . ./make/autoconf/version-numbers
fi  

if [ -f ./make/conf/version-numbers.conf ]
then
  . ./make/conf/version-numbers.conf 
fi  

[ "x${DEFAULT_ACCEPTABLE_BOOT_VERSIONS}" != "x" ] && _acceptable_boot_versions=${DEFAULT_ACCEPTABLE_BOOT_VERSIONS}
[ "x${ACCEPTABLE_BOOT_VERSIONS}" != "x" ] && _acceptable_boot_versions=${ACCEPTABLE_BOOT_VERSIONS}


if [ "${_acceptable_boot_versions}" = "default" ]
then
  echo "Can't gess BOOT JDK from the ws, assume we are on jdk8"
  if [ -f ./make/jprt.properties ]
  then
    _acceptable_boot_versions=8

    # We are building for jdk8 family, do some adjustment
    if [ "x${_nowerror}" = "xyes" ]
    then
      _nowerror=${_nowerror_cmd8}
    fi
  fi
fi

if [ "x${_nowerror}" = "xyes" ]
then
   _nowerror=${_nowerror_cmd11}
fi

if [ "x${_boot_jdk}" = "xdefault" ]
then
  if [ "${_acceptable_boot_versions}" != "default" ]
  then
    for jdk_ver in ${_acceptable_boot_versions}
    do
      coll_root=`echo $_jdk_collection_root | sed -e "s/:/ /g"`
      try_ver=`find $coll_root -maxdepth 1 -type d -name "jdk-${jdk_ver}*" -o -name "jdk${jdk_ver}*" | head -1` 2>/dev/null
      if [ ! -z "$try_ver" ]
      then
        if [ -x "$try_ver/bin/java" ]
        then
           _boot_jdk="$try_ver"
           break
        else
          echo "Discarded invalid jdk '$try_ver'"   
        fi
      fi
    done
  fi      
fi

# Basic parameters
configure_params=" ${_pch} ${_nowerror} ${_headless} --disable-ccache"

if [ "x${_boot_jdk}" != "default" ]
then
  configure_params="${configure_params} --with-boot-jdk=${_boot_jdk}"
fi

# Set number of jobs to value convenient for development
# If that fails, fallback to configure logic that uses CPU aggressively

_jobs=""
if [ -f /proc/cpuinfo ]
then
 _jobs=`grep -c processor /proc/cpuinfo`
else
 _jobs=`sysctl -n hw.ncpu`
fi

if [ "x${_jobs}" != "x" ]
then
 if [ ${_jobs} -gt 1 -a ${_jobs} -le 16 ]
 then
   _jobs=`expr ${_jobs} / 2`
 else
   _jobs=`expr ${_jobs} - 4`
 fi

  configure_params="${configure_params} --with-jobs=${_jobs}"
fi

if [ "x${_variants}" != "x" ]
then
  configure_params="${configure_params} --with-jvm-variants=minimal,client,server"
fi

if [ "x${_confname}" != "x" ]
then
  configure_params="${configure_params} --with-conf-name=${_confname}"
fi

# Try to include ${_cross_root}/${_target}/jdk_build_include.sh
# That set additional parameters for cross compilation
#
# e.g.
#
# configure_params="${configure_params} --openjdk-target=riscv64-unknown-linux-gnu"
# configure_params="${configure_params} --with-toolchain-path=/opt/riscv64/bin"
# configure_params="${configure_params} --with-sysroot=/opt/riscv64/sysroot-jdk"

if [ "${_target}" != "default" ]
then
  cross_options="${_cross_root}/${_target}/jdk_build_include.sh"
  if [ ! -f "${cross_options}" ]
  then
    echo "Target ${_target} is requested, but no cross options ${cross_options} found"
    exit 1
  fi 
  echo "Using ${cross_options} to set additional options"
  . ${cross_options}
fi

# jmh e.g. "/opt/jmh/target"
if [ "x$_jmh" != "xno" ]
then
  echo "JMH to ${_jmh}" 
  configure_params="${configure_params} --with-jmh=${_jmh}"
fi  

if [ "x${_features}" = "xjvmci" ]
then
  configure_params="${configure_params} --with-jvm-features=jvmci,compiler1,compiler2"
fi

if [ "x${_flavor}" = "xfastdebug" ]
then
  configure_params="${configure_params} ${_werror} --with-debug-level=fastdebug --with-native-debug-symbols=external"
fi

if [ "x${_flavor}" = "xproduct" ]
then
  configure_params="${configure_params} ${_werror}  --with-debug-level=release --with-native-debug-symbols=none"
fi

if [ "x${JDK_CONFIGURE_ADD}" != "x" ]
then
  configure_params="${configure_params} ${JDK_CONFIGURE_ADD}"
fi

echo "======= Running: ./configure ${configure_params}"
eval bash ./configure ${configure_params}
