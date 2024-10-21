#!/bin/bash

# Set to "yes" to keep $_tmpdir and enable some additional output
_debug="no"
[ "x$1" = "xdebug" ] && _debug="yes" && shift

# Tests to be executed,
# Empty _run_list means all, if _run_list is not empty, _skip_list is ignored
_run_list=$*
_skip_list=""

. ../testlib.sh

start_run

# Perform additional initialization

# ==== Define tests
test_001() {
    title "Simplest example test"
    echo "We are testing"
    result_eq
}

test_002() {
    title "Simplest negative example test"
    echo "We are testing" | grep -q Bla
    result_ne
}

test_003() {
    title "Test that uses tmpdir"
    echo "We are testing" > $_tmpdir/testme.txt
    cd $_tmpdir
    cat testme.txt | grep -q are
    result_eq
}

# ====== Execute
do_run
# List all tmp files to be deleted below
cleanup_run testme.txt
finish_run
