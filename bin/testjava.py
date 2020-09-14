#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: expandtab shiftwidth=2 softtabstop=2

# version 2.01 2020-09-14

import os
import glob

thispath = os.getcwd()
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

for d in dirlist:
  print(d)
