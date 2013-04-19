require 'SecureRandom'
require 'optparse'
require_relative 'stack'


options = {}
stack_name = ''
opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: stackmate.rb STACK_NAME [options]"
    opts.separator ""
    opts.separator "Specific options:"
    opts.on(:REQUIRED, "--template-file FILE", String, "Path to the file that contains the template") do |f|
        options[:file] = f
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
    p = Stacker.new(options[:file], stack_name + '_' + SecureRandom.hex(3))
    p.launch()
else 
    puts opt_parser.help()
end
