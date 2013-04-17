
require 'rufus-json/automatic'
require 'ruote'
require 'ruote/storage/fs_storage'
require 'json'

class Instance < Ruote::Participant
  def on_workitem
    sleep(rand)
    result =
      [ workitem.participant_name, (20 * rand + 1).to_i ]
    (workitem.fields['spotted'] ||= []) << result
    p result
    reply
  end
end

class WaitConditionHandle < Ruote::Participant
  def on_workitem
    sleep(rand)
    result =
      [ workitem.participant_name, (40 * rand + 1).to_i ]
    (workitem.fields['spotted'] ||= []) << result
    p result
    reply
  end
end

class WaitCondition < Ruote::Participant
  def on_workitem
    sleep(rand)
    result =
      [ workitem.participant_name, (40 * rand + 1).to_i ]
    (workitem.fields['spotted'] ||= []) << result
    p result
    reply
  end
end

class SecurityGroup < Ruote::Participant
  def on_workitem
    sleep(rand)
    result =
      [ workitem.participant_name, (40 * rand + 1).to_i ]
    (workitem.fields['spotted'] ||= []) << result
    p result
    reply
  end
end

class Finisher < Ruote::Participant
  def on_workitem
    p workitem.fields.keys
    p 'done'
    reply
  end
end


class Stacker
    @@class_map = { "AWS::EC2::Instance" => "Instance",
              "AWS::CloudFormation::WaitConditionHandle" => "WaitConditionHandle",
              "AWS::CloudFormation::WaitCondition" => "WaitCondition",
              "AWS::EC2::SecurityGroup" => "SecurityGroup" }

    def initialize(templatefile, stackid)
        @stackid = stackid
        @engine = Ruote::Dashboard.new(
          Ruote::Worker.new(
            Ruote::FsStorage.new('stacker_work_' + @stackid.to_s())))

        @engine.noisy = ENV['NOISY'] == 'true'
        @stack = {}
        @resources = {}
        stackstr = File.read(templatefile)
        @templ = JSON.parse(stackstr) 
        #resolve_param_refs
        #order_resources
        @params = @templ['Parameters']
        pdef()
    end

    def pdef()
        participants = []
        @templ['Resources'].keys.each do |k|
            t = @templ['Resources'][k]['Type']
            #for each type of resource, build a list of instances of that resource
            (@resources[t] ||= [])  << k
            @engine.register_participant k, @@class_map[t]
            #one participant per resource instance. FIXME: needs to be ordered
            participants << k
        end
        @engine.register_participant 'finisher', 'Finisher'
        participants << 'finisher'
        p participants
        @pdef = Ruote.define 'mydef'+ @stackid.to_s() do
            cursor do
                participants.collect{ |name| __send__(name) }
            end
        end
    end
    
    def launch()
        wfid = @engine.launch( @pdef, @templ)
        @engine.wait_for(wfid)
    end
end


p = Stacker.new('LAMP_Single_Instance.template', 3)
p.launch()
