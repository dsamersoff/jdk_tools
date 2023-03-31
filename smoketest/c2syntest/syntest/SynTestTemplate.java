package syntest;

public class SynTestTemplate implements SynTestRunner {
    public int add(int a, int b) {
        return a+b;
    }

    public int doit(int a, int b, int c, SynTestRunner prev) {
        int result = a + b;
        if (a > b)  {
            result = result * result;
            if (a > c) {
                result = result * result;
            }
        }

        if (a < b)  {
            result = result + result;
            if (a < c) {
                result = result + result;
            }
        }
        if (prev != null) {
            prev.doit(99, 99, 99, null);
        }
        return result;
    }
}