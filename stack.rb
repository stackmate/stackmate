
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


class Stacker
    @@class_map = { "AWS::EC2::Instance" => "Instance",
              "AWS::CloudFormation::WaitConditionHandle" => "WaitConditionHandle",
              "AWS::CloudFormation::WaitCondition" => "WaitCondition",
              "AWS::EC2::SecurityGroup" => "SecurityGroup" }

    def initialize(templatefile, stackid)
        @stackid = stackid
        @engine = Ruote::Dashboard.new(
          Ruote::Worker.new(
            Ruote::FsStorage.new('stacker_work')))

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
            if ! @resources.has_key?(t)
                @resources[t] = []
            end
            @resources[t] << k
            @engine.register_participant k, @@class_map[t]
            participants << k
        end
        @pdef = Ruote.define 'mydef'+@stackid.to_s() do
            cursor do
                participants.collect{ |name| __send__(name) }
            end
        end
        p @pdef
    end
    
    def launch()
        wfid = @engine.launch(
        @pdef,
        @params)
        @engine.wait_for(wfid)
    end
end


p = Stacker.new('LAMP_Single_Instance.template', 1)
p.launch()
