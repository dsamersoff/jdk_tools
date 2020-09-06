#!/bin/sh

VERSION="2.02 2020-09-06"

# Directory to drop jdk sources to
export JDK_WORKSPACE_ROOT=/home/dsamersoff/workspaces

# Directory to search for boot jdk - jdk11, jdk14 etc
export JDK_COLLECTION_ROOT=/opt/dsamersoff

# Remote machine setup

# ssh key-based auth have to be working
# Add to ~/.ssh/config 
# PasswordAuthentication=no 

export JBB_REMOTE_USER="dsamersoff"
export JBB_REMOTE_HOST="10.112.40.87"

# Remove job data from remote machine, when job finishes
export JBB_REMOTE_CLEANUP=Yes

# Directory to store specjbb runs
export JBB_REMOTE_ROOT=/home/dsamersoff/specjbb_work

# Location of specjbb distro on the remote machine
export JBB_HOME="/home/dsamersoff/specjbb2015-1.03a"

# JTEG support
# Stable JDK to run jtreg it self
export JTREG_JAVA="/export/dsamersoff/bin/java"

# Path to tests relative to workspace root
export JTREG_TEST_ROOT="test/hotspot/jtreg"

# Path to jtreg
export JTREG_HOME="/export/dsamersoff/jtreg"