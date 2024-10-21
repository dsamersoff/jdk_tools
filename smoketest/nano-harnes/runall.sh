#!/bin/bash

for suite in *
do
    if [ -x $suite/testme.sh ]; then
        (
            cd $suite
            ./testme.sh
        )
    fi
done

t_ok=`cat */*-test.log | grep "TEST OK" | wc -l`
t_fail=`cat */*-test.log | grep "TEST FAILED" | wc -l`
t_skip=`cat */*-test.log | grep "TEST SKIPPED" | wc -l`

if [ $t_fail -ne 0 ]; then
    echo
    echo "*** FAILED tests list"
    for suite in *
    do
        if [ -x $suite/testme.sh ]; then
            if [ -f $suite/*-test.log ]; then
                nf=`cat $suite/*-test.log | grep "TEST FAILED" | wc -l`
                if [ $nf -ne 0 ]; then
                    echo "Suite $suite has $nf FAILED tests:"
                    cat $suite/*-test.log | grep "TEST FAILED"
                fi
            fi
        fi
    done
fi

t_crash=`find . -name "hs_err*" | wc -l`

if [ $t_crash -ne 0 ]; then
    echo
    echo "*** VM CRASHES list"
    for suite in *
    do
        if [ -x $suite/testme.sh ]; then
           for hs in $suite/hs_err* $suite/scratch/hs_err*
           do
                echo $hs
           done
        fi
    done
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
