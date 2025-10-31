#!/bin/bash

# Set to "yes" to keep $_tmpdir and enable some additional output
_debug="no"
[ "x$1" = "xdebug" ] && _debug="yes" && shift

# Tests to be executed,
# Empty _run_list means all, if _run_list is not empty, _skip_list is ignored
_run_list=$*
_skip_list=""
_print_help="yes"

. ../testlib.sh

start_run

# List all tmp files to be deleted on testsuite finish
cleanup_list="testme.txt ziplister.class"

# Perform additional initialization
prepare_run() {
    extract_precompiled_if_exist
    [ "$?" -eq 0 ] && return

    for jf in ziplister.java
    do
        do_javac \
            --source-path="${_rt}" \
            -d $_tmpdir $_rt/$jf
    done

    build_precompiled
}

# ==== Define tests
test_001() {
    title "Simplest example test"
    outcome "The sample is OK"

    help01 "This test tests nothing"
    help02 "But provides an example of harnes usage"

    echo "We are testing"
    result_eq
    return $?
}

test_002() {
    title "Simplest negative example test"
    echo "We are testing" | grep -q Bla
    result_ne
    return $?
}

test_003() {
    title "Test that uses tmpdir"
    echo "We are testing" > $_tmpdir/testme.txt
    cd $_tmpdir
    cat testme.txt | grep -q are
    result_eq
    return $?
}

test_003() {
    title "Test that intentionally fails"

    help01 "This test always fails"
    help02 "And demonstrate harnes reporting"

    return 1
}


# ====== Execute
prepare_run
do_run
cleanup_run $cleanup_list
finish_run
