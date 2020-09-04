#!/bin/sh

# Directory to drop jdk sources to
export JDK_WORKSPACE_ROOT=/home/dsamersoff/workspaces

# Directory to search for boot jdk - jdk11, jdk14 etc
export JDK_COLLECTION_ROOT=/opt/dsamersoff

# Remote machine to run on
# ssh key-based auth have to be working
# Add to ~/.ssh/config 
# PasswordAuthentication=no 

export JBB_REMOTE="dsamersoff@10.112.40.87"

# Directory to store specjbb runs
export JBB_RUN_ROOT=/home/dsamersoff/specjbb_work

# Location of specjbb distro
export JBB_HOME="/home/dsamersoff/specjbb2015-1.03a"

