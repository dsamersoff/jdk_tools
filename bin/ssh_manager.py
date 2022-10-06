#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: expandtab shiftwidth=2 softtabstop=2

_BANNER="""
  SSH config manager
  Version 1.01 2022-06-14
  Author: Dmitry Samersoff dms@samersoff.net
"""

_HELP="""
Usage: ssh_manager hostname

The tool prepares .ssh_<hostname> folder ready to be copied to the target host.
It reads config_<hostname> file in ssh_config(5) format and

1. Parse IdentityFile option and copy all required private keys to .ssh_<hostname> folder.
   Public keys copied as well for consistency

2. Parse "# AcceptHost <hostname>" meta-comments, find appropriate public key and copy it
   to .ssh_<hostname>/authorized_keys. Keys expected to be named as id_<hostname>_*.pub

NOTE: authorized_keys file will be overwritten.

Example of config_D1H file, this file will be copied to .ssh_D1H/config:

# AcceptKey akino
# AcceptKey natsu
# AcceptKey 4foo
# AcceptKey extern/dmitry

Host github.com
  User git
  IdentityFile ~/.ssh/id_openjdk_rsa

Host akino akino.mircat.net
  IdentityFile ~/.ssh/id_D1H_rsa
"""

import os
import sys
import getopt
import signal
import traceback

from enum import Enum

from glob import glob
import shutil
import re

_ssh_keys_storage = "~/.ssh"

def target(hostname, filename):
  return os.path.normpath(".ssh_%s/%s" % (hostname, filename))

def source(filename):
  global _ssh_keys_storage
  return os.path.normpath("%s/%s" % (_ssh_keys_storage, filename))

def copy_config(hostname):
  shutil.copy("config_%s" % hostname, target(hostname, "config"))

def copy_identity_files(hostname):
  with open("config_%s" % hostname, "r") as fd:
    for ln in fd.readlines():
      idx = ln.find("IdentityFile")
      if idx != -1:
        key_file = os.path.basename(ln[idx + len("IdentityFile") + 1:-1])
        print("Copy key %s ..." % key_file)
        try:
          shutil.copy(source(key_file), target(hostname, key_file))
          shutil.copy(source(key_file + ".pub"), target(hostname, key_file + ".pub"))
        except FileNotFoundError as ex:
          print (ex)

def create_authorized_keys(hostname):
  authorized_key_files = list()
  with open("config_%s" % hostname, "r") as fd:
    for ln in fd.readlines():
      idx = ln.find("AcceptKey")
      if idx != -1:
        key_id = ln[idx + len("AcceptKey") + 1:-1]
        key_id=key_id.rstrip()
        d_idx =key_id.rfind("/")
        dirpart = ""
        if d_idx != -1:
          dirpart = key_id[:d_idx+1]
          key_id = key_id[d_idx+1:]
        key_files_list = glob(source(dirpart + "id_" + key_id + "*.pub"))
        if len(key_files_list) == 0:
          print ("Warning! Accept key %s%s not found" % (dirpart, key_id))
        else:
          authorized_key_files += key_files_list

  if len(authorized_key_files) > 0:
    if os.path.isfile(target(hostname, "authorized_keys")):
      os.remove(target(hostname, "authorized_keys"))
    with open(target(hostname, "authorized_keys"), 'a+') as fdw:
      for kf in authorized_key_files:
        print("Accept key %s ..." % kf)
        with open(kf, "r") as fdr:
          fdw.write(fdr.read())
  return

def signal_handler(signal, frame): #pylint: disable=unused-argument
  sys.stdout.write("\nInterrupted. Exiting ...\n")
  sys.exit(-1)

def usage(msg=None):
  global _HELP
  if msg is not None:
    print ("Error: %s" % msg)
  print(_HELP)
  sys.exit(7)


if __name__ == '__main__':
  signal.signal(signal.SIGINT, signal_handler)

  try:
    opts, args = getopt.getopt(sys.argv[1:],
                                "hVs:",
                               ["help", "version"])

    for o, a in opts:
      if o in ("-h", "--help", "-V", "--version"):
        print(_BANNER)
        if o in ("-h", "--help"):
          usage()
        sys.exit(7)
      elif o in ("-s", "--storage"):
        """Path to ssh key storage"""
        _ssh_keys_storage = a
      else:
        assert False, "Unhandled option '%s'" % o

  # except getopt.GetoptError as ex:
  except Exception as ex:
    usage("Bad command line: %s (%s) " % (str(ex), repr(sys.argv[1:])))

  _ssh_keys_storage = os.path.abspath(os.path.expanduser(_ssh_keys_storage))

  assert os.path.isdir(_ssh_keys_storage), "Key storage %s is not a directory" % _ssh_keys_storage
  assert args[0] != "", "Host should be specified"
  assert os.path.isfile("config_%s" % args[0]), "Config file 'config_%s' does not exist or not readable" % args[0]

  os.makedirs(".ssh_%s" % args[0], exist_ok = True)
  copy_config(args[0])
  copy_identity_files(args[0])
  create_authorized_keys(args[0])
