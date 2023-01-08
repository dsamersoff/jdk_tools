#!/usr/bin/python3

import os 
import sys
import glob

thispath = os.getcwd()
cwd = os.getcwd()

dirlist = []

while True:
  """ Check for image first """
  d = glob.glob(thispath + "/*/build/*/images/jdk")
  if len(d) > 0:
    dirlist += d
    break

  """ Try to find exploded image """
  d = glob.glob(thispath + "/*/build/*/jdk")
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

tpl = []
for d in dirlist:
  tpl.append( (d, os.path.commonpath([cwd,d])) )
tpl = sorted(tpl, key=lambda n: len(n[1]), reverse=True)

if len(sys.argv) <= 1 or sys.argv[1] != "--all":
  """Attempt to guess the best option"""
  un = os.uname()
  cands=list()
  for d in tpl:
    if d[1] != cwd:
      continue
    if d[0].find(un.machine) == -1:
      continue
    cands.append(d)
  tpl = cands

"""Print all survived candidates"""
for d in tpl:
    print(d[0])
