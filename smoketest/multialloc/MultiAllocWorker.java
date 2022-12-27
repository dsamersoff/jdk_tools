public class MultiAllocWorker {
    public static int count = 0;
    private Object allocationLock = new Object();

    private void doAllocation(Thread t) {
       try{
           count += 1;
           System.out.println(" " + t + " ");
           for (int i = 0; i < 1024; i++) {
               long[] hog = new long[1024];
           }
        } catch (java.lang.InternalError e) {
            System.out.println("Exception " + e);
        }
    }

    public void allocSynchronized(Thread t) {
        synchronized (allocationLock) {
             doAllocation(t); 
        }
    }

    public void allocConcurrent(Thread t) {
        doAllocation(t); 
    }
}
