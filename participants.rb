require 'rufus-json/automatic'
require 'ruote'
require 'ruote/storage/fs_storage'
require 'json'
require 'cloudstack_ruby_client'
require 'set'
require 'tsort'
require 'SecureRandom'
require 'optparse'

class CloudStackResource < Ruote::Participant
  def initialize()
      @url = ENV['URL']
      @apikey = ENV['APIKEY']
      @seckey = ENV['SECKEY']
      @client = CloudstackRubyClient::Client.new(@url, @apikey, @seckey, false)
  end
  def on_workitem
    p workitem.participant_name
    reply
  end
end

class Instance < CloudStackResource
  def on_workitem
    p workitem.participant_name
    sleep(rand)
    args0 = workitem.fields['Resources'][workitem.participant_name]['Properties']
    #p args0
    args = { 'serviceofferingid' => '13954c5a-60f5-4ec8-9858-f45b12f4b846',
             'templateid' => '7fc2c704-a950-11e2-8b38-0b06fbda5106',
             'zoneid' => '1',
             'securitygroupnames' => 'WebServerSecurityGroup',
             'userdata' => 'abc',
             'displayname' => workitem.participant_name,
             'keypair' => 'mykeypair'
    }
    @client.deployVirtualMachine(args)
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

class SecurityGroup < CloudStackResource
  def on_workitem
    p workitem.participant_name
    sleep(rand)
    props = workitem.fields['Resources'][workitem.participant_name]['Properties']
    name = workitem.fields['StackName'] + '-' + workitem.participant_name;
    #FIXME: workaround bug in cloudstack_ruby_client. 
    #Transform spaces in description into underscore
    args = { 'name' => name,
             'description' => props['GroupDescription'].tr(' ', '_')
    }
    @client.createSecurityGroup(args)
    props['SecurityGroupIngress'].each do |rule|
        args = { 'securitygroupname' => name,
            'startport' => rule['FromPort'],
            'endport' => rule['ToPort'],
            'protocol' => rule['IpProtocol'],
            'cidrlist' => rule['CidrIp']
        }
        #TODO handle usersecuritygrouplist
        @client.authorizeSecurityGroupIngress(args)
    end
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

