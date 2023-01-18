/**
 *
 *
 */
package syntest;

import org.objectweb.asm.*;
import org.objectweb.asm.util.*;

import java.lang.Math;
import java.io.PrintWriter;
import java.util.List;
import java.util.stream.Collectors;

import java.lang.management.ManagementFactory;
import java.lang.management.MemoryPoolMXBean;
import java.lang.management.MemoryUsage;
import java.lang.management.MemoryType;

import javax.management.ObjectName;
import javax.management.MBeanServer;


public class SynTest implements Opcodes {
  private final static String packageName = "syntest";
  private final static String classNamePrefix = "SynImpl";
  private final static int numClasses = 20_000;
  private final static SynTestRunner dtrs[] = new SynTestRunner[numClasses];
  private final static int warmUps = 10_000;
  private final static int numBatches = 1_000;
  private final static long timesPerBatch = 1_000;
  private final static long batchTime[] = new long[numBatches];
  private final static boolean traceMethodGeneration = false;

  private static long runResult = 0;

  private static List<MemoryPoolMXBean> memoryBeans;

  static class SynClassLoader extends ClassLoader {
    public Class<?> defineClass(String name, byte[] b) {
        return defineClass(name, b, 0, b.length);
    }
  }

  public static byte[] doGenerateClass(String className) {
    String interfaces[] = { packageName + "/SynTestRunner" };

    ClassWriter cw = new ClassWriter(ClassWriter.COMPUTE_FRAMES | ClassWriter.COMPUTE_MAXS);
    cw.visit(V17, ACC_PUBLIC, packageName + "/" + className, null, "java/lang/Object", interfaces);

    MethodVisitor ctr = cw.visitMethod(ACC_PUBLIC, "<init>", "()V", null, null);
    ctr.visitCode();
    ctr.visitVarInsn(ALOAD, 0);
    ctr.visitMethodInsn(INVOKESPECIAL, "java/lang/Object", "<init>", "()V", false);
    ctr.visitInsn(RETURN);
    ctr.visitMaxs(1, 1);

    // Simple ADD for smoke test
    MethodVisitor m_add = cw.visitMethod(ACC_PUBLIC, "add", "(II)I", null, null);
    m_add.visitCode();
    m_add.visitVarInsn(ILOAD, 1);
    m_add.visitVarInsn(ILOAD, 2);
    m_add.visitInsn(IADD);
    m_add.visitInsn(IRETURN);
    m_add.visitMaxs(2, 3);

    MethodVisitor m_do;
    if (traceMethodGeneration) {
      MethodVisitor mv = cw.visitMethod(ACC_PUBLIC, "doit", "(III)I", null, null);
      m_do = new TraceMethodVisitor(mv, new Textifier());
    }
    else {
      m_do = cw.visitMethod(ACC_PUBLIC, "doit", "(III)I", null, null);
    }

    Label lab_one = new Label();
    Label lab_two = new Label();

    m_do.visitCode();

   // int result = a + b;
    m_do.visitVarInsn(ILOAD, 1);
    m_do.visitVarInsn(ILOAD, 2);
    m_do.visitInsn(IADD);
    m_do.visitVarInsn(ISTORE, 4);

    // if (a > b)  {
    m_do.visitVarInsn(ILOAD, 1);
    m_do.visitVarInsn(ILOAD, 2);
    m_do.visitJumpInsn(IF_ICMPLE, lab_one);

    //  result = result * result;
    m_do.visitVarInsn(ILOAD, 4);
    m_do.visitVarInsn(ILOAD, 4);
    m_do.visitInsn(IMUL);
    m_do.visitVarInsn(ISTORE, 4);

    // if (a > c) {
    m_do.visitVarInsn(ILOAD, 1);
    m_do.visitVarInsn(ILOAD, 3);
    m_do.visitJumpInsn(IF_ICMPLE, lab_one);

    //  result = result * result;
    m_do.visitVarInsn(ILOAD, 4);
    m_do.visitVarInsn(ILOAD, 4);
    m_do.visitInsn(IMUL);
    m_do.visitVarInsn(ISTORE, 4);

    // }}
    m_do.visitLabel(lab_one);

    // if (a < b)  {
    m_do.visitVarInsn(ILOAD, 1);
    m_do.visitVarInsn(ILOAD, 2);
    m_do.visitJumpInsn(IF_ICMPGE, lab_two);

    //  result = result + result;
    m_do.visitVarInsn(ILOAD, 4);
    m_do.visitVarInsn(ILOAD, 4);
    m_do.visitInsn(IADD);
    m_do.visitVarInsn(ISTORE, 4);

    //  if (a < c) {
    m_do.visitVarInsn(ILOAD, 1);
    m_do.visitVarInsn(ILOAD, 3);
    m_do.visitJumpInsn(IF_ICMPGE, lab_two);

    //  result = result + result;
    m_do.visitVarInsn(ILOAD, 4);
    m_do.visitVarInsn(ILOAD, 4);
    m_do.visitInsn(IADD);
    m_do.visitVarInsn(ISTORE, 4);

    // }}
    m_do.visitLabel(lab_two);

    // return result;
    m_do.visitVarInsn(ILOAD, 4);
    m_do.visitInsn(IRETURN);
    m_do.visitMaxs(2, 4);

    if (traceMethodGeneration) {
      System.out.println(((TraceMethodVisitor)m_do).p.getText());
      System.exit(1);
    }

    cw.visitEnd();
    return cw.toByteArray();
  }

  public static void printMemoryUsage() {
    System.err.println("---------- Memory Usage ----------");
    for (MemoryPoolMXBean m: memoryBeans) {
      MemoryUsage u = m.getUsage();
      double used = u.getUsed();
      // Skip Java Heap
      if (m.getType() == MemoryType.NON_HEAP) {
         System.err.println(m.getName() + " " + used);
      }
    }
    System.err.println("---------------------------------");
  }

  public static void printCompiledMethods() {
    try {
      ObjectName objectName = new ObjectName("com.sun.management:type=DiagnosticCommand");
      MBeanServer mbeanServer = ManagementFactory.getPlatformMBeanServer();

      String operationName = "compilerCodelist"; //vmFlags
      Object[] params = new Object[1];
      String[] signature = new String[]{String[].class.getName()};

      String result = (String) mbeanServer.invoke(objectName, operationName, params, signature);

      List<String> filtered = result.lines().filter(
        (line) -> line.contains(packageName + ".SynImpl_")
      ).collect(Collectors.toList());

      long all_count = filtered.size();

      long c2_count = filtered.stream().filter(
        (line) -> {
          String fields[] = line.split(" ");
          return Integer.valueOf(fields[1]) == 4;
        }
      ).count();

      /*
      result.lines().filter(
        (line) -> line.contains(packageName + ".SynImpl_")
      ).forEach(System.out::println);
      */

      System.out.printf("Found compiled syntetic methods, all: %d c2: %d\n", all_count, c2_count);
    } catch(Throwable ex) {
       ex.printStackTrace();
    }
  }

  public static void printStat(int numItems) {
    do_print_stat(numItems, false);
  }

  public static void printFinalStat(int numItems) {
    do_print_stat(numItems, true);
  }

  public static long do_measure(long times) {
    long start = System.currentTimeMillis();
    for (long j = 0; j < times; ++j) {
      for (int i = 0; i < numClasses; ++i) {
        runResult += dtrs[i].doit(i, (int) j, 2);
      }
    }
    long end = System.currentTimeMillis();
    return end - start;
  }

  public static void do_print_stat(int numItems, boolean last_call) {
    long total = 0;
    for (int i = 0; i < numItems; ++i) {
      total += batchTime[i];
    }

    double mean = total / numItems;

    double variance = 0;
    for (int i = 0; i < numItems; i++) {
      variance += Math.pow(batchTime[i] - mean, 2);
    }
    variance = variance / numItems;

    double std = Math.sqrt(variance);

    System.out.printf("Executed %d classes, %d times in %d batches\n", numClasses, (long)(numItems * timesPerBatch), numItems);
    if (last_call) {
      System.out.print("Final ");
    }
    System.out.printf("Results %d (%f +- %f)\n", total, mean, std);
}

  public static void main(String args[]) {
    System.out.println("Syntetic test started");

    try {
      memoryBeans = ManagementFactory.getMemoryPoolMXBeans();
      printMemoryUsage();
      printCompiledMethods();

      System.out.println("Generating");
      for (int i = 0; i < numClasses; ++i) {
        String className = String.format("%s_%04d", classNamePrefix, i);
        byte[] class_ba = doGenerateClass(className);
        SynClassLoader loader = new SynClassLoader();
        Class<?> clazz = loader.defineClass(packageName + "." + className, class_ba);
        dtrs[i] = (SynTestRunner) clazz.getDeclaredConstructor().newInstance();
      }

      System.out.println("Smoke check: " + dtrs[0].add(2,2) + " " + dtrs[0].doit(2,2,2));

      System.out.println("Warming Up");
      for (int j = 0; j < warmUps; ++j) {
        for (int i = 0; i < numClasses; ++i) {
          runResult += dtrs[i].doit(i, j, 100);
        }
      }
      System.out.println("Warmup result:" + runResult);

      printCompiledMethods();
      printMemoryUsage();

      System.out.println("Executing");
      for (int i = 0; i < numBatches; ++i) {
        batchTime[i] = do_measure(timesPerBatch);
        printStat(i+1);
      }

      System.out.println("Execution result:" + runResult);

      printCompiledMethods();
      printMemoryUsage();

      printFinalStat(numBatches);

    } catch(Throwable ex) {
       ex.printStackTrace();
    }
  }
}
