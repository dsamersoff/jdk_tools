JAVAC=$(JAVA_HOME)/bin/javac

DACAPO?=/opt/dacapo/dacapo-chopin.jar
DSO=perf_callback.so

CLASSES=VMStatCallback.class PerfCallback.class

all: $(CLASSES) $(DSO)

clean:
	rm -f $(CLASSES) $(DSO)

VMStatCallback.class: VMStatCallback.java
	$(JAVAC) -cp $(DACAPO) $<

PerfCallback.class: PerfCallback.java
	$(JAVAC) -cp $(DACAPO) $<

perf_callback.so: perf_callback.c PerfCallback.h
	$(CC) -shared -fPIC -I$(JAVA_HOME)/include -I$(JAVA_HOME)/include/linux -o $@ $<
