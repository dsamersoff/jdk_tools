UDP message is the fastest way to print something from your code. Syslog format (RFC 3164) gives you an option to do it the standard way. You can use the libc syslog() call or format the message manually.

This utility is the simplest syslog server written in Java, by default it's listening on port 22514. Optionally, you can restrict the output to certain tags specified on the command line.

Example syslog sender is also provided.

e.g.
```
echo "<9>May 29 10:15:00 localhost mytag: This is a test message" | nc -u localhost 22514

```
