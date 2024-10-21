JAVAC=$(JAVA_HOME)/bin/javac
DACAPO=/usr/share/benchmarks/dacapo/dacapochopin.jar

CLASSES=VMStatCallback.class PerfCallback.class

all: $(CLASSES)

clean:
	rm -f $(CLASSES) 

VMStatCallback.class: VMStatCallback.java
	$(JAVAC) -cp $(DACAPO) $<

PerfCallback.class: PerfCallback.java
	$(JAVAC) -cp $(DACAPO) $<

# g++ -I${JAVA_HOME}/include -I${JAVA_HOME}/include/linux perf_events.cpp -o perf_events.so -shared -fPIC
