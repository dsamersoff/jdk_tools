# Don't run, this is include file

# Define basic harnes constants
_rt=`dirname $0`
_rt=`cd $_rt && pwd`

_suite=`basename $_rt`
_tmpdir="$_rt/scratch"
_testlog="$_rt/${_suite}-test.log"

cd "$_rt"

[ -f $_rt/../testlib_local.sh ] && source $_rt/../testlib_local.sh

l_echo() {
    echo $* | tee -a $_testlog
}

title() {
    echo
}

result() {
    if [ $1 -eq 0 ]; then
        l_echo "+++ TEST OK"
    else
        l_echo "!!! TEST FAILED"
    fi
}

result_eq() {
    result $? $1
}

result_ne() {
    rc=`expr 1 - $?`
    result $rc $1
}

uid_check() {
    uid=`id -u`
    if [ $uid -ne 0 ]; then
        echo "Test must be run with uid = 0"
        exit 1
    fi
}

start_run() {
    if [ "x${BASH_VERSION}" = "x" ]; then
       echo "Bash required, exiting"
       exit 1
    fi

    uid_check
    echo "Test run started " > $_testlog
    date --rfc-3339=seconds | tee -a $_testlog
    l_echo "suite: $_suite"

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
        title=`declare -f $test | sed -n -e "s/title //p" | sed -e "s/[ ;\"]\+/ /g"`
        should_skip="no"
        for skip in $_skip_list
        do
            if [ $skip = $test ]; then
              should_skip="yes"
              break;
            fi
        done
        if [ "x$should_skip" = "xyes" ]; then
            echo "$test $title --- TEST SKIPPED" | tee -a $_testlog
        else
            echo -n "$test $title" | tee -a $_testlog
            $test
        fi
    done
}

cleanup_run() {
    if [ $_debug != "yes" ]; then
        l_echo "Cleaning ${_tmpdir}"
        for fn in $*
        do
            [ -d $_tmpdir/$fn ] && rmdir $_tmpdir/$fn
            [ -f $_tmpdir/$fn ] && rm -f $_tmpdir/$fn
        done
        rmdir $_tmpdir
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
    l_echo "***** Test \"$_suite\" Run Summary ****"

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


    t_ok=`cat $_testlog | grep OK | wc -l`
    t_fail=`cat $_testlog | grep FAILED | wc -l`
    t_skip=`cat $_testlog | grep SKIPPED | wc -l`

    if [ $t_fail -ne 0 ]; then
        l_echo "Failed tests:"
        cat $_testlog | grep FAILED | tee -a $_testlog
        l_echo
    fi

    l_echo "Tests PASSED: $t_ok"
    l_echo "Tests FAILED: $t_fail"
    l_echo "Tests SKIPPED: $t_skip"
    l_echo
}
