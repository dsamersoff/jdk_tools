public class MultiAlloc {
    static MultiAllocWorker worker = new MultiAllocWorker();
    public static void main(String args[]) {        

        if (args[0].equals("sync")) {
            System.out.println("Synchronized allocation");
            // Allocate through syncronized worker
            for (int i = 0; i < 20; i++) {
                Thread thread = new Thread() {          
                    public void run() {             
                        worker.allocSynchronized(this);
                    }
                };
                thread.start();
            }
        }    
        else if (args[0].equals("concurrent")) {
            System.out.println("Concurrent allocation");
            // Allocate through concurrent worker
            for (int i = 0; i < 20; i++) {
                Thread thread = new Thread() {          
                    public void run() {             
                        worker.allocConcurrent(this);
                    }
                };
                thread.start();
            }
        }
        else {
            System.out.println("Usage: MultiAlloc [sync|concurrent]");
        }
    }
}
