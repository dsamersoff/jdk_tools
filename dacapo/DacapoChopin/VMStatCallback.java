/**
 * Callback for Dacapo Chopin
 *
 *    ${TESTJAVA}/bin/java -cp ${CALLBACK_DIR}:${DACAPO} -Dvmstat.enable_jfr=yes Harness -v -n 5 -c VMStatCallback <benchmarks>
 *
 * This callback performs
 *    -n iterations in total
 *    --window timed iteration (default is 3)
 *    CONVERGE methodology is not supported
 * At the end of each timed run it prints enhanced VM statistics
 * of memory usage and compilation.
 *
 * To enable JFR recording during benchmark specify
 *  -Dvmstat.enable_jfr=yes
 * default output is vmstat_{benchmark}_{iteration}.jfr
 * but you can set different recording prefix, e.g.:
 *    -Dvmstat.jfr_recording_prefix="/tmp/some_name_"
 *
 * To enable CSV output
 *   -Dvmstat.csv=yes
 */

import java.lang.Math;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import java.lang.management.ManagementFactory;
import java.lang.management.MemoryPoolMXBean;
import java.lang.management.MemoryUsage;
import java.lang.management.MemoryType;

import javax.management.ObjectName;
import javax.management.MBeanServer;
import com.sun.management.OperatingSystemMXBean;

import org.dacapo.harness.Callback;
import org.dacapo.harness.CommandLineArgs;
import org.dacapo.harness.CommandLineArgs.Methodology;
import org.dacapo.harness.TestHarness;

public class VMStatCallback extends Callback {

  private long startTime = 0L;
  private long batchTime[];

  private int theIterations = 0;      // the number of iterations by -n
  private int theWindow = 0;          // the number of iterations to measure time set by -window
  private int currentIteration = 0;   // Iteration count starts from 1
  private boolean theVerbose = false; // Verbose reproting
  private boolean outCSV = false;   // Print CSV as well as human readable message

  private boolean enableJFR = false;   // Start end stop JFR for each timed run
  private String jfrRecordingPrefix = null; // Filename to store JFR recording
  private String jfrSettings = null; // JFR settings filename

  private List<MemoryPoolMXBean> memoryBeans;
  private OperatingSystemMXBean osBean;

  private long processCPUTime = 0L;

  private String do_run_dcmd(String operationName, String operationArgs[]) {
    String result = null;
    try {
      ObjectName objectName = new ObjectName("com.sun.management:type=DiagnosticCommand");
      MBeanServer mbeanServer = ManagementFactory.getPlatformMBeanServer();
      Object[] params = new Object[] { operationArgs };
      String[] signature = new String[]{String[].class.getName()};

      result = (String) mbeanServer.invoke(objectName, operationName, params, signature);
    } catch(Throwable ex) {
      ex.printStackTrace();
      System.exit(1);
    }
    return result;
  }

  public void printStat(String benchmark, int iterations) {
    long total = 0;
    int windowStart = theIterations - theWindow;
    for (int i = windowStart; i < iterations; ++i) {
      total += batchTime[i];
    }

    double mean = total / (iterations - windowStart);

    double variance = 0;
    for (int i = windowStart; i < iterations; i++) {
      variance += Math.pow(batchTime[i] - mean, 2);
    }
    variance = variance / (iterations - windowStart);

    double std = Math.sqrt(variance);
    System.out.printf("===== %s Execution Time: Average %.2f ms +- %.2f total(%d) %d ms =====\n",
                        benchmark, mean, std, (iterations - windowStart), total);
    if (outCSV) {
      System.out.printf("#CSV Duration#,%s,%d,%.2f,%.2f\n", benchmark, iterations, mean, std);
    }
  }

  public void printMemoryUsage(String benchmark) {
    System.out.println("===== Memory Usage =====");
    if (memoryBeans == null) {
      System.out.println("MemoryPoolMxBeans is not available.");
      return;
    }

    for (MemoryPoolMXBean m: memoryBeans) {
      if (m.getType() == MemoryType.NON_HEAP) {
        MemoryUsage u = m.getUsage();
        double used = u.getUsed();
        System.out.printf("%s %dKb\n", m.getName(), Math.round(used/1024));
      }
    }

    System.out.println("");
    for (MemoryPoolMXBean m: memoryBeans) {
      if (m.getType() != MemoryType.NON_HEAP) {
        MemoryUsage u = m.getUsage();
        double used = u.getUsed();
        System.out.printf("%s %dKb\n", m.getName(), Math.round(used/1024));
      }
    }

    System.out.println("");

    if (outCSV) {
      StringBuilder str = new StringBuilder("#CSV Memory,");
      str.append(benchmark);
      for (MemoryPoolMXBean m: memoryBeans) {
        MemoryUsage u = m.getUsage();
        str.append(String.format(",%s,%d", m.getName(), u.getUsed()));
      }
      System.out.println(str.toString());
    }
  }

  public void printCPUUsage(String benchmark) {
    if (osBean == null) {
      System.out.println("===== CPU Usage: OperatingSystemMxBeans is not available. =====");
      return;
    }

    long elapsedProcessCpuTime = osBean.getProcessCpuTime() - processCPUTime;

    System.out.printf("===== CPU Usage: Process cpu load %.2f System cpu load %.2f, Elapsed cpu time %.2f ms =====\n",
             osBean.getProcessCpuLoad() * 100, osBean.getSystemCpuLoad()  * 100, (double) elapsedProcessCpuTime/1000000);
    if (outCSV) {
      System.out.printf("#CSV CPU#,%s,%.2f,%.2f,%.2f\n", benchmark,
             osBean.getProcessCpuLoad() * 100, osBean.getSystemCpuLoad()  * 100, (double) elapsedProcessCpuTime/1000000);
    }
  }

  public void printCompiledMethods(String benchmark) {
    System.out.println("===== Compiled Methods Summary =====");

    long counts[] = new long[5];
    long state_counts[] = new long[5];
    long in_use_counts[] = new long[5];

    String result = do_run_dcmd("compilerCodelist", new String[]{});
    List<String> filtered = result.lines().collect(Collectors.toList());
    long all_count = filtered.size();

    for (String line : filtered) {
      String fields[] = line.split(" ");
      int state = Integer.valueOf(fields[2]); // account nmethod state see: compiledMethod.hpp
      int comp_level = Integer.valueOf(fields[1]);

      counts[comp_level] += 1;
      if (state != -1) { // skip initializing
        state_counts[state] += 1;
        if (state == 0 /*in_use*/) {
          in_use_counts[comp_level] += 1;
        }
      }
    }

    System.out.printf("Compiled at levels 1: %d 2: %d 3: %d 4: %d\n",
            counts[1], counts[2], counts[3], counts[4]);
    if (theVerbose) {
      System.out.printf("In use at levels 1: %d 2: %d 3: %d 4: %d\n",
            in_use_counts[1], in_use_counts[2], in_use_counts[3], in_use_counts[4]);
      System.out.printf("CodeCache states in_use: %d not_used: %d not_reentrant: %d zombie: %d unloaded: %d\n",
            state_counts[0], state_counts[1], state_counts[2], state_counts[3], state_counts[4]);
    }
    System.out.printf("Total methods in Codecache (all states): %d\n\n", all_count);

    if (outCSV) {
      System.out.printf("#CSV Compiled#,%s,%d,%d,%d,%d,%d\n", benchmark,
                              counts[1], counts[2], counts[3], counts[4], all_count);
    }
  }

  public int iterIndex() {
    return currentIteration - 1;
  }

  public static boolean getBooleanProperty(String name) {
    String prop_str = System.getProperty(name, "No").toLowerCase();
    return (prop_str.equals("yes") || prop_str.equals("true"));
  }

  /* =================== Dacapo API overloads ========================== */
  public VMStatCallback(CommandLineArgs cla) {
    super(cla);
    theWindow = cla.getWindow();
    theIterations = cla.getIterations();
    theVerbose = cla.getVerbose();

    outCSV = getBooleanProperty("vmstat.csv");

    enableJFR = getBooleanProperty("vmstat.enable_jfr");
    jfrRecordingPrefix = System.getProperty("vmstat.jfr_recording_prefix", "vmstat_");
    jfrSettings = System.getProperty("vmstat.jfr_settings");

    if (theWindow > theIterations) {
      if (theVerbose) {
        System.out.printf("Timed window (%d) is less than total number of iterations (%d), warmap is disabled\n", theWindow, theIterations);
      }
      theWindow = theIterations;
    }

    if (cla.getMethodology() == Methodology.CONVERGE) {
      if (theVerbose) {
        System.out.println("Converge mthodology is not supported by this callback, continue in TIMED mode");
      }
    }

    batchTime = new long[cla.getIterations()];

    try {
      memoryBeans = ManagementFactory.getMemoryPoolMXBeans();
    } catch(Throwable ex) {
      memoryBeans = null;
      if (theVerbose) {
        System.err.println("Can't access MemoryPoolMXBeans. Memory usage statistics will not be provided.");
      }
    }

    try {
      osBean = ManagementFactory.getPlatformMXBean(OperatingSystemMXBean.class);
    } catch(Throwable ex) {
      osBean = null;
      if (theVerbose) {
        System.err.println("Can't access OperatingSystemMXBean. CPU usage statistics will not be provided.");
      }
    }

    if (theVerbose) {
      System.out.printf("Running with %d iterations and %d window\n", theIterations, theWindow);
      if (enableJFR) {
        System.out.printf("JFR recording is enabled. Dump will be stored as %s_{benchmark}_{iteration}.jfr\n", jfrRecordingPrefix);
      }
      if (theWindow != theIterations) {
        System.out.println("===== Warming Up =====\n");
      }
    }
  }

  @Override
  public boolean isWarmup() {
    return iterIndex() < (theIterations - theWindow);
  }

  @Override
  public boolean runAgain() {
    return currentIteration < theIterations;
  }

  @Override
  public void start(String benchmark) {
    currentIteration += 1;
    if (theVerbose) {
      if (iterIndex() == (theIterations - theWindow)) {
        System.out.println("===== Measuring =====\n");
      }
    }
    if (enableJFR) {
      if (iterIndex() > (theIterations - theWindow)) {
        String filename = String.format("%s%s_%d.jfr", jfrRecordingPrefix, benchmark, currentIteration);
        if (theVerbose) {
          System.out.println("Staring JFR, dump will be stored in " + filename);
        }

        ArrayList<String> jfrOptions = new ArrayList<String>();
	jfrOptions.add("filename=" + filename);
	if (jfrSettings != null) {
	   jfrOptions.add("settings=" + jfrSettings);
	}

	String[] opts = new String[jfrOptions.size()];
        do_run_dcmd("jfrStart", jfrOptions.toArray(opts));
	// JFR initialization creates significant overhead,
	// wait for jfr to complete initialization
        do_run_dcmd("jfrCheck", new String[]{});
      }
    }
    processCPUTime = (osBean == null) ? 0 : osBean.getProcessCpuTime();
    startTime = System.currentTimeMillis();
  }

  /* Immediately after the end of the benchmark */
  @Override
  public void stop(long duration) {
    long endTime = System.currentTimeMillis();
    batchTime[iterIndex()] = endTime - startTime;

    if (enableJFR) {
        do_run_dcmd("jfrStop", new String[]{});
     }
   }

  @Override
  public void complete(String benchmark, boolean valid) {
    String wmode = isWarmup() ? "WARMUP" : "TIMED";
    if (!valid) {
      System.err.printf("===== DaCapo %s %s %s iteration %d FAILED === \n", TestHarness.getBuildVersion(), benchmark, wmode, currentIteration);
      System.err.flush();
    }
    else {
      System.out.printf("===== DaCapo %s %s %s iteration %d PASSED in %d ms === \n", TestHarness.getBuildVersion(),
                                 benchmark, wmode, currentIteration, batchTime[iterIndex()]);
      if (iterIndex() >= (theIterations - theWindow)) {
        printStat(benchmark, currentIteration);
        printCPUUsage(benchmark);
        printMemoryUsage(benchmark);
        printCompiledMethods(benchmark);
        System.out.flush();
      }
    }
  }
}
