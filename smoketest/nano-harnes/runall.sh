#!/bin/bash
# Nano harness to write java-related tests

# Could be use, ignore, rebuild
# default use if exists or reebuild

# export NANOHAR_USE_PRECOMPILED="ignore"
# export NANOHAR_TMP_ROOT="/tmp/nanohar"

. ./testlib.sh

(
    cd $_rt

    for suite in *
    do
        if [ -x $suite/testme.sh ]; then
            (
                cd $suite
                ./testme.sh
            )
        fi
    done
)




t_ok=`cat ${_tmp_root}/*-test.log | grep "TEST OK" | wc -l`
t_fail=`cat ${_tmp_root}/*-test.log | grep "TEST FAILED" | wc -l`
t_skip=`cat ${_tmp_root}/*-test.log | grep "TEST SKIPPED" | wc -l`

if [ $t_fail -ne 0 ]; then
    echo
    echo "*** FAILED tests list"
    (
        cd $_tmp_root

        for log in *-test.log
        do
            nf=`cat $log | grep "TEST FAILED" | wc -l`
            if [ $nf -ne 0 ]; then
                suite=`echo $log | sed -e "s/-test.log//"`
                echo "Suite $suite has $nf FAILED tests:"
                cat $log | grep "TEST FAILED"
            fi
        done
    )
fi

t_crash=`find ${_tmp_root} -name "hs_err*" | wc -l`

if [ $t_crash -ne 0 ]; then
    echo
    echo "*** VM CRASHES list"
    (
        cd $_tmp_root

        for suite in *
        do
            if [ -x $suite/testme.sh ]; then
                for hs in $suite/hs_err* $suite/scratch/hs_err*
                do
                    echo $hs
                done
            fi
        done
    )
fi

echo
echo "********************************"
echo "**** All Suites Run Summary ****"
if [ $t_crash -ne 0 ]; then
echo "=> VM CRASHES: $t_crash"
fi
echo "Tests PASSED: $t_ok"
echo "Tests FAILED: $t_fail"
echo "Tests SKIPPED: $t_skip"
echo
