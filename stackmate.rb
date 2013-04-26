require 'ruote'
require 'ruote/storage/fs_storage'
require 'optparse'
require_relative 'stack'
require_relative 'waitcondition_server'


options = {}
stack_name = ''
opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: stackmate.rb STACK_NAME [options]"
    opts.separator ""
    opts.separator "Specific options:"
    opts.on(:REQUIRED, "--template-file FILE", String, "Path to the file that contains the template") do |f|
        options[:file] = f
    end
    opts.on("-p", "--parameters [KEY1=VALUE1 KEY2=VALUE2..]", "Parameter values used to create the stack.") do |p|
        options[:params] = p
        puts p
    end
    opts.on("-h", "--help", "Show this message")  do
        puts opts
        exit
    end
end

begin
    opt_parser.parse!(ARGV)
    if ARGV.size == 1
        stack_name = ARGV[0]
    end
rescue => e
    puts e.message.capitalize 
    puts opt_parser.help()
    exit 1
end

if options[:file] && stack_name != ''
    Thread.new do
      WaitConditionServer.run!
    end
    engine = Ruote::Dashboard.new(
      Ruote::Worker.new(
        Ruote::HashStorage.new))
    engine.noisy = ENV['NOISY'] == 'true'

    unresolved = catch(:unresolved) do
        p = Stacker.new(engine, options[:file], stack_name, options[:params])
        p.launch()
    end
    if unresolved.kind_of? Array
        puts 'Failed to resolve parameters ' + unresolved.to_s
    end
else 
    puts opt_parser.help()
end
