#!/gpfs1m/apps/apps/ruby2.0/bin/ruby
require 'yaml'
require 'socket'
require 'time'


#creates a hash in ArgParser.argv, after parsing the argument list
#Can use [] directly on ArgParser to reference @argv[]
class ArgParser
  attr_accessor :argv
  
  DEFAULT_COMMAND = 'iput' #default transfer command
  MAX_RETRIES = 5

  def initialize(argv_list)
    set_defaults
    return if ! argv_list.respond_to?('[]')
    parse_argv(argv_list)
  end
  
  def usage
    warn "Usage:\n tfr_queue  -f <srcfile> <dest_file> [-d] [ -f <srcfile> <dest_file> [-d] [-f ...]]"
    warn "  [--ru <remote_user] specifies the remote users name (irods specifies this in ~/.irods/.irodsEnv)"
    warn "  [--rh <remote_host] specifies the remote hosts name (irods specifies this in ~/.irods/.irodsEnv)"
    warn "  [--tc <tfr_command>] override the default transfer command. (Default irods iput)"
    warn "    Valid cmds are iput (default), iget, cp, mv, gridput, gridget, scpput, scpget"
    warn "    Authentication is assumed to be through certs. Not passwords"
    warn "  [--js <job_step_id>] specify the LL job_step_id. Used in building the control file name (default $LOADL_STEP_ID)"
    warn "  [--nh <node_hostname>] so the source of the transfer can be tracked (Default $HOSTNAME)"
    warn "  [--sd <def_source_dir] specify a default source directory (Default nil)"
    warn "  [--dd <def_dest_dir>] specify a default destination directory (Default nil)"
    warn "  [--cf <control_file>] override the default control file name (Default ${HOSTNAME}_${LOADL_STEP_ID}_${DATETTIME}.tfr)"
    warn "  [--ld <transfer_log_directory] default is users home directory  (Default ${HOSTNAME})"
    warn "  [--tl <transfer_log>] override the default log file name (Default ${HOSTNAME}_${LOADL_STEP_ID}_${DATETTIME}.tfr_log)"
    warn "  [--retries <n>] override the default retry count (Default 5)"
  end

  def set_defaults
    @argv = {}
    @argv[:tfr_command] = DEFAULT_COMMAND
    @argv[:queued_time] = Time.now.strftime("%Y-%m-%dT%H:%M:%S")
    @argv[:user] = ENV['USER']
    @argv[:home] = ENV['HOME']
    @argv[:pwd] = ENV['PWD'] == nil ? Dir.pwd : ENV['PWD']
    @argv[:log_dir] = ENV['HOME']
    @argv[:job_step_id] = ENV['LOADL_STEP_ID'] == nil ? Process.pid : ENV['LOADL_STEP_ID']  #Unique to a step in a LL job
    @argv[:hostname] = ENV['HOSTNAME'] == nil ? Socket.gethostname : ENV['HOSTNAME'] #HOSTNAME is the hostname of the parent host for this LL job
    @argv[:control_file] = "#{@argv[:hostname]}_#{@argv[:job_step_id]}_#{Time.now.strftime('%Y%m%dT%H%M%S')}.tfr"
    @argv[:transfer_log] = "#{@argv[:hostname]}_#{@argv[:job_step_id]}_#{Time.now.strftime('%Y%m%dT%H%M%S')}.tfr_log"
    @argv[:files] = [] #default file list is empty.
    #Not sure these next two are a good idea. It might cause issues with the remote side.
    @argv[:def_source_dir] = nil 
    @argv[:def_destination_dir] =  nil
    @argv[:remote_host] = nil
    @argv[:remote_user] = nil
    @argv[:retries] = 0  #how many times we have retried
    @argv[:maxretries] = 5 #how many retries we want, before giving up
  end
  
  def parse_argv(command_list)
    command_list.each_with_index do |arg, i|
      case arg
      when '--debug';
        @argv[:debug] = true;
      when '--retries'; #Sets max retries.
        if i+1 < command_list.length && command_list[i+1][0...1] != '-'
          @argv[:maxretries] = command_list[i+1].to_i
          next(2)
        end
      when '--cf';
        if i+1 < command_list.length && command_list[i+1][0...1] != '-'
          @argv[:control_file] = command_list[i+1]
          next(2)
        end
      when '--rh';
        if i+1 < command_list.length && command_list[i+1][0...1] != '-'
          @argv[:remote_host] = command_list[i+1]
          next(2)
        end
      when '--ru';
        if i+1 < command_list.length && command_list[i+1][0...1] != '-'
          @argv[:remote_user] = command_list[i+1]
          next(2)
        end
      when '--ld'; 
        if i+1 < command_list.length && command_list[i+1][0...1] != '-'
          @argv[:log_dir] = command_list[i+1] if i+1 < command_list.length
          next(2)
        end
      when '--tl'; 
        if i+1 < command_list.length && command_list[i+1][0...1] != '-'
          @argv[:transfer_log] = command_list[i+1] if i+1 < command_list.length
          next(2)
        end
      when '--tc'; 
        if i+1 < command_list.length && command_list[i+1][0...1] != '-'
          @argv[:tfr_command] = command_list[i+1] if i+1 < command_list.length
          next(2)
        end
      when '--sd'; 
        if i+1 < command_list.length && command_list[i+1][0...1] != '-'
          @argv[:def_source_dir] = command_list[i+1] if i+1 < command_list.length
          next(2)
        end
      when '--dd'; 
        if i+1 < command_list.length && command_list[i+1][0...1] != '-'
          @argv[:def_destination_dir] = command_list[i+1] if i+1 < command_list.length
          next(2)
        end
      when '--nh'; 
        if i+1 < command_list.length && command_list[i+1][0...1] != '-'
          @argv[:node_hostname] = command_list[i+1] if i+1 < command_list.length
          next(2)
        end
      when '--js'; 
        if i+1 < command_list.length && command_list[i+1][0...1] != '-'
          @argv[:job_step_id] = command_list[i+1] if i+1 < command_list.length
          next(2)
        end
      when '-f'; 
        files = {}
        if i+1 < command_list.length && command_list[i+1][0...1] != '-'
          src = command_list[i+1]
          plus = 2
          if i+2 < command_list.length && command_list[i+2][0...1] != '-'
            dest = command_list[i+2]
            plus = 3
            if i+3 < command_list.length && command_list[i+3] == '-d'
              flags = command_list[i+3]
              plus = 4
            else
              flags = nil
            end
          else
            dest = src
            flags = nil
          end
          @argv[:files] << {:src=>src, :dest=>dest,:flags=>flags, :complete=>false, :time=>nil}
          next(plus)
        end
      end
    end
  end
  
  def nfiles
    if @argv[:files] != nil
      return @argv[:files].length
    else
      return 0
    end
  end
  
  def[](key)
    @argv[key]
  end
    
  def[]=(key,value)
    @argv[key] = value
  end

  def to_s
    YAML::dump(@argv)
  end
  
  def self.test #Class level method
    puts "basic call, with default source and destination directories, and file list"
    ap = ArgParser.new(["--tc", "debug", "--sd", "src", "--dd","dest", "-f","src1","dest1", "-d","-f","src2", "dest2", "-f", "src3", "dest3", "-d"])
    puts ap.to_s
    puts
    puts "Overriding defaults"
    ap = ArgParser.new(["--tc", "debug", "--cf","ctl.tfr", "--ld", "/tmp", "-lf","log.tfr","-f","src1","dest1", "-d","-f","src2", "dest2", "-f", "src3", "dest3", "-d", "--sd", "somewhere-else", "--dd","another-place",  "--nh", "myhost"])
    puts ap.to_s
  end
end

#ArgParser.test

