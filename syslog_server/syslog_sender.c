#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <syslog.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>


#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <syslog.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <time.h>

#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <syslog.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <time.h>

void get_current_timestamp(char* timestamp, size_t size) {
    time_t current_time;
    struct tm* time_info;

    time(&current_time);
    time_info = localtime(&current_time);

    strftime(timestamp, size, "%b %d %H:%M:%S", time_info);
}

void send_syslog_udp(const char* server, int server_port, int priority, const char *tag, const char* format, ...) {
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0) {
        perror("Socket error");
        return;
    }

    // Prepare the syslog message
    va_list args;
    va_start(args, format);
    char message[1024];
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);

    // Construct the syslog packet
    char timestamp[64];
    get_current_timestamp(timestamp, sizeof(timestamp));

    char packet[1024];
    snprintf(packet, sizeof(packet), "<%d>%s %s: %s", priority, timestamp, tag, message);

    // Get the server IP address
    struct hostent* server_info = gethostbyname(server);
    if (server_info == NULL) {
        perror("Failed to resolve hostname");
        return;
    }

    // Create the destination address
    struct sockaddr_in dest_addr;
    memset(&dest_addr, 0, sizeof(dest_addr));
    dest_addr.sin_family = AF_INET;
    dest_addr.sin_port = htons(server_port);
    memcpy(&dest_addr.sin_addr, server_info->h_addr, server_info->h_length);

    // Send the syslog packet
    ssize_t sent_bytes = sendto(sockfd, packet, strlen(packet), 0, (struct sockaddr*)&dest_addr, sizeof(dest_addr));
    if (sent_bytes < 0) {
        perror("Sendto error");
        return;
    }

    close(sockfd);
}

int main() {
    send_syslog_udp("localhost", 22514, LOG_INFO, "mytag", "This is a test message");
    return 0;
}
