require 'ruote'
require 'json'
require 'stackmate/stack'
require 'stackmate/logging'
require 'stackmate/classmap'
require 'stackmate/participants/cloudstack'
require 'stackmate/participants/common'

module StackMate

class StackExecutor < StackMate::Stacker
    include Logging

    def initialize(templatefile, stackname, params, engine, create_wait_conditions)
        stackstr = File.read(templatefile)
        super(stackstr, stackname, resolve_param_refs(params, stackname))
        @engine = engine
        @create_wait_conditions = create_wait_conditions
    end

    def resolve_param_refs(params, stackname)
        resolved_params = {}
        params.split(';').each do |p|
           i = p.split('=')
           resolved_params[i[0]] = i[1]
        end
        resolved_params['AWS::Region'] = 'us-east-1' #TODO handle this better
        resolved_params['AWS::StackName'] = stackname
        resolved_params['AWS::StackId'] = stackname
        resolved_params
    end

    def pdef
        participants = self.strongly_connected_components.flatten
        #if we want to skip creating wait conditions (useful for automated tests)
        participants = participants.select { |p|
            StackMate.class_for(@templ['Resources'][p]['Type']) != 'StackMate::WaitCondition'
        } if !@create_wait_conditions

        logger.info("Ordered list of participants: #{participants}")

        participants.each do |p|
            t = @templ['Resources'][p]['Type']
            throw :unknown, t if !StackMate.class_for(t)
            @engine.register_participant p, StackMate.class_for(t)
        end

        @engine.register_participant 'Output', 'StackMate::Output'
        participants << 'Output'
        @pdef = Ruote.define @stackname.to_s() do
            cursor do
                participants.collect{ |name| __send__(name) }
            end
        end
    end
    
    def launch
        wfid = @engine.launch( pdef, @templ)
        @engine.wait_for(wfid)
        logger.error { "engine error : #{@engine.errors.first.message}"} if @engine.errors.first
    end
end

end
