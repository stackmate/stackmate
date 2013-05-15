require 'rufus-json/automatic'
require 'ruote'
require 'ruote/storage/fs_storage'
require 'json'
require 'set'
require 'tsort'
require 'stackmate/logging'
require 'stackmate/classmap'
require 'stackmate/participants/participants'

module StackMate

class Stacker
    include TSort
    include Logging

    @@class_map = { 'AWS::EC2::Instance' => 'StackMate::Instance',
              'AWS::CloudFormation::WaitConditionHandle' => 'StackMate::WaitConditionHandle',
              'AWS::CloudFormation::WaitCondition' => 'StackMate::WaitCondition',
              'AWS::EC2::SecurityGroup' => 'StackMate::SecurityGroup'}

    def initialize(engine, templatefile, stackname, create_wait_conditions, params)
        @stackname = stackname
        @create_wait_conditions = create_wait_conditions
        @resolved = {}
        stackstr = File.read(templatefile)
        @templ = JSON.parse(stackstr) 
        @templ['StackName'] = @stackname
        @param_names = @templ['Parameters']
        @engine = engine
        @deps = {}
        @pdeps = {}
        resolve_param_refs(params)
        validate_param_values
        resolve_dependencies()
        @templ['ResolvedNames'] = @resolved
        pdef()
    end

    def resolve_param_refs(params)
        params.split(';').each do |p|
           i = p.split('=')
           @resolved[i[0]] = i[1]
        end
        @resolved['AWS::Region'] = 'us-east-1' #TODO handle this better
    end
    
    def validate_param_values
    end

    def resolve_dependencies
        @templ['Resources'].each { |key,val| 
            deps = Set.new
            pdeps = Set.new
            find_refs(key, val, deps, pdeps)
            deps << val['DependsOn'] if val['DependsOn']
            #print key, " depends on ", deps.to_a, "\n"
            #print key, " depends on ", pdeps.to_a, "\n"
            @deps[key] = deps.to_a
            @pdeps[key] = pdeps.to_a
        }
        @pdeps.keys.each do |k|
            unres = @pdeps[k] - @resolved.keys
            if ! unres.empty?
                unres.each do |u|
                    deflt = @param_names[u]['Default']
                    #print "Found default value ", deflt, " for ", u, "\n" if deflt
                    @resolved[u] = deflt if deflt
                end
                unres = @pdeps[k] - @resolved.keys
                throw :unresolved, (@pdeps[k] - @resolved.keys) if !unres.empty?
            end
        end
    end


    def find_refs (parent, jsn, deps, pdeps)
        case jsn
            when Array
                jsn.each {|x| find_refs(parent, x, deps, pdeps)}
                #print parent, ": ", jsn, "\n"
            when Hash
                jsn.keys.each do |k|
                    #TODO Fn::GetAtt
                    if k == "Ref"
                        #only resolve dependencies on other resources for now
                        if !@param_names.keys.index(jsn[k]) && jsn[k] != 'AWS::Region' && jsn[k] != 'AWS::StackId'
                            deps << jsn[k]
                            #print parent, ": ", deps.to_a, "\n"
                        else if @param_names.keys.index(jsn[k])
                            pdeps << jsn[k]
                        end
                        end
                    else
                        find_refs(parent, jsn[k], deps, pdeps)
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
        #if we want to skip creating wait conditions (useful for automated tests)
        participants = participants.select { |p|
            StackMate::CLASS_MAP[@templ['Resources'][p]['Type']] != 'WaitCondition'
        } if !@create_wait_conditions

        logger.info("Ordered list of participants: #{participants}")

        participants.each do |p|
            t = @templ['Resources'][p]['Type']
            throw :unknown, t if !StackMate::CLASS_MAP[t]
            @engine.register_participant p, StackMate::CLASS_MAP[t]
        end
        @engine.register_participant 'Output', 'StackMate::Output'
        participants << 'Output'
        @pdef = Ruote.define @stackname.to_s() do
            cursor do
                participants.collect{ |name| __send__(name) }
            end
        end
        #p @pdef
    end
    
    def launch
        wfid = @engine.launch( @pdef, @templ)
        @engine.wait_for(wfid)
        #puts "engine error : #{@engine.errors.first.message}"
    end
end

end
