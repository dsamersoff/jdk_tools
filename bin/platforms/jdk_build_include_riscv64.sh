#!/bin/sh
configure_params="${configure_params} --openjdk-target=riscv64-unknown-linux-gnu" 
configure_params="${configure_params} --with-toolchain-path=/opt/riscv64/bin"
configure_params="${configure_params} --with-sysroot=/opt/riscv64/sysroot-jdk"
