#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: expandtab shiftwidth=2 softtabstop=2

# version 2.01 2020-09-14

import os
import sys
import getopt
import shutil
from configparser import SafeConfigParser, NoSectionError

G_gatedpush = False
G_defpath = ['push']
G_ojdkname = None

def fixDefaultPath(wspath):
    """Mimic most often case of hg fdefpath usage, walk across repositories
      and replace(or add) to hgrc file

      default = http://closedjdk.us.oracle.com/jdk7u/jdk7u-cpu/jdk/test/closed
      default-push = ssh://dsamersoff@closedjdk.us.oracle.com/jdk7u/jdk7u-cpu-gate/jdk/test/closed

      as it doesn't use mercurital api to do it, it works much faster then defpath extension
    """
    config = SafeConfigParser()
    ini = os.path.join(wspath,'.hg/hgrc')

    config.read(ini);

    defaultPull = None
    defaultPush = None

    if config.has_section('paths'):
      if config.has_option('paths','default'):
        defaultPull = config.get('paths','default')
      if config.has_option('paths','default-push'):
        defaultPush = config.get('paths','default-push')

    if defaultPull == None:
      print("Can't build push path default path is invalid")
      return

    ojn = "" if G_ojdkname == None else G_ojdkname + '@'

    if defaultPull.startswith('http://'):
      p = defaultPull[7:]
    elif defaultPull.startswith('https://'):
      p = defaultPull[8:]
    elif defaultPull.startswith('ssh://'):
      p = defaultPull[6:]
    else:
      print("Can't build push path default path is invalid or local (%s)" % defaultPull)
      return

    ps = p.split('/')
    if G_gatedpush:
      ps[2] = ps[2]+'-gate'

    newDefaultPush = 'ssh://' + ojn + '/'.join(ps) if 'push' in G_defpath else defaultPush
    newDefaultPull = 'ssh://' + ojn + p            if 'pull' in G_defpath else defaultPull

    if defaultPush == newDefaultPush and defaultPull == newDefaultPull:
      print("Defpath: %s (not changing)\n %s\n %s" % (ini, defaultPull, defaultPush))
    else:
      print("Defpath: %s\n %s\n %s" % (ini, newDefaultPull, newDefaultPush))
      shutil.move(ini,ini+'.old')
      config.set('paths','default',newDefaultPull)
      config.set('paths','default-push',newDefaultPush)
      fp = open(ini,'w')
      config.write(fp)
      fp.close()

def fatal(msg):
  print(msg)
  sys.exit(255)

def usage():
  print("Usage: fixpath -o ojdkname")
  sys.exit(7)

if __name__ == '__main__':

  try:
    opts, args = getopt.getopt(sys.argv[1:], "ho:", ["help","ojdkname="])
  except getopt.GetoptError as err:
    fatal(str(err))

  for o, a in opts:
    if o in ("-h", "--help"):
      usage()
    elif o in ("-o", "--ojdkname"):
      G_ojdkname=a
    else:
      fatal("unhandled option '%s'" % o)

  for directory, dirnames, filenames in os.walk("."):
    if '.hg' in dirnames:
      fixDefaultPath(directory)
