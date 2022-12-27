/**
 *
 *
 */
package syntest;

import org.objectweb.asm.*;
import org.objectweb.asm.util.*;

import java.lang.Math;
import java.io.PrintWriter;

public class SynTest implements Opcodes {
  private final static String packageName = "syntest";
  private final static String classNamePrefix = "SynImpl";
  private final static int numClasses = 80_000;
  private final static SynTestRunner dtrs[] = new SynTestRunner[numClasses];
  private final static int warmUps = 10_000;
  private final static int numBatches = 1_000_000;
  private final static long timesPerBatch = 1_000_000;
  private final static long batchTime[] = new long[numBatches];
  private final static boolean traceMethodGeneration = false;

  private static long runResult = 0;

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

  public static void main(String args[]) {
    System.out.println("Syntetic test started");
    try {
      System.out.println("Generating");
      for (int i = 0; i < numClasses; ++i) {
        String className = String.format("%s_%04d", classNamePrefix, i);
        byte[] class_ba = doGenerateClass(className);
        SynClassLoader loader = new SynClassLoader();
        Class<?> clazz = loader.defineClass(packageName + "." + className, class_ba);
        dtrs[i] = (SynTestRunner) clazz.newInstance();
      }

      System.out.println("Smoke check: " + dtrs[0].add(2,2) + " " + dtrs[0].doit(2,2,2));

      System.out.println("Warming Up");
      for (int j = 0; j < warmUps; ++j) {
        for (int i = 0; i < numClasses; ++i) {
          runResult += dtrs[i].doit(i, j, 100);
        }
      }
      System.out.println("Warmup result:" + runResult);

      System.out.println("Executing");
      for (int i = 0; i < numBatches; ++i) {
        batchTime[i] = do_measure(timesPerBatch);
      }
      System.out.println("Exec result:" + runResult);

      double total = 0;
      for (int i = 0; i < numBatches; ++i) {
        total += batchTime[i];
      }

      double mean = total / numBatches;

      double variance = 0;
      for (int i = 0; i < numBatches; i++) {
        variance += Math.pow(batchTime[i] - mean, 2);
      }
      variance = variance / numBatches;

      double std = Math.sqrt(variance);

      System.out.printf("Executed %d classes, %d times in %d batches\n", numClasses, (long)(numBatches * timesPerBatch), numBatches);
      System.out.printf("Results %f (%f +- %f)\n", total, mean, std);
    } catch(Throwable ex) {
       ex.printStackTrace();
    }
  }
}
