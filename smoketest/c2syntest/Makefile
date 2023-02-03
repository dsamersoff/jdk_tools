JAVAC=$(TESTJAVA)/bin/javac
JAVA=$(TESTJAVA)/bin/java

CLASSPATH=asm-9.4.jar:asm-util-9.4.jar:commons-cli-1.5.0.jar:.
JAVACOPTS=-sourcepath .

CLASSES=SynTest.class

LOGGING=-Xlog:codecache=debug:codecache.log::filecount=0
C2_OPTIONS=-XX:+SegmentedCodeCache \
	       -XX:+TieredCompilation \
	       -XX:Tier4InvocationThreshold=1000 \
		   -XX:+UnlockDiagnosticVMOptions \
		   -XX:+CompilerDirectivesPrint \
		   -XX:CompilerDirectivesFile=compiler_tips.rc

all: build

build: asm-9.4.jar asm-util-9.4.jar commons-cli-1.5.0.jar syntest/SynTest.class

clean:
	rm -f syntest/SynTest*.class gc.log

asm-9.4.jar:
	wget https://repo1.maven.org/maven2/org/ow2/asm/asm/9.4/asm-9.4.jar

asm-util-9.4.jar:
	wget https://repo1.maven.org/maven2/org/ow2/asm/asm-util/9.4/asm-util-9.4.jar

commons-cli-1.5.0.jar:
	wget https://repo1.maven.org/maven2/commons-cli/commons-cli/1.5.0/commons-cli-1.5.0.jar

run: build
	$(JAVA) -cp $(CLASSPATH) -ms2G -mx2G $(LOGGING) $(C2_OPTIONS) syntest.SynTest -c 20000 -b 100 -i 100 -d compiler_tips.rc

syntest/SynTest.class: syntest/SynTest.java
	$(JAVAC) -cp $(CLASSPATH) $(JAVACOPTS) $<
