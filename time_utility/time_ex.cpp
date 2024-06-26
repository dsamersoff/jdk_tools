/*
 * Advanced utility to measure application execution time.
 * 1. Take care about CPU setup
 * 2. Do number of warmup calls
 * 3. Record statistics
 */

#include <getopt.h>
#include <errno.h>
#include <fcntl.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/resource.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>

// Should be global to be accessible by signal handler.
pid_t _pid;
int _should_exit = 0;

#define log_errno(msg) fprintf(stderr, "%s - %s (%d)\n", msg, strerror(errno), errno)
#define CHECK(a, msg) if ((a) == -1) { log_errno(msg); exit(EXIT_FAILURE); }
#define CHECK_NULL(a, msg) if ((a) == nullptr) { log_errno(msg); exit(EXIT_FAILURE); }
#define CHECK_EINTR(msg) if ((errno) != EINTR) { log_errno(msg); exit(EXIT_FAILURE); }
#define CHECK_CLK(a) CHECK(a, "Can't read clock")

// Print statistics
void print_stat(long long total_nsec, long long total_usec, long long total_ssec, int num_runs) {
    // Total set execution time, sec nsec
    long long tv_sec = total_nsec / 1000000000L;
    long long tv_nsec = total_nsec % 1000000000L;

    printf("Total: %lld.%lld", tv_sec, tv_nsec);

    if (num_runs > 0) {
        long long mean_sec = (total_nsec/num_runs) / 1000000000L;
        long long mean_nsec = (total_nsec/num_runs) % 1000000000L;

        long long user_sec = (total_usec/num_runs) / 1000000L;
        long long user_msec = (total_usec/num_runs) % 1000000L;

        long long sys_sec = (total_ssec/num_runs) / 1000000L;
        long long sys_msec = (total_ssec/num_runs) % 1000000L;

        printf(" Mean (%d): %lld.%lld %lld.%lldu %lld.%llds", num_runs,
                    mean_sec, mean_nsec, user_sec, user_msec, sys_sec, sys_msec);
    }
    printf("\n");
}

// Make sure that the program is bound
// to  the single cpu only
void bind_to_cpu() {
    cpu_set_t cpu_set;
    int core = 0;

    CPU_ZERO(&cpu_set);
    CPU_SET(core, &cpu_set);
    CHECK(sched_setaffinity(getpid(), sizeof(cpu_set), &cpu_set), "Can't bind to cpu");
}

void flush_disk_cache() {
    int fd = open("/proc/sys/vm/drop_caches", O_WRONLY);
    CHECK(fd, "Can't flush disk cache");
    sync();
    write(fd, "3", 1);
    close(fd);
}

// Actually exec
int do_exec(int keep_output, char * const argv[]) {
    _pid = vfork();
    CHECK(_pid, "fork failed");

    if (_pid == 0) {
        // This is the child process
        // Throw away stdout output from called program
        if (! keep_output) {
            CHECK_NULL(freopen("/dev/null", "w", stdout), "Can't redirect stdout");
        }
        CHECK(execve(argv[0], argv, NULL), "Can't execute child");
    } else {
        // This is the parent process
        // Wait for the child process to complete
        int status;
        if (waitpid(_pid, &status, 0) == -1) {
            CHECK_EINTR("Child problem, waitpid failed");
            // Skip this run, callee interrupted by signal
            return -1;
        }

        if (WIFEXITED(status)) {
            // Record the run only if callee exit code is zero
           return WEXITSTATUS(status);
        }
    }
    // Any other kind of errors, Skip this run.
    return -1;
}

// Print help and exit. Exit code 7 indicate command line error.
void usage(const char *prog_name) {
    fprintf(stderr, "Usage: %s [-w warmap] [-r runs] [-q] -- [commad_to_run...]\n", prog_name);
    exit(7);
}

// Signal handler
// Rise the flag to terminate exec loop and
// pass the signal to a running child
void sigint_handler(int signum) {
    fprintf(stderr, "Caught SIGINT signal (%d)\n", signum);
    _should_exit = 1;
    __sync_synchronize();
    if (_pid > 1 && _pid != getpid()) { // Paranoia
      kill(_pid, SIGINT);
    }
}


int main(int argc, char *argv[]) {

    int opt;
    char * const* argv_ex = NULL;
    int num_warmaps = 0;
    int num_runs = 1;
    int keep_output = 1;
    int flush = 0;

    while ((opt = getopt(argc, argv, "fqr:w:")) != -1) {
        switch (opt) {
            case 'f':
                flush = 1;
                break;
            case 'q':
                keep_output = 0;
                break;
            case 'r':
                num_runs = atoi(optarg);
                break;
           case 'w':
                num_warmaps = atoi(optarg);
                break;
            default:
                // Handle invalid options here
                fprintf(stderr, "Invalid option '%c'\n", opt);
                usage(argv[0]);
        }
    }

    // Assign rest of command line arguments to argv_ex
    if (optind < argc) {
        argv_ex = &(argv[optind]);
    }

    if (argv_ex == NULL) {
        fprintf(stderr, "No command to run\n");
        usage(argv[0]);
    }

    bind_to_cpu();

    // Catch SIGINT, to print some statistics
    // if the user decide to interrupt run
    struct sigaction sa;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sa.sa_handler = sigint_handler;
    CHECK(sigaction(SIGINT, &sa, NULL), "Can't set signal handler");

    // Warming up
    for (int i = 0; i < num_warmaps; i++) {
        do_exec(0 /*always discard output of warmup runs*/, argv_ex);
        if (_should_exit) {
           fprintf(stderr, "Warmup interrupted!\n");
           exit(EXIT_FAILURE);
        }
    }

    // Execution
    struct timespec child_time0 = {0, 0};
    struct timespec child_time1 = {0, 0};
    struct timespec flush_time0 = {0, 0};
    struct timespec flush_time1 = {0, 0};
    struct rusage child_ru;

    long long total_umsec = 0;
    long long total_smsec = 0;
    long long flush_nsec = 0;

    int actual_runs = 0;

    CHECK_CLK(clock_gettime(CLOCK_MONOTONIC, &child_time0));

    for (int j = 0; j < num_runs; ++j) {
        if (flush) {
            // Flushing may take some time, so adjust execution time
            CHECK_CLK(clock_gettime(CLOCK_MONOTONIC, &flush_time0));
            flush_disk_cache();
            CHECK_CLK(clock_gettime(CLOCK_MONOTONIC, &flush_time1));
            long long tmp_sec =  (long long) (flush_time1.tv_sec - flush_time0.tv_sec);
            flush_nsec += (tmp_sec * 1000000000L) + (long long) (flush_time1.tv_nsec - flush_time0.tv_nsec);
        }
        if (do_exec(keep_output, argv_ex) == 0) {
            // Callee terminated normally, with zero exit code, record the run
            CHECK(getrusage(RUSAGE_CHILDREN, &child_ru), "Can't read rusage");

            total_umsec += child_ru.ru_utime.tv_sec * 1000000L + child_ru.ru_utime.tv_usec;
            total_smsec += child_ru.ru_stime.tv_sec * 1000000L + child_ru.ru_stime.tv_usec;

            ++ actual_runs;
        }

        if (_should_exit) {
            fprintf(stderr, "Interrupted! Results may suffer.\n");
            break;
        }
    }

    CHECK_CLK(clock_gettime(CLOCK_MONOTONIC, &child_time1));

    // Convert elapsed time to nsec and pass to reporting function
    long long tv_sec =  (long long) (child_time1.tv_sec - child_time0.tv_sec);
    long long tv_nsec = (tv_sec * 1000000000L) + (long long) (child_time1.tv_nsec - child_time0.tv_nsec);

    print_stat(tv_nsec - flush_nsec, total_umsec, total_smsec, actual_runs);
    return 0;
}
