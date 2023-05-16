This small utility is designed to measure the performance of external programs, such as Java startup performance, and is essentially a variation of the Unix time utility.

It supports warming up, batch execution, skip of run with non-zerro exit code etc.


e.g.
```
./time_ex -w 0 -r 1000 -- /bin/ls -R /export/workspaces

```
