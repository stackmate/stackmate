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

    def make_sync_request(cmd,args)
        begin
          logger.debug "Going to make sync request #{cmd} to CloudStack server for resource #{@name}"
          resp = @client.send(cmd, args)
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

    def make_async_request(cmd, args)
        begin
          logger.debug "Going to make async request #{cmd} to CloudStack server for resource #{@name}"
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
            return {'error' => true} if resp['jobstatus'] == 2
        end
        sleep(period)
        i += 1 
      end
    return {}
    end

end

      class CloudStackCondition < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['threshold'] = get_threshold
          args['relationaloperator'] = get_relationaloperator
          args['counterid'] = get_counterid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['account'] = get_account if @props.has_key?('account')
        args['domainid'] = get_domainid if @props.has_key?('domainid')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createCondition',args)
        resource_obj = result_obj['Condition'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteCondition',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_threshold
        resolved_threshold = get_resolved(@props["threshold"],workitem)
        if resolved_threshold.nil?
          raise "Missing mandatory parameter threshold for resource #{@name}"
        end
        resolved_threshold
      end      
      

      def get_relationaloperator
        resolved_relationaloperator = get_resolved(@props["relationaloperator"],workitem)
        if resolved_relationaloperator.nil?
          raise "Missing mandatory parameter relationaloperator for resource #{@name}"
        end
        resolved_relationaloperator
      end      
      

      def get_counterid
        resolved_counterid = get_resolved(@props["counterid"],workitem)
        if resolved_counterid.nil?
          raise "Missing mandatory parameter counterid for resource #{@name}"
        end
        resolved_counterid
      end      
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      
end
    
   class CloudStackNicToVirtualMachine < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['virtualmachineid'] = get_virtualmachineid
          args['networkid'] = get_networkid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['ipaddress'] = get_ipaddress if @props.has_key?('ipaddress')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('addNicToVirtualMachine',args)
        resource_obj = result_obj['NicToVirtualMachine'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'virtualmachineid' => physical_id
                  }
            result_obj = make_async_request('removeNicToVirtualMachine',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_virtualmachineid
        resolved_virtualmachineid = get_resolved(@props["virtualmachineid"],workitem)
        if resolved_virtualmachineid.nil?
          raise "Missing mandatory parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end      
      

      def get_networkid
        resolved_networkid = get_resolved(@props["networkid"],workitem)
        if resolved_networkid.nil?
          raise "Missing mandatory parameter networkid for resource #{@name}"
        end
        resolved_networkid
      end      
      

      def get_ipaddress
        get_resolved(@props['ipaddress'],workitem)
      end
      
end
    
   class CloudStackVpnConnection < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['s2scustomergatewayid'] = get_s2scustomergatewayid
          args['s2svpngatewayid'] = get_s2svpngatewayid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createVpnConnection',args)
        resource_obj = result_obj['VpnConnection'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteVpnConnection',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_s2scustomergatewayid
        resolved_s2scustomergatewayid = get_resolved(@props["s2scustomergatewayid"],workitem)
        if resolved_s2scustomergatewayid.nil?
          raise "Missing mandatory parameter s2scustomergatewayid for resource #{@name}"
        end
        resolved_s2scustomergatewayid
      end      
      

      def get_s2svpngatewayid
        resolved_s2svpngatewayid = get_resolved(@props["s2svpngatewayid"],workitem)
        if resolved_s2svpngatewayid.nil?
          raise "Missing mandatory parameter s2svpngatewayid for resource #{@name}"
        end
        resolved_s2svpngatewayid
      end      
      
end
    
   class CloudStackSecurityGroupIngress < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['endport'] = get_endport if @props.has_key?('endport')
        args['securitygroupid'] = get_securitygroupid if @props.has_key?('securitygroupid')
        args['protocol'] = get_protocol if @props.has_key?('protocol')
        args['icmpcode'] = get_icmpcode if @props.has_key?('icmpcode')
        args['startport'] = get_startport if @props.has_key?('startport')
        args['projectid'] = get_projectid if @props.has_key?('projectid')
        args['usersecuritygrouplist'] = get_usersecuritygrouplist if @props.has_key?('usersecuritygrouplist')
        args['cidrlist'] = get_cidrlist if @props.has_key?('cidrlist')
        args['securitygroupname'] = get_securitygroupname if @props.has_key?('securitygroupname')
        args['icmptype'] = get_icmptype if @props.has_key?('icmptype')
        args['account'] = get_account if @props.has_key?('account')
        args['domainid'] = get_domainid if @props.has_key?('domainid')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('authorizeSecurityGroupIngress',args)
        resource_obj = result_obj['SecurityGroupIngress'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('revokeSecurityGroupIngress',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_endport
        get_resolved(@props['endport'],workitem)
      end
      

      def get_securitygroupid
        get_resolved(@props['securitygroupid'],workitem)
      end
      

      def get_protocol
        get_resolved(@props['protocol'],workitem)
      end
      

      def get_icmpcode
        get_resolved(@props['icmpcode'],workitem)
      end
      

      def get_startport
        get_resolved(@props['startport'],workitem)
      end
      

      def get_projectid
        get_resolved(@props['projectid'],workitem)
      end
      

      def get_usersecuritygrouplist
        get_resolved(@props['usersecuritygrouplist'],workitem)
      end
      

      def get_cidrlist
        get_resolved(@props['cidrlist'],workitem)
      end
      

      def get_securitygroupname
        get_resolved(@props['securitygroupname'],workitem)
      end
      

      def get_icmptype
        get_resolved(@props['icmptype'],workitem)
      end
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      
end
    
   class CloudStackTemplate < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['displaytext'] = get_displaytext
          args['ostypeid'] = get_ostypeid
          args['name'] = get_name
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['snapshotid'] = get_snapshotid if @props.has_key?('snapshotid')
        args['details'] = get_details if @props.has_key?('details')
        args['virtualmachineid'] = get_virtualmachineid if @props.has_key?('virtualmachineid')
        args['requireshvm'] = get_requireshvm if @props.has_key?('requireshvm')
        args['ispublic'] = get_ispublic if @props.has_key?('ispublic')
        args['volumeid'] = get_volumeid if @props.has_key?('volumeid')
        args['bits'] = get_bits if @props.has_key?('bits')
        args['url'] = get_url if @props.has_key?('url')
        args['templatetag'] = get_templatetag if @props.has_key?('templatetag')
        args['isdynamicallyscalable'] = get_isdynamicallyscalable if @props.has_key?('isdynamicallyscalable')
        args['passwordenabled'] = get_passwordenabled if @props.has_key?('passwordenabled')
        args['isfeatured'] = get_isfeatured if @props.has_key?('isfeatured')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createTemplate',args)
        resource_obj = result_obj['Template'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteTemplate',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_displaytext
        resolved_displaytext = get_resolved(@props["displaytext"],workitem)
        if resolved_displaytext.nil?
          raise "Missing mandatory parameter displaytext for resource #{@name}"
        end
        resolved_displaytext
      end      
      

      def get_ostypeid
        resolved_ostypeid = get_resolved(@props["ostypeid"],workitem)
        if resolved_ostypeid.nil?
          raise "Missing mandatory parameter ostypeid for resource #{@name}"
        end
        resolved_ostypeid
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_snapshotid
        get_resolved(@props['snapshotid'],workitem)
      end
      

      def get_details
        get_resolved(@props['details'],workitem)
      end
      

      def get_virtualmachineid
        get_resolved(@props['virtualmachineid'],workitem)
      end
      

      def get_requireshvm
        get_resolved(@props['requireshvm'],workitem)
      end
      

      def get_ispublic
        get_resolved(@props['ispublic'],workitem)
      end
      

      def get_volumeid
        get_resolved(@props['volumeid'],workitem)
      end
      

      def get_bits
        get_resolved(@props['bits'],workitem)
      end
      

      def get_url
        get_resolved(@props['url'],workitem)
      end
      

      def get_templatetag
        get_resolved(@props['templatetag'],workitem)
      end
      

      def get_isdynamicallyscalable
        get_resolved(@props['isdynamicallyscalable'],workitem)
      end
      

      def get_passwordenabled
        get_resolved(@props['passwordenabled'],workitem)
      end
      

      def get_isfeatured
        get_resolved(@props['isfeatured'],workitem)
      end
      
end
    
   class CloudStackNetwork < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['displaytext'] = get_displaytext
          args['networkofferingid'] = get_networkofferingid
          args['name'] = get_name
          args['zoneid'] = get_zoneid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['networkdomain'] = get_networkdomain if @props.has_key?('networkdomain')
        args['projectid'] = get_projectid if @props.has_key?('projectid')
        args['startip'] = get_startip if @props.has_key?('startip')
        args['domainid'] = get_domainid if @props.has_key?('domainid')
        args['displaynetwork'] = get_displaynetwork if @props.has_key?('displaynetwork')
        args['startipv6'] = get_startipv6 if @props.has_key?('startipv6')
        args['acltype'] = get_acltype if @props.has_key?('acltype')
        args['endip'] = get_endip if @props.has_key?('endip')
        args['account'] = get_account if @props.has_key?('account')
        args['gateway'] = get_gateway if @props.has_key?('gateway')
        args['vlan'] = get_vlan if @props.has_key?('vlan')
        args['endipv6'] = get_endipv6 if @props.has_key?('endipv6')
        args['ip6cidr'] = get_ip6cidr if @props.has_key?('ip6cidr')
        args['aclid'] = get_aclid if @props.has_key?('aclid')
        args['isolatedpvlan'] = get_isolatedpvlan if @props.has_key?('isolatedpvlan')
        args['ip6gateway'] = get_ip6gateway if @props.has_key?('ip6gateway')
        args['netmask'] = get_netmask if @props.has_key?('netmask')
        args['subdomainaccess'] = get_subdomainaccess if @props.has_key?('subdomainaccess')
        args['vpcid'] = get_vpcid if @props.has_key?('vpcid')
        args['physicalnetworkid'] = get_physicalnetworkid if @props.has_key?('physicalnetworkid')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_sync_request('createNetwork',args)
        resource_obj = result_obj['Network'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteNetwork',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_displaytext
        resolved_displaytext = get_resolved(@props["displaytext"],workitem)
        if resolved_displaytext.nil?
          raise "Missing mandatory parameter displaytext for resource #{@name}"
        end
        resolved_displaytext
      end      
      

      def get_networkofferingid
        resolved_networkofferingid = get_resolved(@props["networkofferingid"],workitem)
        if resolved_networkofferingid.nil?
          raise "Missing mandatory parameter networkofferingid for resource #{@name}"
        end
        resolved_networkofferingid
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_zoneid
        resolved_zoneid = get_resolved(@props["zoneid"],workitem)
        if resolved_zoneid.nil?
          raise "Missing mandatory parameter zoneid for resource #{@name}"
        end
        resolved_zoneid
      end      
      

      def get_networkdomain
        get_resolved(@props['networkdomain'],workitem)
      end
      

      def get_projectid
        get_resolved(@props['projectid'],workitem)
      end
      

      def get_startip
        get_resolved(@props['startip'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      

      def get_displaynetwork
        get_resolved(@props['displaynetwork'],workitem)
      end
      

      def get_startipv6
        get_resolved(@props['startipv6'],workitem)
      end
      

      def get_acltype
        get_resolved(@props['acltype'],workitem)
      end
      

      def get_endip
        get_resolved(@props['endip'],workitem)
      end
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_gateway
        get_resolved(@props['gateway'],workitem)
      end
      

      def get_vlan
        get_resolved(@props['vlan'],workitem)
      end
      

      def get_endipv6
        get_resolved(@props['endipv6'],workitem)
      end
      

      def get_ip6cidr
        get_resolved(@props['ip6cidr'],workitem)
      end
      

      def get_aclid
        get_resolved(@props['aclid'],workitem)
      end
      

      def get_isolatedpvlan
        get_resolved(@props['isolatedpvlan'],workitem)
      end
      

      def get_ip6gateway
        get_resolved(@props['ip6gateway'],workitem)
      end
      

      def get_netmask
        get_resolved(@props['netmask'],workitem)
      end
      

      def get_subdomainaccess
        get_resolved(@props['subdomainaccess'],workitem)
      end
      

      def get_vpcid
        get_resolved(@props['vpcid'],workitem)
      end
      

      def get_physicalnetworkid
        get_resolved(@props['physicalnetworkid'],workitem)
      end
      
end
    
   class CloudStackVolumeOps < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['id'] = get_id
          args['virtualmachineid'] = get_virtualmachineid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['deviceid'] = get_deviceid if @props.has_key?('deviceid')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('attachVolume',args)
        resource_obj = result_obj['Volume'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('detachVolume',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_id
        resolved_id = get_resolved(@props["id"],workitem)
        if resolved_id.nil?
          raise "Missing mandatory parameter id for resource #{@name}"
        end
        resolved_id
      end      
      

      def get_virtualmachineid
        resolved_virtualmachineid = get_resolved(@props["virtualmachineid"],workitem)
        if resolved_virtualmachineid.nil?
          raise "Missing mandatory parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end      
      

      def get_deviceid
        get_resolved(@props['deviceid'],workitem)
      end
      
end
    
   class CloudStackAffinityGroup < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['name'] = get_name
          args['type'] = get_type
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['domainid'] = get_domainid if @props.has_key?('domainid')
        args['account'] = get_account if @props.has_key?('account')
        args['description'] = get_description if @props.has_key?('description')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createAffinityGroup',args)
        resource_obj = result_obj['AffinityGroup'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteAffinityGroup',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_type
        resolved_type = get_resolved(@props["type"],workitem)
        if resolved_type.nil?
          raise "Missing mandatory parameter type for resource #{@name}"
        end
        resolved_type
      end      
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_description
        get_resolved(@props['description'],workitem)
      end
      
end
    
   class CloudStackAutoScaleVmProfile < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['zoneid'] = get_zoneid
          args['serviceofferingid'] = get_serviceofferingid
          args['templateid'] = get_templateid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['otherdeployparams'] = get_otherdeployparams if @props.has_key?('otherdeployparams')
        args['destroyvmgraceperiod'] = get_destroyvmgraceperiod if @props.has_key?('destroyvmgraceperiod')
        args['autoscaleuserid'] = get_autoscaleuserid if @props.has_key?('autoscaleuserid')
        args['counterparam'] = get_counterparam if @props.has_key?('counterparam')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createAutoScaleVmProfile',args)
        resource_obj = result_obj['AutoScaleVmProfile'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteAutoScaleVmProfile',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_zoneid
        resolved_zoneid = get_resolved(@props["zoneid"],workitem)
        if resolved_zoneid.nil?
          raise "Missing mandatory parameter zoneid for resource #{@name}"
        end
        resolved_zoneid
      end      
      

      def get_serviceofferingid
        resolved_serviceofferingid = get_resolved(@props["serviceofferingid"],workitem)
        if resolved_serviceofferingid.nil?
          raise "Missing mandatory parameter serviceofferingid for resource #{@name}"
        end
        resolved_serviceofferingid
      end      
      

      def get_templateid
        resolved_templateid = get_resolved(@props["templateid"],workitem)
        if resolved_templateid.nil?
          raise "Missing mandatory parameter templateid for resource #{@name}"
        end
        resolved_templateid
      end      
      

      def get_otherdeployparams
        get_resolved(@props['otherdeployparams'],workitem)
      end
      

      def get_destroyvmgraceperiod
        get_resolved(@props['destroyvmgraceperiod'],workitem)
      end
      

      def get_autoscaleuserid
        get_resolved(@props['autoscaleuserid'],workitem)
      end
      

      def get_counterparam
        get_resolved(@props['counterparam'],workitem)
      end
      
end
    
   class CloudStackSecurityGroup < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['name'] = get_name
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['description'] = get_description if @props.has_key?('description')
        args['domainid'] = get_domainid if @props.has_key?('domainid')
        args['account'] = get_account if @props.has_key?('account')
        args['projectid'] = get_projectid if @props.has_key?('projectid')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_sync_request('createSecurityGroup',args)
        resource_obj = result_obj['SecurityGroup'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_sync_request('deleteSecurityGroup',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_description
        get_resolved(@props['description'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_projectid
        get_resolved(@props['projectid'],workitem)
      end
      
end
    
   class CloudStackSSHKeyPair < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['name'] = get_name
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['account'] = get_account if @props.has_key?('account')
        args['domainid'] = get_domainid if @props.has_key?('domainid')
        args['projectid'] = get_projectid if @props.has_key?('projectid')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_sync_request('createSSHKeyPair',args)
        resource_obj = result_obj['SSHKeyPair'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'name' => physical_id
                  }
            result_obj = make_sync_request('deleteSSHKeyPair',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      

      def get_projectid
        get_resolved(@props['projectid'],workitem)
      end
      
end
    
   class CloudStackGlobalLoadBalancerRule < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['regionid'] = get_regionid
          args['gslbservicetype'] = get_gslbservicetype
          args['gslbdomainname'] = get_gslbdomainname
          args['name'] = get_name
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['account'] = get_account if @props.has_key?('account')
        args['domainid'] = get_domainid if @props.has_key?('domainid')
        args['gslbstickysessionmethodname'] = get_gslbstickysessionmethodname if @props.has_key?('gslbstickysessionmethodname')
        args['description'] = get_description if @props.has_key?('description')
        args['gslblbmethod'] = get_gslblbmethod if @props.has_key?('gslblbmethod')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createGlobalLoadBalancerRule',args)
        resource_obj = result_obj['GlobalLoadBalancerRule'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteGlobalLoadBalancerRule',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_regionid
        resolved_regionid = get_resolved(@props["regionid"],workitem)
        if resolved_regionid.nil?
          raise "Missing mandatory parameter regionid for resource #{@name}"
        end
        resolved_regionid
      end      
      

      def get_gslbservicetype
        resolved_gslbservicetype = get_resolved(@props["gslbservicetype"],workitem)
        if resolved_gslbservicetype.nil?
          raise "Missing mandatory parameter gslbservicetype for resource #{@name}"
        end
        resolved_gslbservicetype
      end      
      

      def get_gslbdomainname
        resolved_gslbdomainname = get_resolved(@props["gslbdomainname"],workitem)
        if resolved_gslbdomainname.nil?
          raise "Missing mandatory parameter gslbdomainname for resource #{@name}"
        end
        resolved_gslbdomainname
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      

      def get_gslbstickysessionmethodname
        get_resolved(@props['gslbstickysessionmethodname'],workitem)
      end
      

      def get_description
        get_resolved(@props['description'],workitem)
      end
      

      def get_gslblbmethod
        get_resolved(@props['gslblbmethod'],workitem)
      end
      
end
    
   class CloudStackStaticRoute < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['gatewayid'] = get_gatewayid
          args['cidr'] = get_cidr
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createStaticRoute',args)
        resource_obj = result_obj['StaticRoute'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteStaticRoute',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_gatewayid
        resolved_gatewayid = get_resolved(@props["gatewayid"],workitem)
        if resolved_gatewayid.nil?
          raise "Missing mandatory parameter gatewayid for resource #{@name}"
        end
        resolved_gatewayid
      end      
      

      def get_cidr
        resolved_cidr = get_resolved(@props["cidr"],workitem)
        if resolved_cidr.nil?
          raise "Missing mandatory parameter cidr for resource #{@name}"
        end
        resolved_cidr
      end      
      
end
    
   class CloudStackVMSnapshot < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['virtualmachineid'] = get_virtualmachineid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['description'] = get_description if @props.has_key?('description')
        args['snapshotmemory'] = get_snapshotmemory if @props.has_key?('snapshotmemory')
        args['name'] = get_name if @props.has_key?('name')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createVMSnapshot',args)
        resource_obj = result_obj['VMSnapshot'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'vmsnapshotid' => physical_id
                  }
            result_obj = make_async_request('deleteVMSnapshot',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_virtualmachineid
        resolved_virtualmachineid = get_resolved(@props["virtualmachineid"],workitem)
        if resolved_virtualmachineid.nil?
          raise "Missing mandatory parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end      
      

      def get_description
        get_resolved(@props['description'],workitem)
      end
      

      def get_snapshotmemory
        get_resolved(@props['snapshotmemory'],workitem)
      end
      

      def get_name
        get_resolved(@props['name'],workitem)
      end
      
end
    
   class CloudStackStaticNat < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['ipaddressid'] = get_ipaddressid
          args['virtualmachineid'] = get_virtualmachineid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['networkid'] = get_networkid if @props.has_key?('networkid')
        args['vmguestip'] = get_vmguestip if @props.has_key?('vmguestip')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_sync_request('enableStaticNat',args)
        resource_obj = result_obj['StaticNat'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'ipaddressid' => physical_id
                  }
            result_obj = make_async_request('disableStaticNat',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_ipaddressid
        resolved_ipaddressid = get_resolved(@props["ipaddressid"],workitem)
        if resolved_ipaddressid.nil?
          raise "Missing mandatory parameter ipaddressid for resource #{@name}"
        end
        resolved_ipaddressid
      end      
      

      def get_virtualmachineid
        resolved_virtualmachineid = get_resolved(@props["virtualmachineid"],workitem)
        if resolved_virtualmachineid.nil?
          raise "Missing mandatory parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end      
      

      def get_networkid
        get_resolved(@props['networkid'],workitem)
      end
      

      def get_vmguestip
        get_resolved(@props['vmguestip'],workitem)
      end
      
end
    
   class CloudStackIpForwardingRule < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['ipaddressid'] = get_ipaddressid
          args['protocol'] = get_protocol
          args['startport'] = get_startport
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['cidrlist'] = get_cidrlist if @props.has_key?('cidrlist')
        args['endport'] = get_endport if @props.has_key?('endport')
        args['openfirewall'] = get_openfirewall if @props.has_key?('openfirewall')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createIpForwardingRule',args)
        resource_obj = result_obj['IpForwardingRule'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteIpForwardingRule',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_ipaddressid
        resolved_ipaddressid = get_resolved(@props["ipaddressid"],workitem)
        if resolved_ipaddressid.nil?
          raise "Missing mandatory parameter ipaddressid for resource #{@name}"
        end
        resolved_ipaddressid
      end      
      

      def get_protocol
        resolved_protocol = get_resolved(@props["protocol"],workitem)
        if resolved_protocol.nil?
          raise "Missing mandatory parameter protocol for resource #{@name}"
        end
        resolved_protocol
      end      
      

      def get_startport
        resolved_startport = get_resolved(@props["startport"],workitem)
        if resolved_startport.nil?
          raise "Missing mandatory parameter startport for resource #{@name}"
        end
        resolved_startport
      end      
      

      def get_cidrlist
        get_resolved(@props['cidrlist'],workitem)
      end
      

      def get_endport
        get_resolved(@props['endport'],workitem)
      end
      

      def get_openfirewall
        get_resolved(@props['openfirewall'],workitem)
      end
      
end
    
   class CloudStackLoadBalancer < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['sourceport'] = get_sourceport
          args['scheme'] = get_scheme
          args['algorithm'] = get_algorithm
          args['networkid'] = get_networkid
          args['sourceipaddressnetworkid'] = get_sourceipaddressnetworkid
          args['name'] = get_name
          args['instanceport'] = get_instanceport
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['description'] = get_description if @props.has_key?('description')
        args['sourceipaddress'] = get_sourceipaddress if @props.has_key?('sourceipaddress')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createLoadBalancer',args)
        resource_obj = result_obj['LoadBalancer'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteLoadBalancer',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_sourceport
        resolved_sourceport = get_resolved(@props["sourceport"],workitem)
        if resolved_sourceport.nil?
          raise "Missing mandatory parameter sourceport for resource #{@name}"
        end
        resolved_sourceport
      end      
      

      def get_scheme
        resolved_scheme = get_resolved(@props["scheme"],workitem)
        if resolved_scheme.nil?
          raise "Missing mandatory parameter scheme for resource #{@name}"
        end
        resolved_scheme
      end      
      

      def get_algorithm
        resolved_algorithm = get_resolved(@props["algorithm"],workitem)
        if resolved_algorithm.nil?
          raise "Missing mandatory parameter algorithm for resource #{@name}"
        end
        resolved_algorithm
      end      
      

      def get_networkid
        resolved_networkid = get_resolved(@props["networkid"],workitem)
        if resolved_networkid.nil?
          raise "Missing mandatory parameter networkid for resource #{@name}"
        end
        resolved_networkid
      end      
      

      def get_sourceipaddressnetworkid
        resolved_sourceipaddressnetworkid = get_resolved(@props["sourceipaddressnetworkid"],workitem)
        if resolved_sourceipaddressnetworkid.nil?
          raise "Missing mandatory parameter sourceipaddressnetworkid for resource #{@name}"
        end
        resolved_sourceipaddressnetworkid
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_instanceport
        resolved_instanceport = get_resolved(@props["instanceport"],workitem)
        if resolved_instanceport.nil?
          raise "Missing mandatory parameter instanceport for resource #{@name}"
        end
        resolved_instanceport
      end      
      

      def get_description
        get_resolved(@props['description'],workitem)
      end
      

      def get_sourceipaddress
        get_resolved(@props['sourceipaddress'],workitem)
      end
      
end
    
   class CloudStackNetworkACLList < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['vpcid'] = get_vpcid
          args['name'] = get_name
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['description'] = get_description if @props.has_key?('description')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createNetworkACLList',args)
        resource_obj = result_obj['NetworkACLList'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteNetworkACLList',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_vpcid
        resolved_vpcid = get_resolved(@props["vpcid"],workitem)
        if resolved_vpcid.nil?
          raise "Missing mandatory parameter vpcid for resource #{@name}"
        end
        resolved_vpcid
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_description
        get_resolved(@props['description'],workitem)
      end
      
end
    
   class CloudStackPortForwardingRule < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['privateport'] = get_privateport
          args['protocol'] = get_protocol
          args['ipaddressid'] = get_ipaddressid
          args['virtualmachineid'] = get_virtualmachineid
          args['publicport'] = get_publicport
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['privateendport'] = get_privateendport if @props.has_key?('privateendport')
        args['cidrlist'] = get_cidrlist if @props.has_key?('cidrlist')
        args['vmguestip'] = get_vmguestip if @props.has_key?('vmguestip')
        args['networkid'] = get_networkid if @props.has_key?('networkid')
        args['publicendport'] = get_publicendport if @props.has_key?('publicendport')
        args['openfirewall'] = get_openfirewall if @props.has_key?('openfirewall')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createPortForwardingRule',args)
        resource_obj = result_obj['PortForwardingRule'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deletePortForwardingRule',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_privateport
        resolved_privateport = get_resolved(@props["privateport"],workitem)
        if resolved_privateport.nil?
          raise "Missing mandatory parameter privateport for resource #{@name}"
        end
        resolved_privateport
      end      
      

      def get_protocol
        resolved_protocol = get_resolved(@props["protocol"],workitem)
        if resolved_protocol.nil?
          raise "Missing mandatory parameter protocol for resource #{@name}"
        end
        resolved_protocol
      end      
      

      def get_ipaddressid
        resolved_ipaddressid = get_resolved(@props["ipaddressid"],workitem)
        if resolved_ipaddressid.nil?
          raise "Missing mandatory parameter ipaddressid for resource #{@name}"
        end
        resolved_ipaddressid
      end      
      

      def get_virtualmachineid
        resolved_virtualmachineid = get_resolved(@props["virtualmachineid"],workitem)
        if resolved_virtualmachineid.nil?
          raise "Missing mandatory parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end      
      

      def get_publicport
        resolved_publicport = get_resolved(@props["publicport"],workitem)
        if resolved_publicport.nil?
          raise "Missing mandatory parameter publicport for resource #{@name}"
        end
        resolved_publicport
      end      
      

      def get_privateendport
        get_resolved(@props['privateendport'],workitem)
      end
      

      def get_cidrlist
        get_resolved(@props['cidrlist'],workitem)
      end
      

      def get_vmguestip
        get_resolved(@props['vmguestip'],workitem)
      end
      

      def get_networkid
        get_resolved(@props['networkid'],workitem)
      end
      

      def get_publicendport
        get_resolved(@props['publicendport'],workitem)
      end
      

      def get_openfirewall
        get_resolved(@props['openfirewall'],workitem)
      end
      
end
    
   class CloudStackEgressFirewallRule < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['networkid'] = get_networkid
          args['protocol'] = get_protocol
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['icmpcode'] = get_icmpcode if @props.has_key?('icmpcode')
        args['cidrlist'] = get_cidrlist if @props.has_key?('cidrlist')
        args['type'] = get_type if @props.has_key?('type')
        args['endport'] = get_endport if @props.has_key?('endport')
        args['icmptype'] = get_icmptype if @props.has_key?('icmptype')
        args['startport'] = get_startport if @props.has_key?('startport')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createEgressFirewallRule',args)
        resource_obj = result_obj['EgressFirewallRule'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteEgressFirewallRule',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_networkid
        resolved_networkid = get_resolved(@props["networkid"],workitem)
        if resolved_networkid.nil?
          raise "Missing mandatory parameter networkid for resource #{@name}"
        end
        resolved_networkid
      end      
      

      def get_protocol
        resolved_protocol = get_resolved(@props["protocol"],workitem)
        if resolved_protocol.nil?
          raise "Missing mandatory parameter protocol for resource #{@name}"
        end
        resolved_protocol
      end      
      

      def get_icmpcode
        get_resolved(@props['icmpcode'],workitem)
      end
      

      def get_cidrlist
        get_resolved(@props['cidrlist'],workitem)
      end
      

      def get_type
        get_resolved(@props['type'],workitem)
      end
      

      def get_endport
        get_resolved(@props['endport'],workitem)
      end
      

      def get_icmptype
        get_resolved(@props['icmptype'],workitem)
      end
      

      def get_startport
        get_resolved(@props['startport'],workitem)
      end
      
end
    
   class CloudStackInstanceGroup < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['name'] = get_name
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['account'] = get_account if @props.has_key?('account')
        args['projectid'] = get_projectid if @props.has_key?('projectid')
        args['domainid'] = get_domainid if @props.has_key?('domainid')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_sync_request('createInstanceGroup',args)
        resource_obj = result_obj['InstanceGroup'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_sync_request('deleteInstanceGroup',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_projectid
        get_resolved(@props['projectid'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      
end
    
   class CloudStackIpToNic < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['nicid'] = get_nicid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['ipaddress'] = get_ipaddress if @props.has_key?('ipaddress')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('addIpToNic',args)
        resource_obj = result_obj['IpToNic'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('removeIpToNic',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_nicid
        resolved_nicid = get_resolved(@props["nicid"],workitem)
        if resolved_nicid.nil?
          raise "Missing mandatory parameter nicid for resource #{@name}"
        end
        resolved_nicid
      end      
      

      def get_ipaddress
        get_resolved(@props['ipaddress'],workitem)
      end
      
end
    
   class CloudStackAutoScaleVmGroup < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['maxmembers'] = get_maxmembers
          args['minmembers'] = get_minmembers
          args['scaledownpolicyids'] = get_scaledownpolicyids
          args['lbruleid'] = get_lbruleid
          args['scaleuppolicyids'] = get_scaleuppolicyids
          args['vmprofileid'] = get_vmprofileid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['interval'] = get_interval if @props.has_key?('interval')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createAutoScaleVmGroup',args)
        resource_obj = result_obj['AutoScaleVmGroup'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteAutoScaleVmGroup',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_maxmembers
        resolved_maxmembers = get_resolved(@props["maxmembers"],workitem)
        if resolved_maxmembers.nil?
          raise "Missing mandatory parameter maxmembers for resource #{@name}"
        end
        resolved_maxmembers
      end      
      

      def get_minmembers
        resolved_minmembers = get_resolved(@props["minmembers"],workitem)
        if resolved_minmembers.nil?
          raise "Missing mandatory parameter minmembers for resource #{@name}"
        end
        resolved_minmembers
      end      
      

      def get_scaledownpolicyids
        resolved_scaledownpolicyids = get_resolved(@props["scaledownpolicyids"],workitem)
        if resolved_scaledownpolicyids.nil?
          raise "Missing mandatory parameter scaledownpolicyids for resource #{@name}"
        end
        resolved_scaledownpolicyids
      end      
      

      def get_lbruleid
        resolved_lbruleid = get_resolved(@props["lbruleid"],workitem)
        if resolved_lbruleid.nil?
          raise "Missing mandatory parameter lbruleid for resource #{@name}"
        end
        resolved_lbruleid
      end      
      

      def get_scaleuppolicyids
        resolved_scaleuppolicyids = get_resolved(@props["scaleuppolicyids"],workitem)
        if resolved_scaleuppolicyids.nil?
          raise "Missing mandatory parameter scaleuppolicyids for resource #{@name}"
        end
        resolved_scaleuppolicyids
      end      
      

      def get_vmprofileid
        resolved_vmprofileid = get_resolved(@props["vmprofileid"],workitem)
        if resolved_vmprofileid.nil?
          raise "Missing mandatory parameter vmprofileid for resource #{@name}"
        end
        resolved_vmprofileid
      end      
      

      def get_interval
        get_resolved(@props['interval'],workitem)
      end
      
end
    
   class CloudStackLBHealthCheckPolicy < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['lbruleid'] = get_lbruleid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['responsetimeout'] = get_responsetimeout if @props.has_key?('responsetimeout')
        args['unhealthythreshold'] = get_unhealthythreshold if @props.has_key?('unhealthythreshold')
        args['pingpath'] = get_pingpath if @props.has_key?('pingpath')
        args['description'] = get_description if @props.has_key?('description')
        args['intervaltime'] = get_intervaltime if @props.has_key?('intervaltime')
        args['healthythreshold'] = get_healthythreshold if @props.has_key?('healthythreshold')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createLBHealthCheckPolicy',args)
        resource_obj = result_obj['LBHealthCheckPolicy'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteLBHealthCheckPolicy',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_lbruleid
        resolved_lbruleid = get_resolved(@props["lbruleid"],workitem)
        if resolved_lbruleid.nil?
          raise "Missing mandatory parameter lbruleid for resource #{@name}"
        end
        resolved_lbruleid
      end      
      

      def get_responsetimeout
        get_resolved(@props['responsetimeout'],workitem)
      end
      

      def get_unhealthythreshold
        get_resolved(@props['unhealthythreshold'],workitem)
      end
      

      def get_pingpath
        get_resolved(@props['pingpath'],workitem)
      end
      

      def get_description
        get_resolved(@props['description'],workitem)
      end
      

      def get_intervaltime
        get_resolved(@props['intervaltime'],workitem)
      end
      

      def get_healthythreshold
        get_resolved(@props['healthythreshold'],workitem)
      end
      
end
    
   class CloudStackVpnCustomerGateway < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['esppolicy'] = get_esppolicy
          args['ikepolicy'] = get_ikepolicy
          args['ipsecpsk'] = get_ipsecpsk
          args['cidrlist'] = get_cidrlist
          args['gateway'] = get_gateway
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['esplifetime'] = get_esplifetime if @props.has_key?('esplifetime')
        args['dpd'] = get_dpd if @props.has_key?('dpd')
        args['name'] = get_name if @props.has_key?('name')
        args['domainid'] = get_domainid if @props.has_key?('domainid')
        args['ikelifetime'] = get_ikelifetime if @props.has_key?('ikelifetime')
        args['account'] = get_account if @props.has_key?('account')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createVpnCustomerGateway',args)
        resource_obj = result_obj['VpnCustomerGateway'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteVpnCustomerGateway',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_esppolicy
        resolved_esppolicy = get_resolved(@props["esppolicy"],workitem)
        if resolved_esppolicy.nil?
          raise "Missing mandatory parameter esppolicy for resource #{@name}"
        end
        resolved_esppolicy
      end      
      

      def get_ikepolicy
        resolved_ikepolicy = get_resolved(@props["ikepolicy"],workitem)
        if resolved_ikepolicy.nil?
          raise "Missing mandatory parameter ikepolicy for resource #{@name}"
        end
        resolved_ikepolicy
      end      
      

      def get_ipsecpsk
        resolved_ipsecpsk = get_resolved(@props["ipsecpsk"],workitem)
        if resolved_ipsecpsk.nil?
          raise "Missing mandatory parameter ipsecpsk for resource #{@name}"
        end
        resolved_ipsecpsk
      end      
      

      def get_cidrlist
        resolved_cidrlist = get_resolved(@props["cidrlist"],workitem)
        if resolved_cidrlist.nil?
          raise "Missing mandatory parameter cidrlist for resource #{@name}"
        end
        resolved_cidrlist
      end      
      

      def get_gateway
        resolved_gateway = get_resolved(@props["gateway"],workitem)
        if resolved_gateway.nil?
          raise "Missing mandatory parameter gateway for resource #{@name}"
        end
        resolved_gateway
      end      
      

      def get_esplifetime
        get_resolved(@props['esplifetime'],workitem)
      end
      

      def get_dpd
        get_resolved(@props['dpd'],workitem)
      end
      

      def get_name
        get_resolved(@props['name'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      

      def get_ikelifetime
        get_resolved(@props['ikelifetime'],workitem)
      end
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      
end
    
   class CloudStackVpnGateway < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['vpcid'] = get_vpcid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createVpnGateway',args)
        resource_obj = result_obj['VpnGateway'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteVpnGateway',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_vpcid
        resolved_vpcid = get_resolved(@props["vpcid"],workitem)
        if resolved_vpcid.nil?
          raise "Missing mandatory parameter vpcid for resource #{@name}"
        end
        resolved_vpcid
      end      
      
end
    
   class CloudStackSecurityGroupEgress < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['cidrlist'] = get_cidrlist if @props.has_key?('cidrlist')
        args['securitygroupname'] = get_securitygroupname if @props.has_key?('securitygroupname')
        args['account'] = get_account if @props.has_key?('account')
        args['endport'] = get_endport if @props.has_key?('endport')
        args['usersecuritygrouplist'] = get_usersecuritygrouplist if @props.has_key?('usersecuritygrouplist')
        args['protocol'] = get_protocol if @props.has_key?('protocol')
        args['domainid'] = get_domainid if @props.has_key?('domainid')
        args['icmptype'] = get_icmptype if @props.has_key?('icmptype')
        args['startport'] = get_startport if @props.has_key?('startport')
        args['icmpcode'] = get_icmpcode if @props.has_key?('icmpcode')
        args['projectid'] = get_projectid if @props.has_key?('projectid')
        args['securitygroupid'] = get_securitygroupid if @props.has_key?('securitygroupid')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('authorizeSecurityGroupEgress',args)
        resource_obj = result_obj['SecurityGroupEgress'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('revokeSecurityGroupEgress',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_cidrlist
        get_resolved(@props['cidrlist'],workitem)
      end
      

      def get_securitygroupname
        get_resolved(@props['securitygroupname'],workitem)
      end
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_endport
        get_resolved(@props['endport'],workitem)
      end
      

      def get_usersecuritygrouplist
        get_resolved(@props['usersecuritygrouplist'],workitem)
      end
      

      def get_protocol
        get_resolved(@props['protocol'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      

      def get_icmptype
        get_resolved(@props['icmptype'],workitem)
      end
      

      def get_startport
        get_resolved(@props['startport'],workitem)
      end
      

      def get_icmpcode
        get_resolved(@props['icmpcode'],workitem)
      end
      

      def get_projectid
        get_resolved(@props['projectid'],workitem)
      end
      

      def get_securitygroupid
        get_resolved(@props['securitygroupid'],workitem)
      end
      
end
    
   class CloudStackIso < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['id'] = get_id
          args['virtualmachineid'] = get_virtualmachineid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('attachIso',args)
        resource_obj = result_obj['Iso'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'virtualmachineid' => physical_id
                  }
            result_obj = make_async_request('detachIso',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_id
        resolved_id = get_resolved(@props["id"],workitem)
        if resolved_id.nil?
          raise "Missing mandatory parameter id for resource #{@name}"
        end
        resolved_id
      end      
      

      def get_virtualmachineid
        resolved_virtualmachineid = get_resolved(@props["virtualmachineid"],workitem)
        if resolved_virtualmachineid.nil?
          raise "Missing mandatory parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end      
      
end
    
   class CloudStackTags < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['resourceids'] = get_resourceids
          args['tags'] = get_tags
          args['resourcetype'] = get_resourcetype
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['customer'] = get_customer if @props.has_key?('customer')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createTags',args)
        resource_obj = result_obj['Tags'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'resourcetype' => physical_id
                  }
            result_obj = make_async_request('deleteTags',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_resourceids
        resolved_resourceids = get_resolved(@props["resourceids"],workitem)
        if resolved_resourceids.nil?
          raise "Missing mandatory parameter resourceids for resource #{@name}"
        end
        resolved_resourceids
      end      
      

      def get_tags
        resolved_tags = get_resolved(@props["tags"],workitem)
        if resolved_tags.nil?
          raise "Missing mandatory parameter tags for resource #{@name}"
        end
        resolved_tags
      end      
      

      def get_resourcetype
        resolved_resourcetype = get_resolved(@props["resourcetype"],workitem)
        if resolved_resourcetype.nil?
          raise "Missing mandatory parameter resourcetype for resource #{@name}"
        end
        resolved_resourcetype
      end      
      

      def get_customer
        get_resolved(@props['customer'],workitem)
      end
      
end
    
   class CloudStackAutoScaleVmGroup < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['id'] = get_id
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('enableAutoScaleVmGroup',args)
        resource_obj = result_obj['AutoScaleVmGroup'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('disableAutoScaleVmGroup',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_id
        resolved_id = get_resolved(@props["id"],workitem)
        if resolved_id.nil?
          raise "Missing mandatory parameter id for resource #{@name}"
        end
        resolved_id
      end      
      
end
    
   class CloudStackSnapshotPolicy < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['volumeid'] = get_volumeid
          args['maxsnaps'] = get_maxsnaps
          args['schedule'] = get_schedule
          args['intervaltype'] = get_intervaltype
          args['timezone'] = get_timezone
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_sync_request('createSnapshotPolicy',args)
        resource_obj = result_obj['SnapshotPolicy'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_sync_request('deleteSnapshotPolicy',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_volumeid
        resolved_volumeid = get_resolved(@props["volumeid"],workitem)
        if resolved_volumeid.nil?
          raise "Missing mandatory parameter volumeid for resource #{@name}"
        end
        resolved_volumeid
      end      
      

      def get_maxsnaps
        resolved_maxsnaps = get_resolved(@props["maxsnaps"],workitem)
        if resolved_maxsnaps.nil?
          raise "Missing mandatory parameter maxsnaps for resource #{@name}"
        end
        resolved_maxsnaps
      end      
      

      def get_schedule
        resolved_schedule = get_resolved(@props["schedule"],workitem)
        if resolved_schedule.nil?
          raise "Missing mandatory parameter schedule for resource #{@name}"
        end
        resolved_schedule
      end      
      

      def get_intervaltype
        resolved_intervaltype = get_resolved(@props["intervaltype"],workitem)
        if resolved_intervaltype.nil?
          raise "Missing mandatory parameter intervaltype for resource #{@name}"
        end
        resolved_intervaltype
      end      
      

      def get_timezone
        resolved_timezone = get_resolved(@props["timezone"],workitem)
        if resolved_timezone.nil?
          raise "Missing mandatory parameter timezone for resource #{@name}"
        end
        resolved_timezone
      end      
      
end
    
   class CloudStackNetworkACL < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['protocol'] = get_protocol
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['networkid'] = get_networkid if @props.has_key?('networkid')
        args['endport'] = get_endport if @props.has_key?('endport')
        args['action'] = get_action if @props.has_key?('action')
        args['startport'] = get_startport if @props.has_key?('startport')
        args['traffictype'] = get_traffictype if @props.has_key?('traffictype')
        args['cidrlist'] = get_cidrlist if @props.has_key?('cidrlist')
        args['icmpcode'] = get_icmpcode if @props.has_key?('icmpcode')
        args['aclid'] = get_aclid if @props.has_key?('aclid')
        args['number'] = get_number if @props.has_key?('number')
        args['icmptype'] = get_icmptype if @props.has_key?('icmptype')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createNetworkACL',args)
        resource_obj = result_obj['NetworkACL'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteNetworkACL',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_protocol
        resolved_protocol = get_resolved(@props["protocol"],workitem)
        if resolved_protocol.nil?
          raise "Missing mandatory parameter protocol for resource #{@name}"
        end
        resolved_protocol
      end      
      

      def get_networkid
        get_resolved(@props['networkid'],workitem)
      end
      

      def get_endport
        get_resolved(@props['endport'],workitem)
      end
      

      def get_action
        get_resolved(@props['action'],workitem)
      end
      

      def get_startport
        get_resolved(@props['startport'],workitem)
      end
      

      def get_traffictype
        get_resolved(@props['traffictype'],workitem)
      end
      

      def get_cidrlist
        get_resolved(@props['cidrlist'],workitem)
      end
      

      def get_icmpcode
        get_resolved(@props['icmpcode'],workitem)
      end
      

      def get_aclid
        get_resolved(@props['aclid'],workitem)
      end
      

      def get_number
        get_resolved(@props['number'],workitem)
      end
      

      def get_icmptype
        get_resolved(@props['icmptype'],workitem)
      end
      
end
    
   class CloudStackVPC < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['cidr'] = get_cidr
          args['zoneid'] = get_zoneid
          args['name'] = get_name
          args['vpcofferingid'] = get_vpcofferingid
          args['displaytext'] = get_displaytext
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['projectid'] = get_projectid if @props.has_key?('projectid')
        args['account'] = get_account if @props.has_key?('account')
        args['domainid'] = get_domainid if @props.has_key?('domainid')
        args['networkdomain'] = get_networkdomain if @props.has_key?('networkdomain')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createVPC',args)
        resource_obj = result_obj['VPC'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        p resource_obj
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
        exit
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteVPC',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_cidr
        resolved_cidr = get_resolved(@props["cidr"],workitem)
        if resolved_cidr.nil?
          raise "Missing mandatory parameter cidr for resource #{@name}"
        end
        resolved_cidr
      end      
      

      def get_zoneid
        resolved_zoneid = get_resolved(@props["zoneid"],workitem)
        if resolved_zoneid.nil?
          raise "Missing mandatory parameter zoneid for resource #{@name}"
        end
        resolved_zoneid
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_vpcofferingid
        resolved_vpcofferingid = get_resolved(@props["vpcofferingid"],workitem)
        if resolved_vpcofferingid.nil?
          raise "Missing mandatory parameter vpcofferingid for resource #{@name}"
        end
        resolved_vpcofferingid
      end      
      

      def get_displaytext
        resolved_displaytext = get_resolved(@props["displaytext"],workitem)
        if resolved_displaytext.nil?
          raise "Missing mandatory parameter displaytext for resource #{@name}"
        end
        resolved_displaytext
      end      
      

      def get_projectid
        get_resolved(@props['projectid'],workitem)
      end
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      

      def get_networkdomain
        get_resolved(@props['networkdomain'],workitem)
      end
      
end
    
   class CloudStackVolume < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['name'] = get_name
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['maxiops'] = get_maxiops if @props.has_key?('maxiops')
        args['domainid'] = get_domainid if @props.has_key?('domainid')
        args['projectid'] = get_projectid if @props.has_key?('projectid')
        args['displayvolume'] = get_displayvolume if @props.has_key?('displayvolume')
        args['snapshotid'] = get_snapshotid if @props.has_key?('snapshotid')
        args['miniops'] = get_miniops if @props.has_key?('miniops')
        args['diskofferingid'] = get_diskofferingid if @props.has_key?('diskofferingid')
        args['size'] = get_size if @props.has_key?('size')
        args['account'] = get_account if @props.has_key?('account')
        args['zoneid'] = get_zoneid if @props.has_key?('zoneid')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createVolume',args)
        resource_obj = result_obj['Volume'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_sync_request('deleteVolume',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_maxiops
        get_resolved(@props['maxiops'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      

      def get_projectid
        get_resolved(@props['projectid'],workitem)
      end
      

      def get_displayvolume
        get_resolved(@props['displayvolume'],workitem)
      end
      

      def get_snapshotid
        get_resolved(@props['snapshotid'],workitem)
      end
      

      def get_miniops
        get_resolved(@props['miniops'],workitem)
      end
      

      def get_diskofferingid
        get_resolved(@props['diskofferingid'],workitem)
      end
      

      def get_size
        get_resolved(@props['size'],workitem)
      end
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_zoneid
        get_resolved(@props['zoneid'],workitem)
      end
      
end
    
   class CloudStackRemoteAccessVpn < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['publicipid'] = get_publicipid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['account'] = get_account if @props.has_key?('account')
        args['domainid'] = get_domainid if @props.has_key?('domainid')
        args['openfirewall'] = get_openfirewall if @props.has_key?('openfirewall')
        args['iprange'] = get_iprange if @props.has_key?('iprange')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createRemoteAccessVpn',args)
        resource_obj = result_obj['RemoteAccessVpn'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'publicipid' => physical_id
                  }
            result_obj = make_async_request('deleteRemoteAccessVpn',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_publicipid
        resolved_publicipid = get_resolved(@props["publicipid"],workitem)
        if resolved_publicipid.nil?
          raise "Missing mandatory parameter publicipid for resource #{@name}"
        end
        resolved_publicipid
      end      
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      

      def get_openfirewall
        get_resolved(@props['openfirewall'],workitem)
      end
      

      def get_iprange
        get_resolved(@props['iprange'],workitem)
      end
      
end
    
   class CloudStackVpnUser < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['password'] = get_password
          args['username'] = get_username
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['projectid'] = get_projectid if @props.has_key?('projectid')
        args['account'] = get_account if @props.has_key?('account')
        args['domainid'] = get_domainid if @props.has_key?('domainid')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('addVpnUser',args)
        resource_obj = result_obj['VpnUser'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'username' => physical_id
                  }
            result_obj = make_async_request('removeVpnUser',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_password
        resolved_password = get_resolved(@props["password"],workitem)
        if resolved_password.nil?
          raise "Missing mandatory parameter password for resource #{@name}"
        end
        resolved_password
      end      
      

      def get_username
        resolved_username = get_resolved(@props["username"],workitem)
        if resolved_username.nil?
          raise "Missing mandatory parameter username for resource #{@name}"
        end
        resolved_username
      end      
      

      def get_projectid
        get_resolved(@props['projectid'],workitem)
      end
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      
end
    
   class CloudStackProject < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['name'] = get_name
          args['displaytext'] = get_displaytext
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['account'] = get_account if @props.has_key?('account')
        args['domainid'] = get_domainid if @props.has_key?('domainid')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createProject',args)
        resource_obj = result_obj['Project'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteProject',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_displaytext
        resolved_displaytext = get_resolved(@props["displaytext"],workitem)
        if resolved_displaytext.nil?
          raise "Missing mandatory parameter displaytext for resource #{@name}"
        end
        resolved_displaytext
      end      
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      
end
    
   class CloudStackLoadBalancerRule < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['publicport'] = get_publicport
          args['privateport'] = get_privateport
          args['name'] = get_name
          args['algorithm'] = get_algorithm
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['description'] = get_description if @props.has_key?('description')
        args['networkid'] = get_networkid if @props.has_key?('networkid')
        args['openfirewall'] = get_openfirewall if @props.has_key?('openfirewall')
        args['account'] = get_account if @props.has_key?('account')
        args['domainid'] = get_domainid if @props.has_key?('domainid')
        args['publicipid'] = get_publicipid if @props.has_key?('publicipid')
        args['zoneid'] = get_zoneid if @props.has_key?('zoneid')
        args['cidrlist'] = get_cidrlist if @props.has_key?('cidrlist')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createLoadBalancerRule',args)
        resource_obj = result_obj['LoadBalancerRule'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteLoadBalancerRule',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_publicport
        resolved_publicport = get_resolved(@props["publicport"],workitem)
        if resolved_publicport.nil?
          raise "Missing mandatory parameter publicport for resource #{@name}"
        end
        resolved_publicport
      end      
      

      def get_privateport
        resolved_privateport = get_resolved(@props["privateport"],workitem)
        if resolved_privateport.nil?
          raise "Missing mandatory parameter privateport for resource #{@name}"
        end
        resolved_privateport
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_algorithm
        resolved_algorithm = get_resolved(@props["algorithm"],workitem)
        if resolved_algorithm.nil?
          raise "Missing mandatory parameter algorithm for resource #{@name}"
        end
        resolved_algorithm
      end      
      

      def get_description
        get_resolved(@props['description'],workitem)
      end
      

      def get_networkid
        get_resolved(@props['networkid'],workitem)
      end
      

      def get_openfirewall
        get_resolved(@props['openfirewall'],workitem)
      end
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      

      def get_publicipid
        get_resolved(@props['publicipid'],workitem)
      end
      

      def get_zoneid
        get_resolved(@props['zoneid'],workitem)
      end
      

      def get_cidrlist
        get_resolved(@props['cidrlist'],workitem)
      end
      
end
    
   class CloudStackAutoScalePolicy < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['action'] = get_action
          args['duration'] = get_duration
          args['conditionids'] = get_conditionids
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['quiettime'] = get_quiettime if @props.has_key?('quiettime')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createAutoScalePolicy',args)
        resource_obj = result_obj['AutoScalePolicy'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteAutoScalePolicy',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_action
        resolved_action = get_resolved(@props["action"],workitem)
        if resolved_action.nil?
          raise "Missing mandatory parameter action for resource #{@name}"
        end
        resolved_action
      end      
      

      def get_duration
        resolved_duration = get_resolved(@props["duration"],workitem)
        if resolved_duration.nil?
          raise "Missing mandatory parameter duration for resource #{@name}"
        end
        resolved_duration
      end      
      

      def get_conditionids
        resolved_conditionids = get_resolved(@props["conditionids"],workitem)
        if resolved_conditionids.nil?
          raise "Missing mandatory parameter conditionids for resource #{@name}"
        end
        resolved_conditionids
      end      
      

      def get_quiettime
        get_resolved(@props['quiettime'],workitem)
      end
      
end
    
   class CloudStackLBStickinessPolicy < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['methodname'] = get_methodname
          args['lbruleid'] = get_lbruleid
          args['name'] = get_name
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['param'] = get_param if @props.has_key?('param')
        args['description'] = get_description if @props.has_key?('description')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createLBStickinessPolicy',args)
        resource_obj = result_obj['LBStickinessPolicy'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteLBStickinessPolicy',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_methodname
        resolved_methodname = get_resolved(@props["methodname"],workitem)
        if resolved_methodname.nil?
          raise "Missing mandatory parameter methodname for resource #{@name}"
        end
        resolved_methodname
      end      
      

      def get_lbruleid
        resolved_lbruleid = get_resolved(@props["lbruleid"],workitem)
        if resolved_lbruleid.nil?
          raise "Missing mandatory parameter lbruleid for resource #{@name}"
        end
        resolved_lbruleid
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil?
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_param
        get_resolved(@props['param'],workitem)
      end
      

      def get_description
        get_resolved(@props['description'],workitem)
      end
      
end
    
   class CloudStackSnapshot < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['volumeid'] = get_volumeid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['domainid'] = get_domainid if @props.has_key?('domainid')
        args['account'] = get_account if @props.has_key?('account')
        args['policyid'] = get_policyid if @props.has_key?('policyid')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createSnapshot',args)
        resource_obj = result_obj['Snapshot'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteSnapshot',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_volumeid
        resolved_volumeid = get_resolved(@props["volumeid"],workitem)
        if resolved_volumeid.nil?
          raise "Missing mandatory parameter volumeid for resource #{@name}"
        end
        resolved_volumeid
      end      
      

      def get_domainid
        get_resolved(@props['domainid'],workitem)
      end
      

      def get_account
        get_resolved(@props['account'],workitem)
      end
      

      def get_policyid
        get_resolved(@props['policyid'],workitem)
      end
      
end
    
   class CloudStackFirewallRule < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['protocol'] = get_protocol
          args['ipaddressid'] = get_ipaddressid
  
        rescue Exception => e
          #logging.error("Missing required parameter for resource #{@name}")
          logger.error(e.message)
          raise e
        end
        
        args['startport'] = get_startport if @props.has_key?('startport')
        args['cidrlist'] = get_cidrlist if @props.has_key?('cidrlist')
        args['icmpcode'] = get_icmpcode if @props.has_key?('icmpcode')
        args['type'] = get_type if @props.has_key?('type')
        args['icmptype'] = get_icmptype if @props.has_key?('icmptype')
        args['endport'] = get_endport if @props.has_key?('endport')

        logger.info("Creating resource #{@name} with following arguments")
        p args
        result_obj = make_async_request('createFirewallRule',args)
        resource_obj = result_obj['FirewallRule'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteFirewallRule',args)
            if (!result_obj.empty?)
              logger.info("Successfully deleted resource #{@name}")
            else
              logger.info("CloudStack error while deleting resource #{@name}")
            end
          else
            logger.info("Resource  not created in CloudStack. Skipping delete...")
          end
        rescue Exception => e
          logger.error("Unable to delete resorce #{@name}")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_protocol
        resolved_protocol = get_resolved(@props["protocol"],workitem)
        if resolved_protocol.nil?
          raise "Missing mandatory parameter protocol for resource #{@name}"
        end
        resolved_protocol
      end      
      

      def get_ipaddressid
        resolved_ipaddressid = get_resolved(@props["ipaddressid"],workitem)
        if resolved_ipaddressid.nil?
          raise "Missing mandatory parameter ipaddressid for resource #{@name}"
        end
        resolved_ipaddressid
      end      
      

      def get_startport
        get_resolved(@props['startport'],workitem)
      end
      

      def get_cidrlist
        get_resolved(@props['cidrlist'],workitem)
      end
      

      def get_icmpcode
        get_resolved(@props['icmpcode'],workitem)
      end
      

      def get_type
        get_resolved(@props['type'],workitem)
      end
      

      def get_icmptype
        get_resolved(@props['icmptype'],workitem)
      end
      

      def get_endport
        get_resolved(@props['endport'],workitem)
      end
      
end
    

    


end
