#!/bin/bash
# Nano harness to write java-related tests

# Could be use, ignore, rebuild
# default use if exists or reebuild

export NANOHAR_USE_PRECOMPILED="ignore"
# export NANOHAR_TMP_ROOT="/tmp/nanohar"

_report_only="no"
_print_help="no"
_clean_tmp="no"

. ./testlib.sh

for parm in "$@"
do
    case $parm in
        --print-test-help) _print_help="yes"  ;;
        --report-only) _report_only="yes" ;;
        --clean) _clean_tmp="yes" ;;
            *) echo "Undefined parameter $parm."; exit  ;;
    esac
done

if [ "${_clean_tmp}" = "yes" ]; then
(
   cd ${_tmp_root}

    for suite in *
    do
        rm -f "${suite}-test.log"
        rm -f "${suite}-test-tools.log"
    done
)
fi

if [ "$_report_only" != "yes" ]; then
(
    cd $_rt
    n_suites=0

    for suite in *
    do
        if [ -x $suite/testme.sh ]; then
            n_suites=$((n_suites+1))
            (
                cd $suite
                ./testme.sh
            )
        fi
    done

    echo "All Done For $n_suites Suites"
    echo
)
fi


t_ok=`cat ${_tmp_root}/*-test.log | grep "TEST OK" | wc -l`
t_fail=`cat ${_tmp_root}/*-test.log | grep "TEST FAILED" | wc -l`
t_skip=`cat ${_tmp_root}/*-test.log | grep "TEST SKIPPED" | wc -l`

echo "*** Run Summary ***"
(

    cd ${_rt}
    suite_list=`find . -name "*" -type "d"`

    cd ${_tmp_root}

    for suite in $suite_list
    do
        [ "${suite}" = "." ] && continue

        echo
        echo "$suite"
        echo

        if [ ! -f "${suite}-test.log" ]; then
            echo "Suite was not run"
            continue
        fi

        mapfile -t lines < "${suite}-test.log"
        for rr in "${lines[@]}"
        do
            if [ "$_print_help" = "yes" ]; then
                line=`echo $rr | sed -n -e "s/--- //p" | sed -n -e "s/START //p"`
                [ ! -z "$line" ] && echo "# $line"
                line=`echo $rr | sed -n -e "s/ HELP//p"`
                [ ! -z "$line" ] && echo "$line"
            fi

            line=`echo $rr | sed -n -e "s/--- //p" | grep "TEST "`
            [ ! -z "$line" ] && echo "$line"
        done
    done


    if [ "$t_fail" -gt 0 ]; then
        echo "*** FAILED Tests list ***"

        for suite in $suite_list
        do
            [ "${suite}" = "." ] && continue
            [ ! -f "${suite}-test.log" ] && continue
            echo
            echo "$suite"

            mapfile -t lines < "${suite}-test.log"
            for rr in "${lines[@]}"
            do
                line=`echo $rr | sed -n -e "s/--- //p" | grep "TEST FAILED"`
                [ ! -z "$line" ] && echo "$line"
            done
        done
    fi
)

echo
echo "*** Summa Summarum ***"
echo

echo "Passed Tests: $t_ok"
echo "Failed Tests: $t_fail"
echo "Skipped Tests: $t_skip"
echo
