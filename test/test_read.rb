#!/gpfs1m/apps/apps/ruby2.0/bin/ruby
require 'pp'
require 'yaml'

def qualified_name(path, filename)
  if filename[0,1] == '/' || path == nil
    return filename
  end
  return "#{path}/#{filename}"
end


filename = qualified_name('/gpfs1m/Tfr_queue/', ARGV[0])

File.open(filename, "r+")  do |fd|  
  begin
    puts "YAML.load"
    @transfer_ctl = YAML.load(fd)
    puts "Output Hash"
    puts @transfer_ctl[:retries].class
    pp @transfer_ctl
  rescue Exception => error
    puts "YAML.load(#{ARGV[0]}) FAILED #{error}"
    exit -1
  end
end

