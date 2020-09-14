#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: expandtab shiftwidth=2 softtabstop=2

# version 2.01 2020-09-14

import sys
import os
import re
import getopt

from urllib.request import urlopen

from xml.dom import minidom, Node
import codecs

"""
<person>
<name>ohair</name>
<full-name>Kelly O'Hair</full-name>
<blog>http://blogs.oracle.com/kto/</blog>
<org>Oracle</org>
</person>
"""

DB_URL="http://db.openjdk.java.net/people"

_long = True
_color = True
_retrive = False

ANSI_COLORS = {"black":30, "red":31, "green":32, "yellow":33, "blue":34, "magenta":35, "cyan":36, "white":37}

class Person:
  def __init__(self):
    self.name = None
    self.fullname = None
    self.blog = None
    self.org = ""

  def __str__(self):
    return "%-20s %-20s %s" % (self.name, self.fullname, self.org)

people = []

def cl(color = None):
  if not _color :
    return ""
  if color == None or color == "/":
    return "\033[0m"
  return "\033[%dm" % ANSI_COLORS[color]

def parse_person(p_node):
  p = Person()
  for child in p_node.childNodes:
    if child.nodeType == Node.ELEMENT_NODE:
      if child.tagName == "name":
        p.name = child.firstChild.nodeValue
      elif child.tagName == "full-name":
        p.fullname = child.firstChild.nodeValue
      elif child.tagName == "blog":
        p.blog = child.firstChild.nodeValue
      elif child.tagName == "org":
        p.org = child.firstChild.nodeValue
      else:
        assert False, "Unexpected tag '%s'" % child.tagName
  people.append(p)

def load():
  """ Load people list from remote url or cache 
      TODO: Expire cache
  """
  people_cache = os.path.expanduser("~/.ojdk_people.xml")

  if _retrive or not os.path.exists(people_cache):
    sys.stdout.write(cl("magenta") + "Retriving people data ..." + cl("/")+"\n")
    with urlopen(DB_URL) as fh:
      page = fh.read();

    with open(people_cache, "wb") as fh:
      fh.write(page)
  else:
    with open(people_cache, "r") as fh:
      page = fh.read();

  dom = minidom.parseString(page)
  for child in dom.documentElement.childNodes:
    if child.nodeType == Node.ELEMENT_NODE:
      if child.tagName == "person":
        parse_person(child)

def usage():
  print("Usage: lspeople -l (--long) shell_style_pattern")
  sys.exit(7)


if __name__ == '__main__':
  try:
    opts, args = getopt.getopt(sys.argv[1:], "hclr", ["help", "color", "long", "retrive"])
  except getopt.GetoptError as err:
    print(str(err))
    usage()

  for o, a in opts:
    if o in ("-c", "--color"):
      """Use ansy color on printing"""
      _color = not _color
    elif o in ("-l", "--long"):
      """Print blog and other fileds as well"""
      _long = not _long
    elif o in ("-r", "--retrive"):
      """Update cache"""
      _retrive = not _retrive
    elif o in ("-h", "--help"):
      usage()
    else:
      assert False, "unhandled option"

  load()

  if len(args) == 0:
    for p in people:
      print(p)
  else:
    ask_re = re.compile(args[0],re.IGNORECASE)
    for p in people:
      match = ask_re.search(str(p))
      if match != None:
        a = match.string[:match.start(0)]
        b = match.string[match.start(0):match.end(0)]
        c = match.string[match.end(0):]

        print(a + cl("green") + b + cl("/") + c)
