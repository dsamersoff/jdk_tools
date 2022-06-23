#!/bin/sh
cws="/opt/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu"

# Delete ${cws}/lib/gcc/aarch64-none-linux-gnu/10.3.1/include-fixed/pthread.h
# otherwise the build fails

configure_params="${configure_params} --openjdk-target=aarch64-none-linux-gnu" 
configure_params="${configure_params} --with-toolchain-path=${cws}/bin:${cws}/aarch64-none-linux-gnu/bin:${cws}/libexec/gcc/aarch64-none-linux-gnu/10.3.1/"
configure_params="${configure_params} --with-sysroot=/opt/aarch64/sysroot-glibc-linaro-2.25-2018.05-aarch64-linux-gnu-jdk"
