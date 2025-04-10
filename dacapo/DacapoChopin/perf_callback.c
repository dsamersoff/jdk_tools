
#include <stdio.h>
#include <stdint.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <ucontext.h>

#include <setjmp.h>

// Check for availability of important perf events
#include <linux/perf_event.h>    /* Definition of PERF_* constants */
#include <linux/hw_breakpoint.h> /* Definition of HW_* constants */
#include <sys/syscall.h>         /* Definition of SYS_* constants */

#include <sys/ioctl.h>
#include <unistd.h>
#include <string.h>

#include "PerfCallback.h"

/* Build perf event, return associated fd*/
static int perf_event_prepare(uint32_t p_type, uint64_t p_config) {
  unsigned long flags = PERF_FLAG_FD_CLOEXEC;
  int fd = -1;
  struct perf_event_attr attr;

  memset(&attr, 0, sizeof(attr));
  attr.type = p_type;
  attr.size = sizeof(attr);
  attr.config = p_config;
  attr.disabled = 1;
  attr.exclude_kernel = 1;
  attr.exclude_hv = 1;

  return syscall(__NR_perf_event_open, &attr, 0 /*pid*/, -1 /*cpu*/, -1 /*group_fd*/, flags);
}

/* start perf event */
int perf_event_start(uint32_t p_type, uint64_t p_config) {
  int fd = perf_event_prepare(p_type, p_config);
  if (fd > 0) {
    ioctl(fd, PERF_EVENT_IOC_RESET, 0);
    ioctl(fd, PERF_EVENT_IOC_ENABLE, 0);
  }
  return fd;
}

long long perf_event_stop(int fd) {
  long long count = 0;
  ioctl(fd, PERF_EVENT_IOC_DISABLE, 0);
  read(fd, &count, sizeof(count));
  // close(fd);
  return count;
}

/* JNI Functions */
JNIEXPORT jint JNICALL Java_PerfCallback_startPerfEvent(JNIEnv *env, jobject obj, jint type, jlong config) {
  return perf_event_start(type, config);
}

JNIEXPORT jlong JNICALL Java_PerfCallback_stopPerfEvent(JNIEnv * env, jobject obj, jint fd) {
  return perf_event_stop(fd);
}