require 'rufus-json/automatic'
require 'ruote'
require 'ruote/storage/fs_storage'
require 'json'
require 'cloudstack_ruby_client'
require 'set'
require 'tsort'
require 'SecureRandom'
require 'optparse'

class Instance < Ruote::Participant
  URL = 'http://192.168.56.10:8080/client/api/'
  APIKEY = 'yy0sfCPpyKnvREhgpeIWzXORIIvyteq_iCgFpKXnqpdbnHuoYiK78nprSggG4hcx-hxwW897nU-XvGB0Tq8YFw'
  SECKEY = 'Pse4fqYNnr1xvoRXlAe8NQKCSXeK_VGdwUxUzyLEPVQ7B3cI1Q7B8jmZ42FQpz2jIICFax1foIzg2716lJFZVw'
  def initialize()
      @client = CloudstackRubyClient::Client.new(URL, APIKEY, SECKEY, false)
  end
  def on_workitem
    sleep(rand)
    #p workitem.fields['Resources'][workitem.participant_name]['Properties']
    #@client.listNetworkOfferings()
    p workitem.participant_name
    reply
  end
end

class WaitConditionHandle < Ruote::Participant
  def on_workitem
    sleep(rand)
    p workitem.participant_name
    reply
  end
end

class WaitCondition < Ruote::Participant
  def on_workitem
    sleep(rand)
    p workitem.participant_name
    reply
  end
end

class SecurityGroup < Ruote::Participant
  def on_workitem
    sleep(rand)
    p workitem.participant_name
    reply
  end
end

class Output < Ruote::Participant
  def on_workitem
    #p workitem.fields.keys
    p workitem.participant_name
    p "Done"
    reply
  end
end


class Stacker
    include TSort
    @@class_map = { "AWS::EC2::Instance" => "Instance",
              "AWS::CloudFormation::WaitConditionHandle" => "WaitConditionHandle",
              "AWS::CloudFormation::WaitCondition" => "WaitCondition",
              "AWS::EC2::SecurityGroup" => "SecurityGroup" }

    def initialize(templatefile, stackid)
        @stackid = stackid
        @engine = Ruote::Dashboard.new(
          Ruote::Worker.new(
            Ruote::FsStorage.new(@stackid.to_s())))

        @engine.noisy = ENV['NOISY'] == 'true'
        #@engine.noisy = true
        @stack = {}
        @resources = {}
        stackstr = File.read(templatefile)
        @templ = JSON.parse(stackstr) 
        #resolve_param_refs
        #order_resources
        @params = @templ['Parameters']
        @deps = {}
        @templ['Resources'].each { |key,val| deps = Set.new; find_refs(key, val, deps); @deps[key] = deps.to_a}
        pdef()
    end

    def find_refs (parent, jsn, deps)
        case jsn
            when Array
                jsn.each {|x| find_refs(parent, x, deps)}
            when Hash
                jsn.keys.each do |k|
                    if k == "Ref"
                        if !@params.keys.index(jsn[k]) && jsn[k] != "AWS::Region" && jsn[k] != "AWS::StackId"
                            deps << jsn[k]
                            #print parent, ": ", deps.to_a, "\n"
                        end
                    else
                        find_refs(parent, jsn[k], deps)
                    end
                end
        end
        return deps
    end

    def tsort_each_node(&block)
        @deps.each_key(&block)
    end

    def tsort_each_child(name, &block)
        @deps[name].each(&block) if @deps.has_key?(name)
    end

    def pdef()
        participants = self.strongly_connected_components.flatten
        @templ['Resources'].keys.each do |k|
            t = @templ['Resources'][k]['Type']
            #for each type of resource, build a list of instances of that resource
            (@resources[t] ||= [])  << k
            @engine.register_participant k, @@class_map[t]
        end
        @engine.register_participant 'Output', 'Output'
        participants << 'Output'
        print "Ordered list of participants: ",  participants, "\n"
        @pdef = Ruote.define 'mydef'+ @stackid.to_s() do
            cursor do
                participants.collect{ |name| __send__(name) }
            end
        end
        #p @pdef
    end
    
    def launch()
        wfid = @engine.launch( @pdef, @templ)
        @engine.wait_for(wfid)
    end
end

options = {}
stack_name = ''
opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: stack.rb STACK_NAME [options]"
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
