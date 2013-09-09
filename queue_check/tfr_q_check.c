#include <sys/types.h>
#include <stdarg.h> 
#include <stdio.h>
#include <syslog.h>
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <string.h>
#include <lockfile_p.h>

#define TFR_Q_CHECK_C
#include "tfr_q_check.h"

static int daily_check = 0;
static int debug = 0;

int main(int argc, char **argv)
{
DIR *dp;
struct dirent *ep;
char buff[1024];
uid_t uid = -1;
uid_t gid = -1;
char pid_buff[16];
int i;

  //Parse args for -c and -d
  for(i=1; i < argc; i++)
  {  
    if(strcmp(argv[i],"-c") == 0)
      daily_check = 1;
    else if(strcmp(argv[i],"-d") == 0)
      debug = 1;
  }
  //Config syslog
  openlog("tfr_q_check", 0, LOG_CRON);
  if(debug) syslog(LOG_INFO, "Running tfr_q_check in Debug mode");

  //Lock queue, so we don't get two processes parsing the same queue
  //Lock is ignored by tfr_queue and tfr_handler, as the files they work on 
  //are ignored by tfr_q_check.
  sprintf(pid_buff,"%d", getpid());  
  if(lockfile_p(TFR_RUN_LOCK, pid_buff, debug) == 0)
  {
    if(debug) syslog(LOG_INFO, "Created TFR_RUN_LOCK %s",TFR_RUN_LOCK);
    
    //Walk through the queue
    dp = opendir (TFR_QUEUE_DIR);
    if (dp != NULL)
    {
      if(debug) syslog(LOG_INFO, "Walking directory TFR_QUEUE_DIR %s",TFR_QUEUE_DIR);
      
      while (ep = readdir (dp))
      {
        //check each file entry, ignoring directory and other non-file entries
        sprintf(buff, "%s/%s",TFR_QUEUE_DIR,ep->d_name);
        if(debug) syslog(LOG_INFO, "Checking file %s", buff);
        switch(get_stat(buff, &uid, &gid))
        {
          case 1: launch_handler(buff, uid, gid); break; //launch tfr_handler for this file
          case 2: notify_handle(buff); break; //send notification for this file.
        }
      } 
      (void) closedir (dp);
    }
    else
      syslog(LOG_ERR, "%m -Couldn't open the directory %s", TFR_QUEUE_DIR);
      
    if(debug) syslog(LOG_INFO, "Removing TFR_RUN_LOCK %s",TFR_RUN_LOCK);
    unlink(TFR_RUN_LOCK); //remove the lockfile
    return 0;
  }
  else
  {
    syslog(LOG_ERR, "Couldn't get lock %s",TFR_RUN_LOCK);
    return -1;
  }
}

//Examine the stat entry for this file.
//Ignores directory and special files.
//Removes stray files users may have manually put in the queue.
//Returns processing code
static int get_stat(char *file, uid_t *uid, uid_t *gid)
{
struct stat sb;
int l = strlen(file);

  //skip . and ..
  if(strcmp(file, ".") == 0 || strcmp(file, "..") == 0) return 0;
  
  //Stat the file
  if(stat(file, &sb) == -1)
  { 
    if(debug) syslog(LOG_INFO, "Couldn't stat file %s",file); //might just have been removed.
    return -1;
  }

  //Check this is a regular file, and return if it is not.
  if(! S_ISREG(sb.st_mode) )
  {
    if(debug) syslog(LOG_INFO, "Ignoring %s. Not a regular file",file);
    return(4); //ignore directories and symbolic links, etc
  }
    
  //Check file is a transfer file, and delete strays.
  if(l < 4 || strcmp(&file[l-4], ".tfr") != 0)
  {
    syslog(LOG_INFO,"Unexpected file in queue. Deleting %s",file);
    return 3;
    //unlink(file);
  }
  
  //Check for queue files that don't seem to be progressing.
  if(daily_check 
  && (( sb.st_mode & ALLPERMS ) == RUN_STATE     
  || ( sb.st_mode & ALLPERMS ) ==  CREATE_STATE 
  || ( sb.st_mode & ALLPERMS ) ==  READY_STATE ) 
  && (time(NULL) - sb.st_mtime) >  WEEK )
  {
    if(debug) syslog(LOG_INFO, "File ready to run for over a week %s",file); 
    return 2; //File has been in a queue for over a week
  }

  //File is of the right type, and the right mode.
  if(( sb.st_mode & ALLPERMS ) == READY_STATE)
  {
    if(debug) syslog(LOG_INFO, "File ready to run %s",file);
    *uid =  sb.st_uid;
    *gid =  sb.st_gid;
    return 1; //file is ready to be processed
  }
  
  return 0; //ignore files with other st_modes
}

static void launch_handler(char *file, uid_t uid, uid_t gid)
{
int pid;
  //Check we aren't being asked to run as root
  if(uid == 0 || gid == 0) //Child process uid and gid. We are running as root!
  {
    syslog(LOG_ERR, "Launching transfers as root is not permitted");
    return;
  }
  
  if((pid = fork()) == -1)
  {
    syslog(LOG_ERR, "Fork failed for %s: %m", file); //move on and try the next one.
    return;
  }
  
  if(pid == 0) //We forked, and are the child process
  { 
    if(debug) syslog(LOG_INFO, "exec( %s , %s )",LAUNCH_HANDLER, file);
    
    //Mark the file as being processed.
    if(chmod(file, RUN_STATE) == -1)
    {
      syslog(LOG_ERR, "chmod(%s,RUN_STATE) before exec( %s , %s ) failed with %m",file, LAUNCH_HANDLER, file);
      _exit(2); //We are in the child
    }
    
    //run as the owner of the file, but not if the owner or group is root.
    if(setgid(gid) || setuid(uid))
    {      
      syslog(LOG_ERR, "setuid failed. Launching '%s %s' Error: %m", LAUNCH_HANDLER, file);
      _exit(1); //We are in the Child.
    }
    
    //close(0);close(1);close(2);
    //default signals should be set to defaults.
    signal(SIGTTIN, SIG_DFL);
    signal(SIGTTOU, SIG_DFL);
    signal(SIGTSTP, SIG_DFL);
    signal(SIGINT , SIG_DFL);
    signal(SIGQUIT, SIG_DFL);
    execl(LAUNCH_HANDLER, LAUNCH_HANDLER, file, NULL);
    //Should never get here.
    syslog(LOG_ERR, "execl failed for '%s %s' Error: %m", LAUNCH_HANDLER, file);
    _exit(1); //_exit, as child needs to skip cleanup done by exit().
  }
  //else 
    // we forked and are the parent
}

static void notify_handle(char *file)
{
  syslog(LOG_WARNING, "File still in Tranfer queue after 1 week. Control file: %s", file);
}
