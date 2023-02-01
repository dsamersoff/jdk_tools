#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: expandtab shiftwidth=2 softtabstop=2

_BANNER="""
  Python Utility Template
  Version 1.000 2020-09-25
  Author: Dmitry Samersoff dms@samersoff.net
"""

_HELP="""
  Usage:
"""

import os
import sys
import getopt
import signal
import traceback

from enum import Enum

import configparser
import re
import requests

import xml.etree.ElementTree as ET

class Retrive(Enum):
  Never = 0
  OnDemand = 1
  Always = 2

class Color(Enum):
  Default = 0
  Red = 31
  Green = 32
  Magenta = 35

_ini_name = ".lsbug.ini"

_api_url = None
_api_email = None
_api_token = None

# https://bugs.openjdk.org/si/jira.issueviews:issue-xml/JDK-8293806/JDK-8293806.xml
_jdk_xml_url = "https://bugs.openjdk.org/si/jira.issueviews:issue-xml/%s/%s.xml?field=title"

_dirname_re = re.compile(r"([A-Z]+-[0-9]+).*")
_comments_file = "comments"

_verbosity = 9

_retrive = Retrive.OnDemand

class Issue:
  def __init__(self, id, summary):
    self.id = id
    self.summary = summary

  def __str__(self):
    return "%s: %s" % (self.id, self.summary)

class Print:
  @staticmethod
  def cl(verbosity, color, text):
    if verbosity <= _verbosity:
      print("\033[%dm" % color.value, text, "\033[0m")

  def error(text):
    Print.cl(0, Color.Red, text)

  def info(text):
    Print.cl(1, Color.Default, text)

  def debug(text):
    Print.cl(2, Color.Magenta, text)

def get_from_file(filename):
  """ Retrive Issue data from file. Single line ID: summary is expected"""
  with open(filename, "r") as fd:
    ln = fd.readline().rstrip()
    idx = ln.index(":")
  return Issue(ln[:idx].strip(), ln[idx+1:].strip())

def get_from_JIRA_rest(id):
  """ Retrive Issue data from JIRA using REST"""
  Print.debug("Retriving %s ..." % id)
  url = "%s/issue/%s?fields=status,summary" % (_api_url, id)
  response = requests.get(url, auth=(_api_email, _api_token),
                          headers={'X-Atlassian-Token':'no-check',
                                   'Content-Type':'application/json; charset=utf-8'})
  if response.status_code != 200:
    Print.error("Error: %d %s" % (response.status_code, response.text))
    return None

  data = response.json()
  # print(response.json())
  # for k,v in data.items():
  #   print( k + "=" + repr(v))
  summary = data["fields"]["summary"]
  Print.debug(" ... got %s: %s" % (id, summary))
  return Issue(id, summary)

def get_from_JIRA_xml(id):
  """ Retrive Issue data from JIRA using XML rss"""
  Print.debug("Retriving %s ..." % id)
  url = _jdk_xml_url % (id, id)
  response = requests.get(url,
                          headers={'X-Atlassian-Token':'no-check',
                                   'Content-Type':'text/xml; charset=utf-8'})
  if response.status_code != 200:
    Print.error("Error: %d %s" % (response.status_code, response.text))
    return None

  root = ET.fromstring(response.text)
  summary = ""
  channel = root.find("channel")
  for elem in channel.find("item"):
    if elem.tag == "title":
      summary = elem.text
  summary = summary[summary.find("]") + 1 : ].strip()
  Print.debug(" ... got %s: %s" % (id, summary))
  return Issue(id, summary)

def process_directory(dirname):
  """ Get directory with name TAG-NNN[-_.]text,
      and proceed with creating required infra:
      comments file and ID_takeaway folder
  """
  issue = None
  m = _dirname_re.match(dirname)
  if m == None:
    return None
  id = m.group(1)
  takeaway_dir = id + "_takeaway"
  if os.path.isdir(dirname):
    takeaway_dir = os.path.join(dirname, takeaway_dir)

  os.makedirs(takeaway_dir, exist_ok = True)
  cmt_file = os.path.join(takeaway_dir, _comments_file)

  if (_retrive == Retrive.Always) or \
    (_retrive == Retrive.OnDemand and not os.path.isfile(cmt_file)):
    if id.startswith("LIB-"):
      issue = get_from_JIRA_rest(id)
    elif id.startswith("JDK-"):
      issue = get_from_JIRA_xml(id)
    else:
      issue = Issue(id, "Unknown source")

    with open(cmt_file, "w") as fd:
      fd.write(str(issue) + "\n")

  issue = get_from_file(cmt_file)
  return issue

def load_credentials():
  """ Load defaults from the configuration file. """
  global _ini_name, _api_url, _api_email, _api_token

  inifile = os.path.expanduser(os.path.join("~", _ini_name))
  cfg = configparser.ConfigParser()
  cfg.read(inifile)

  _api_url = cfg.get("DEFAULT", "url")
  _api_email = cfg.get("DEFAULT", "user")
  _api_token = cfg.get("DEFAULT", "token")

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
                                "hVr",
                               ["help", "version"])

    for o, a in opts:
      if o in ("-h", "--help", "-V", "--version"):
        print(_BANNER)
        if o in ("-h", "--help"):
          usage()
        sys.exit(7)
      elif o in ("-r", "--retrive"):
        """Always access JIRA"""
        _retrive = Retrive.Always
      else:
        assert False, "Unhandled option '%s'" % o

  # except getopt.GetoptError as ex:
  except Exception as ex:
    usage("Bad command line: %s (%s) " % (str(ex), repr(sys.argv[1:])))

  try:
    load_credentials()
  except Exception as ex:
    tb_lines = traceback.format_exc().splitlines()
    Print.debug(ex)
    Print.debug("\n".join(tb_lines[1:4]))

  if _api_url == None or _api_token == None or _api_email == None:
    Print.error("JIRA REST api credentials doesn't set. Retrive is disabled")
    _retrive = Retrive.Never

  the_dir = "."
  if len(args) > 0:
    """Process single directory if it match the pattern"""
    the_dir = args[0]
    if the_dir == ".":
      the_dir = os.path.basename(os.getcwd())
      issue = process_directory(the_dir)
    elif os.path.isdir(the_dir):
      issue = process_directory(the_dir)

    if issue != None:
      Print.info(str(issue))
      exit(0)

  for dn in os.listdir(the_dir):
    if os.path.isdir(dn):
      try:
        issue = process_directory(dn)
        if issue != None:
          Print.info(str(issue))
      except Exception as ex:
        tb_lines = traceback.format_exc().splitlines()
        Print.error(ex)
        Print.debug("\n".join(tb_lines[1:4]))
