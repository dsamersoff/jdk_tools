/**
 * Perf callback for Dacapo Chopin
 */

import org.dacapo.harness.Callback;
import org.dacapo.harness.CommandLineArgs;
import org.dacapo.harness.CommandLineArgs.Methodology;
import org.dacapo.harness.TestHarness;


public class PerfCallback extends Callback {

  private native int startPerfEvent(int type, long config);
  private native long stopPerfEvent(int fd);

  private long startTime = 0L;
  private long batchTime[];

  private int theIterations = 0;      // the number of iterations by -n
  private int theWindow = 0;          // the number of iterations to measure time set by -window
  private int currentIteration = 0;   // Iteration count starts from 1
  private int perfFD = -1;
  private boolean theVerbose = false; // Verbose reporting

  private String perfEventType_str = null;
  private int perfEventType = -1;
  private int perfEvent = -1;

  static {
    String perf_lib = System.getProperty("perf.lib", "perf_callback.so");
    System.load(perf_lib);
  }

  public void printStat(int iterations) {
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
    System.out.println("---------- Execution time ----------");
    System.out.printf("Average %f ms +- %f, total %d ms\n", mean, std, total);
  }

  public int iterIndex() {
    return currentIteration - 1;
  }

  public int get_event_type(String strType) {
      int eventType = -1;
      switch(strType) {
        case "HARDWARE":
          eventType = 0;
          break;
        case "SOFTWARE":
          eventType = 1;
          break;
        case "TRACEPOINT":
          eventType = 2;
          break;
        case "HW_CACHE":
          eventType = 3;
          break;
        case "RAW":
          eventType = 4;
          break;
        case "BREAKPOINT":
          eventType = 5;
          break;
      }
      return eventType;
  }

  /* =================== Dacapo API overloads ========================== */
  public PerfCallback(CommandLineArgs cla) {
    super(cla);
    theWindow = cla.getWindow();
    theIterations = cla.getIterations();
    theVerbose = cla.getVerbose();

    perfEventType_str = System.getProperty("perf.type");
    perfEventType = get_event_type(perfEventType_str);
    if (perfEventType < 0) {
      throw new RuntimeException("Invalid perf event type " + perfEventType_str + " Should be: HARDWARE, SOFTWARE, TRACEPOINT, HW_CACHE, RAW, BREAKPOINT");
    }
    perfEvent = Integer.parseInt(System.getProperty("perf.event"));

    if (theWindow > theIterations) {
      if (theVerbose) {
        System.out.printf("Timed window (%d) is less than total number of iterations (%d), warmup is disabled\n", theWindow, theIterations);
      }
      theWindow = theIterations;
    }

    if (cla.getMethodology() == Methodology.CONVERGE) {
      if (theVerbose) {
        System.out.println("Converge methodology is not supported by this callback, continue in TIMED mode");
      }
    }

    batchTime = new long[cla.getIterations()];

    if (theVerbose) {
      if (theWindow != theIterations) {
        System.out.println("-------------- Warming Up ------------\n");
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
        System.out.println("-------------- Measuring ------------\n");
      }
    }
    perfFD = startPerfEvent(perfEventType, perfEvent);
    startTime = System.currentTimeMillis();
  }

  /* Immediately after the end of the benchmark */
  @Override
  public void stop(long duration) {
    long endTime = System.currentTimeMillis();
    batchTime[iterIndex()] = endTime - startTime;
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
        printStat(currentIteration);
        long res = stopPerfEvent(perfFD);
        System.out.printf("Perf counter (%s:%d): %d\n", perfEventType_str, perfEvent, res);
        System.out.flush();
      }
    }
  }
}
