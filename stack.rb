require 'rufus-json/automatic'
require 'ruote'
require 'ruote/storage/fs_storage'
require 'json'
require 'set'
require 'tsort'
require_relative 'participants'

class Stacker
    include TSort
    @@class_map = { 'AWS::EC2::Instance' => 'Instance',
              'AWS::CloudFormation::WaitConditionHandle' => 'WaitConditionHandle',
              'AWS::CloudFormation::WaitCondition' => 'WaitCondition',
              'AWS::EC2::SecurityGroup' => 'SecurityGroup'}

    def initialize(templatefile, stackname)
        @stackname = stackname
        p stackname
        @engine = Ruote::Dashboard.new(
          Ruote::Worker.new(
            Ruote::FsStorage.new('work/' + @stackname.to_s())))

        @engine.noisy = ENV['NOISY'] == 'true'
        #@engine.noisy = true
        @stack = {}
        @resources = {}
        stackstr = File.read(templatefile)
        @templ = JSON.parse(stackstr) 
        #resolve_param_refs
        #order_resources
        @params = @templ['Parameters']
        resolve_dependencies()
        @templ['StackName'] = @stackname
        pdef()
    end

    def resolve_dependencies
        @deps = {}
        @templ['Resources'].each { |key,val| 
            deps = Set.new
            find_refs(key, val, deps)
            @deps[key] = deps.to_a
        }
    end

    def find_refs (parent, jsn, deps)
        case jsn
            when Array
                jsn.each {|x| find_refs(parent, x, deps)}
            when Hash
                jsn.keys.each do |k|
                    if k == "Ref"
                        #only resolve dependencies on other resources for now
                        if !@params.keys.index(jsn[k]) && jsn[k] != 'AWS::Region' && jsn[k] != 'AWS::StackId'
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

    def pdef
        participants = self.strongly_connected_components.flatten
        participants.each do |p|
            t = @templ['Resources'][p]['Type']
            @engine.register_participant p, @@class_map[t]
        end
        @engine.register_participant 'Output', 'Output'
        participants << 'Output'
        print 'Ordered list of participants: ',  participants, "\n"
        @pdef = Ruote.define @stackname.to_s() do
            set 'f:stack_name' => @stackname
            cursor do
                participants.collect{ |name| __send__(name) }
            end
        end
        #p @pdef
    end
    
    def launch
        wfid = @engine.launch( @pdef, @templ)
        @engine.wait_for(wfid)
    end
end
