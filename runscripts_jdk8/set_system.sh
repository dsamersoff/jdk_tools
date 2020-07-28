#!/bin/bash

SYS_VERSION="2.03 2020-05-09"

function sysfile() {
   echo -n "$1 "
   echo $2 | sudo tee $1
}

function sysopt() {
   sudo sysctl -w $1=$2
}

# TXOS support
# limit descriptors 65536
ulimit -n 65536
sysopt net.ipv4.conf.lo.accept_local 1
#

sysopt vm.max_map_count 10485
sysopt vm.min_free_kbytes 67584
sysopt vm.nr_hugepages 0
sysopt vm.swappiness 10
sysopt kernel.shmmax 16777216 
sysopt vm.hugetlb_shm_group 0

sysopt net.core.rmem_default 262144 
sysopt net.core.wmem_default 262144 
sysopt net.core.rmem_max 262144 
sysopt net.core.wmem_max 262144 
sysopt net.core.somaxconn 4096 


# some kernels may have no cfq scheduler
# check and enable it explicsitly
# echo cfq > /sys/block/sda/queue/scheduler

sysfile /sys/kernel/mm/transparent_hugepage/enabled always
sysfile /sys/kernel/mm/transparent_hugepage/defrag defer

sysfile /proc/sys/kernel/sched_latency_ns 24000000 
sysfile /proc/sys/kernel/sched_min_granularity_ns 6000000 
sysfile /proc/sys/kernel/sched_migration_cost_ns 1000

sysfile /proc/sys/vm/dirty_background_bytes 10
sysfile /proc/sys/vm/dirty_writeback_centisecs 1500
sysfile /proc/sys/vm/dirty_expire_centisecs 10000

sysfile /proc/sys/kernel/numa_balancing 0

