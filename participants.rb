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

