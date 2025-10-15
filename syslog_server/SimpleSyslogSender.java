import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.net.SocketException;
import java.net.UnknownHostException;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class SimpleSyslogSender {
  /**
   * <a href="https://datatracker.ietf.org/doc/html/rfc3164#section-4.1">syslog Message Parts</a>
   */
  private static final String SYSLOG_FORMAT = "<%d>%s %s: %s";
  /**
   * <a href="https://datatracker.ietf.org/doc/html/rfc3164#section-4.1.1">PRI Part</a>
   */
  private static final int PRI = 9; // Numerical value for clock daemon
  /**
   * <a href="https://datatracker.ietf.org/doc/html/rfc3164#section-4.1.2">HEADER Part of a syslog Packet</a>
   */
  private static final DateTimeFormatter TIME_FORMATTER = DateTimeFormatter.ofPattern("MMM d HH:mm:ss");

  public static void main(String[] args) {
    sendSyslogUdp("localhost", 22514, PRI, "mytag", "This is a test message");
  }

  private static void sendSyslogUdp(
      String server, int server_port,
      int priority,
      String tag,
      String format, Object... args
  ) {
    try (DatagramSocket socket = new DatagramSocket()) {
      LocalDateTime timestamp = LocalDateTime.now();
      String content = String.format(format, args);
      String msg = String.format(SYSLOG_FORMAT, priority, timestamp.format(TIME_FORMATTER), tag, content);
      byte[] bytes = msg.getBytes(StandardCharsets.UTF_8);
      DatagramPacket dataPacket = new DatagramPacket(bytes, bytes.length, InetAddress.getByName(server), server_port);
      socket.send(dataPacket);
    } catch (UnknownHostException e) {
      throw new RuntimeException("Unknow host name: ", e);
    } catch (SocketException e) {
      throw new RuntimeException("Cannot open DatagramSocket: ", e);
    } catch (IOException e) {
      throw new RuntimeException("Can't send DatagramPacket: ", e);
    }
  }
}
