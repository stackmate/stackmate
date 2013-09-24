require 'json'
require 'cloudstack_ruby_client'
require 'yaml'
require 'stackmate/logging'
require 'stackmate/intrinsic_functions'
require 'stackmate/resolver'

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

    workitem['IdMap'][resultobj['virtualmachine']['id']] = participant_name
  end

  def delete
    logger.info "In delete #{participant_name}"
    return nil if !workitem[participant_name]
    physical_id = workitem[participant_name]['physical_id']
    if physical_id
      args = {'id' => physical_id}
      del_resp = make_request('destroyVirtualMachine', args)
    end
  end

  def on_workitem
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
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

class CloudStackVPCNoOp < CloudStackResource
  include Logging
  include Intrinsic
  include Resolver

  def initialize(opts)
    super(opts)
    localized = {}
    load_local_mappings{}
  end
    
  
  def create
    #vpc_name = workitem.participant_name
    workitem[@vpc_name]={}
    logger.debug "Creating VPC #{@vpc_name} NoOp "
    #p workitem
    resolved = workitem['ResolvedNames']
    vpc_props = workitem['Resources'][@vpc_name]['Properties']
    vpc_name_cs = workitem['StackName'] + '-' + @vpc_name
    resolved[@vpc_name] = vpc_name_cs

    args = { 'name' => vpc_name_cs,
             'zoneid' => default_zone_id,
             'displaytext' => vpc_name_cs,
           }
    #Traverse tags to change displaytext
    args['displaytext'] = get_named_tag('Name',vpc_props,workitem,vpc_name_cs)
    args['cidr'] = get_resolved(vpc_props['CidrBlock'],workitem) #Call resolver on this
    instance_tenancy = vpc_props['InstanceTenancy']
    vpc_offering_id = get_vpc_offering_id(instance_tenancy) #Or take from parameters. TODO decide
    args['vpcofferingid'] = vpc_offering_id
    workitem[@vpc_name]['args'] = args
  end 

  def delete
    logger.debug "Deleting VPC #{@vpc_name} NoOp"
    args = {'id' => workitem[@vpc_name]['physical_id']
            }
    #result_obj = make_request("deleteVPC",args)
  end

  def on_workitem
    @vpc_name = workitem.participant_name
    @name = @vpc_name
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
    reply
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
  
  def get_vpc_offering_id(tenancy)
      if @localized['vpc_offering_id']
          @localized['vpc_offering_id']
      else
          '1'
      end
  end
end


class CloudStackVPC < CloudStackResource

  include Logging
  include Intrinsic
  include Resolver

  def create
    resolved = workitem['ResolvedNames']
    attachment_props = workitem['Resources'][@attachment_name]['Properties']
    #Below two lines are valid and not fragile since the template specification says it has to be reference
    vpc_name = get_resolved(attachment_props['VpcId']['Ref'],workitem)
    dhcp_options = get_resolved(attachment_props['DhcpOptionsId']['Ref'],workitem)
    logger.debug("Creating VPC #{vpc_name} using options #{dhcp_options} in attachment #{@attachment_name}")
    args = workitem[vpc_name]['args']
    args['networkdomain'] = workitem[dhcp_options]['domain_name']

    logger.info("Creating VPC with following arguments ")
    p args
    result_obj = make_request('createVPC', args)
    vpc_obj = result_obj['vpc']
    workitem[vpc_name][:physical_id] = vpc_obj['id']
    workitem[vpc_name][:account] = vpc_obj['account']
    workitem[vpc_name][:domainid] = vpc_obj['domainid']
    workitem[vpc_name][:name] = vpc_name

    #then get public gateway details by making list API request
    args = {'vpcid' => workitem[vpc_name][:physical_id]
            }
    result_obj = make_request('listRouters',args)
    router_obj = result_obj['router'][0]
    workitem[vpc_name]['public_router'] = {}
    workitem[vpc_name]['public_router'][:routerid] = router_obj['id']
    workitem[vpc_name]['public_router'][:publicip] = router_obj['publicip']
    workitem[vpc_name]['public_router'][:publicnetmask] = router_obj['publicnetmask']
    workitem[vpc_name]['public_router'][:gateway] = router_obj['gateway']
    workitem['IdMap'][vpc_obj['id']] = vpc_name
  end

  def delete
    attachment_props = workitem['Resources'][@attachment_name]['Properties']
    vpc_name = get_resolved(attachment_props['Properties']['VpcId'],workitem)
    logger.debug("Deleting VPC #{vpc_name} associated with #{@attachment_name}")
    args = {'id' => workitem[vpc_name]['physical_id']
            }
    #make_request('deleteVPC',args,vpc_name)
  end

  def on_workitem
    @attachment_name = workitem.participant_name
    @name = @attachment_name
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
    reply
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
    workitem['IdMap'][sg_resp['securitygroup']['id']] = participant_name
  end

  def delete
    logger.info "In delete #{participant_name}"
    return nil if !workitem[participant_name]
    logger.info "In delete #{participant_name} #{workitem[participant_name].inspect}"
    physical_id = workitem[participant_name]['physical_id']
    if physical_id
      args = {'id' => physical_id}
      del_resp = make_request('deleteSecurityGroup', args)
    end
  end

  def on_workitem
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
    reply
  end
end

class CloudStackDHCPNoOp < Ruote::Participant
  include Logging
  include Resolver
  include Intrinsic

  def create
    logger.debug("Creating DHCPOptions for #{@name}")
    
    workitem[@name] = {}
    resolved = workitem['ResolvedNames']
    dhcp_name_cs = workitem['StackName'] + '-' + @name
    #resolved[name] = dhcp_name_cs
    props = workitem['Resources'][@name]['Properties']
    workitem[@name][:domain_name] = get_resolved(props['DomainName'],workitem)
    workitem[@name][:tagged_name] = get_named_tag('Name',props,workitem,dhcp_name_cs)
  end

  def delete
    logger.debug("Deleting DHCPOptions for #{@name}")
  end
  
  def on_workitem
    @name = workitem.participant_name
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
    reply
  end
end

class CloudStackACL < CloudStackResource
  include Logging
  include Intrinsic
  include Resolver

  def create
    workitem[@acl_name]={}
    logger.debug "Creating VPC ACL List resource #{acl_name} "
    resolved = workitem['ResolvedNames']
    acl_props = workitem['Resources'][@acl_name]['Properties']
    acl_name_cs = workitem['StackName'] + '-' + @acl_name
    resolved[@acl_name] = acl_name_cs
    vpcid = get_vpc_ref(acl_props,workitem)['physical_id']
    description = get_named_tag('Name',acl_props,workitem,acl_name)
    args = {'name' => acl_name_cs,
            'vpcid' => vpcid,
            'description' => description
            }
    # acl_props.keys.each do |property|
    #   args[property] = acl_props[property]
    # end
    
    result_obj = make_request('createNetworkACLList',args)
    acl_obj = result_obj['acllist']
    workitem[@acl_name][:physical_id] = acl_obj['id']
    workitem[@acl_name][:name] = acl_obj['name']
    workitem[@acl_name][:vpcid] = acl_obj['vpcid']

    workitem['IdMap'][acl_obj['id']] = @acl_name
  end

  def delete
    logger.debug "Deleting VPC ACL List resource #{acl_name} "
  end

  def on_workitem
    @acl_name = workitem.participant_name
    @name = @acl_name
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
    reply
  end

  def get_vpc_ref(props,workitem)
    workitem[props['VpcId']['Ref']] #Return resolved not needed. Actually may be needed
  end

end

class CloudStackGatewayNoOp < CloudStackResource
  include Logging
  include Intrinsic
  include Resolver

  def create
    logger.debug("Creating resource Gateway(NoOp) #{@gateway_name}")
    
    workitem[@gateway_name] = {}
    resolved = workitem['ResolvedNames']
    gateway_props = workitem['Resources'][@gateway_name]['Properties']
    gateway_name_cs =  workitem['StackName'] + '-' + @gateway_name
    resolved[@gateway_name] = gateway_name_cs
    #Only resolve names
    workitem[@gateway_name][:name] = get_named_tag('Name',gateway_props,workitem,gateway_name_cs)
    #p get_named_tag('Name',gateway_props,workitem,gateway_name_cs)

  end

  def delete
    logger.debug("Deleting resource Gateway(NoOp) #{@gateway_name}")
  end

  def on_workitem
    @gateway_name = workitem.participant_name
    @name = @gateway_name
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
    reply
  end
end

#This is same as above
class CloudStackInetGatewayNoOp < Ruote::Participant
  include Logging
  include Intrinsic
  include Resolver
  def create
    logger.debug("Creating resource InetGateway(NoOp) #{@gateway_name}")
    workitem[@gateway_name] = {}
    resolved = workitem['ResolvedNames']
    gateway_props = workitem['Resources'][@gateway_name]['Properties']
    gateway_name_cs =  workitem['StackName'] + '-' + @gateway_name
    resolved[@gateway_name] = gateway_name_cs
    #Only resolve names
    workitem[@gateway_name][:name] = get_named_tag('Name',gateway_props,workitem,gateway_name_cs)
  end

  def delete
    logger.debug("Deleting resource InetGateway(NoOp) #{@gateway_name}")
  end
  def on_workitem
    @gateway_name = workitem.participant_name
    @name = @gateway_name
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
    reply
  end
end

class CloudStackVPNGateway < CloudStackResource
  include Logging
  include Intrinsic
  include Resolver

  def create
    logger.debug("Creating actual gateway with attachment #{@gateway_attachment}")
    workitem[@gateway_attachment] = {}
    resolved = workitem['ResolvedNames']
    gateway_props = workitem['Resources'][@gateway_attachment]['Properties']
    gateway_cs =  workitem['StackName'] + '-' + @gateway_attachment
    p get_vpc_ref(gateway_props,workitem)
    vpc_id = get_vpc_ref(gateway_props,workitem)['physical_id']
    args={
          'vpcid' => vpc_id
          }

    #make request
    logger.info("Making request for VPN Gateway to CloudStack with parameters ")
    p args
  end

  def delete
    logger.debug("Deleting actual gateway with attachment #{@gateway_attachment}")
  end
  def on_workitem
    @gateway_attachment = workitem.participant_name
    @name = @gateway_attachment
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
    reply
  end

  def get_vpc_ref(props,workitem)
    workitem[props['VpcId']['Ref']] #Return resolved not needed
  end

  def get_gateway_ref(props,workitem)
    workitem[props['InternetGatewayId']['Ref']]
  end
end

class CloudStackVPCGatewayAttachmentNoOp < Ruote::Participant
  include Logging
  include Intrinsic
  include Resolver

  def create
    logger.debug("Linking gateway with attachment #{@gateway_attachment}")
    #workitem[@gateway_attachment] = {}
    resolved = workitem['ResolvedNames']
    gateway_props = workitem['Resources'][@gateway_attachment]['Properties']
    gateway_cs =  workitem['StackName'] + '-' + @gateway_attachment
    vpc = get_vpc_ref(gateway_props,workitem)
    gateway = get_gateway_ref(gateway_props,workitem)
    workitem[gateway][:physical_id] = vpc['public_router']['id']
    workitem[gateway][:ip] = vpc['public_router']['publicip']
    workitem[gateway][:netmask] = vpc['public_router']['publicnetmask']
    workitem[gateway][:gateway] = vpc['public_router']['gateway']
    logger.info("Attaching public internet gateway info for #{@gateway_attachment} ")
    #workitem['IdMap'][vpc['public_router']['id']] = @gateway_attachment
    p workitem[gateway]
  end

  def delete
    logger.debug("Deleting gateway with attachment #{@gateway_attachment}")
  end

  def on_workitem
    @gateway_attachment = workitem.participant_name
    @name = @gateway_attachment
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
    reply
  end

  def get_vpc_ref(props,workitem)
    workitem[props['VpcId']['Ref']] #Return resolved not needed. Actually may be needed
  end

  def get_gateway_ref(props,workitem)
    workitem[props['InternetGatewayId']['Ref']]
  end
end

class CloudStackVPCNetwork < CloudStackResource
  include Logging
  include Resolver
  include Intrinsic
  require 'netaddr'


  def create
    logger.debug("Creating resource Network for VPC #{@network_name}")
    workitem[@network_name] = {}
    resolved = workitem['ResolvedNames']
    network_name_cs = workitem['StackName'] + '-' + @network_name
    resolved[@network_name] = network_name_cs
    network_props = workitem['Resources'][@network_name]['Properties']
    displaytext = get_named_tag('Name',network_props,workitem,network_name_cs)
    #TODO handle other tags
    vpcid = get_vpc_ref(network_props,workitem)['physical_id']
    args = {'vpcid' => vpcid,
            'name' => network_name_cs,
            'displaytext' => displaytext,
            'zoneid' => default_zone_id }
    cidr = get_resolved(network_props['CidrBlock'],workitem)
    cidr_obj = NetAddr::CIDR.create(cidr)
    #gateway_ip = 
    #netmask = get_netmask(cidr_obj)
    args['netmask'] = get_netmask(cidr_obj)
    args['gateway'] = get_gateway_ip(cidr_obj)
    result_obj = make_request('createNetwork',args)
    network_obj = result_obj['network']
    workitem[@network_name][:physical_id] = network_obj['id']
    workitem[@network_name][:name] = network_obj['name']
    workitem[@network_name][:cidr] = network_obj['cidr']
    workitem[@network_name][:gatewayip] = network_obj['gateway']
    workitem[@network_name][:netmask] = network_obj['netmask']
    workitem[@network_name][:vpcid] = network_obj['vpcid']
    workitem[@network_name][:networkdomain] = network_obj['networkdomain']
    workitem[@network_name][:networkofferingid] = network_obj['networkofferingid']

    workitem['IdMap'][network_obj['id']] = @network_name

  end

  def delete
    logger.debug("Deleting resource Network for VPC #{@network_name}")
  end

  def on_workitem
    @network_name = workitem.participant_name
    @name = @network_name
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
    reply
  end

  def get_netmask(cidr)
    cidr.wildcard_mask
  end

  def get_gateway_ip(cidr)
    cidr.nth(1)
  end

  def get_vpc_ref(props,workitem)
    workitem[props['VpcId']['Ref']] #Return resolved not needed
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

  def get_network_offering_id(vpcid)
      if @localized['network_offering_id']
          @localized['network_offering_id']
      else
          '11'
      end
  end
end

class CloudStackVolume < CloudStackResource
  include Logging
  include Resolver
  include Intrinsic

  def create
    logger.debug("Creating new volume #{@volume_name}")
    workitem[@volume_name] = {}
    resolved = workitem['ResolvedNames']
    volume_name_cs =  workitem['StackName'] + '-' + @volume_name
    resolved[@volume_name] = volume_name_cs
    volume_props = workitem['Resources'][@volume_name]['Properties']
    args = {'name' => volume_name_cs,
            }
    args['snapshotid'] = volume_props['SnapshotId'] if !volume_props['SnapshotId'].nil?
    args['size'] = volume_props['Size'] if !volume_props['Size'].nil?
    args['diskofferingid'] = get_diskoffering_id(volume_props,workitem) if !volume_props['Size'].nil? 
    args['zoneid'] = default_zone_id if !volume_props['Size'].nil? 
    #TODO handle Iops, volumetype if possible
    result_obj = make_request('createVolume',args)
    volume_obj = result_obj['volume']
    workitem[@volume_name][:physical_id] = volume_obj['id']
    workitem[@volume_name][:size] = volume_obj['size']

    workitem['IdMap'][volume_obj['id']] = @volume_name
  end

  def delete
    logger.debug("Deleting volume #{@volume_name}")
    #first detach
    #then delete

  end

  def on_workitem
    @volume_name = workitem.participant_name
    @name = @volume_name
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
    reply
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

  def get_diskoffering_id(volume_props,workitem)
    if @localized['diskofferingid']
      @localized['diskofferingid']
    else
      '6' #custom diskofferingid so size is used
    end
  end
end

class CloudStackVolumeAttachment < CloudStackResource
  include Logging
  include Resolver
  include Intrinsic

  def create
    logger.debug("Attaching volume to instance using attachment #{@volume_attachment}")
    workitem[@volume_attachment] = {}
    volume_props = workitem['Resources'][@volume_attachment]['Properties']
    volume_id = get_volume_ref(volume_props,workitem)
    instance_id = get_instance_ref(volume_props,workitem)
    device_id = resolve_to_deviceid(get_resolved(volume_props['Device']))
    args = {'id' => volume_id,
            'virtualmachineid' => instance_id,
            'deviceid' => device_id
            }
    result_obj = make_request('attachVolume',args)
    volume_obj = result_obj['volume']
    workitem[@volume_attachment][:physical_id] = volume_obj['id']
    workitem[@volume_attachment][:instanceid] = volume_obj['virtualmachineid']
    workitem[@volume_attachment][:deviceid] = volume_obj['deviceid']
  end

  def delete
    logger.debug("Disconnecting attachment #{@volume_attachment}")
  end

  def on_workitem
    @volume_attachment = workitem.participant_name
    @name = @volume_attachment
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
    reply
  end

  def get_volume_ref(volume_props,workitem)
    get_resolved(volume_props['VolumeId'],workitem)
  end

  def get_instance_ref(volume_props,workitem)
    get_resolved(volume_props['InstanceId'],workitem)
  end
end

class CloudStackOutput < Ruote::Participant
  include Logging
  include Intrinsic
  def on_workitem
    stackname = workitem['StackName']
    logger.debug "Entering Outputs for #{stackname} "
    outputs = workitem['Outputs']
    outputs.each do |key, val|
      v = val['Value']
      constructed_value = intrinsic(v, workitem)
      val['Value'] = constructed_value
      logger.debug "Output: key = #{key}, value = #{constructed_value} descr = #{val['Description']}"
    end
    logger.debug "Output Done"
    if("True".eql?(workitem['ResolvedNames']['isnested']))
      stackrand = workitem['ResolvedNames']['stackrand']
      File.open("/tmp/#{stackname}.workitem.#{stackrand}",'w') { |file| file.write(YAML.dump(workitem)) } #TODO better file handling
    end
    reply
  end
end

end
