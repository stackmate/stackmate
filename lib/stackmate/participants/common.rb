require 'stackmate/logging'
require 'stackmate/aws_attribs'
require 'stackmate/intrinsic_functions'

module StackMate


class WaitConditionHandle < Ruote::Participant
  include Logging

  def on_workitem
    logger.debug "Entering #{participant_name} "
    workitem[participant_name] = {}
    presigned_url = 'http://localhost:4567/waitcondition/' + workitem.fei.wfid + '/' + participant_name
    workitem.fields['ResolvedNames'][participant_name] = presigned_url
    logger.info "Your pre-signed URL is: #{presigned_url} "
    logger.info "Try: \ncurl -X PUT --data 'foo' #{presigned_url}"
    WaitCondition.create_handle(participant_name, presigned_url)
    workitem[participant_name][:physical_id] = presigned_url

    reply
  end
end

class WaitCondition < Ruote::Participant
  include Logging
  @@handles = {}
  @@conditions = []

  def on_workitem
    logger.debug "Entering #{workitem.participant_name} "
    workitem[participant_name] = {}
    @@conditions << self
    stackname = workitem.fields['ResolvedNames']['AWS::StackName']
    workitem[participant_name][:physical_id] =  stackname + '-' + 'WaitCondition'
  end

  def self.create_handle(handle_name, handle)
      @@handles[handle_name] = handle
  end

  def set_handle(handle_name)
      reply(workitem) if @@handles[handle_name]
  end

  def self.get_conditions()
      @@conditions
  end
end

class Output < Ruote::Participant
  include Logging
  include Intrinsic

  def on_workitem
    #p workitem.fields.keys
    logger.debug "Entering #{workitem.participant_name} "
    outputs = workitem.fields['Outputs']
    logger.debug "In StackMate::Output.on_workitem #{outputs.inspect}"
    outputs.each do |key, val|
      v = val['Value']
      constructed_value = intrinsic(v, workitem)
      val['Value'] = constructed_value
      logger.debug "Output: key = #{key}, value = #{constructed_value} descr = #{val['Description']}"
    end

    logger.debug "Output Done"
    reply
  end
end

class NoOpResource < Ruote::Participant
  include Logging

  def on_workitem
    logger.debug "Entering #{participant_name} wfid=#{workitem.fei.wfid} fei=#{workitem.fei.to_h}"
    workitem[participant_name] = {}
    stackname = workitem.fields['ResolvedNames']['AWS::StackName']
    logger.debug "physical id is  #{stackname}-#{participant_name} "
    workitem[participant_name][:physical_id] =  stackname + '-' + participant_name
    typ = workitem['Resources'][participant_name]['Type']
    if AWS_FAKE_ATTRIB_VALUES[typ]
      AWS_FAKE_ATTRIB_VALUES[typ].each do |k,v| 
        workitem[participant_name][k] = v
      end
    end
    reply
  end
end

end
