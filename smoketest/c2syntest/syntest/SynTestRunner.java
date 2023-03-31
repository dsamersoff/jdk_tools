/**
 *
 *
 *
 */
package syntest;

public interface SynTestRunner {
    public int add(int left, int right);
    public int doit(int left, int right, int mulc, SynTestRunner prev);
}
