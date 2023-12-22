#!/usr/bin/python3
# -*- coding: utf-8 -*-
# vim: expandtab shiftwidth=2 softtabstop=2

# Version 3.07 2020-05-25

_HELP="""
The program to sync current machine folder with owncloud instance
Basic usage:
 ./owncsync.py -l user:password -d|-u file1 dir2 ... ...

Command line options:
 -c                Check file date and overwrite on upload if cloud instance is older than host one
 -d                Download either directory as zip or individual files
 -f                Always overwrite on upload
 -l user:password  Set login credentials from command line
 -p prefix         Prefix destination path with directory on upload, hostname by default
 -P                Don't prefix destination path with hostname on upload
 -t int            Tolerance time value in seconds, files with difference less than this time treated as the same
 -u                Upload files from path, default mode
 -v int            Level of verbosity 0 silent, 9 debug

 All these options could be set in ini file, it will be created in the user home directory on the first run.
 System wide ini in /etc, /usr/local/etc, /opt/etc are respected
"""
import os
import sys
import getopt
import platform
import traceback
import configparser

from datetime import datetime, timedelta
from signal import signal, SIGINT

try:
  import nextcloud_client as cloud
  HTTPResponseError = cloud.nextcloud_client.HTTPResponseError
except ImportError as ex:
  print("Error: %s, run: pip install pyncclient" % str(ex))
  sys.exit(-1)

_cloud = "4foo.net"
_oc_url = "https://cloud.4foo.net/nextcloud"
_user = "ojdk"
_password = None
_overwrite = "never" # never, always, check
_verbose = 2
_tolerance = 10

_mode = "upload"
_ini_name = ".ownsync.ini"
_host = platform.uname()[1]

# BEGIN: Disable SSL certificates check for requests lib
import requests, urllib3
from requests.packages.urllib3.exceptions import InsecureRequestWarning #pylint: disable=import-error,no-member

requests.packages.urllib3.disable_warnings(InsecureRequestWarning) #pylint: disable=import-error,no-member
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
os.environ["CURL_CA_BUNDLE"] = ""
# END

""" Supporting function """
def print_vb(level, msg):
  global _verbose
  if _verbose >= level:
    today_str = datetime.today().strftime("%Y%m%d %H%M%S")
    print("%s:%d: %s" % (today_str, level, msg))

def fatal(msg, ex):
  """ Report exception if requested """
  global _verbose

  print(msg + "(%s)" % str(ex))
  if _verbose > 2:
    print(traceback.format_exc())
  sys.exit(-1)

def compare_dates(a, b):
  """ Return whether date a > b, with tolerance """
  global _tolerance
  if a > b:
    difference = (a - b).total_seconds()
    if difference > _tolerance:
      return True
  return False

def format_dates(a, b):
  """ Format date difference in printable way """
  global _tolerance

  difference = (a - b).total_seconds()
  # gt = "-gt" if compare_dates(src_lmd, dst_lmd) else "-le"
  return "%s vs %s (%d/%d)" % (str(a), str(b), difference, _tolerance)

class ocWrapper(object):
  def __init__(self, url, hostname, username, password):
    self.url = url
    self.user = username
    self.password = password
    self.hostname = hostname
    self.oc = None

  def connect(self):
    """ Connect to cloud with error check """
    try:
      self.oc = cloud.Client(self.url)
      self.oc.login(self.user, self.password)
    except HTTPResponseError as ex:
      if ex.status_code == 401:
        fatal("Authentication failed for '%s' as '%s'" % (self.url, self.user), ex)
      else:
        raise ex
    return

  def make_root(self):
    """ Make root directory """
    if self.hostname != "":
      self.mkdir("")

  def normpath(self, dst, prefix_hostname = True):
    """Convert remote path to unified form """
    (drive, tail) = os.path.splitdrive(dst) #pylint: disable=unused-variable
    tail = os.path.normpath(tail)
    path_elements = [ self.hostname ] if prefix_hostname else []
    path_elements += tail.split(os.sep)
    return "/".join(path_elements)

  def mkdir(self, dst):
    """ Make remote directory with response check"""
    dstname = self.normpath(dst)
    try:
      print_vb(3, "Mkdir '%s'" % dstname)
      self.oc.mkdir(dstname)
    except HTTPResponseError as ex:
      if ex.status_code == 405:
        """ Ignore file already exists error """
        print_vb(9, "Error creating '%s' '%s' (ignored)" % (dstname, str(ex)))
      else:
        raise ex

  def mkpath(self, dst):
    """ Make entire path on remote, take dst as it is """
    dst_path = dst.split("/")
    dstname = ""
    for dst_item in dst_path:
      dstname = dstname + "/" + dst_item
      try:
        print_vb(3, "Mkdir '%s'" % dstname)
        self.oc.mkdir(dstname)
      except HTTPResponseError as ex:
        if ex.status_code == 405:
          """ Ignore file already exists error """
          print_vb(9, "Error creating '%s' '%s' (ignored)" % (dstname, str(ex)))
        else:
          raise ex

  def get_lmd(self, dst):
    """ Get last modified date with response check"""
    dstname = self.normpath(dst)
    lmd = None
    try:
      print_vb(3, "Get lmd '%s'" % dstname)
      file_info = self.oc.file_info(dstname)
      lmd = file_info.get_last_modified()
    except HTTPResponseError as ex:
      if ex.status_code == 404:
        """ Ignore file doesn't exist error """
        print_vb(9, "Error reading fileinfo '%s' '%s' (ignored)" % (dstname, str(ex)))
      else:
        raise ex
    return lmd

  def is_dir(self, dst, prefix_hostname = True):
    """ Test for directory with response check"""
    isdir = False
    dstname = self.normpath(dst, prefix_hostname)
    try:
      print_vb(3, "Get isdir '%s'" % dstname)
      isdir = self.oc.file_info(dstname).is_dir()
    except HTTPResponseError as ex:
      if ex.status_code == 404:
        """ Ignore file doesn't exist error """
        print_vb(9, "Error reading fileinfo '%s' '%s' (ignored)" % (dstname, str(ex)))
      else:
        raise ex
    return isdir

  def should_copy(self, overwrite, src, dst):
    dst_lmd = self.get_lmd(dst)
    t = os.path.getmtime(src)
    src_lmd = datetime.utcfromtimestamp(round(float(t)))

    if dst_lmd == None:
      """ File doesn't exists """
      print_vb(2, "Doesn't exist(%s) %s %s" % (_overwrite, dst, str(src_lmd)))
      return True

    if overwrite == 'check':
      if compare_dates(src_lmd, dst_lmd):
        """ Local file is newer than remote one """
        print_vb(2, "Updating(%s) %s %s" % (_overwrite, dst, format_dates(src_lmd, dst_lmd)))
        return True

    if overwrite == 'always':
      print_vb(2, "Overwriting(%s) %s %s" % (_overwrite, dst, format_dates(src_lmd, dst_lmd)))
      return True

    print_vb(2, "Skipping(%s) %s %s" % (_overwrite, dst, format_dates(src_lmd, dst_lmd)))
    return False

  def rm_file(self, remote):
    dstname = self.normpath(remote)
    print_vb(1, "Deleting '%s'" % dstname)
    self.oc.delete(dstname)

  def put_file(self, local, remote):
    dstname = self.normpath(remote)
    print_vb(1, "Upload '%s' => '%s'" % (local, dstname))
    try:
      self.oc.put_file(dstname, local)
    except HTTPResponseError as ex:
      if ex.status_code == 404:
        """ Cloud returns file doen't exist. It might mean that entire path doesn't exist anymore
            Try to fix the path and repeat """
        print_vb(9, "Error creating '%s' '%s' (fixing)" % (dstname, str(ex)))
        self.mkpath(os.path.dirname(dstname))
        print_vb(9, "Upload '%s' => '%s'" % (local, dstname))
        self.oc.put_file(dstname, local)
      else:
        raise ex



  def get_file(self, remote, local):
    rmtname = self.normpath(remote, False)
    print_vb(1, "Download '%s' => '%s'" % (rmtname, local))
    self.oc.get_file(remote, local)

  def get_dir_as_zip(self, remote, local):
    rmtname = self.normpath(remote, False)
    print_vb(1, "Zip '%s' => '%s'" % (rmtname, local))
    self.oc.get_directory_as_zip(remote, local)

# ====================== Entry points ==================================
def upload_tree(oc, src, dst):
  """Upload file or entire directory recursively"""
  global _overwrite

  if not os.path.isdir(src):
    if oc.should_copy(_overwrite, src, dst):
      oc.put_file(dst, src)
    return

  oc.mkdir(dst)
  names = os.listdir(src)
  for name in names:
    upload_tree(oc, os.path.join(src, name), os.path.join(dst, name))
  return

def download_zip(oc, local, remote):
  """Download a file of directory as zip"""
  local_name = local
  if oc.is_dir(remote, False):
    if os.path.isdir(local):
      zipname = remote.split('/')[-1] + ".zip"
      local_name = os.path.join(local, zipname)
    oc.get_dir_as_zip(remote, local_name)
  else:
    if os.path.isdir(local):
      dstname = remote.split('/')[-1]
      local_name = os.path.join(local, dstname)
    oc.get_file(remote, local_name)

def load_defaults():
  """ Load defaults from the configuration file. """
  global _ini_name, _oc_url, _user, _password, _overwrite, _verbose, _tolerance, _cloud

  inifiles = [
    os.path.join("/etc", _ini_name),
    os.path.join("/usr/local/etc", _ini_name),
    os.path.join("/opt/etc", _ini_name),
    os.path.expanduser(os.path.join("~", _ini_name))
  ]

  config_loaded = False
  cfg = configparser.ConfigParser()
  for inifile in inifiles:
    if os.path.exists(inifile):
      cfg.read(inifile)
      config_loaded = True

  if config_loaded:
    cloud = cfg.get("DEFAULT", "name")
    _oc_url = cfg.get(cloud, "url", fallback=_oc_url)
    _user = cfg.get(cloud, "user", fallback=_user)
    _password = cfg.get(cloud, "password", fallback=None)
    _overwrite = cfg.get(cloud, "overwrite", fallback=_overwrite)
    _verbose = cfg.getint(cloud, "verbose", fallback=_verbose)
    _tolerance = cfg.getint(cloud, "tolerance", fallback=_tolerance)
  return config_loaded

def store_defaults():
  """ Load defaults from the configuration file. """
  global _ini_name, _oc_url, _user, _password, _overwrite, _verbose, _tolerance, _cloud

  cfg = configparser.ConfigParser()
  cfg["DEFAULT"]["name"] = _cloud
  cfg[_cloud] = {}
  mycloud = cfg[_cloud]
  mycloud["url"] = _oc_url
  mycloud["user"] = _user
  mycloud["password"] = ""
  mycloud["overwrite"] = _overwrite
  mycloud["verbose"] = str(_verbose)
  mycloud["tolerance"] = str(_tolerance)

  inifile = os.path.expanduser(os.path.join("~", _ini_name))
  with open(inifile, 'w') as ofd:
    cfg.write(ofd)

def signal_handler(signal, frame): #pylint: disable=unused-argument
  sys.stdout.write("\nInterrupted. Exiting ...\n")
  sys.exit(-1)

def usage(msg=None):
  global _HELP
  if msg != None:
    print(msg)
  print(_HELP)
  sys.exit(7)

if __name__ == '__main__':
  """ set ctrl-C handler and reopen stdout unbuffered """
  signal(SIGINT, signal_handler)

  if not load_defaults():
    store_defaults()

  try:
    opts, args = getopt.getopt(sys.argv[1:],
                              "hcfl:n:NdpPt:uv:z",
                              ["help", "check", "force", "login" "download",
                               "prefix", "no-prefix", "tolerance", "upload", "verbose", "zip"])
  except getopt.GetoptError as ex:
    usage(ex)

  for o, a in opts:
    if o in ("-h", "--help"):
      usage()
    elif o in ("-c", "--check"):
      """Overwrite on upload if cloud instance is older than host one"""
      _overwrite = "check"
    elif o in ("-d", "--download", "-z", "--zip"):
      """ Download either directory as zip or individual files """
      _mode = "download"
    elif o in ("-f", "--force"):
      """Always overwrite on upload"""
      _overwrite = "always"
    elif o in ("-l", "--login"):
      """Set login credentials from command line user:password"""
      (_user, _password) = a.split(":", 2)
    elif o in ("-p", "--prefix"):
      """ Override hostname prefix on upload """
      _host = a
    elif o in ("-P", "--no-prefix"):
      """ Don't prefix hostname on upload """
      _host = ""
    elif o in ("-t", "--tolerance"):
      """ Tolerance time value in seconds """
      _tolerance = int(a)
    elif o in ("-u", "--upload"):
      """ Upload files from path """
      _mode = "upload"
    elif o in ("-v", "--verbose"):
      """ Verbose output """
      _verbose = int(a)
    else:
      assert False, "unhandled option '%s'" % o

  if len(args) == 0:
    usage()

  print_vb(9, "_oc_url = %s" %_oc_url)
  print_vb(9, "_user = %s" % _user)
  print_vb(9, "_password = %s" % _password)
  print_vb(9, "_overwrite = %s" % _overwrite)
  print_vb(9, "_tolerance = %s" % _tolerance)

  try:
    assert _overwrite in ["never", "always", "check"], "Bad _overwrite value %s" % _overwrite
    assert _mode in ["upload", "download"], "Bad _mode value %s" % _mode
    assert _password != None, "Password must be set. Check ~/%s file or use -l name:password" % _ini_name
  except AssertionError as ex:
    usage(ex)

  oc = ocWrapper(_oc_url, _host, _user, _password)
  oc.connect()

  try:
    if _mode == "upload":
      oc.make_root()
      for arg in args:
        upload_tree(oc, arg, arg)
    elif _mode == "download":
      for arg in args:
        download_zip(oc, ".", arg)
  except Exception as ex:
    fatal("Error", ex)

  sys.exit(0)
