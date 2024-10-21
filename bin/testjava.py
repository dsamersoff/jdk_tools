#!/usr/bin/python3

import os 
import sys
import glob

thispath = os.getcwd()
cwd = os.getcwd()

dirlist = []

while True:
  d = glob.glob(thispath + "/*/build/*/images/jdk")  # Check for image first
  if len(d) > 0:
    dirlist += d
    break

  d = glob.glob(thispath + "/*/build/*/images/j2sdk-image")  # Check for image for jdk8
  if len(d) > 0:
    dirlist += d
    break

  d = glob.glob(thispath + "/*/build/*/jdk")  #  Try to find exploded image 
  if len(d) > 0:
    dirlist += d
    break

  (thispath, tail) = os.path.split(thispath)  # Nothing found, do one step upward 
  if thispath == '/':
    break

  if len(thispath) == 3 and thispath[1] == ":":  #  Handle windows drive letter D:/ 
    break

tpl = []
for d in dirlist:
  tpl.append( (d, os.path.commonpath([cwd,d])) )
tpl = sorted(tpl, key=lambda n: len(n[1]), reverse=True)


print_all = (len(sys.argv) > 1) and (sys.argv[1] in [ "--all", "-a" ])

if not print_all:  # Filter list of candidates in attempt to guess the best option
  un = os.uname()
  cands=list()
  for d in tpl:
    if d[1] != cwd:
      continue
    if d[0].find(un.machine) == -1:
      continue
    cands.append(d)
  if len(cands) > 0:  # No good candidates left, print all found
    tpl = cands

for d in tpl:  # Print all found or survived candidates
    print(d[0])
