JAVAC=$(TESTJAVA)/bin/javac
JAVA=$(TESTJAVA)/bin/java

CLASSPATH=jars/asm-9.4.jar:jars/asm-util-9.4.jar:jars/asm-commons-9.4.jar:jars/commons-cli-1.5.0.jar:.
JAVACOPTS=-sourcepath .

CLASSES=SynTest.class

LOGGING=-Xlog:codecache*=debug:codecache.log::filecount=0

C2_OPTIONS=-XX:+SegmentedCodeCache \
	       -XX:+TieredCompilation \
		   -XX:-UseCodeCacheFlushing \
		   -XX:ReservedCodeCacheSize=128M \
		   -XX:InitialCodeCacheSize=128M \
		   -XX:+UnlockDiagnosticVMOptions \
		   -XX:+CompilerDirectivesPrint \
		   -XX:CompilerDirectivesFile=compiler_tips.rc

ifndef TESTJAVA
$(error TESTJAVA must be set)
endif

all: build

build: jars/asm-9.4.jar jars/asm-util-9.4.jar jars/asm-commons-9.4.jar jars/commons-cli-1.5.0.jar syntest/SynTest.class

generate: syntest/SynTestTemplate.class
	$(JAVA) -cp $(CLASSPATH) org.objectweb.asm.util.ASMifier syntest/SynTestTemplate.class

clean:
	rm -f syntest/SynTest*.class gc.log codecache.log

jars/asm-9.4.jar:
	mkdir -p jars && wget https://repo1.maven.org/maven2/org/ow2/asm/asm/9.4/asm-9.4.jar -O $@

jars/asm-util-9.4.jar:
	mkdir -p jars && wget https://repo1.maven.org/maven2/org/ow2/asm/asm-util/9.4/asm-util-9.4.jar -O $@

jars/asm-commons-9.4.jar:
	mkdir -p jars && wget https://repo1.maven.org/maven2/org/ow2/asm/asm-commons/9.4/asm-commons-9.4.jar -O $@

jars/commons-cli-1.5.0.jar:
	mkdir -p jars && wget https://repo1.maven.org/maven2/commons-cli/commons-cli/1.5.0/commons-cli-1.5.0.jar -O $@

run: build
	$(JAVA) -cp $(CLASSPATH) -ms2G -mx2G $(LOGGING) $(C2_OPTIONS) syntest.SynTest -c 20000 -b 100 -i 100 -d compiler_tips.rc

syntest/SynTest.class: syntest/SynTest.java
	$(JAVAC) -cp $(CLASSPATH) $(JAVACOPTS) $<

syntest/SynTestTemplate.class: syntest/SynTestTemplate.java
	$(JAVAC) -cp $(CLASSPATH) $(JAVACOPTS) $<
