require 'json'
require 'cloudstack_ruby_client'
require 'yaml'
require 'stackmate/logging'
require 'stackmate/intrinsic_functions'

module StackMate

class CloudStackApiException < StandardError
    def initialize(msg)
        super(msg)
    end
end

class CloudStackResource < Ruote::Participant
  include Logging

  attr_reader :name

  def initialize(opts)
      @opts = opts
      @url = opts['URL'] || ENV['URL'] or raise ArgumentError.new("CloudStackResources: no URL supplied for CloudStack API")
      @apikey = opts['APIKEY'] || ENV['APIKEY'] or raise ArgumentError.new("CloudStackResources: no api key supplied for CloudStack API")
      @seckey = opts['SECKEY'] || ENV['SECKEY'] or raise ArgumentError.new("CloudStackResources: no secret key supplied for CloudStack API")
      @client = CloudstackRubyClient::Client.new(@url, @apikey, @seckey, false)
  end

  def on_workitem
    p workitem.participant_name
    reply
  end

  protected
    
    def make_request(cmd, args)
        begin
          logger.debug "Going to make request #{cmd} to CloudStack server for resource #{@name}"
          resp = @client.send(cmd, args)
          jobid = resp['jobid'] if resp
          resp = api_poll(jobid, 3, 3) if jobid
          return resp
        rescue => e
          logger.error("Failed to make request #{cmd} to CloudStack server while creating resource #{@name}")
          logger.error e.message + "\n " + e.backtrace.join("\n ")
          raise e
        rescue SystemExit
          logger.error "Rescued a SystemExit exception"
          raise CloudStackApiException, "Did not get 200 OK while making api call #{cmd}"
        end
    end
  
    def api_poll (jobid, num, period)
      i = 0 
      loop do 
        break if i > num
        resp = @client.queryAsyncJobResult({'jobid' => jobid})
        if resp
            return resp['jobresult'] if resp['jobstatus'] == 1
            return {'jobresult' => {}} if resp['jobstatus'] == 2
        end
        sleep(period)
        i += 1 
      end
    return {}
    end

end

class CloudStackInstance < CloudStackResource
  def initialize(opts)
    super (opts)
    @localized = {}
    load_local_mappings()
  end

  def create
    workitem[participant_name] = {}
    myname = participant_name
    @name = myname
    resolved = workitem['ResolvedNames']
    props = workitem['Resources'][workitem.participant_name]['Properties']
    security_group_names = []
    props['SecurityGroups'].each do |sg| 
        sg_name = resolved[sg['Ref']]
        security_group_names << sg_name
    end
    keypair = resolved[props['KeyName']['Ref']] if props['KeyName']
    userdata = nil
    if props['UserData']
        userdata = user_data(props['UserData'], resolved)
    end
    templateid = image_id(props['ImageId'], resolved, workitem['Mappings'])
    templateid = @localized['templates'][templateid] if @localized['templates']
    svc_offer = resolved[props['InstanceType']['Ref']]  #TODO fragile
    svc_offer = @localized['service_offerings'][svc_offer] if @localized['service_offerings']
    args = { 'serviceofferingid' => svc_offer,
             'templateid' => templateid,
             'zoneid' => default_zone_id,
             'securitygroupnames' => security_group_names.join(','),
             'displayname' => myname,
             #'name' => myname
    }
    args['keypair'] = keypair if keypair
    args['userdata'] = userdata  if userdata
    resultobj = make_request('deployVirtualMachine', args)
    logger.debug("Created resource #{myname}")

    logger.debug("result = #{resultobj.inspect}")
    workitem[participant_name][:physical_id] =  resultobj['virtualmachine']['id']
    workitem[participant_name][:AvailabilityZone] =  resultobj['virtualmachine']['zoneid']
    ipaddress = resultobj['virtualmachine']['nic'][0]['ipaddress']
    workitem[participant_name][:PrivateDnsName] =  ipaddress
    workitem[participant_name][:PublicDnsName] =  ipaddress
    workitem[participant_name][:PrivateIp] = ipaddress
    workitem[participant_name][:PublicIp] =  ipaddress
  end

  def on_workitem
    create
    reply
  end

  def user_data(datum, resolved)
      #TODO make this more general purpose
      actual = datum['Fn::Base64']['Fn::Join']
      delim = actual[0]
      data = actual[1].map { |d|
          d.kind_of?(Hash) ? resolved[d['Ref']]: d
      }
      Base64.urlsafe_encode64(data.join(delim))
  end

  def load_local_mappings()
      begin
          @localized = YAML.load_file('local.yml')
      rescue
          logger.warning "Warning: Failed to load localized mappings from local.yaml\n"
      end
  end

  def default_zone_id
      if @localized['zoneid'] 
          @localized['zoneid']
      else
          '1'
      end
  end

  def image_id(imgstring, resolved, mappings)
      #TODO convoluted logic only handles the cases
      #ImageId : {"Ref" : "FooBar"}
      #ImageId :  { "Fn::FindInMap" : [ "Map1", { "Ref" : "OuterKey" },
      #                          { "Fn::FindInMap" : [ "Map2", { "Ref" : "InnerKey" }, "InnerVal" ] } ] },
      #ImageId :  { "Fn::FindInMap" : [ "Map1", { "Ref" : "Key" },  "Value" ] } ] },
      if imgstring['Ref']
          return resolved[imgstring['Ref']]
      else 
          if imgstring['Fn::FindInMap']
              key = resolved[imgstring['Fn::FindInMap'][1]['Ref']]
              #print "Key = ", key, "\n"
              if imgstring['Fn::FindInMap'][2]['Ref']
                  val = resolved[imgstring['Fn::FindInMap'][2]['Ref']]
                  #print "Val [Ref] = ", val, "\n"
              else
                  if imgstring['Fn::FindInMap'][2]['Fn::FindInMap']
                      val = image_id(imgstring['Fn::FindInMap'][2], resolved, mappings)
                      #print "Val [FindInMap] = ", val, "\n"
                  else
                      val = imgstring['Fn::FindInMap'][2]
                  end
              end
          end
          return mappings[imgstring['Fn::FindInMap'][0]][key][val]
      end
  end

end


class CloudStackSecurityGroup < CloudStackResource
  def create
    myname = workitem.participant_name
    workitem[participant_name] = {}
    logger.debug("Going to create resource #{myname}")
    @name = myname
    p myname
    resolved = workitem['ResolvedNames']
    props = workitem['Resources'][myname]['Properties']
    name = workitem['StackName'] + '-' + workitem.participant_name;
    resolved[myname] = name
    args = { 'name' => name,
             'description' => props['GroupDescription']
    }
    sg_resp = make_request('createSecurityGroup', args)
    logger.debug("created resource #{myname}")
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
        make_request('authorizeSecurityGroupIngress', args)
    end
    workitem[participant_name][:physical_id] =  sg_resp['securitygroup']['id']
  end

  def on_workitem
    create
    reply
  end
end


class CloudStackOutput < Ruote::Participant
  include Logging
  include Intrinsic

  def on_workitem
    logger.debug "Entering #{participant_name} "
    outputs = workitem['Outputs']
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

end
