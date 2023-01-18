JAVAC=$(TESTJAVA)/bin/javac
JAVA=$(TESTJAVA)/bin/java

CLASSPATH=asm-9.4.jar:asm-util-9.4.jar:.
JAVACOPTS=-sourcepath .

CLASSES=SynTest.class

# LOGGING=-Xlog:gc,gc+heap=debug,gc+age=trace:gc.log::filecount=0
C2_OPTIONS=-XX:+SegmentedCodeCache \
	       -XX:+TieredCompilation \
	       -XX:Tier4InvocationThreshold=1000 \
           -XX:CompileCommandFile=compiler_tips.rc

all: asm-9.4.jar asm-util-9.4.jar syntest/SynTest.class

clean:
	rm -f syntest/SynTest*.class gc.log

asm-9.4.jar:
	wget https://repo1.maven.org/maven2/org/ow2/asm/asm/9.4/asm-9.4.jar

asm-util-9.4.jar:
	wget https://repo1.maven.org/maven2/org/ow2/asm/asm-util/9.4/asm-util-9.4.jar


run:
	$(JAVA) -cp $(CLASSPATH) -ms2G -mx2G $(LOGGING) $(C2_OPTIONS) syntest.SynTest

syntest/SynTest.class: syntest/SynTest.java
	$(JAVAC) -cp $(CLASSPATH) $(JAVACOPTS) $<
