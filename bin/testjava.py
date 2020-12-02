#!/usr/bin/python3

import os 
import sys
import glob

thispath = os.getcwd()
cwd = os.getcwd()

dirlist = []

while True:
  """ Check for image first """
  d = glob.glob(thispath + "/*/build/linux-*/images/jdk")
  if len(d) > 0:
    dirlist += d
    break

  """ Try to find exploded image """
  d = glob.glob(thispath + "/*/build/linux-*/jdk")
  if len(d) > 0:
    dirlist += d
    break

  """ Nothing found, do one step upward """
  (thispath, tail) = os.path.split(thispath)
  if thispath == '/':
    break

  """ Handle windows drive letter D:/ """
  if len(thispath) == 3 and thispath[1] == ":":
    break


if len(dirlist) == 0:
  if len(sys.argv) > 1 and sys.argv[1] == "-all":
    print ("Nothing found")
  sys.exit(-1)

tpl = []
for d in dirlist:
  tpl.append( (d, os.path.commonpath([cwd,d])) )
tpl = sorted(tpl, key=lambda n: len(n[1]), reverse=True)

if len(sys.argv) > 1 and sys.argv[1] == "-all":
  for d in tpl:
    print(d[0])
else:
  print(tpl[0][0])
