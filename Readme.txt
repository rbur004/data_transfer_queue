PAN Data Staging Hack

Transfer Queue Directory /gpfs1m/Tfr_queue
  Files are YAML, and have a .tfr extension
  Files without a .tfr extension are mercilessly removed. <--------NOTE
  File mode is used for workflow state:
  FAILED_STATE=0000 #Bad config file
  CREATE_STATE=0200 #While writing the config file
  READY_STATE=0600  #config file ready for running on the transfer node
  RUN_STATE=0700    #transfer running
  FIN_STATE=0400    #transfer complete
  ABORTED_STATE=0500 #Too many retries

Workflow lock is /var/run/tfr_run.lock

Bin Dir is currently /gpfs1m/apps/utils/bin/tfr/

Process
  1. Files are queued by creating a transfer control file in the Transfer directory
  
        Usage: 
          tfr_queue  -f <srcfile> <dest_file> [-d] [ -f <srcfile> <dest_file> [-d] [-f ...]]
        Additional Options to override the defaults:
          [--ru <remote_user] specifies the remote users name (irods specifies this in ~/.irods/.irodsEnv)
          [--rh <remote_host] specifies the remote hosts name (irods specifies this in ~/.irods/.irodsEnv)
          [--tc <tfr_command>] override the default transfer command. (Default irods iput)
            Valid cmds are iput (default), iget, cp, mv, gridput, gridget, scpput, scpget
            Authentication is assumed to be through certs. Not passwords
          [--js <job_step_id>] specify the LL job_step_id. Used in building the control file name (default $LOADL_STEP_ID)
          [--nh <node_hostname>] so the source of the transfer can be tracked (Default $HOSTNAME)
          [--sd <def_source_dir] specify a default source directory (Default $HOME)
          [--dd <def_dest_dir>] specify a default destination directory (Default '')
          [--cf <control_file>] override the default control file name (Default ${HOSTNAME}_${LOADL_STEP_ID}_${DATETTIME}.tfr)
          [--ld <transfer_log_directory] default is users home directory  (Default ${HOSTNAME})
          [--tl <transfer_log>] override the default log file name (Default ${HOSTNAME}_${LOADL_STEP_ID}_${DATETTIME}.tfr_log)
          [--retries <n>] override the default retry count (Default 5)
          [--debug]
     
   2. Cron, running as root on a DTN, runs tfr_q_check every X minutes and launches tfr_handler for each tfr file with mode 700
        2.1 TFR_RUN_LOCK is obtained
        2.2 directory is scanned for .tfr files having mode 0700 and changed to 0740 to indicate it is being processed
        2.1 TFR_RUN_LOCK is freed
        2.3 for each of these .tfr file, a tfr_handler process is launched as the user (root transfers are rejected)
            2.3.1 tfr_handler parses the .tfr file and initiates the transfer, changing the .tfr file mode as appropriate.
   
Security:
  * The queuing and Transfer jobs run as the user who wrote the job_id file, so only files accessible by that user can be transferred
  and only files that the user could delete, can be deleted by the transfer job. Transfer jobs are not permitted to be run as root.
  * The user's environment is not available to the transfer job.
  * The only valid transfer commands are iget, iput, cp, mv, scp_get, scp_put.  These execute as:
      iget    "/gpfs1m/apps/utils/bin/iget -N 4 -f -K #{src} #{dest}"   (Remote user and host for iRods is in ~/.irods/.irodsEnv)
      iput    "/gpfs1m/apps/utils/bin/iput -N 4 -f -K #{src} #{dest}"   (Remote user and host for iRods is in ~/.irods/.irodsEnv)
      cp      "/bin/cp #{src} #{dest}"
      mv      "/bin/mv #{src} #{dest}"
      scp_get "/usr/bin/scp #{ruser}@#{src} #{dest}"
      scp_put "/usr/bin/scp #{src} #{ruser}@#{dest}"
      debug   "/bin/echo #{src} #{dest}"
  * For iRods, we assume that the user has logged into the data fabric or has the appropriate certificates in place.
  * For scp, we assume ssh certs
