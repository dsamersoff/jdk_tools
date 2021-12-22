#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: expandtab shiftwidth=2 softtabstop=2

_BANNER="""
  RSS Benchmark Launcher 
  Version 1.000 2020-09-25
  Author: Dmitry Samersoff dms@samersoff.net
"""   

_HELP="""
  Usage: rss_launcher ${TESTJAVA}
"""

import os
import sys
import getopt
import signal
import traceback
import threading
import subprocess
import time

from enum import Enum

# _testjava="/jdk17u/build/linux-x86_64-server-release/images/jdk"
# _testjava + "/bin/java",

_options_common = [
 "-Xlog:gc:gc.log",
 "-Xms2G",
 "-Xmx2G",
 "-XX:+UseParallelGC"
 ]

_benchmark = "-jar dacapo-9.12-MR1-bach.jar -s large -n 16 lusearch".split()

def signal_handler(signal, frame): #pylint: disable=unused-argument
    sys.stdout.write("\nInterrupted. Exiting ...\n")
    sys.exit(-1)

def usage(msg=None):
    global _HELP
    if msg is not None:
        print ("Error: %s" % msg)
    print(_HELP)
    sys.exit(7)


class RunJava(threading.Thread):
    def __init__(self, java_cmd):
        self.stdout = None
        self.stderr = None
        self.p = None
        self.java_cmd  = java_cmd
        threading.Thread.__init__(self)

    def run(self):
        self.p = subprocess.Popen(self.java_cmd,
                             shell=False,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)

        self.stdout, self.stderr = self.p.communicate()

    def wait_for_pid(self):    
        while(self.p == None):
            pass
        return self.p.pid
  
    def collect_status(self, freq):
        results = []  
        try:
            while(True):
                with open("/proc/%d/status" % self.p.pid, "r") as fd:
                    proc_status = fd.read()
                (ts, name, rss) = (time.clock_gettime(time.CLOCK_BOOTTIME), None, None)
                for ln in proc_status.splitlines():
                    if ln.startswith("Name:"):
                        name = ln[6:]
                    if ln.startswith("RssAnon:"):
                        rss = ln[9:-3]
                results.append((ts, name, rss))    
                time.sleep(freq)
        except FileNotFoundError as ex:
            pass
        return results

def do_run(java_cmd):
    myclass = MyClass(dacapo)
    myclass.start()

    while(myclass.p == None):
        pass

    res = myclass.collect_status(10)
    myclass.join()
    return res


if __name__ == '__main__':
    signal.signal(signal.SIGINT, signal_handler)

    try:
        opts, args = getopt.getopt(sys.argv[1:],
                                "hV",
                               ["help", "version"])

        for o, a in opts:
            if o in ("-h", "--help", "-V", "--version"):
                print(_BANNER)
            if o in ("-h", "--help"):
                usage()
                sys.exit(7)  
            else:
                assert False, "Unhandled option '%s'" % o

    # except getopt.GetoptError as ex:
    except Exception as ex:
        usage("Bad command line: %s (%s) " % (str(ex), repr(sys.argv[1:])))

    if len(args) == 0:
        usage()

    try:
        java = [args[0] + "/bin/java"] + _options_common + _benchmark
        assert os.path.isfile(java[0]), "Bad TESTJAVA '%s'" % java[0]

        myclass = RunJava(java)
        myclass.start()
        myclass.wait_for_pid()
        res = myclass.collect_status(10)
        myclass.join()

        print ("Java:     " + java[0]) 
        print ("Cmd line: " + " ".join(java[1:])) 
        
        assert len(res) > 0, "No results taken"

        print ("Proc Binary:  " +  res[0][1])
        print()
        print("TS, RSS")
        for (ts, name, rss) in res:
            print("%d, %d" % (int(ts), int(rss)))
    except Exception as ex:
        print("Unexpected Exception occured: \n\n" + repr(ex))
        print("\nRun cmd: " + repr(java))
        traceback.print_exc(file=sys.stdout)