require 'stackmate/logging'

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
  def on_workitem
    #p workitem.fields.keys
    logger.debug "Entering #{workitem.participant_name} "
    logger.debug "Done"
    reply
  end
end

class NoOpResource < Ruote::Participant
  include Logging

  def on_workitem
    logger.debug "Entering #{participant_name} "
    workitem[participant_name] = {}
    stackname = workitem.fields['ResolvedNames']['AWS::StackName']
    logger.debug "physical id is  #{stackname}-#{participant_name} "
    workitem[participant_name][:physical_id] =  stackname + '-' + participant_name
    reply
  end
end

end
