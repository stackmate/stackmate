require 'json'
#require 'cloudstack_ruby_client'
require 'stackmate/client'
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
  include Resolver

  attr_reader :name

  def initialize(opts)
      @opts = opts
      @url = opts['URL'] || ENV['URL'] or raise ArgumentError.new("CloudStackResources: no URL supplied for CloudStack API")
      @apikey = opts['APIKEY'] || ENV['APIKEY'] or raise ArgumentError.new("CloudStackResources: no api key supplied for CloudStack API")
      @seckey = opts['SECKEY'] || ENV['SECKEY'] or raise ArgumentError.new("CloudStackResources: no secret key supplied for CloudStack API")
      #@client = CloudstackRubyClient::Client.new(@url, @apikey, @seckey, false)
      @client = StackMate::CloudStackClient.new(@url, @apikey, @seckey, false)
  end

  def on_workitem
    p workitem.participant_name
    reply
  end

  protected

    def set_tags(tags,resourceId,resourceType)
        tags_hash = resolve_tags(tags,workitem)
        tags_args = {}
        i = 0
        tags_hash.each_key do |k|
          tags_args["tags[#{i}].key"] = k
          tags_args["tags[#{i}].value"] = tags_hash[k]
          i = i + 1
        end
        tags_args['resourceids'] = resourceId
        tags_args['resourcetype'] = resourceType
        logger.debug("Attemping to add tags for resource #{@name}")
        p tags_args
        result_tags = make_async_request("createTags",tags_args)
        if (!(result_tags['error']==true))
          workitem[@name]['tags'] = tags_hash
        else
          logger.error("Unable to set tags for resource #{@name}")
        end
    end

    def make_sync_request(cmd,args)
        begin
          logger.debug "Going to make sync request #{cmd} to CloudStack server for resource #{@name}"
          #resp = @client.send(cmd, args)
          resp = @client.api_call(cmd,args)
          return resp
        rescue => e
          logger.error("Failed to make request #{cmd} to CloudStack server while creating resource #{@name}")
          logger.debug e.message + "\n " + e.backtrace.join("\n ")
          raise e
        rescue SystemExit
          logger.error "Rescued a SystemExit exception"
          raise CloudStackApiException, "Did not get 200 OK while making api call #{cmd}"
        end
    end

    def make_async_request(cmd, args)
        begin
          logger.debug "Going to make async request #{cmd} to CloudStack server for resource #{@name}"
          #resp = @client.send(cmd, args)
          resp = @client.api_call(cmd,args)
          jobid = resp['jobid'] if resp
          resp = api_poll(jobid, 3, 3) if jobid
          return resp
        rescue => e
          logger.error("Failed to make request #{cmd} to CloudStack server while creating resource #{@name}")
          logger.debug e.message + "\n " + e.backtrace.join("\n ")
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
        #resp = @client.queryAsyncJobResult({'jobid' => jobid})
        resp = @client.api_call("queryAsyncJobResult",{'jobid' => jobid})
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"Condition") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteCondition',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_threshold.nil? || !validate_param(resolved_threshold,"long")
          raise "Missing mandatory parameter threshold for resource #{@name}"
        end
        resolved_threshold
      end      
      

      def get_relationaloperator
        resolved_relationaloperator = get_resolved(@props["relationaloperator"],workitem)
        if resolved_relationaloperator.nil? || !validate_param(resolved_relationaloperator,"string")
          raise "Missing mandatory parameter relationaloperator for resource #{@name}"
        end
        resolved_relationaloperator
      end      
      

      def get_counterid
        resolved_counterid = get_resolved(@props["counterid"],workitem)
        if resolved_counterid.nil? || !validate_param(resolved_counterid,"uuid")
          raise "Missing mandatory parameter counterid for resource #{@name}"
        end
        resolved_counterid
      end      
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"NicToVirtualMachine") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'virtualmachineid' => physical_id
                  }
            result_obj = make_async_request('removeNicToVirtualMachine',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_virtualmachineid.nil? || !validate_param(resolved_virtualmachineid,"uuid")
          raise "Missing mandatory parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end      
      

      def get_networkid
        resolved_networkid = get_resolved(@props["networkid"],workitem)
        if resolved_networkid.nil? || !validate_param(resolved_networkid,"uuid")
          raise "Missing mandatory parameter networkid for resource #{@name}"
        end
        resolved_networkid
      end      
      

      def get_ipaddress
        resolved_ipaddress = get_resolved(@props['ipaddress'],workitem)
        if resolved_ipaddress.nil? || !validate_param(resolved_ipaddress,"string")
          raise "Malformed optional parameter ipaddress for resource #{@name}"
        end
        resolved_ipaddress
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"VpnConnection") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteVpnConnection',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_s2scustomergatewayid.nil? || !validate_param(resolved_s2scustomergatewayid,"uuid")
          raise "Missing mandatory parameter s2scustomergatewayid for resource #{@name}"
        end
        resolved_s2scustomergatewayid
      end      
      

      def get_s2svpngatewayid
        resolved_s2svpngatewayid = get_resolved(@props["s2svpngatewayid"],workitem)
        if resolved_s2svpngatewayid.nil? || !validate_param(resolved_s2svpngatewayid,"uuid")
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
          resource_obj = result_obj['securitygroup']['ingressrule'.downcase][0]
          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('ruleid'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"SecurityGroupIngress") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('revokeSecurityGroupIngress',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_endport
        resolved_endport = get_resolved(@props['endport'],workitem)
        if resolved_endport.nil? || !validate_param(resolved_endport,"integer")
          raise "Malformed optional parameter endport for resource #{@name}"
        end
        resolved_endport
      end
      

      def get_securitygroupid
        resolved_securitygroupid = get_resolved(@props['securitygroupid'],workitem)
        if resolved_securitygroupid.nil? || !validate_param(resolved_securitygroupid,"uuid")
          raise "Malformed optional parameter securitygroupid for resource #{@name}"
        end
        resolved_securitygroupid
      end
      

      def get_protocol
        resolved_protocol = get_resolved(@props['protocol'],workitem)
        if resolved_protocol.nil? || !validate_param(resolved_protocol,"string")
          raise "Malformed optional parameter protocol for resource #{@name}"
        end
        resolved_protocol
      end
      

      def get_icmpcode
        resolved_icmpcode = get_resolved(@props['icmpcode'],workitem)
        if resolved_icmpcode.nil? || !validate_param(resolved_icmpcode,"integer")
          raise "Malformed optional parameter icmpcode for resource #{@name}"
        end
        resolved_icmpcode
      end
      

      def get_startport
        resolved_startport = get_resolved(@props['startport'],workitem)
        if resolved_startport.nil? || !validate_param(resolved_startport,"integer")
          raise "Malformed optional parameter startport for resource #{@name}"
        end
        resolved_startport
      end
      

      def get_projectid
        resolved_projectid = get_resolved(@props['projectid'],workitem)
        if resolved_projectid.nil? || !validate_param(resolved_projectid,"uuid")
          raise "Malformed optional parameter projectid for resource #{@name}"
        end
        resolved_projectid
      end
      

      def get_usersecuritygrouplist
        resolved_usersecuritygrouplist = get_resolved(@props['usersecuritygrouplist'],workitem)
        if resolved_usersecuritygrouplist.nil? || !validate_param(resolved_usersecuritygrouplist,"map")
          raise "Malformed optional parameter usersecuritygrouplist for resource #{@name}"
        end
        resolved_usersecuritygrouplist
      end
      

      def get_cidrlist
        resolved_cidrlist = get_resolved(@props['cidrlist'],workitem)
        if resolved_cidrlist.nil? || !validate_param(resolved_cidrlist,"list")
          raise "Malformed optional parameter cidrlist for resource #{@name}"
        end
        resolved_cidrlist
      end
      

      def get_securitygroupname
        resolved_securitygroupname = get_resolved(@props['securitygroupname'],workitem)
        if resolved_securitygroupname.nil? || !validate_param(resolved_securitygroupname,"string")
          raise "Malformed optional parameter securitygroupname for resource #{@name}"
        end
        resolved_securitygroupname
      end
      

      def get_icmptype
        resolved_icmptype = get_resolved(@props['icmptype'],workitem)
        if resolved_icmptype.nil? || !validate_param(resolved_icmptype,"integer")
          raise "Malformed optional parameter icmptype for resource #{@name}"
        end
        resolved_icmptype
      end
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
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
          args['name'] = workitem['StackName'] +'-' + get_name
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"Template") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteTemplate',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_displaytext.nil? || !validate_param(resolved_displaytext,"string")
          raise "Missing mandatory parameter displaytext for resource #{@name}"
        end
        resolved_displaytext
      end      
      

      def get_ostypeid
        resolved_ostypeid = get_resolved(@props["ostypeid"],workitem)
        if resolved_ostypeid.nil? || !validate_param(resolved_ostypeid,"uuid")
          raise "Missing mandatory parameter ostypeid for resource #{@name}"
        end
        resolved_ostypeid
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_snapshotid
        resolved_snapshotid = get_resolved(@props['snapshotid'],workitem)
        if resolved_snapshotid.nil? || !validate_param(resolved_snapshotid,"uuid")
          raise "Malformed optional parameter snapshotid for resource #{@name}"
        end
        resolved_snapshotid
      end
      

      def get_details
        resolved_details = get_resolved(@props['details'],workitem)
        if resolved_details.nil? || !validate_param(resolved_details,"map")
          raise "Malformed optional parameter details for resource #{@name}"
        end
        resolved_details
      end
      

      def get_virtualmachineid
        resolved_virtualmachineid = get_resolved(@props['virtualmachineid'],workitem)
        if resolved_virtualmachineid.nil? || !validate_param(resolved_virtualmachineid,"uuid")
          raise "Malformed optional parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end
      

      def get_requireshvm
        resolved_requireshvm = get_resolved(@props['requireshvm'],workitem)
        if resolved_requireshvm.nil? || !validate_param(resolved_requireshvm,"boolean")
          raise "Malformed optional parameter requireshvm for resource #{@name}"
        end
        resolved_requireshvm
      end
      

      def get_ispublic
        resolved_ispublic = get_resolved(@props['ispublic'],workitem)
        if resolved_ispublic.nil? || !validate_param(resolved_ispublic,"boolean")
          raise "Malformed optional parameter ispublic for resource #{@name}"
        end
        resolved_ispublic
      end
      

      def get_volumeid
        resolved_volumeid = get_resolved(@props['volumeid'],workitem)
        if resolved_volumeid.nil? || !validate_param(resolved_volumeid,"uuid")
          raise "Malformed optional parameter volumeid for resource #{@name}"
        end
        resolved_volumeid
      end
      

      def get_bits
        resolved_bits = get_resolved(@props['bits'],workitem)
        if resolved_bits.nil? || !validate_param(resolved_bits,"integer")
          raise "Malformed optional parameter bits for resource #{@name}"
        end
        resolved_bits
      end
      

      def get_url
        resolved_url = get_resolved(@props['url'],workitem)
        if resolved_url.nil? || !validate_param(resolved_url,"string")
          raise "Malformed optional parameter url for resource #{@name}"
        end
        resolved_url
      end
      

      def get_templatetag
        resolved_templatetag = get_resolved(@props['templatetag'],workitem)
        if resolved_templatetag.nil? || !validate_param(resolved_templatetag,"string")
          raise "Malformed optional parameter templatetag for resource #{@name}"
        end
        resolved_templatetag
      end
      

      def get_isdynamicallyscalable
        resolved_isdynamicallyscalable = get_resolved(@props['isdynamicallyscalable'],workitem)
        if resolved_isdynamicallyscalable.nil? || !validate_param(resolved_isdynamicallyscalable,"boolean")
          raise "Malformed optional parameter isdynamicallyscalable for resource #{@name}"
        end
        resolved_isdynamicallyscalable
      end
      

      def get_passwordenabled
        resolved_passwordenabled = get_resolved(@props['passwordenabled'],workitem)
        if resolved_passwordenabled.nil? || !validate_param(resolved_passwordenabled,"boolean")
          raise "Malformed optional parameter passwordenabled for resource #{@name}"
        end
        resolved_passwordenabled
      end
      

      def get_isfeatured
        resolved_isfeatured = get_resolved(@props['isfeatured'],workitem)
        if resolved_isfeatured.nil? || !validate_param(resolved_isfeatured,"boolean")
          raise "Malformed optional parameter isfeatured for resource #{@name}"
        end
        resolved_isfeatured
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
          args['name'] = workitem['StackName'] +'-' + get_name
          args['zoneid'] = get_zoneid
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"Network") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteNetwork',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_displaytext.nil? || !validate_param(resolved_displaytext,"string")
          raise "Missing mandatory parameter displaytext for resource #{@name}"
        end
        resolved_displaytext
      end      
      

      def get_networkofferingid
        resolved_networkofferingid = get_resolved(@props["networkofferingid"],workitem)
        if resolved_networkofferingid.nil? || !validate_param(resolved_networkofferingid,"uuid")
          raise "Missing mandatory parameter networkofferingid for resource #{@name}"
        end
        resolved_networkofferingid
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_zoneid
        resolved_zoneid = get_resolved(@props["zoneid"],workitem)
        if resolved_zoneid.nil? || !validate_param(resolved_zoneid,"uuid")
          raise "Missing mandatory parameter zoneid for resource #{@name}"
        end
        resolved_zoneid
      end      
      

      def get_networkdomain
        resolved_networkdomain = get_resolved(@props['networkdomain'],workitem)
        if resolved_networkdomain.nil? || !validate_param(resolved_networkdomain,"string")
          raise "Malformed optional parameter networkdomain for resource #{@name}"
        end
        resolved_networkdomain
      end
      

      def get_projectid
        resolved_projectid = get_resolved(@props['projectid'],workitem)
        if resolved_projectid.nil? || !validate_param(resolved_projectid,"uuid")
          raise "Malformed optional parameter projectid for resource #{@name}"
        end
        resolved_projectid
      end
      

      def get_startip
        resolved_startip = get_resolved(@props['startip'],workitem)
        if resolved_startip.nil? || !validate_param(resolved_startip,"string")
          raise "Malformed optional parameter startip for resource #{@name}"
        end
        resolved_startip
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_displaynetwork
        resolved_displaynetwork = get_resolved(@props['displaynetwork'],workitem)
        if resolved_displaynetwork.nil? || !validate_param(resolved_displaynetwork,"boolean")
          raise "Malformed optional parameter displaynetwork for resource #{@name}"
        end
        resolved_displaynetwork
      end
      

      def get_startipv6
        resolved_startipv6 = get_resolved(@props['startipv6'],workitem)
        if resolved_startipv6.nil? || !validate_param(resolved_startipv6,"string")
          raise "Malformed optional parameter startipv6 for resource #{@name}"
        end
        resolved_startipv6
      end
      

      def get_acltype
        resolved_acltype = get_resolved(@props['acltype'],workitem)
        if resolved_acltype.nil? || !validate_param(resolved_acltype,"string")
          raise "Malformed optional parameter acltype for resource #{@name}"
        end
        resolved_acltype
      end
      

      def get_endip
        resolved_endip = get_resolved(@props['endip'],workitem)
        if resolved_endip.nil? || !validate_param(resolved_endip,"string")
          raise "Malformed optional parameter endip for resource #{@name}"
        end
        resolved_endip
      end
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_gateway
        resolved_gateway = get_resolved(@props['gateway'],workitem)
        if resolved_gateway.nil? || !validate_param(resolved_gateway,"string")
          raise "Malformed optional parameter gateway for resource #{@name}"
        end
        resolved_gateway
      end
      

      def get_vlan
        resolved_vlan = get_resolved(@props['vlan'],workitem)
        if resolved_vlan.nil? || !validate_param(resolved_vlan,"string")
          raise "Malformed optional parameter vlan for resource #{@name}"
        end
        resolved_vlan
      end
      

      def get_endipv6
        resolved_endipv6 = get_resolved(@props['endipv6'],workitem)
        if resolved_endipv6.nil? || !validate_param(resolved_endipv6,"string")
          raise "Malformed optional parameter endipv6 for resource #{@name}"
        end
        resolved_endipv6
      end
      

      def get_ip6cidr
        resolved_ip6cidr = get_resolved(@props['ip6cidr'],workitem)
        if resolved_ip6cidr.nil? || !validate_param(resolved_ip6cidr,"string")
          raise "Malformed optional parameter ip6cidr for resource #{@name}"
        end
        resolved_ip6cidr
      end
      

      def get_aclid
        resolved_aclid = get_resolved(@props['aclid'],workitem)
        if resolved_aclid.nil? || !validate_param(resolved_aclid,"uuid")
          raise "Malformed optional parameter aclid for resource #{@name}"
        end
        resolved_aclid
      end
      

      def get_isolatedpvlan
        resolved_isolatedpvlan = get_resolved(@props['isolatedpvlan'],workitem)
        if resolved_isolatedpvlan.nil? || !validate_param(resolved_isolatedpvlan,"string")
          raise "Malformed optional parameter isolatedpvlan for resource #{@name}"
        end
        resolved_isolatedpvlan
      end
      

      def get_ip6gateway
        resolved_ip6gateway = get_resolved(@props['ip6gateway'],workitem)
        if resolved_ip6gateway.nil? || !validate_param(resolved_ip6gateway,"string")
          raise "Malformed optional parameter ip6gateway for resource #{@name}"
        end
        resolved_ip6gateway
      end
      

      def get_netmask
        resolved_netmask = get_resolved(@props['netmask'],workitem)
        if resolved_netmask.nil? || !validate_param(resolved_netmask,"string")
          raise "Malformed optional parameter netmask for resource #{@name}"
        end
        resolved_netmask
      end
      

      def get_subdomainaccess
        resolved_subdomainaccess = get_resolved(@props['subdomainaccess'],workitem)
        if resolved_subdomainaccess.nil? || !validate_param(resolved_subdomainaccess,"boolean")
          raise "Malformed optional parameter subdomainaccess for resource #{@name}"
        end
        resolved_subdomainaccess
      end
      

      def get_vpcid
        resolved_vpcid = get_resolved(@props['vpcid'],workitem)
        if resolved_vpcid.nil? || !validate_param(resolved_vpcid,"uuid")
          raise "Malformed optional parameter vpcid for resource #{@name}"
        end
        resolved_vpcid
      end
      

      def get_physicalnetworkid
        resolved_physicalnetworkid = get_resolved(@props['physicalnetworkid'],workitem)
        if resolved_physicalnetworkid.nil? || !validate_param(resolved_physicalnetworkid,"uuid")
          raise "Malformed optional parameter physicalnetworkid for resource #{@name}"
        end
        resolved_physicalnetworkid
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"Volume") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('detachVolume',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_id.nil? || !validate_param(resolved_id,"uuid")
          raise "Missing mandatory parameter id for resource #{@name}"
        end
        resolved_id
      end      
      

      def get_virtualmachineid
        resolved_virtualmachineid = get_resolved(@props["virtualmachineid"],workitem)
        if resolved_virtualmachineid.nil? || !validate_param(resolved_virtualmachineid,"uuid")
          raise "Missing mandatory parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end      
      

      def get_deviceid
        resolved_deviceid = get_resolved(@props['deviceid'],workitem)
        if resolved_deviceid.nil? || !validate_param(resolved_deviceid,"long")
          raise "Malformed optional parameter deviceid for resource #{@name}"
        end
        resolved_deviceid
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
        
          args['name'] = workitem['StackName'] +'-' + get_name
          args['type'] = get_type
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"AffinityGroup") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteAffinityGroup',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_type
        resolved_type = get_resolved(@props["type"],workitem)
        if resolved_type.nil? || !validate_param(resolved_type,"string")
          raise "Missing mandatory parameter type for resource #{@name}"
        end
        resolved_type
      end      
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_description
        resolved_description = get_resolved(@props['description'],workitem)
        if resolved_description.nil? || !validate_param(resolved_description,"string")
          raise "Malformed optional parameter description for resource #{@name}"
        end
        resolved_description
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"AutoScaleVmProfile") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteAutoScaleVmProfile',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_zoneid.nil? || !validate_param(resolved_zoneid,"uuid")
          raise "Missing mandatory parameter zoneid for resource #{@name}"
        end
        resolved_zoneid
      end      
      

      def get_serviceofferingid
        resolved_serviceofferingid = get_resolved(@props["serviceofferingid"],workitem)
        if resolved_serviceofferingid.nil? || !validate_param(resolved_serviceofferingid,"uuid")
          raise "Missing mandatory parameter serviceofferingid for resource #{@name}"
        end
        resolved_serviceofferingid
      end      
      

      def get_templateid
        resolved_templateid = get_resolved(@props["templateid"],workitem)
        if resolved_templateid.nil? || !validate_param(resolved_templateid,"uuid")
          raise "Missing mandatory parameter templateid for resource #{@name}"
        end
        resolved_templateid
      end      
      

      def get_otherdeployparams
        resolved_otherdeployparams = get_resolved(@props['otherdeployparams'],workitem)
        if resolved_otherdeployparams.nil? || !validate_param(resolved_otherdeployparams,"string")
          raise "Malformed optional parameter otherdeployparams for resource #{@name}"
        end
        resolved_otherdeployparams
      end
      

      def get_destroyvmgraceperiod
        resolved_destroyvmgraceperiod = get_resolved(@props['destroyvmgraceperiod'],workitem)
        if resolved_destroyvmgraceperiod.nil? || !validate_param(resolved_destroyvmgraceperiod,"integer")
          raise "Malformed optional parameter destroyvmgraceperiod for resource #{@name}"
        end
        resolved_destroyvmgraceperiod
      end
      

      def get_autoscaleuserid
        resolved_autoscaleuserid = get_resolved(@props['autoscaleuserid'],workitem)
        if resolved_autoscaleuserid.nil? || !validate_param(resolved_autoscaleuserid,"uuid")
          raise "Malformed optional parameter autoscaleuserid for resource #{@name}"
        end
        resolved_autoscaleuserid
      end
      

      def get_counterparam
        resolved_counterparam = get_resolved(@props['counterparam'],workitem)
        if resolved_counterparam.nil? || !validate_param(resolved_counterparam,"map")
          raise "Malformed optional parameter counterparam for resource #{@name}"
        end
        resolved_counterparam
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
        
          args['name'] = workitem['StackName'] +'-' + get_name
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"SecurityGroup") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_sync_request('deleteSecurityGroup',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_description
        resolved_description = get_resolved(@props['description'],workitem)
        if resolved_description.nil? || !validate_param(resolved_description,"string")
          raise "Malformed optional parameter description for resource #{@name}"
        end
        resolved_description
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_projectid
        resolved_projectid = get_resolved(@props['projectid'],workitem)
        if resolved_projectid.nil? || !validate_param(resolved_projectid,"uuid")
          raise "Malformed optional parameter projectid for resource #{@name}"
        end
        resolved_projectid
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
        
          args['name'] = workitem['StackName'] +'-' + get_name
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"SSHKeyPair") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'name' => physical_id
                  }
            result_obj = make_sync_request('deleteSSHKeyPair',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_projectid
        resolved_projectid = get_resolved(@props['projectid'],workitem)
        if resolved_projectid.nil? || !validate_param(resolved_projectid,"uuid")
          raise "Malformed optional parameter projectid for resource #{@name}"
        end
        resolved_projectid
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
          args['name'] = workitem['StackName'] +'-' + get_name
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"GlobalLoadBalancerRule") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteGlobalLoadBalancerRule',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_regionid.nil? || !validate_param(resolved_regionid,"integer")
          raise "Missing mandatory parameter regionid for resource #{@name}"
        end
        resolved_regionid
      end      
      

      def get_gslbservicetype
        resolved_gslbservicetype = get_resolved(@props["gslbservicetype"],workitem)
        if resolved_gslbservicetype.nil? || !validate_param(resolved_gslbservicetype,"string")
          raise "Missing mandatory parameter gslbservicetype for resource #{@name}"
        end
        resolved_gslbservicetype
      end      
      

      def get_gslbdomainname
        resolved_gslbdomainname = get_resolved(@props["gslbdomainname"],workitem)
        if resolved_gslbdomainname.nil? || !validate_param(resolved_gslbdomainname,"string")
          raise "Missing mandatory parameter gslbdomainname for resource #{@name}"
        end
        resolved_gslbdomainname
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_gslbstickysessionmethodname
        resolved_gslbstickysessionmethodname = get_resolved(@props['gslbstickysessionmethodname'],workitem)
        if resolved_gslbstickysessionmethodname.nil? || !validate_param(resolved_gslbstickysessionmethodname,"string")
          raise "Malformed optional parameter gslbstickysessionmethodname for resource #{@name}"
        end
        resolved_gslbstickysessionmethodname
      end
      

      def get_description
        resolved_description = get_resolved(@props['description'],workitem)
        if resolved_description.nil? || !validate_param(resolved_description,"string")
          raise "Malformed optional parameter description for resource #{@name}"
        end
        resolved_description
      end
      

      def get_gslblbmethod
        resolved_gslblbmethod = get_resolved(@props['gslblbmethod'],workitem)
        if resolved_gslblbmethod.nil? || !validate_param(resolved_gslblbmethod,"string")
          raise "Malformed optional parameter gslblbmethod for resource #{@name}"
        end
        resolved_gslblbmethod
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"StaticRoute") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteStaticRoute',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_gatewayid.nil? || !validate_param(resolved_gatewayid,"uuid")
          raise "Missing mandatory parameter gatewayid for resource #{@name}"
        end
        resolved_gatewayid
      end      
      

      def get_cidr
        resolved_cidr = get_resolved(@props["cidr"],workitem)
        if resolved_cidr.nil? || !validate_param(resolved_cidr,"string")
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
          args['description'] = get_description if @props.has_key?('description')
          args['snapshotmemory'] = get_snapshotmemory if @props.has_key?('snapshotmemory')
          args['name'] = workitem['StackName'] +'-' + get_name if @props.has_key?('name')

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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"VMSnapshot") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'vmsnapshotid' => physical_id
                  }
            result_obj = make_async_request('deleteVMSnapshot',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_virtualmachineid.nil? || !validate_param(resolved_virtualmachineid,"uuid")
          raise "Missing mandatory parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end      
      

      def get_description
        resolved_description = get_resolved(@props['description'],workitem)
        if resolved_description.nil? || !validate_param(resolved_description,"string")
          raise "Malformed optional parameter description for resource #{@name}"
        end
        resolved_description
      end
      

      def get_snapshotmemory
        resolved_snapshotmemory = get_resolved(@props['snapshotmemory'],workitem)
        if resolved_snapshotmemory.nil? || !validate_param(resolved_snapshotmemory,"boolean")
          raise "Malformed optional parameter snapshotmemory for resource #{@name}"
        end
        resolved_snapshotmemory
      end
      

      def get_name
        resolved_name = get_resolved(@props['name'],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Malformed optional parameter name for resource #{@name}"
        end
        resolved_name
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"StaticNat") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'ipaddressid' => physical_id
                  }
            result_obj = make_async_request('disableStaticNat',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_ipaddressid.nil? || !validate_param(resolved_ipaddressid,"uuid")
          raise "Missing mandatory parameter ipaddressid for resource #{@name}"
        end
        resolved_ipaddressid
      end      
      

      def get_virtualmachineid
        resolved_virtualmachineid = get_resolved(@props["virtualmachineid"],workitem)
        if resolved_virtualmachineid.nil? || !validate_param(resolved_virtualmachineid,"uuid")
          raise "Missing mandatory parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end      
      

      def get_networkid
        resolved_networkid = get_resolved(@props['networkid'],workitem)
        if resolved_networkid.nil? || !validate_param(resolved_networkid,"uuid")
          raise "Malformed optional parameter networkid for resource #{@name}"
        end
        resolved_networkid
      end
      

      def get_vmguestip
        resolved_vmguestip = get_resolved(@props['vmguestip'],workitem)
        if resolved_vmguestip.nil? || !validate_param(resolved_vmguestip,"string")
          raise "Malformed optional parameter vmguestip for resource #{@name}"
        end
        resolved_vmguestip
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"IpForwardingRule") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteIpForwardingRule',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_ipaddressid.nil? || !validate_param(resolved_ipaddressid,"uuid")
          raise "Missing mandatory parameter ipaddressid for resource #{@name}"
        end
        resolved_ipaddressid
      end      
      

      def get_protocol
        resolved_protocol = get_resolved(@props["protocol"],workitem)
        if resolved_protocol.nil? || !validate_param(resolved_protocol,"string")
          raise "Missing mandatory parameter protocol for resource #{@name}"
        end
        resolved_protocol
      end      
      

      def get_startport
        resolved_startport = get_resolved(@props["startport"],workitem)
        if resolved_startport.nil? || !validate_param(resolved_startport,"integer")
          raise "Missing mandatory parameter startport for resource #{@name}"
        end
        resolved_startport
      end      
      

      def get_cidrlist
        resolved_cidrlist = get_resolved(@props['cidrlist'],workitem)
        if resolved_cidrlist.nil? || !validate_param(resolved_cidrlist,"list")
          raise "Malformed optional parameter cidrlist for resource #{@name}"
        end
        resolved_cidrlist
      end
      

      def get_endport
        resolved_endport = get_resolved(@props['endport'],workitem)
        if resolved_endport.nil? || !validate_param(resolved_endport,"integer")
          raise "Malformed optional parameter endport for resource #{@name}"
        end
        resolved_endport
      end
      

      def get_openfirewall
        resolved_openfirewall = get_resolved(@props['openfirewall'],workitem)
        if resolved_openfirewall.nil? || !validate_param(resolved_openfirewall,"boolean")
          raise "Malformed optional parameter openfirewall for resource #{@name}"
        end
        resolved_openfirewall
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
          args['name'] = workitem['StackName'] +'-' + get_name
          args['instanceport'] = get_instanceport
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"LoadBalancer") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteLoadBalancer',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_sourceport.nil? || !validate_param(resolved_sourceport,"integer")
          raise "Missing mandatory parameter sourceport for resource #{@name}"
        end
        resolved_sourceport
      end      
      

      def get_scheme
        resolved_scheme = get_resolved(@props["scheme"],workitem)
        if resolved_scheme.nil? || !validate_param(resolved_scheme,"string")
          raise "Missing mandatory parameter scheme for resource #{@name}"
        end
        resolved_scheme
      end      
      

      def get_algorithm
        resolved_algorithm = get_resolved(@props["algorithm"],workitem)
        if resolved_algorithm.nil? || !validate_param(resolved_algorithm,"string")
          raise "Missing mandatory parameter algorithm for resource #{@name}"
        end
        resolved_algorithm
      end      
      

      def get_networkid
        resolved_networkid = get_resolved(@props["networkid"],workitem)
        if resolved_networkid.nil? || !validate_param(resolved_networkid,"uuid")
          raise "Missing mandatory parameter networkid for resource #{@name}"
        end
        resolved_networkid
      end      
      

      def get_sourceipaddressnetworkid
        resolved_sourceipaddressnetworkid = get_resolved(@props["sourceipaddressnetworkid"],workitem)
        if resolved_sourceipaddressnetworkid.nil? || !validate_param(resolved_sourceipaddressnetworkid,"uuid")
          raise "Missing mandatory parameter sourceipaddressnetworkid for resource #{@name}"
        end
        resolved_sourceipaddressnetworkid
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_instanceport
        resolved_instanceport = get_resolved(@props["instanceport"],workitem)
        if resolved_instanceport.nil? || !validate_param(resolved_instanceport,"integer")
          raise "Missing mandatory parameter instanceport for resource #{@name}"
        end
        resolved_instanceport
      end      
      

      def get_description
        resolved_description = get_resolved(@props['description'],workitem)
        if resolved_description.nil? || !validate_param(resolved_description,"string")
          raise "Malformed optional parameter description for resource #{@name}"
        end
        resolved_description
      end
      

      def get_sourceipaddress
        resolved_sourceipaddress = get_resolved(@props['sourceipaddress'],workitem)
        if resolved_sourceipaddress.nil? || !validate_param(resolved_sourceipaddress,"string")
          raise "Malformed optional parameter sourceipaddress for resource #{@name}"
        end
        resolved_sourceipaddress
      end
      
end
    
   class CloudStackVirtualMachine < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['templateid'] = get_templateid
          args['serviceofferingid'] = get_serviceofferingid
          args['zoneid'] = get_zoneid
          args['securitygroupnames'] = get_securitygroupnames if @props.has_key?('securitygroupnames')
          args['affinitygroupids'] = get_affinitygroupids if @props.has_key?('affinitygroupids')
          args['startvm'] = get_startvm if @props.has_key?('startvm')
          args['displayvm'] = get_displayvm if @props.has_key?('displayvm')
          args['diskofferingid'] = get_diskofferingid if @props.has_key?('diskofferingid')
          args['hypervisor'] = get_hypervisor if @props.has_key?('hypervisor')
          args['keyboard'] = get_keyboard if @props.has_key?('keyboard')
          args['name'] = workitem['StackName'] +'-' + get_name if @props.has_key?('name')
          #args['iptonetworklist'] = get_iptonetworklist if @props.has_key?('iptonetworklist')
          if @props.has_key?('iptonetworklist')
            ipnetworklist = get_iptonetworklist
            #split
            list_params = ipnetworklist.split("&")
            list_params.each do |p|
              fields = p.split("=")
              args[fields[0]] = fields[1]
            end
          end
          args['networkids'] = get_networkids if @props.has_key?('networkids')
          args['account'] = get_account if @props.has_key?('account')
          args['userdata'] = get_userdata if @props.has_key?('userdata')
          args['keypair'] = get_keypair if @props.has_key?('keypair')
          args['projectid'] = get_projectid if @props.has_key?('projectid')
          args['ipaddress'] = get_ipaddress if @props.has_key?('ipaddress')
          args['displayname'] = get_displayname if @props.has_key?('displayname')
          args['ip6address'] = get_ip6address if @props.has_key?('ip6address')
          args['affinitygroupnames'] = get_affinitygroupnames if @props.has_key?('affinitygroupnames')
          args['domainid'] = get_domainid if @props.has_key?('domainid')
          args['size'] = get_size if @props.has_key?('size')
          args['hostid'] = get_hostid if @props.has_key?('hostid')
          args['securitygroupids'] = get_securitygroupids if @props.has_key?('securitygroupids')
          args['group'] = get_group if @props.has_key?('group')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('deployVirtualMachine',args)
          resource_obj = result_obj['VirtualMachine'.downcase]
          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          workitem[@name][:PrivateIp] = resource_obj['nic'][0]['ipaddress']
          set_tags(@props['tags'],workitem[@name]['physical_id'],"UserVm") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('destroyVirtualMachine',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_templateid
        resolved_templateid = get_resolved(@props["templateid"],workitem)
        if resolved_templateid.nil? || !validate_param(resolved_templateid,"uuid")
          raise "Missing mandatory parameter templateid for resource #{@name}"
        end
        resolved_templateid
      end      
      

      def get_serviceofferingid
        resolved_serviceofferingid = get_resolved(@props["serviceofferingid"],workitem)
        if resolved_serviceofferingid.nil? || !validate_param(resolved_serviceofferingid,"uuid")
          raise "Missing mandatory parameter serviceofferingid for resource #{@name}"
        end
        resolved_serviceofferingid
      end      
      

      def get_zoneid
        resolved_zoneid = get_resolved(@props["zoneid"],workitem)
        if resolved_zoneid.nil? || !validate_param(resolved_zoneid,"uuid")
          raise "Missing mandatory parameter zoneid for resource #{@name}"
        end
        resolved_zoneid
      end      
      

      def get_securitygroupnames
        resolved_securitygroupnames = get_resolved(@props['securitygroupnames'],workitem)
        if resolved_securitygroupnames.nil? || !validate_param(resolved_securitygroupnames,"list")
          raise "Malformed optional parameter securitygroupnames for resource #{@name}"
        end
        resolved_securitygroupnames
      end
      

      def get_affinitygroupids
        resolved_affinitygroupids = get_resolved(@props['affinitygroupids'],workitem)
        if resolved_affinitygroupids.nil? || !validate_param(resolved_affinitygroupids,"list")
          raise "Malformed optional parameter affinitygroupids for resource #{@name}"
        end
        resolved_affinitygroupids
      end
      

      def get_startvm
        resolved_startvm = get_resolved(@props['startvm'],workitem)
        if resolved_startvm.nil? || !validate_param(resolved_startvm,"boolean")
          raise "Malformed optional parameter startvm for resource #{@name}"
        end
        resolved_startvm
      end
      

      def get_displayvm
        resolved_displayvm = get_resolved(@props['displayvm'],workitem)
        if resolved_displayvm.nil? || !validate_param(resolved_displayvm,"boolean")
          raise "Malformed optional parameter displayvm for resource #{@name}"
        end
        resolved_displayvm
      end
      

      def get_diskofferingid
        resolved_diskofferingid = get_resolved(@props['diskofferingid'],workitem)
        if resolved_diskofferingid.nil? || !validate_param(resolved_diskofferingid,"uuid")
          raise "Malformed optional parameter diskofferingid for resource #{@name}"
        end
        resolved_diskofferingid
      end
      

      def get_hypervisor
        resolved_hypervisor = get_resolved(@props['hypervisor'],workitem)
        if resolved_hypervisor.nil? || !validate_param(resolved_hypervisor,"string")
          raise "Malformed optional parameter hypervisor for resource #{@name}"
        end
        resolved_hypervisor
      end
      

      def get_keyboard
        resolved_keyboard = get_resolved(@props['keyboard'],workitem)
        if resolved_keyboard.nil? || !validate_param(resolved_keyboard,"string")
          raise "Malformed optional parameter keyboard for resource #{@name}"
        end
        resolved_keyboard
      end
      

      def get_name
        resolved_name = get_resolved(@props['name'],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Malformed optional parameter name for resource #{@name}"
        end
        resolved_name
      end
      

      def get_iptonetworklist
        resolved_iptonetworklist = get_resolved(@props['iptonetworklist'],workitem)
        if resolved_iptonetworklist.nil? || !validate_param(resolved_iptonetworklist,"map")
          raise "Malformed optional parameter iptonetworklist for resource #{@name}"
        end
        resolved_iptonetworklist
      end
      

      def get_networkids
        resolved_networkids = get_resolved(@props['networkids'],workitem)
        if resolved_networkids.nil? || !validate_param(resolved_networkids,"list")
          raise "Malformed optional parameter networkids for resource #{@name}"
        end
        resolved_networkids
      end
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_userdata
        resolved_userdata = get_resolved(@props['userdata'],workitem)
        if resolved_userdata.nil? || !validate_param(resolved_userdata,"string")
          raise "Malformed optional parameter userdata for resource #{@name}"
        end
        resolved_userdata
      end
      

      def get_keypair
        resolved_keypair = get_resolved(@props['keypair'],workitem)
        if resolved_keypair.nil? || !validate_param(resolved_keypair,"string")
          raise "Malformed optional parameter keypair for resource #{@name}"
        end
        resolved_keypair
      end
      

      def get_projectid
        resolved_projectid = get_resolved(@props['projectid'],workitem)
        if resolved_projectid.nil? || !validate_param(resolved_projectid,"uuid")
          raise "Malformed optional parameter projectid for resource #{@name}"
        end
        resolved_projectid
      end
      

      def get_ipaddress
        resolved_ipaddress = get_resolved(@props['ipaddress'],workitem)
        if resolved_ipaddress.nil? || !validate_param(resolved_ipaddress,"string")
          raise "Malformed optional parameter ipaddress for resource #{@name}"
        end
        resolved_ipaddress
      end
      

      def get_displayname
        resolved_displayname = get_resolved(@props['displayname'],workitem)
        if resolved_displayname.nil? || !validate_param(resolved_displayname,"string")
          raise "Malformed optional parameter displayname for resource #{@name}"
        end
        resolved_displayname
      end
      

      def get_ip6address
        resolved_ip6address = get_resolved(@props['ip6address'],workitem)
        if resolved_ip6address.nil? || !validate_param(resolved_ip6address,"string")
          raise "Malformed optional parameter ip6address for resource #{@name}"
        end
        resolved_ip6address
      end
      

      def get_affinitygroupnames
        resolved_affinitygroupnames = get_resolved(@props['affinitygroupnames'],workitem)
        if resolved_affinitygroupnames.nil? || !validate_param(resolved_affinitygroupnames,"list")
          raise "Malformed optional parameter affinitygroupnames for resource #{@name}"
        end
        resolved_affinitygroupnames
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_size
        resolved_size = get_resolved(@props['size'],workitem)
        if resolved_size.nil? || !validate_param(resolved_size,"long")
          raise "Malformed optional parameter size for resource #{@name}"
        end
        resolved_size
      end
      

      def get_hostid
        resolved_hostid = get_resolved(@props['hostid'],workitem)
        if resolved_hostid.nil? || !validate_param(resolved_hostid,"uuid")
          raise "Malformed optional parameter hostid for resource #{@name}"
        end
        resolved_hostid
      end
      

      def get_securitygroupids
        resolved_securitygroupids = get_resolved(@props['securitygroupids'],workitem)
        if resolved_securitygroupids.nil? || !validate_param(resolved_securitygroupids,"list")
          raise "Malformed optional parameter securitygroupids for resource #{@name}"
        end
        resolved_securitygroupids
      end
      

      def get_group
        resolved_group = get_resolved(@props['group'],workitem)
        if resolved_group.nil? || !validate_param(resolved_group,"string")
          raise "Malformed optional parameter group for resource #{@name}"
        end
        resolved_group
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
          args['name'] = workitem['StackName'] +'-' + get_name
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"NetworkACLList") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteNetworkACLList',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_vpcid.nil? || !validate_param(resolved_vpcid,"uuid")
          raise "Missing mandatory parameter vpcid for resource #{@name}"
        end
        resolved_vpcid
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_description
        resolved_description = get_resolved(@props['description'],workitem)
        if resolved_description.nil? || !validate_param(resolved_description,"string")
          raise "Malformed optional parameter description for resource #{@name}"
        end
        resolved_description
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"PortForwardingRule") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deletePortForwardingRule',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_privateport.nil? || !validate_param(resolved_privateport,"integer")
          raise "Missing mandatory parameter privateport for resource #{@name}"
        end
        resolved_privateport
      end      
      

      def get_protocol
        resolved_protocol = get_resolved(@props["protocol"],workitem)
        if resolved_protocol.nil? || !validate_param(resolved_protocol,"string")
          raise "Missing mandatory parameter protocol for resource #{@name}"
        end
        resolved_protocol
      end      
      

      def get_ipaddressid
        resolved_ipaddressid = get_resolved(@props["ipaddressid"],workitem)
        if resolved_ipaddressid.nil? || !validate_param(resolved_ipaddressid,"uuid")
          raise "Missing mandatory parameter ipaddressid for resource #{@name}"
        end
        resolved_ipaddressid
      end      
      

      def get_virtualmachineid
        resolved_virtualmachineid = get_resolved(@props["virtualmachineid"],workitem)
        if resolved_virtualmachineid.nil? || !validate_param(resolved_virtualmachineid,"uuid")
          raise "Missing mandatory parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end      
      

      def get_publicport
        resolved_publicport = get_resolved(@props["publicport"],workitem)
        if resolved_publicport.nil? || !validate_param(resolved_publicport,"integer")
          raise "Missing mandatory parameter publicport for resource #{@name}"
        end
        resolved_publicport
      end      
      

      def get_privateendport
        resolved_privateendport = get_resolved(@props['privateendport'],workitem)
        if resolved_privateendport.nil? || !validate_param(resolved_privateendport,"integer")
          raise "Malformed optional parameter privateendport for resource #{@name}"
        end
        resolved_privateendport
      end
      

      def get_cidrlist
        resolved_cidrlist = get_resolved(@props['cidrlist'],workitem)
        if resolved_cidrlist.nil? || !validate_param(resolved_cidrlist,"list")
          raise "Malformed optional parameter cidrlist for resource #{@name}"
        end
        resolved_cidrlist
      end
      

      def get_vmguestip
        resolved_vmguestip = get_resolved(@props['vmguestip'],workitem)
        if resolved_vmguestip.nil? || !validate_param(resolved_vmguestip,"string")
          raise "Malformed optional parameter vmguestip for resource #{@name}"
        end
        resolved_vmguestip
      end
      

      def get_networkid
        resolved_networkid = get_resolved(@props['networkid'],workitem)
        if resolved_networkid.nil? || !validate_param(resolved_networkid,"uuid")
          raise "Malformed optional parameter networkid for resource #{@name}"
        end
        resolved_networkid
      end
      

      def get_publicendport
        resolved_publicendport = get_resolved(@props['publicendport'],workitem)
        if resolved_publicendport.nil? || !validate_param(resolved_publicendport,"integer")
          raise "Malformed optional parameter publicendport for resource #{@name}"
        end
        resolved_publicendport
      end
      

      def get_openfirewall
        resolved_openfirewall = get_resolved(@props['openfirewall'],workitem)
        if resolved_openfirewall.nil? || !validate_param(resolved_openfirewall,"boolean")
          raise "Malformed optional parameter openfirewall for resource #{@name}"
        end
        resolved_openfirewall
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"EgressFirewallRule") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteEgressFirewallRule',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_networkid.nil? || !validate_param(resolved_networkid,"uuid")
          raise "Missing mandatory parameter networkid for resource #{@name}"
        end
        resolved_networkid
      end      
      

      def get_protocol
        resolved_protocol = get_resolved(@props["protocol"],workitem)
        if resolved_protocol.nil? || !validate_param(resolved_protocol,"string")
          raise "Missing mandatory parameter protocol for resource #{@name}"
        end
        resolved_protocol
      end      
      

      def get_icmpcode
        resolved_icmpcode = get_resolved(@props['icmpcode'],workitem)
        if resolved_icmpcode.nil? || !validate_param(resolved_icmpcode,"integer")
          raise "Malformed optional parameter icmpcode for resource #{@name}"
        end
        resolved_icmpcode
      end
      

      def get_cidrlist
        resolved_cidrlist = get_resolved(@props['cidrlist'],workitem)
        if resolved_cidrlist.nil? || !validate_param(resolved_cidrlist,"list")
          raise "Malformed optional parameter cidrlist for resource #{@name}"
        end
        resolved_cidrlist
      end
      

      def get_type
        resolved_type = get_resolved(@props['type'],workitem)
        if resolved_type.nil? || !validate_param(resolved_type,"string")
          raise "Malformed optional parameter type for resource #{@name}"
        end
        resolved_type
      end
      

      def get_endport
        resolved_endport = get_resolved(@props['endport'],workitem)
        if resolved_endport.nil? || !validate_param(resolved_endport,"integer")
          raise "Malformed optional parameter endport for resource #{@name}"
        end
        resolved_endport
      end
      

      def get_icmptype
        resolved_icmptype = get_resolved(@props['icmptype'],workitem)
        if resolved_icmptype.nil? || !validate_param(resolved_icmptype,"integer")
          raise "Malformed optional parameter icmptype for resource #{@name}"
        end
        resolved_icmptype
      end
      

      def get_startport
        resolved_startport = get_resolved(@props['startport'],workitem)
        if resolved_startport.nil? || !validate_param(resolved_startport,"integer")
          raise "Malformed optional parameter startport for resource #{@name}"
        end
        resolved_startport
      end
      
end
    
   class CloudStackToGlobalLoadBalancerRule < CloudStackResource

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
          args['loadbalancerrulelist'] = get_loadbalancerrulelist
          args['gslblbruleweightsmap'] = get_gslblbruleweightsmap if @props.has_key?('gslblbruleweightsmap')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('assignToGlobalLoadBalancerRule',args)
          resource_obj = result_obj['ToGlobalLoadBalancerRule'.downcase]
          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"ToGlobalLoadBalancerRule") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'loadbalancerrulelist' => physical_id
                  }
            result_obj = make_async_request('removeToGlobalLoadBalancerRule',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_id.nil? || !validate_param(resolved_id,"uuid")
          raise "Missing mandatory parameter id for resource #{@name}"
        end
        resolved_id
      end      
      

      def get_loadbalancerrulelist
        resolved_loadbalancerrulelist = get_resolved(@props["loadbalancerrulelist"],workitem)
        if resolved_loadbalancerrulelist.nil? || !validate_param(resolved_loadbalancerrulelist,"list")
          raise "Missing mandatory parameter loadbalancerrulelist for resource #{@name}"
        end
        resolved_loadbalancerrulelist
      end      
      

      def get_gslblbruleweightsmap
        resolved_gslblbruleweightsmap = get_resolved(@props['gslblbruleweightsmap'],workitem)
        if resolved_gslblbruleweightsmap.nil? || !validate_param(resolved_gslblbruleweightsmap,"map")
          raise "Malformed optional parameter gslblbruleweightsmap for resource #{@name}"
        end
        resolved_gslblbruleweightsmap
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
        
          args['name'] = workitem['StackName'] +'-' + get_name
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"InstanceGroup") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_sync_request('deleteInstanceGroup',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_projectid
        resolved_projectid = get_resolved(@props['projectid'],workitem)
        if resolved_projectid.nil? || !validate_param(resolved_projectid,"uuid")
          raise "Malformed optional parameter projectid for resource #{@name}"
        end
        resolved_projectid
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"IpToNic") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('removeIpToNic',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_nicid.nil? || !validate_param(resolved_nicid,"uuid")
          raise "Missing mandatory parameter nicid for resource #{@name}"
        end
        resolved_nicid
      end      
      

      def get_ipaddress
        resolved_ipaddress = get_resolved(@props['ipaddress'],workitem)
        if resolved_ipaddress.nil? || !validate_param(resolved_ipaddress,"string")
          raise "Malformed optional parameter ipaddress for resource #{@name}"
        end
        resolved_ipaddress
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"AutoScaleVmGroup") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteAutoScaleVmGroup',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_maxmembers.nil? || !validate_param(resolved_maxmembers,"integer")
          raise "Missing mandatory parameter maxmembers for resource #{@name}"
        end
        resolved_maxmembers
      end      
      

      def get_minmembers
        resolved_minmembers = get_resolved(@props["minmembers"],workitem)
        if resolved_minmembers.nil? || !validate_param(resolved_minmembers,"integer")
          raise "Missing mandatory parameter minmembers for resource #{@name}"
        end
        resolved_minmembers
      end      
      

      def get_scaledownpolicyids
        resolved_scaledownpolicyids = get_resolved(@props["scaledownpolicyids"],workitem)
        if resolved_scaledownpolicyids.nil? || !validate_param(resolved_scaledownpolicyids,"list")
          raise "Missing mandatory parameter scaledownpolicyids for resource #{@name}"
        end
        resolved_scaledownpolicyids
      end      
      

      def get_lbruleid
        resolved_lbruleid = get_resolved(@props["lbruleid"],workitem)
        if resolved_lbruleid.nil? || !validate_param(resolved_lbruleid,"uuid")
          raise "Missing mandatory parameter lbruleid for resource #{@name}"
        end
        resolved_lbruleid
      end      
      

      def get_scaleuppolicyids
        resolved_scaleuppolicyids = get_resolved(@props["scaleuppolicyids"],workitem)
        if resolved_scaleuppolicyids.nil? || !validate_param(resolved_scaleuppolicyids,"list")
          raise "Missing mandatory parameter scaleuppolicyids for resource #{@name}"
        end
        resolved_scaleuppolicyids
      end      
      

      def get_vmprofileid
        resolved_vmprofileid = get_resolved(@props["vmprofileid"],workitem)
        if resolved_vmprofileid.nil? || !validate_param(resolved_vmprofileid,"uuid")
          raise "Missing mandatory parameter vmprofileid for resource #{@name}"
        end
        resolved_vmprofileid
      end      
      

      def get_interval
        resolved_interval = get_resolved(@props['interval'],workitem)
        if resolved_interval.nil? || !validate_param(resolved_interval,"integer")
          raise "Malformed optional parameter interval for resource #{@name}"
        end
        resolved_interval
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"LBHealthCheckPolicy") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteLBHealthCheckPolicy',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_lbruleid.nil? || !validate_param(resolved_lbruleid,"uuid")
          raise "Missing mandatory parameter lbruleid for resource #{@name}"
        end
        resolved_lbruleid
      end      
      

      def get_responsetimeout
        resolved_responsetimeout = get_resolved(@props['responsetimeout'],workitem)
        if resolved_responsetimeout.nil? || !validate_param(resolved_responsetimeout,"integer")
          raise "Malformed optional parameter responsetimeout for resource #{@name}"
        end
        resolved_responsetimeout
      end
      

      def get_unhealthythreshold
        resolved_unhealthythreshold = get_resolved(@props['unhealthythreshold'],workitem)
        if resolved_unhealthythreshold.nil? || !validate_param(resolved_unhealthythreshold,"integer")
          raise "Malformed optional parameter unhealthythreshold for resource #{@name}"
        end
        resolved_unhealthythreshold
      end
      

      def get_pingpath
        resolved_pingpath = get_resolved(@props['pingpath'],workitem)
        if resolved_pingpath.nil? || !validate_param(resolved_pingpath,"string")
          raise "Malformed optional parameter pingpath for resource #{@name}"
        end
        resolved_pingpath
      end
      

      def get_description
        resolved_description = get_resolved(@props['description'],workitem)
        if resolved_description.nil? || !validate_param(resolved_description,"string")
          raise "Malformed optional parameter description for resource #{@name}"
        end
        resolved_description
      end
      

      def get_intervaltime
        resolved_intervaltime = get_resolved(@props['intervaltime'],workitem)
        if resolved_intervaltime.nil? || !validate_param(resolved_intervaltime,"integer")
          raise "Malformed optional parameter intervaltime for resource #{@name}"
        end
        resolved_intervaltime
      end
      

      def get_healthythreshold
        resolved_healthythreshold = get_resolved(@props['healthythreshold'],workitem)
        if resolved_healthythreshold.nil? || !validate_param(resolved_healthythreshold,"integer")
          raise "Malformed optional parameter healthythreshold for resource #{@name}"
        end
        resolved_healthythreshold
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
          args['esplifetime'] = get_esplifetime if @props.has_key?('esplifetime')
          args['dpd'] = get_dpd if @props.has_key?('dpd')
          args['name'] = workitem['StackName'] +'-' + get_name if @props.has_key?('name')
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"VpnCustomerGateway") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteVpnCustomerGateway',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_esppolicy.nil? || !validate_param(resolved_esppolicy,"string")
          raise "Missing mandatory parameter esppolicy for resource #{@name}"
        end
        resolved_esppolicy
      end      
      

      def get_ikepolicy
        resolved_ikepolicy = get_resolved(@props["ikepolicy"],workitem)
        if resolved_ikepolicy.nil? || !validate_param(resolved_ikepolicy,"string")
          raise "Missing mandatory parameter ikepolicy for resource #{@name}"
        end
        resolved_ikepolicy
      end      
      

      def get_ipsecpsk
        resolved_ipsecpsk = get_resolved(@props["ipsecpsk"],workitem)
        if resolved_ipsecpsk.nil? || !validate_param(resolved_ipsecpsk,"string")
          raise "Missing mandatory parameter ipsecpsk for resource #{@name}"
        end
        resolved_ipsecpsk
      end      
      

      def get_cidrlist
        resolved_cidrlist = get_resolved(@props["cidrlist"],workitem)
        if resolved_cidrlist.nil? || !validate_param(resolved_cidrlist,"string")
          raise "Missing mandatory parameter cidrlist for resource #{@name}"
        end
        resolved_cidrlist
      end      
      

      def get_gateway
        resolved_gateway = get_resolved(@props["gateway"],workitem)
        if resolved_gateway.nil? || !validate_param(resolved_gateway,"string")
          raise "Missing mandatory parameter gateway for resource #{@name}"
        end
        resolved_gateway
      end      
      

      def get_esplifetime
        resolved_esplifetime = get_resolved(@props['esplifetime'],workitem)
        if resolved_esplifetime.nil? || !validate_param(resolved_esplifetime,"long")
          raise "Malformed optional parameter esplifetime for resource #{@name}"
        end
        resolved_esplifetime
      end
      

      def get_dpd
        resolved_dpd = get_resolved(@props['dpd'],workitem)
        if resolved_dpd.nil? || !validate_param(resolved_dpd,"boolean")
          raise "Malformed optional parameter dpd for resource #{@name}"
        end
        resolved_dpd
      end
      

      def get_name
        resolved_name = get_resolved(@props['name'],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Malformed optional parameter name for resource #{@name}"
        end
        resolved_name
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_ikelifetime
        resolved_ikelifetime = get_resolved(@props['ikelifetime'],workitem)
        if resolved_ikelifetime.nil? || !validate_param(resolved_ikelifetime,"long")
          raise "Malformed optional parameter ikelifetime for resource #{@name}"
        end
        resolved_ikelifetime
      end
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"VpnGateway") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteVpnGateway',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_vpcid.nil? || !validate_param(resolved_vpcid,"uuid")
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
          resource_obj = result_obj['securitygroup']['egressrule'.downcase][0]
          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('ruleid'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"SecurityGroupEgress") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('revokeSecurityGroupEgress',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_cidrlist
        resolved_cidrlist = get_resolved(@props['cidrlist'],workitem)
        if resolved_cidrlist.nil? || !validate_param(resolved_cidrlist,"list")
          raise "Malformed optional parameter cidrlist for resource #{@name}"
        end
        resolved_cidrlist
      end
      

      def get_securitygroupname
        resolved_securitygroupname = get_resolved(@props['securitygroupname'],workitem)
        if resolved_securitygroupname.nil? || !validate_param(resolved_securitygroupname,"string")
          raise "Malformed optional parameter securitygroupname for resource #{@name}"
        end
        resolved_securitygroupname
      end
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_endport
        resolved_endport = get_resolved(@props['endport'],workitem)
        if resolved_endport.nil? || !validate_param(resolved_endport,"integer")
          raise "Malformed optional parameter endport for resource #{@name}"
        end
        resolved_endport
      end
      

      def get_usersecuritygrouplist
        resolved_usersecuritygrouplist = get_resolved(@props['usersecuritygrouplist'],workitem)
        if resolved_usersecuritygrouplist.nil? || !validate_param(resolved_usersecuritygrouplist,"map")
          raise "Malformed optional parameter usersecuritygrouplist for resource #{@name}"
        end
        resolved_usersecuritygrouplist
      end
      

      def get_protocol
        resolved_protocol = get_resolved(@props['protocol'],workitem)
        if resolved_protocol.nil? || !validate_param(resolved_protocol,"string")
          raise "Malformed optional parameter protocol for resource #{@name}"
        end
        resolved_protocol
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_icmptype
        resolved_icmptype = get_resolved(@props['icmptype'],workitem)
        if resolved_icmptype.nil? || !validate_param(resolved_icmptype,"integer")
          raise "Malformed optional parameter icmptype for resource #{@name}"
        end
        resolved_icmptype
      end
      

      def get_startport
        resolved_startport = get_resolved(@props['startport'],workitem)
        if resolved_startport.nil? || !validate_param(resolved_startport,"integer")
          raise "Malformed optional parameter startport for resource #{@name}"
        end
        resolved_startport
      end
      

      def get_icmpcode
        resolved_icmpcode = get_resolved(@props['icmpcode'],workitem)
        if resolved_icmpcode.nil? || !validate_param(resolved_icmpcode,"integer")
          raise "Malformed optional parameter icmpcode for resource #{@name}"
        end
        resolved_icmpcode
      end
      

      def get_projectid
        resolved_projectid = get_resolved(@props['projectid'],workitem)
        if resolved_projectid.nil? || !validate_param(resolved_projectid,"uuid")
          raise "Malformed optional parameter projectid for resource #{@name}"
        end
        resolved_projectid
      end
      

      def get_securitygroupid
        resolved_securitygroupid = get_resolved(@props['securitygroupid'],workitem)
        if resolved_securitygroupid.nil? || !validate_param(resolved_securitygroupid,"uuid")
          raise "Malformed optional parameter securitygroupid for resource #{@name}"
        end
        resolved_securitygroupid
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"Iso") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'virtualmachineid' => physical_id
                  }
            result_obj = make_async_request('detachIso',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_id.nil? || !validate_param(resolved_id,"uuid")
          raise "Missing mandatory parameter id for resource #{@name}"
        end
        resolved_id
      end      
      

      def get_virtualmachineid
        resolved_virtualmachineid = get_resolved(@props["virtualmachineid"],workitem)
        if resolved_virtualmachineid.nil? || !validate_param(resolved_virtualmachineid,"uuid")
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"Tags") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'resourcetype' => physical_id
                  }
            result_obj = make_async_request('deleteTags',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_resourceids.nil? || !validate_param(resolved_resourceids,"list")
          raise "Missing mandatory parameter resourceids for resource #{@name}"
        end
        resolved_resourceids
      end      
      

      def get_tags
        resolved_tags = get_resolved(@props["tags"],workitem)
        if resolved_tags.nil? || !validate_param(resolved_tags,"map")
          raise "Missing mandatory parameter tags for resource #{@name}"
        end
        resolved_tags
      end      
      

      def get_resourcetype
        resolved_resourcetype = get_resolved(@props["resourcetype"],workitem)
        if resolved_resourcetype.nil? || !validate_param(resolved_resourcetype,"string")
          raise "Missing mandatory parameter resourcetype for resource #{@name}"
        end
        resolved_resourcetype
      end      
      

      def get_customer
        resolved_customer = get_resolved(@props['customer'],workitem)
        if resolved_customer.nil? || !validate_param(resolved_customer,"string")
          raise "Malformed optional parameter customer for resource #{@name}"
        end
        resolved_customer
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"AutoScaleVmGroup") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('disableAutoScaleVmGroup',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_id.nil? || !validate_param(resolved_id,"uuid")
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"SnapshotPolicy") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_sync_request('deleteSnapshotPolicy',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_volumeid.nil? || !validate_param(resolved_volumeid,"uuid")
          raise "Missing mandatory parameter volumeid for resource #{@name}"
        end
        resolved_volumeid
      end      
      

      def get_maxsnaps
        resolved_maxsnaps = get_resolved(@props["maxsnaps"],workitem)
        if resolved_maxsnaps.nil? || !validate_param(resolved_maxsnaps,"integer")
          raise "Missing mandatory parameter maxsnaps for resource #{@name}"
        end
        resolved_maxsnaps
      end      
      

      def get_schedule
        resolved_schedule = get_resolved(@props["schedule"],workitem)
        if resolved_schedule.nil? || !validate_param(resolved_schedule,"string")
          raise "Missing mandatory parameter schedule for resource #{@name}"
        end
        resolved_schedule
      end      
      

      def get_intervaltype
        resolved_intervaltype = get_resolved(@props["intervaltype"],workitem)
        if resolved_intervaltype.nil? || !validate_param(resolved_intervaltype,"string")
          raise "Missing mandatory parameter intervaltype for resource #{@name}"
        end
        resolved_intervaltype
      end      
      

      def get_timezone
        resolved_timezone = get_resolved(@props["timezone"],workitem)
        if resolved_timezone.nil? || !validate_param(resolved_timezone,"string")
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"NetworkACL") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteNetworkACL',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_protocol.nil? || !validate_param(resolved_protocol,"string")
          raise "Missing mandatory parameter protocol for resource #{@name}"
        end
        resolved_protocol
      end      
      

      def get_networkid
        resolved_networkid = get_resolved(@props['networkid'],workitem)
        if resolved_networkid.nil? || !validate_param(resolved_networkid,"uuid")
          raise "Malformed optional parameter networkid for resource #{@name}"
        end
        resolved_networkid
      end
      

      def get_endport
        resolved_endport = get_resolved(@props['endport'],workitem)
        if resolved_endport.nil? || !validate_param(resolved_endport,"integer")
          raise "Malformed optional parameter endport for resource #{@name}"
        end
        resolved_endport
      end
      

      def get_action
        resolved_action = get_resolved(@props['action'],workitem)
        if resolved_action.nil? || !validate_param(resolved_action,"string")
          raise "Malformed optional parameter action for resource #{@name}"
        end
        resolved_action
      end
      

      def get_startport
        resolved_startport = get_resolved(@props['startport'],workitem)
        if resolved_startport.nil? || !validate_param(resolved_startport,"integer")
          raise "Malformed optional parameter startport for resource #{@name}"
        end
        resolved_startport
      end
      

      def get_traffictype
        resolved_traffictype = get_resolved(@props['traffictype'],workitem)
        if resolved_traffictype.nil? || !validate_param(resolved_traffictype,"string")
          raise "Malformed optional parameter traffictype for resource #{@name}"
        end
        resolved_traffictype
      end
      

      def get_cidrlist
        resolved_cidrlist = get_resolved(@props['cidrlist'],workitem)
        if resolved_cidrlist.nil? || !validate_param(resolved_cidrlist,"list")
          raise "Malformed optional parameter cidrlist for resource #{@name}"
        end
        resolved_cidrlist
      end
      

      def get_icmpcode
        resolved_icmpcode = get_resolved(@props['icmpcode'],workitem)
        if resolved_icmpcode.nil? || !validate_param(resolved_icmpcode,"integer")
          raise "Malformed optional parameter icmpcode for resource #{@name}"
        end
        resolved_icmpcode
      end
      

      def get_aclid
        resolved_aclid = get_resolved(@props['aclid'],workitem)
        if resolved_aclid.nil? || !validate_param(resolved_aclid,"uuid")
          raise "Malformed optional parameter aclid for resource #{@name}"
        end
        resolved_aclid
      end
      

      def get_number
        resolved_number = get_resolved(@props['number'],workitem)
        if resolved_number.nil? || !validate_param(resolved_number,"integer")
          raise "Malformed optional parameter number for resource #{@name}"
        end
        resolved_number
      end
      

      def get_icmptype
        resolved_icmptype = get_resolved(@props['icmptype'],workitem)
        if resolved_icmptype.nil? || !validate_param(resolved_icmptype,"integer")
          raise "Malformed optional parameter icmptype for resource #{@name}"
        end
        resolved_icmptype
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
          args['name'] = workitem['StackName'] +'-' + get_name
          args['vpcofferingid'] = get_vpcofferingid
          args['displaytext'] = get_displaytext
          args['projectid'] = get_projectid if @props.has_key?('projectid')
          args['account'] = get_account if @props.has_key?('account')
          args['domainid'] = get_domainid if @props.has_key?('domainid')
          args['networkdomain'] = get_networkdomain if @props.has_key?('networkdomain')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('createVPC',args)
          resource_obj = result_obj['VPC'.downcase]
          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"VPC") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteVPC',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_cidr.nil? || !validate_param(resolved_cidr,"string")
          raise "Missing mandatory parameter cidr for resource #{@name}"
        end
        resolved_cidr
      end      
      

      def get_zoneid
        resolved_zoneid = get_resolved(@props["zoneid"],workitem)
        if resolved_zoneid.nil? || !validate_param(resolved_zoneid,"uuid")
          raise "Missing mandatory parameter zoneid for resource #{@name}"
        end
        resolved_zoneid
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_vpcofferingid
        resolved_vpcofferingid = get_resolved(@props["vpcofferingid"],workitem)
        if resolved_vpcofferingid.nil? || !validate_param(resolved_vpcofferingid,"uuid")
          raise "Missing mandatory parameter vpcofferingid for resource #{@name}"
        end
        resolved_vpcofferingid
      end      
      

      def get_displaytext
        resolved_displaytext = get_resolved(@props["displaytext"],workitem)
        if resolved_displaytext.nil? || !validate_param(resolved_displaytext,"string")
          raise "Missing mandatory parameter displaytext for resource #{@name}"
        end
        resolved_displaytext
      end      
      

      def get_projectid
        resolved_projectid = get_resolved(@props['projectid'],workitem)
        if resolved_projectid.nil? || !validate_param(resolved_projectid,"uuid")
          raise "Malformed optional parameter projectid for resource #{@name}"
        end
        resolved_projectid
      end
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_networkdomain
        resolved_networkdomain = get_resolved(@props['networkdomain'],workitem)
        if resolved_networkdomain.nil? || !validate_param(resolved_networkdomain,"string")
          raise "Malformed optional parameter networkdomain for resource #{@name}"
        end
        resolved_networkdomain
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
        
          args['name'] = workitem['StackName'] +'-' + get_name
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"Volume") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
        rescue NoMethodError => nme 
          logger.error("Create request failed for resource #{@name}. Cleaning up the stack")
          raise nme

        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_sync_request('deleteVolume',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_maxiops
        resolved_maxiops = get_resolved(@props['maxiops'],workitem)
        if resolved_maxiops.nil? || !validate_param(resolved_maxiops,"long")
          raise "Malformed optional parameter maxiops for resource #{@name}"
        end
        resolved_maxiops
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_projectid
        resolved_projectid = get_resolved(@props['projectid'],workitem)
        if resolved_projectid.nil? || !validate_param(resolved_projectid,"uuid")
          raise "Malformed optional parameter projectid for resource #{@name}"
        end
        resolved_projectid
      end
      

      def get_displayvolume
        resolved_displayvolume = get_resolved(@props['displayvolume'],workitem)
        if resolved_displayvolume.nil? || !validate_param(resolved_displayvolume,"boolean")
          raise "Malformed optional parameter displayvolume for resource #{@name}"
        end
        resolved_displayvolume
      end
      

      def get_snapshotid
        resolved_snapshotid = get_resolved(@props['snapshotid'],workitem)
        if resolved_snapshotid.nil? || !validate_param(resolved_snapshotid,"uuid")
          raise "Malformed optional parameter snapshotid for resource #{@name}"
        end
        resolved_snapshotid
      end
      

      def get_miniops
        resolved_miniops = get_resolved(@props['miniops'],workitem)
        if resolved_miniops.nil? || !validate_param(resolved_miniops,"long")
          raise "Malformed optional parameter miniops for resource #{@name}"
        end
        resolved_miniops
      end
      

      def get_diskofferingid
        resolved_diskofferingid = get_resolved(@props['diskofferingid'],workitem)
        if resolved_diskofferingid.nil? || !validate_param(resolved_diskofferingid,"uuid")
          raise "Malformed optional parameter diskofferingid for resource #{@name}"
        end
        resolved_diskofferingid
      end
      

      def get_size
        resolved_size = get_resolved(@props['size'],workitem)
        if resolved_size.nil? || !validate_param(resolved_size,"long")
          raise "Malformed optional parameter size for resource #{@name}"
        end
        resolved_size
      end
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_zoneid
        resolved_zoneid = get_resolved(@props['zoneid'],workitem)
        if resolved_zoneid.nil? || !validate_param(resolved_zoneid,"uuid")
          raise "Malformed optional parameter zoneid for resource #{@name}"
        end
        resolved_zoneid
      end
      
end
    
   class CloudStackToLoadBalancerRule < CloudStackResource

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
          args['virtualmachineids'] = get_virtualmachineids

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('assignToLoadBalancerRule',args)
          resource_obj = result_obj['ToLoadBalancerRule'.downcase]
          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"ToLoadBalancerRule") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'virtualmachineids' => physical_id
                  }
            result_obj = make_async_request('removeToLoadBalancerRule',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_id.nil? || !validate_param(resolved_id,"uuid")
          raise "Missing mandatory parameter id for resource #{@name}"
        end
        resolved_id
      end      
      

      def get_virtualmachineids
        resolved_virtualmachineids = get_resolved(@props["virtualmachineids"],workitem)
        if resolved_virtualmachineids.nil? || !validate_param(resolved_virtualmachineids,"list")
          raise "Missing mandatory parameter virtualmachineids for resource #{@name}"
        end
        resolved_virtualmachineids
      end      
      
end
    
   class CloudStackVirtualMachineOps < CloudStackResource

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
          args['hostid'] = get_hostid if @props.has_key?('hostid')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('startVirtualMachine',args)
          resource_obj = result_obj['VirtualMachine'.downcase]
          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"VirtualMachine") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('stopVirtualMachine',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_id.nil? || !validate_param(resolved_id,"uuid")
          raise "Missing mandatory parameter id for resource #{@name}"
        end
        resolved_id
      end      
      

      def get_hostid
        resolved_hostid = get_resolved(@props['hostid'],workitem)
        if resolved_hostid.nil? || !validate_param(resolved_hostid,"uuid")
          raise "Malformed optional parameter hostid for resource #{@name}"
        end
        resolved_hostid
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"RemoteAccessVpn") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'publicipid' => physical_id
                  }
            result_obj = make_async_request('deleteRemoteAccessVpn',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_publicipid.nil? || !validate_param(resolved_publicipid,"uuid")
          raise "Missing mandatory parameter publicipid for resource #{@name}"
        end
        resolved_publicipid
      end      
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_openfirewall
        resolved_openfirewall = get_resolved(@props['openfirewall'],workitem)
        if resolved_openfirewall.nil? || !validate_param(resolved_openfirewall,"boolean")
          raise "Malformed optional parameter openfirewall for resource #{@name}"
        end
        resolved_openfirewall
      end
      

      def get_iprange
        resolved_iprange = get_resolved(@props['iprange'],workitem)
        if resolved_iprange.nil? || !validate_param(resolved_iprange,"string")
          raise "Malformed optional parameter iprange for resource #{@name}"
        end
        resolved_iprange
      end
      
end
    
   class CloudStackIpAddress < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        
          args['networkid'] = get_networkid if @props.has_key?('networkid')
          args['domainid'] = get_domainid if @props.has_key?('domainid')
          args['account'] = get_account if @props.has_key?('account')
          args['vpcid'] = get_vpcid if @props.has_key?('vpcid')
          args['regionid'] = get_regionid if @props.has_key?('regionid')
          args['zoneid'] = get_zoneid if @props.has_key?('zoneid')
          args['projectid'] = get_projectid if @props.has_key?('projectid')
          args['isportable'] = get_isportable if @props.has_key?('isportable')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('associateIpAddress',args)
          resource_obj = result_obj['IpAddress'.downcase]
          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"IpAddress") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('disassociateIpAddress',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      

      def get_networkid
        resolved_networkid = get_resolved(@props['networkid'],workitem)
        if resolved_networkid.nil? || !validate_param(resolved_networkid,"uuid")
          raise "Malformed optional parameter networkid for resource #{@name}"
        end
        resolved_networkid
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_vpcid
        resolved_vpcid = get_resolved(@props['vpcid'],workitem)
        if resolved_vpcid.nil? || !validate_param(resolved_vpcid,"uuid")
          raise "Malformed optional parameter vpcid for resource #{@name}"
        end
        resolved_vpcid
      end
      

      def get_regionid
        resolved_regionid = get_resolved(@props['regionid'],workitem)
        if resolved_regionid.nil? || !validate_param(resolved_regionid,"integer")
          raise "Malformed optional parameter regionid for resource #{@name}"
        end
        resolved_regionid
      end
      

      def get_zoneid
        resolved_zoneid = get_resolved(@props['zoneid'],workitem)
        if resolved_zoneid.nil? || !validate_param(resolved_zoneid,"uuid")
          raise "Malformed optional parameter zoneid for resource #{@name}"
        end
        resolved_zoneid
      end
      

      def get_projectid
        resolved_projectid = get_resolved(@props['projectid'],workitem)
        if resolved_projectid.nil? || !validate_param(resolved_projectid,"uuid")
          raise "Malformed optional parameter projectid for resource #{@name}"
        end
        resolved_projectid
      end
      

      def get_isportable
        resolved_isportable = get_resolved(@props['isportable'],workitem)
        if resolved_isportable.nil? || !validate_param(resolved_isportable,"boolean")
          raise "Malformed optional parameter isportable for resource #{@name}"
        end
        resolved_isportable
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"VpnUser") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'username' => physical_id
                  }
            result_obj = make_async_request('removeVpnUser',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_password.nil? || !validate_param(resolved_password,"string")
          raise "Missing mandatory parameter password for resource #{@name}"
        end
        resolved_password
      end      
      

      def get_username
        resolved_username = get_resolved(@props["username"],workitem)
        if resolved_username.nil? || !validate_param(resolved_username,"string")
          raise "Missing mandatory parameter username for resource #{@name}"
        end
        resolved_username
      end      
      

      def get_projectid
        resolved_projectid = get_resolved(@props['projectid'],workitem)
        if resolved_projectid.nil? || !validate_param(resolved_projectid,"uuid")
          raise "Malformed optional parameter projectid for resource #{@name}"
        end
        resolved_projectid
      end
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
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
        
          args['name'] = workitem['StackName'] +'-' + get_name
          args['displaytext'] = get_displaytext
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"Project") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteProject',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_displaytext
        resolved_displaytext = get_resolved(@props["displaytext"],workitem)
        if resolved_displaytext.nil? || !validate_param(resolved_displaytext,"string")
          raise "Missing mandatory parameter displaytext for resource #{@name}"
        end
        resolved_displaytext
      end      
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
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
          args['name'] = workitem['StackName'] +'-' + get_name
          args['algorithm'] = get_algorithm
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"LoadBalancerRule") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteLoadBalancerRule',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_publicport.nil? || !validate_param(resolved_publicport,"integer")
          raise "Missing mandatory parameter publicport for resource #{@name}"
        end
        resolved_publicport
      end      
      

      def get_privateport
        resolved_privateport = get_resolved(@props["privateport"],workitem)
        if resolved_privateport.nil? || !validate_param(resolved_privateport,"integer")
          raise "Missing mandatory parameter privateport for resource #{@name}"
        end
        resolved_privateport
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_algorithm
        resolved_algorithm = get_resolved(@props["algorithm"],workitem)
        if resolved_algorithm.nil? || !validate_param(resolved_algorithm,"string")
          raise "Missing mandatory parameter algorithm for resource #{@name}"
        end
        resolved_algorithm
      end      
      

      def get_description
        resolved_description = get_resolved(@props['description'],workitem)
        if resolved_description.nil? || !validate_param(resolved_description,"string")
          raise "Malformed optional parameter description for resource #{@name}"
        end
        resolved_description
      end
      

      def get_networkid
        resolved_networkid = get_resolved(@props['networkid'],workitem)
        if resolved_networkid.nil? || !validate_param(resolved_networkid,"uuid")
          raise "Malformed optional parameter networkid for resource #{@name}"
        end
        resolved_networkid
      end
      

      def get_openfirewall
        resolved_openfirewall = get_resolved(@props['openfirewall'],workitem)
        if resolved_openfirewall.nil? || !validate_param(resolved_openfirewall,"boolean")
          raise "Malformed optional parameter openfirewall for resource #{@name}"
        end
        resolved_openfirewall
      end
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_publicipid
        resolved_publicipid = get_resolved(@props['publicipid'],workitem)
        if resolved_publicipid.nil? || !validate_param(resolved_publicipid,"uuid")
          raise "Malformed optional parameter publicipid for resource #{@name}"
        end
        resolved_publicipid
      end
      

      def get_zoneid
        resolved_zoneid = get_resolved(@props['zoneid'],workitem)
        if resolved_zoneid.nil? || !validate_param(resolved_zoneid,"uuid")
          raise "Malformed optional parameter zoneid for resource #{@name}"
        end
        resolved_zoneid
      end
      

      def get_cidrlist
        resolved_cidrlist = get_resolved(@props['cidrlist'],workitem)
        if resolved_cidrlist.nil? || !validate_param(resolved_cidrlist,"list")
          raise "Malformed optional parameter cidrlist for resource #{@name}"
        end
        resolved_cidrlist
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"AutoScalePolicy") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteAutoScalePolicy',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_action.nil? || !validate_param(resolved_action,"string")
          raise "Missing mandatory parameter action for resource #{@name}"
        end
        resolved_action
      end      
      

      def get_duration
        resolved_duration = get_resolved(@props["duration"],workitem)
        if resolved_duration.nil? || !validate_param(resolved_duration,"integer")
          raise "Missing mandatory parameter duration for resource #{@name}"
        end
        resolved_duration
      end      
      

      def get_conditionids
        resolved_conditionids = get_resolved(@props["conditionids"],workitem)
        if resolved_conditionids.nil? || !validate_param(resolved_conditionids,"list")
          raise "Missing mandatory parameter conditionids for resource #{@name}"
        end
        resolved_conditionids
      end      
      

      def get_quiettime
        resolved_quiettime = get_resolved(@props['quiettime'],workitem)
        if resolved_quiettime.nil? || !validate_param(resolved_quiettime,"integer")
          raise "Malformed optional parameter quiettime for resource #{@name}"
        end
        resolved_quiettime
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
          args['name'] = workitem['StackName'] +'-' + get_name
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"LBStickinessPolicy") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteLBStickinessPolicy',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_methodname.nil? || !validate_param(resolved_methodname,"string")
          raise "Missing mandatory parameter methodname for resource #{@name}"
        end
        resolved_methodname
      end      
      

      def get_lbruleid
        resolved_lbruleid = get_resolved(@props["lbruleid"],workitem)
        if resolved_lbruleid.nil? || !validate_param(resolved_lbruleid,"uuid")
          raise "Missing mandatory parameter lbruleid for resource #{@name}"
        end
        resolved_lbruleid
      end      
      

      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      

      def get_param
        resolved_param = get_resolved(@props['param'],workitem)
        if resolved_param.nil? || !validate_param(resolved_param,"map")
          raise "Malformed optional parameter param for resource #{@name}"
        end
        resolved_param
      end
      

      def get_description
        resolved_description = get_resolved(@props['description'],workitem)
        if resolved_description.nil? || !validate_param(resolved_description,"string")
          raise "Malformed optional parameter description for resource #{@name}"
        end
        resolved_description
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"Snapshot") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteSnapshot',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_volumeid.nil? || !validate_param(resolved_volumeid,"uuid")
          raise "Missing mandatory parameter volumeid for resource #{@name}"
        end
        resolved_volumeid
      end      
      

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end
      

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
      

      def get_policyid
        resolved_policyid = get_resolved(@props['policyid'],workitem)
        if resolved_policyid.nil? || !validate_param(resolved_policyid,"uuid")
          raise "Malformed optional parameter policyid for resource #{@name}"
        end
        resolved_policyid
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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"FirewallRule") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
  
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        

      end
      

      def delete
        logger.debug("Deleting resource #{@name}")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'id' => physical_id
                  }
            result_obj = make_async_request('deleteFirewallRule',args)
            if (!(result_obj['error'] == true))
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
        @props.downcase_key
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
        if resolved_protocol.nil? || !validate_param(resolved_protocol,"string")
          raise "Missing mandatory parameter protocol for resource #{@name}"
        end
        resolved_protocol
      end      
      

      def get_ipaddressid
        resolved_ipaddressid = get_resolved(@props["ipaddressid"],workitem)
        if resolved_ipaddressid.nil? || !validate_param(resolved_ipaddressid,"uuid")
          raise "Missing mandatory parameter ipaddressid for resource #{@name}"
        end
        resolved_ipaddressid
      end      
      

      def get_startport
        resolved_startport = get_resolved(@props['startport'],workitem)
        if resolved_startport.nil? || !validate_param(resolved_startport,"integer")
          raise "Malformed optional parameter startport for resource #{@name}"
        end
        resolved_startport
      end
      

      def get_cidrlist
        resolved_cidrlist = get_resolved(@props['cidrlist'],workitem)
        if resolved_cidrlist.nil? || !validate_param(resolved_cidrlist,"list")
          raise "Malformed optional parameter cidrlist for resource #{@name}"
        end
        resolved_cidrlist
      end
      

      def get_icmpcode
        resolved_icmpcode = get_resolved(@props['icmpcode'],workitem)
        if resolved_icmpcode.nil? || !validate_param(resolved_icmpcode,"integer")
          raise "Malformed optional parameter icmpcode for resource #{@name}"
        end
        resolved_icmpcode
      end
      

      def get_type
        resolved_type = get_resolved(@props['type'],workitem)
        if resolved_type.nil? || !validate_param(resolved_type,"string")
          raise "Malformed optional parameter type for resource #{@name}"
        end
        resolved_type
      end
      

      def get_icmptype
        resolved_icmptype = get_resolved(@props['icmptype'],workitem)
        if resolved_icmptype.nil? || !validate_param(resolved_icmptype,"integer")
          raise "Malformed optional parameter icmptype for resource #{@name}"
        end
        resolved_icmptype
      end
      

      def get_endport
        resolved_endport = get_resolved(@props['endport'],workitem)
        if resolved_endport.nil? || !validate_param(resolved_endport,"integer")
          raise "Malformed optional parameter endport for resource #{@name}"
        end
        resolved_endport
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
    svc_offer = resolved[props['InstanceType']['Ref']] #TODO fragile
    svc_offer = @localized['service_offerings'][svc_offer] if @localized['service_offerings']
    args = { 'serviceofferingid' => svc_offer,
             'templateid' => templateid,
             'zoneid' => default_zone_id,
             'securitygroupnames' => security_group_names.join(','),
             'displayname' => myname,
             #'name' => myname
    }
    args['keypair'] = keypair if keypair
    args['userdata'] = userdata if userdata
    resultobj = make_async_request('deployVirtualMachine', args)
    logger.debug("Created resource #{myname}")

    logger.debug("result = #{resultobj.inspect}")
    workitem[participant_name][:physical_id] = resultobj['virtualmachine']['id']
    workitem[participant_name][:AvailabilityZone] = resultobj['virtualmachine']['zoneid']
    ipaddress = resultobj['virtualmachine']['nic'][0]['ipaddress']
    workitem[participant_name][:PrivateDnsName] = ipaddress
    workitem[participant_name][:PublicDnsName] = ipaddress
    workitem[participant_name][:PrivateIp] = ipaddress
    workitem[participant_name][:PublicIp] = ipaddress
  end

  def delete
    logger.info "In delete #{participant_name}"
    return nil if !workitem[participant_name]
    physical_id = workitem[participant_name]['physical_id']
    if physical_id
      args = {'id' => physical_id}
      del_resp = make_async_request('destroyVirtualMachine', args)
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
      #ImageId : { "Fn::FindInMap" : [ "Map1", { "Ref" : "OuterKey" },
      # { "Fn::FindInMap" : [ "Map2", { "Ref" : "InnerKey" }, "InnerVal" ] } ] },
      #ImageId : { "Fn::FindInMap" : [ "Map1", { "Ref" : "Key" }, "Value" ] } ] },
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


class CloudStackSecurityGroupAWS < CloudStackResource

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
    sg_resp = make_sync_request('createSecurityGroup', args)
    logger.debug("created resource #{myname}")
    props['SecurityGroupIngress'].each do |rule|
        cidrIp = rule['CidrIp']
        if cidrIp.kind_of? Hash
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
        make_async_request('authorizeSecurityGroupIngress', args)
    end
    workitem[participant_name][:physical_id] = sg_resp['securitygroup']['id']
  end

  def delete
    logger.info "In delete #{participant_name}"
    return nil if !workitem[participant_name]
    logger.info "In delete #{participant_name} #{workitem[participant_name].inspect}"
    physical_id = workitem[participant_name]['physical_id']
    if physical_id
      args = {'id' => physical_id}
      del_resp = make_sync_request('deleteSecurityGroup', args)
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


class CloudStackOutput < Ruote::Participant
  include Logging
  include Intrinsic

  def on_workitem
    logger.debug "Entering #{workitem.participant_name} "
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
