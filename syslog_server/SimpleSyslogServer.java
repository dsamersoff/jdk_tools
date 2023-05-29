import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.SocketException;
import java.nio.charset.StandardCharsets;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

// To test the code use:
// echo "<30>Jan 01 10:15:00 localhost mytag: This is a test message" | nc -u localhost 22514

public class SimpleSyslogServer {
    private static final int BUFFER_SIZE = 1024;
    private static final int Port = 22514; // Default syslog port is 514
    private static final String SYSLOG_PATTERN = "<(\\d+)>(\\S+ \\d+ \\d+:\\d+:\\d+) (\\S+) (\\S+): (.*)[\\r\\n]?";
    private static final Pattern PATTERN = Pattern.compile(SYSLOG_PATTERN);

    public static boolean parseSyslogMessage(String message, String pTag) {
        // Parse the syslog format message
        Matcher matcher = PATTERN.matcher(message);
        boolean isSyslogMessage = matcher.matches();
        if (isSyslogMessage) {
            int priority = Integer.parseInt(matcher.group(1));
            String timestamp = matcher.group(2);
            String hostname = matcher.group(3);
            String tag = matcher.group(4);
            String content = matcher.group(5);

            // Print the parsed syslog fields, filter by tag if requested
            if (pTag == null || tag.equals(pTag)) {
               // Not interesting in priority
               System.out.printf("%s %s %s: %s\n", timestamp, hostname, tag, content);
            }
        }
        return isSyslogMessage;
    }

    public static void main(String[] args) {
        try {
            DatagramSocket socket = new DatagramSocket(Port);
            String tag = null;

            System.err.print("Simple UDP server started. ");
            if (args.length == 0) {
                System.err.printf("All messages are printed.\n");
            }
            else {
                tag = args[0];
                System.err.printf("Only messages with tag '%s' are printed.\n", tag);
            }

            byte[] buffer = new byte[BUFFER_SIZE];

            while (true) {
                DatagramPacket packet = new DatagramPacket(buffer, BUFFER_SIZE);
                socket.receive(packet);
                String message = new String(packet.getData(), 0, packet.getLength(), StandardCharsets.UTF_8);
                if (!parseSyslogMessage(message, tag) && tag == null) {
                    // If tag filtering not requested, display mesages that doesn't match syslog format
                    System.out.println("Received: " + message);
                }
            }
        } catch (SocketException e) {
            System.out.println("Socket error: " + e.getMessage());
        } catch (IOException e) {
            System.out.println("I/O error: " + e.getMessage());
        }
    }
}
