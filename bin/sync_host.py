#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: expandtab shiftwidth=2 softtabstop=2

# version 3.01 2020-09-14

#import warnings
#with warnings.catch_warnings():
#    warnings.filterwarnings("ignore",category=DeprecationWarning)

import getopt
import getpass
import glob
import math
import os
import re
import sys
import time
import traceback

import paramiko
from paramiko.config import SSHConfig

from stat import S_ISDIR

# ======= PARAMETERS SETUP ===========
_identity_files = ["~/.ssh/id_dsamersoff_rsa"]
_sshconfig_file = "~/.ssh/config"
_port = 22
_username = None  # guess from ssh config or unix, see -u below
_verbose = True   # see -v below
_skip_debug_info = True
_update_only = True

# ======== Source Layout ==================
_jdk_image = os.getenv("TESTJAVA", None)
_jdk_tests = "../../../../../test"
_jdk_tests_native = "/../../support/test/hotspot/jtreg/native"
_copy_all = False

# ===== Target Host layout ================
_target_host = os.getenv("TESTHOST", "pi64")
_target_image = "/export/ojdk/jdk"
_target_tests = "/export/ojdk/tests"
_target_tests_native = "/export/ojdk/native"

class SFTPWrapper:
  """Utility wrappers around paramico SFTP"""
  def __init__(self, p_sftp) -> None:
    self.sftp = p_sftp
    self.count = 0
    self.start_time = time.time_ns()

  def copy_with_attr(self, srcname, dstname, srcstat):
    """Copy file to server and restore all attributes"""
    self.sftp.put(srcname, dstname)
    self.sftp.chmod(dstname, srcstat.st_mode)
    self.sftp.utime(dstname, (srcstat.st_atime, srcstat.st_mtime))
    self.count += 1

  def stat_no_error(self, dstname):
    dst = None
    try:
      dst = self.sftp.stat(dstname)
    except IOError as ex:
      pass
    return dst

  def mkdir_no_error(self, dstname):
    try:
      self.sftp.mkdir(dstname)
    except IOError as ex:
      pass

  def make_writable(self, dstname):
    self.sftp.chmod(dstname, 0o666)

  def files_copied(self):
    return self.count

  def exec_time(self):
    dt = time.time_ns() - self.start_time
    return (dt//1_000_000_000, (dt - dt//1_000_000_000)//1_000)

# ======================================================================================
def should_copy(srcname):
  """Filter out some files by name, path or extension"""
  if srcname == "src.zip":
    return False
  if _skip_debug_info and srcname.endswith(".debuginfo"):
    return False
  return True

def copytree(sftp, src, dst):
  """SFTP directory recursively. Warning! Works only if src & dst are directories"""
  names = os.listdir(src)
  sftp.mkdir_no_error(dst)
  for name in names:
    srcname = os.path.join(src, name)
    dstname = os.path.join(dst, name)
    if os.path.isdir(srcname):
      copytree(sftp, srcname, dstname)
    else:
      if should_copy(srcname):
        srcstat = os.stat(srcname)
        dststat = sftp.stat_no_error(dstname)
        if dststat != None:
          if not (_update_only and srcstat.st_mode == dststat.st_mode and math.isclose(srcstat.st_mtime, dststat.st_mtime)):
            verbose("Copy: %s" % srcname)
            sftp.make_writable(dstname)
            sftp.copy_with_attr(srcname, dstname, srcstat)
        else:
          verbose("Copy: %s" % srcname)
          sftp.copy_with_attr(srcname, dstname, srcstat)

def error(msg):
  print("Error: " + msg)
  sys.exit(255)

def verbose(msg):
  if _verbose:
    print(msg)

def usage():
  print("sync_host [-c] [-v] [-u username] [-t testhost] $TESTJAVA")
  sys.exit(7)

if __name__ == '__main__':
  try:
    opts, args = getopt.getopt(sys.argv[1:],
       "hadt:u:rv",
       ["help", "all", "debug-info", "target=", "user=", "replace", "verbose"])
  except getopt.GetoptError as err:
    error(repr(err))

  for o, a in opts:
    if o in ("-a", "--all"):
      """Copy everything including tests"""
      _copy_all = True
    elif o in ("-d", "--debug-info"):
      """Copy debug info"""
      _skip_debug_info = False
    elif o in ("-u", "--user"):
      """Username to login, - means auto/prompt"""
      _username = a
    elif o in ("-t", "--target"):
      """Target host to sync"""
      _target_host = a
    elif o in ("-r", "--replace"):
      """Don't check destignation file date"""
      _update_only = False
    elif o in ("-v", "--verbose"):
      """Verbose operations."""
      _verbose = not _verbose
    elif o in ("-h", "--help"):
      usage()
    else:
      assert False,"Unhandled option '%s'" % o

  # Source path setup
  if len(args) > 0:
    """ Set path to copy, overrides $TESTJAVA"""
    _jdk_image = args[0]
  if len(args) > 1:
    """ Set host to copy to, override $TESTHOST and -t key"""
    _target_host = args[1]

  try:
    if _jdk_image == None:
      """ Try to guess from current dir """
      jdk_images = glob.glob("./build/*/images/jdk")
      assert len(jdk_images) <= 1, "More than one image present, specify image to copy explicitly"
      if len(jdk_images) == 1:
        _jdk_image = jdk_images[0]

    assert _jdk_image != None, "Nothing to copy. Specify image to copy in command line or through $TESTJAVA"

    _jdk_image = os.path.abspath(_jdk_image)

    assert os.path.isdir(_jdk_image), "Path %s dosn't exist or not a directory" % _jdk_image
    assert os.path.isfile(_jdk_image + "/bin/java"), "Path %s is not a jdk image" % _jdk_image

    verbose("Copy from '%s'" % _jdk_image)

    if _copy_all:
      _skip_debug_info = False # Copy all imply copying of debuginfo
      _jdk_tests = os.path.abspath(_jdk_image + _jdk_tests)
      _jdk_tests_native = os.path.abspath(_jdk_image + _jdk_tests_native)
      assert os.path.isdir(_jdk_tests), "Path %s dosn't exist or not a directory" % _jdk_tests
      assert os.path.isdir(_jdk_tests_native), "Path %s dosn't exist or not a directory. Run make test-bundles" % _jdk_tests_native
      verbose("Copy from '%s'" % _jdk_tests)
      verbose("Copy from '%s'" % _jdk_tests_native)

    verbose("To host '%s'" % _target_host)

  except AssertionError as ex:
    print(ex)
    sys.exit(1)

  # Read SSH config
  ssh_config = SSHConfig()
  try:
    with open(os.path.expanduser(_sshconfig_file)) as fh:
      ssh_config.parse(fh)
  except Exception as e:
    verbose("Can't read ssh config file %s" % repr(e))

  host_entry = ssh_config.lookup(_target_host)
  _target_port = host_entry.get('port', _port)
  _username = host_entry.get("user", None)
  if _username == None:
    _username = getpass.getuser()
  _userkeys = host_entry.get("identityfile", _identity_files)

  verbose("Using username '%s'" % _username)
  verbose("Using IdentityFiles '%s'" % _userkeys)

  # connect to host by SFTP
  ssh = paramiko.SSHClient()
  ssh.load_system_host_keys()
  ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

  try:
    ssh.connect(_target_host, port=_target_port, username=_username, key_filename=_userkeys)
    sftp = SFTPWrapper(ssh.open_sftp())
    copytree(sftp, _jdk_image, _target_image)
    if _copy_all:
      copytree(sftp, _jdk_tests, _target_tests)
      copytree(sftp, _jdk_tests_native, _target_tests_native)

    # Some statistics
    (ss, ms) = sftp.exec_time()
    print("Total file copied: %d in %d.%d" % (sftp.files_copied(), ss, ms))

  except Exception as e:
    print(repr(e))
    if _verbose:
      traceback.print_exc()
    sys.exit(1)
  finally:
    ssh.close()
