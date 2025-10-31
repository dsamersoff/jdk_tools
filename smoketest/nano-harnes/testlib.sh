#!/bin/false
# Nano harness part
# Don't run, this is include file

if [ "x${BASH_VERSION}" = "x" ]; then
   echo "Bash required, exiting"
   exit 1
fi

# Define basic harness constants
_rt=`dirname $0`
_rt=`cd $_rt && pwd`

_suite=`basename $_rt`

_tmp_root="/tmp/nanohar"
[ "x${NANOHAR_TMP_ROOT}" != "x" ] && _tmp_root="${NANOHAR_TMP_ROOT}"

_tmpdir="${_tmp_root}/${_suite}/scratch"
_testlog="${_tmp_root}/${_suite}-test.log"
_test_tools_log="${_tmp_root}/${_suite}-test-tools.log"

mkdir -p ${_tmp_root}
cd "${_tmp_root}"

[ -f $_rt/../testlib_local.sh ] && source $_rt/../testlib_local.sh

l_echo() {
    echo "$*" | tee -a $_testlog
}

# Pseudo commands to put comments into the test body
title() {
    false
}

outcome() {
    false
}

#   [ "x${_print_help}" = "xyes" ] && echo $*
# Up to four lines of test description
help01() {
   false
}

help02() {
   false
}

help03() {
   false
}

help04() {
   false
}

# Result check helpers
# You can set additional message for result
result() {
    if [ $1 -eq 0 ]; then
        [ "x$2" != "x" ] && l_echo "+++ TEST OK $2"
        return 0
    else
        [ "x$3" != "x" ] && l_echo "!!! TEST FAILED $3"
        return 1
    fi
}

result_eq() {
    result $? "$1" "$2"
    return $?
}

result_ne() {
    rc=`expr 1 - $?`
    result $rc "$1" "$2"
    return $?
}

result_match() {
    if [ "$1" = "$2" ]; then
        result 0 "$3" "$4"
    else
        result 1 "$3" "$4"
    fi
    return $?
}

##

uid_check() {
    uid=`id -u`
    if [ $uid -ne 0 ]; then
        echo "Test must be run with uid = 0"
        exit 1
    fi
}

start_run() {
    echo "Test run started " > $_testlog
    date --rfc-3339=seconds | tee -a $_testlog
    l_echo "suite: $_suite"

    cat $_testlog > $_test_tools_log

    start_run_local

    l_echo
    mkdir -p "$_tmpdir"
}

do_run() {
    # Managed by two variables:
    #   _run_list - run exactly these tests, skip list ignored
    #   _skip_list - run all but these tests
    if [ "x${_run_list}" == "x" ]; then
        for test in `declare -F | sed -n -e "s/declare -f test_/test_/p"`
        do
           _run_list="$_run_list $test"
        done
    else
        _skip_list=""
    fi

    for test in $_run_list
    do
        title=`declare -f $test | sed -n -e "s/title \+//p" | sed -e "s/[ ;\"]\+/ /g"`

        # Additional descriptions within test body. Optional
        outcome=`declare -f $test | sed -n -e "s/outcome \+//p" | sed -e "s/[ ;\"]\+/ /g"`
        if [ "${_print_help}" = "yes" ]; then
           help01=`declare -f $test | sed -n -e "s/help01 \+//p" | sed -e "s/[ ;\"]\+/ /g"`
           help02=`declare -f $test | sed -n -e "s/help02 \+//p" | sed -e "s/[ ;\"]\+/ /g"`
           help03=`declare -f $test | sed -n -e "s/help03 \+//p" | sed -e "s/[ ;\"]\+/ /g"`
           help04=`declare -f $test | sed -n -e "s/help04 \+//p" | sed -e "s/[ ;\"]\+/ /g"`
        fi

        should_skip="no"
        for skip in $_skip_list
        do
            if [ $skip = $test ]; then
              should_skip="yes"
              break;
            fi
        done
        if [ "x$should_skip" = "xyes" ]; then
            echo "$test $title ### TEST SKIPPED" | tee -a $_testlog
        else
            echo "--- $test START $title" | tee -a $_testlog

            for help in "help01" "help02" "help03" "help04"
            do
                if [ ! -z "${!help}" ]; then
                   echo "# $test HELP ${!help}" | tee -a $_testlog
                fi
            done

            (
                # Executing test in a separate shell
                $test
                if [ $? -eq 0 ]; then
                   echo "--- $test TEST OK.... $outcome" | tee -a $_testlog
                else
                   echo "--- $test TEST FAILED $outcome" | tee -a $_testlog
                fi
                echo | tee -a $_testlog
            )
        fi
    done
}

cleanup_run() {
    if [ $_debug != "yes" ]; then
        l_echo "Cleaning ${_tmpdir}"
        for fn in $*
        do
            [ -d "$_tmpdir/$fn" ] && rmdir "$_tmpdir/$fn"
            [ -f "$_tmpdir/$fn" ] && rm -f "$_tmpdir/$fn"
        done
        rmdir -p --ignore-fail-on-non-empty "$_tmpdir"
    else
       l_echo "Debug mode, leave ${_tmpdir}"
    fi
}

finish_run() {
    finish_run_local

    l_echo "Test run finished "
    date --rfc-3339=seconds | tee -a $_testlog
    l_echo "All done."
    l_echo
    l_echo "*** Suite \"$_suite\" Run Summary ***"

    final_list=""
    if [ "x${_run_list}" == "x" ]; then
        for test in `declare -F | sed -n -e "s/declare -f test_/test_/p"`
        do
           _run_list="$_run_list $test"
        done
    fi
    for test in $_run_list
    do
        for skip in $_skip_list
        do
            if [ $skip = $test ]; then
              should_skip="yes"
              break;
            fi
        done
        if [ "x$_should_skip" != "xyes" ]; then
            final_list="$final_list $test"
        fi
    done

    if [ "x${_skip_list}" == "x" ]; then
        l_echo "Tests in run: $final_list"
    else
        l_echo "Tests in run: $final_list / $_skip_list"
    fi


    t_ok=`cat $_testlog | grep "TEST OK" | wc -l`
    t_fail=`cat $_testlog | grep "TEST FAILED" | wc -l`
    t_skip=`cat $_testlog | grep "TEST SKIPPED" | wc -l`

    if [ $t_fail -gt 0 ]; then
        l_echo
        l_echo "Failed tests:"
        cat $_testlog | grep FAILED
        l_echo
    fi

    l_echo "Tests PASSED: $t_ok"
    l_echo "Tests FAILED: $t_fail"
    l_echo "Tests SKIPPED: $t_skip"
    l_echo
}
