/*
 * Advanced utility to measure application execution time.
 * 1. Take care about CPU setup
 * 2. Do number of warmup calls
 * 3. Record statistics
 */

#include <getopt.h>
#include <errno.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/resource.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>

// Should be global to be accessible by signal handler.
pid_t _pid;
int _should_exit = 0;

#define CHECK(a) if ((a) == -1) {perror(#a); exit(EXIT_FAILURE);}
#define CHECK_NULL(a) if ((a) == nullptr) {perror(#a); exit(EXIT_FAILURE);}

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
    CHECK(sched_setaffinity(getpid(), sizeof(cpu_set), &cpu_set));
}

// Actually exec
int do_exec(char * const argv[]) {
    _pid = vfork();
    if (_pid == -1) {
        perror("vfork");
        exit(EXIT_FAILURE);

    } else if (_pid == 0) {
        // This is the child process
        // Throw away stdout output from called program
        CHECK_NULL(freopen("/dev/null", "w", stdout));
        CHECK(execve(argv[0], argv, NULL));
    } else {
        // This is the parent process
        // Wait for the child process to complete
        int status;
        if (waitpid(_pid, &status, 0) == -1) {
            if (errno != EINTR) {
              perror("waitpid");
              exit(EXIT_FAILURE);
            }
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
    fprintf(stderr, "Usage: %s [-w warmap] [-r runs] [-b batches] -- [commad_to_run...]\n", prog_name);
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
    int num_runs = 0;

    while ((opt = getopt(argc, argv, "r:w:")) != -1) {
        switch (opt) {
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
    CHECK(sigaction(SIGINT, &sa, NULL));

    // Warming up
    for (int i = 0; i < num_warmaps; i++) {
        do_exec(argv_ex);
        if (_should_exit) {
           fprintf(stderr, "Warmup interrupted!\n");
           exit(EXIT_FAILURE);
        }
    }

    // Execution
    struct timespec child_time0 = {0, 0};
    struct timespec child_time1 = {0, 0};
    struct rusage child_ru;

    long long total_umsec = 0;
    long long total_smsec = 0;

    int actual_runs = 0;

    CHECK(clock_gettime(CLOCK_MONOTONIC, &child_time0));

    for (int j = 0; j < num_runs; ++j) {
        if (do_exec(argv_ex) == 0) {
            // Callee terminated normally, with zero exit code, record the run
            CHECK(getrusage(RUSAGE_CHILDREN, &child_ru));

            total_umsec += child_ru.ru_utime.tv_sec * 1000000L + child_ru.ru_utime.tv_usec;
            total_smsec += child_ru.ru_stime.tv_sec * 1000000L + child_ru.ru_stime.tv_usec;

            ++ actual_runs;
        }

        if (_should_exit) {
            fprintf(stderr, "Interrupted! Results may suffer.\n");
            break;
        }
    }

    CHECK(clock_gettime(CLOCK_MONOTONIC, &child_time1));

    // Convert elapsed time to nsec and pass to reporting function
    long long tv_sec =  (long long) (child_time1.tv_sec - child_time0.tv_sec);
    long long tv_nsec = (tv_sec * 1000000000L) + (long long) (child_time1.tv_nsec - child_time0.tv_nsec);

    print_stat(tv_nsec, total_umsec, total_smsec, actual_runs);
    return 0;
}
