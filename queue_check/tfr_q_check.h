#ifndef TFR_Q_CHECK_H
#define TFR_Q_CHECK_H

#define TFR_QUEUE_DIR "/gpfs1m/Tfr_queue"
#define LAUNCH_HANDLER "/gpfs1m/apps/utils/bin/tfr/tfr_handler"
#define TFR_RUN_LOCK "/var/run/tfr_run.lock"

#define FAILED_STATE 0000 //Bad config file causes this
#define CREATE_STATE 0200
#define READY_STATE 0600
#define RUN_STATE 0700
#define FIN_STATE 0400
#define ABORTED_STATE 0500 //Too many retries

#define WEEK 604800 //in seconds

#ifdef TFR_Q_CHECK_C
static int get_stat(char *file, uid_t *uid, uid_t *gid);
static void launch_handler(char *file, uid_t uid, uid_t gid);
static void notify_handle(char *file);
#endif //TFR_Q_CHECK_C

#endif  //TFR_Q_CHECK_H
