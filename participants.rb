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
    myname = workitem.participant_name
    resolved = workitem.fields['ResolvedNames']
    sleep(rand)
    args0 = workitem.fields['Resources'][workitem.participant_name]['Properties']
    security_group_names = []
    args0['SecurityGroups'].each do |sg| 
        sg_name = resolved[sg['Ref']]
        security_group_names << sg_name
    end
    keypair = nil
    if args0['KeyName']
        keypair = resolved[args0['KeyName']['Ref']]
    end
    args = { 'serviceofferingid' => '13954c5a-60f5-4ec8-9858-f45b12f4b846',
             'templateid' => '7fc2c704-a950-11e2-8b38-0b06fbda5106',
             'zoneid' => default_zone_id,
             'securitygroupnames' => security_group_names.join(','),
             'userdata' => 'abc',
             'displayname' => myname
    }
    if keypair
        args['keypair'] = keypair
    end

    @client.deployVirtualMachine(args)
    reply
  end

  def default_zone_id
      '1'
  end

  def default_zone_id
      '1'
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
    myname = workitem.participant_name
    resolved = workitem.fields['ResolvedNames']
    sleep(rand)
    props = workitem.fields['Resources'][myname]['Properties']
    name = workitem.fields['StackName'] + '-' + workitem.participant_name;
    resolved[myname] = name
    args = { 'name' => name,
             'description' => props['GroupDescription']
    }
    @client.createSecurityGroup(args)
    props['SecurityGroupIngress'].each do |rule|
        cidrIp = rule['CidrIp']
        if cidrIp.kind_of?  Hash
            #TODO: some sort of validation
            cidrIpName = cidrIp['Ref']
            cidrIp = resolved[cidrIpName]
        end
        args = { 'securitygroupname' => name,
            'startport' => rule['FromPort'],
            'endport' => rule['ToPort'],
            'protocol' => rule['IpProtocol'],
            'cidrlist' => cidrIp
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

