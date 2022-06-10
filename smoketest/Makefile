JAVAC=$(TESTJAVA)/bin/javac
JAVA=$(TESTJAVA)/bin/java

CLASSES=MultiAlloc.class MultiAllocWorker.class

LOGGING=-Xlog:gc,gc+heap=debug:gc.log::filecount=0

VM_OPTIONS=-mx1G -XX:+UseTLAB -XX:+UseParallelGC 

all: $(CLASSES)

clean:
	rm -f 'MultiAlloc$$1.class' 'MultiAlloc$$2.class' $(CLASSES) gc.log

run: run-sync run-concurrent

run-sync: $(CLASSES)
	$(JAVA) $(VM_OPTIONS) $(LOGGING) MultiAlloc sync

run-concurrent: $(CLASSES)
	$(JAVA) $(VM_OPTIONS) $(LOGGING) MultiAlloc concurrent 

MultiAlloc.class: MultiAlloc.java
	$(JAVAC) $<

MultiAllocWorker.class: MultiAllocWorker.java
	$(JAVAC) $<
