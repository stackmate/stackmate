require 'stackmate/logging'

module StackMate


class WaitConditionHandle < Ruote::Participant
  include Logging

  def on_workitem
    myname = workitem.participant_name
    logger.debug "Entering #{workitem.participant_name} "
    presigned_url = 'http://localhost:4567/waitcondition/' + workitem.fei.wfid + '/' + myname
    workitem.fields['ResolvedNames'][myname] = presigned_url
    logger.info "Your pre-signed URL is: #{presigned_url} "
    logger.info "Try: \ncurl -X PUT --data 'foo' #{presigned_url}"
    WaitCondition.create_handle(myname, presigned_url)

    reply
  end
end

class WaitCondition < Ruote::Participant
  include Logging
  @@handles = {}
  @@conditions = []
  def on_workitem
    logger.debug "Entering #{workitem.participant_name} "
    @@conditions << self
    @wi = workitem
  end

  def self.create_handle(handle_name, handle)
      @@handles[handle_name] = handle
  end

  def set_handle(handle_name)
      reply(@wi) if @@handles[handle_name]
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

end
