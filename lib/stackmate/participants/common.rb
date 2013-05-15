require 'json'
require 'stackmate/logging'

module StackMate


class WaitConditionHandle < Ruote::Participant
  def on_workitem
    myname = workitem.participant_name
    p myname
    presigned_url = 'http://localhost:4567/waitcondition/' + workitem.fei.wfid + '/' + myname
    workitem.fields['ResolvedNames'][myname] = presigned_url
    print "Your pre-signed URL is: ", presigned_url, "\n"
    print "Try: ", "\n", "curl -X PUT --data 'foo' ", presigned_url,  "\n"
    WaitCondition.create_handle(myname, presigned_url)

    reply
  end
end

class WaitCondition < Ruote::Participant
  @@handles = {}
  @@conditions = []
  def on_workitem
    p workitem.participant_name
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
  def on_workitem
    #p workitem.fields.keys
    p workitem.participant_name
    p "Done"
    reply
  end
end

end
