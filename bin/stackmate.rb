require 'ruote'
require 'ruote/storage/hash_storage'
require 'optparse'
require 'stackmate'
require 'stackmate/classmap'
require 'stackmate/waitcondition_server'


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
    options[:wait_conditions] = true
    opts.on("-n", "--no-wait-conditions", "Do not create any wait conditions") do 
        options[:wait_conditions] = false
    end
    options[:dry_run] = false
    opts.on("-r", "--dry-run", "Parse and pretend to execute but not actually do anything. Useful for validating the template") do 
        options[:dry_run] = true
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
    if options[:wait_conditions]
      Thread.new do
        StackMate::WaitConditionServer.run!
      end
    end
    engine = Ruote::Dashboard.new(
      Ruote::Worker.new(
        Ruote::HashStorage.new))
    engine.noisy = ENV['NOISY'] == 'true'
    engine.configure('wait_logger_timeout', 600)

    unknown = nil
    unresolved = catch(:unresolved) do
        unknown = catch(:unknown) do
            StackMate.configure('NOOP') if options[:dry_run]
            opts = {}
            api_opts = {:APIKEY => "#{ENV['APIKEY']}", :SECKEY => "#{ENV['SECKEY']}", :URL => "#{ENV['URL']}" }
            p = StackMate::StackExecutor.new(options[:file], stack_name, options[:params], engine, options[:wait_conditions], api_opts)
            p.launch()
            nil
        end
        nil
    end
    puts 'Failed to resolve parameters ' + unresolved.to_s if unresolved
    print "Sorry, I don't know how to create resources of type: ", unknown, "\n" if unknown
else 
    puts opt_parser.help()
end

