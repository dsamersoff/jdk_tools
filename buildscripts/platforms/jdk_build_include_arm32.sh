#!/bin/sh
cws="/opt/arm32/gcc-linaro-7.3.1-2018.05-x86_64_arm-linux-gnueabihf"
configure_params="${configure_params} --openjdk-target=arm-linux-gnueabihf" 
configure_params="${configure_params} --with-toolchain-path=${cws}/bin:${cws}/arm-linux-gnueabihf/bin:${cws}/libexec/gcc/arm-linux-gnueabihf/4.8.2/"
configure_params="${configure_params} --with-sysroot=/opt/arm32/sysroot-glibc-linaro-2.25-2018.05-arm-linux-gnueabihf-jdk"
configure_params="${configure_params} --with-abi-profile=armv6-vfp-hflt" 
