#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: expandtab shiftwidth=2 softtabstop=2

# version 3.01 2020-09-14

#import warnings 
#with warnings.catch_warnings():
#    warnings.filterwarnings("ignore",category=DeprecationWarning)


import sys
import os
import traceback
import getopt
import re
import getpass

import paramiko
from paramiko.config import SSHConfig

from stat import S_ISDIR

# ======= USER PARAMETERS SETUP ===========
_hostname ="cr.openjdk.java.net"
_hostkeys_file = "~/.ssh/known_hosts"
_userkey_file = "~/.ssh/id_dsamersoff_rsa"
_sshconfig_file = "~/.ssh/config"
_port = 22

_username = None              # guess from ssh config or unix, see -u below
_verbose = True               # see -v below
_confirm = False              # see -v below
#==========================================

# Globals
_action = "copy"

def copytree(sftp, src, dst):
    """SFTP directory recursively. Warning! Works only if src & dst are directories"""
    names = os.listdir(src)
    sftp.mkdir(dst)
    for name in names:
        srcname = os.path.join(src, name)
        dstname = os.path.join(dst, name)
        if os.path.isdir(srcname):
           copytree(sftp,srcname, dstname)
        else:
           sftp.put(srcname, dstname)

def deltree(sftp, dst):
    """Delete directory recursively over SFTP"""
    names = sftp.listdir(dst)
    for name in names:
        dstname = os.path.join(dst, name)
        if S_ISDIR(sftp.stat(dstname).st_mode):
           deltree(sftp, dstname)
        else:
           sftp.remove(dstname)
    sftp.rmdir(dst)

def guess_name(dirlist):
    """Enumerate all existsing webrev.NNN directories. And return latest number"""
    num = 0
    for w in sorted(dirlist):
        if w.startswith("webrev."):
            try:
              p = int(w[7:])
              if p > num :
                num = p
            except ValueError:
              pass
    return num

def proceed_delete(sftp, crId):
  """Delete webrev from openjdk server"""
  dirlist = sftp.listdir('.')
  # verbose("CR List: " + repr(sorted(dirlist)))

  if not crId in dirlist :
    raise Exception("Unable to find cr '%s'" % crId)
  sftp.chdir(crId)
  dirlist = sftp.listdir('.')
  # verbose("Webrev List: " + repr(sorted(dirlist)))

  num = guess_name(dirlist)
  webrevName = "webrev.%02d" % num
  if confirm("About to delete '%s/%s'. Confirm?" % (crId,webrevName)) :
    deltree(sftp, webrevName)
    sftp.chdir("..")
    verbose("Delete done. Remote wd: " + sftp.getcwd())
  else:
    verbose("Bailout")

def proceed_copy(sftp,crId):
    """Copy webrev to openjdk server"""
    dirlist = sftp.listdir('.')
    # verbose("CR List: " + repr(sorted(dirlist)))
    webrevName = None

    if not crId in dirlist :
      if confirm("About to create '%s'. Confirm?" % crId):
        sftp.mkdir(crId)
        sftp.chdir(crId)
        webrevName = "webrev.01"
      else:
        verbose("Bailout")
    else:
      sftp.chdir(crId)
      dirlist = sftp.listdir('.')
      # verbose("Webrev List:" + repr(sorted(dirlist)))

      num = guess_name(dirlist)
      webrevName = "webrev.%02d" % (num+1)

    srcName = None
    if os.path.exists("webrev"):
      srcName = "webrev"
    elif os.path.exists("webrevs"):
      srcName = "webrevs"

    if srcName != None and webrevName != None:
      if confirm("About to copy '%s' to '%s/%s'. Confirm?" % (srcName, crId, webrevName)) :
        copytree(sftp, srcName, webrevName)
        verbose("Copy done")
      else:
        verbose("Bailout")
    else:
      verbose("Can't take src or dest webrev name. Bailout")


def proceed_list(sftp, crId):
  """List webrevs on openjdk server"""
  dirlist = sftp.listdir('.')
  # verbose("CR List: " + repr(sorted(dirlist)))
  if not crId in dirlist :
    raise Exception("Unable to find cr '%s'" % crId)
  sftp.chdir(crId)
  dirlist = sftp.listdir('.')
  for dirName in sorted(dirlist):
    print(dirName)

def confirm(question, default="yes"):
  """Ask a yes/no question via raw_input() and return their answer."""
  valid = {"yes":True, "y":True, "ye":True, "no":False, "n":False}

  if default == None:
    prompt = " [y/n] "
  elif default == "yes":
    prompt = " [Y/n] "
  elif default == "no":
    prompt = " [y/N] "
  else:
    raise ValueError("invalid default answer: '%s'" % default)

  if _confirm == False and default != None:
    if _verbose == True:
      print(question + prompt + default)
    return valid[default]

  while True:
    sys.stdout.write(question + prompt)
    choice = input().lower()
    if default is not None and choice == '':
      return valid[default]
    elif choice in valid:
      return valid[choice]
    else:
      sys.stdout.write("Please respond with 'yes' or 'no' (or 'y' or 'n').\n")

def error(msg):
  print("Error: " + msg)
  sys.exit(255)

def verbose(msg):
  if _verbose:
    print(msg)

def usage():
  print("webrev_put [-d|-l|-c*] [-v] [-u username] CR")
  sys.exit(7)

if __name__ == '__main__':
  try:
    opts, args = getopt.getopt(sys.argv[1:], 
       "hcdlpru:v", 
       ["help","copy","delete","confirm","list","replace","user=","verbose"])
  except getopt.GetoptError as err:
    error(repr(err))

  for o, a in opts:
    if o in ("-c", "--copy"):
      """Copy webrev to openjdk server"""
      _action = "copy"
    elif o in ("-d", "--delete"):
      """Delete last found webrev"""
      _action = "delete"
    elif o in ("-l", "--list"):
      """List webrevs"""
      _action = "list"
    elif o in ("-p", "--confirm"):
      """Confirm actions."""
      _confirm = not _confirm
    elif o in ("-r", "--replace"):
      """Delete last found webrev and copy new one"""
      _action = "replace"
    elif o in ("-u", "--user"):
      """Username to login, - means auto/prompt"""
      _username = a 
    elif o in ("-v", "--verbose"):
      """Verbose operations."""
      _verbose = not _verbose
    elif o in ("-h", "--help"):
      usage()
    else:
      assert False,"Unhandled option '%s'" % o

  crId = None
  if len(args) > 0:
    crId = args[0]
  else:
    """ Guess CR from pwd """
    for cr in os.getcwd().split('/'):
      match = re.match("[^0-9]*([0-9]+).*",cr)
      if match != None:
        crId = cr
        break

  if crId == None:
    error("Can't guess CR ID and it's not specified")

  verbose("Using CR ID '%s'" % crId)

  # ** Setup paramico **
  # paramiko.common.logging.basicConfig(level=paramiko.common.DEBUG)
  # paramiko.util.log_to_file('/tmp/sftp_webrev.log')
  verbose("Using hostname '%s'" % _hostname)

  # get username from ssh config or current user if it's not set in command line
  if _username == None:
    ssh_config = SSHConfig()
    try:
      with open(os.path.expanduser(_sshconfig_file)) as fh:
        ssh_config.parse(fh)
        hostdata = ssh_config.lookup(_hostname)
        _username = hostdata["user"]
    except Exception as e:
      verbose("Can't extract username from ssh config file %s" % repr(e))

    if _username == None:
      _username = getpass.getuser()

  verbose("Using username '%s'" % _username)

  hostkey_file = os.path.expanduser(_hostkeys_file)
  verbose("Using hostkey file '%s'" % hostkey_file)
  try:
    host_keys = paramiko.util.load_host_keys(hostkey_file)
  except IOError:
    error("Unable to open host keys file '%s'" % hostkey_file)

  # if hasattr(host_keys, has_key):
  #   """ Support old paramiko """
  #   if not host_keys.has_key(_hostname):
  #     error("No keys for host %s" % _hostname)
  
  if not _hostname in host_keys:
      error("No keys for host %s" % _hostname)

  hostkeytype = host_keys[_hostname].keys()[0]
  hostkey = host_keys[_hostname][hostkeytype]

  userkey_file = os.path.expanduser(_userkey_file)
  verbose("Using userkey file '%s'" % userkey_file)

  try:
    key = paramiko.RSAKey.from_private_key_file(userkey_file)
  except paramiko.PasswordRequiredException:
    password = getpass.getpass("RSA key password: ")
    key = paramiko.RSAKey.from_private_key_file(userkey_file, password)

  try:
    t = paramiko.Transport((_hostname, _port))
    t.connect(username=_username, hostkey=hostkey, pkey=key)

    sftp = paramiko.SFTPClient.from_transport(t)

    if _action == "copy":
      proceed_copy(sftp,crId)
    elif _action == "delete":
      proceed_delete(sftp,crId)
    elif _action == "replace":
      proceed_delete(sftp,crId)
      proceed_copy(sftp,crId)
    elif _action == "list":
      proceed_list(sftp,crId)
    else:
      assert False, "Bad action '%s'" % _action

  except Exception as e:
    print(repr(e))
    if _verbose:
      traceback.print_exc()
    sys.exit(1)
  finally:
    t.close()
