require 'stackmate/participants/cloudstack'

module StackMate
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
          args['name'] = workitem['StackName'] +'-' +get_name
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
          set_metadata if workitem['Resources'][@name].has_key?('Metadata')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        
        rescue NoMethodError => nme
          logger.error("Create request failed for resource . Cleaning up the stack")
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
            result_obj = make_async_request('deleteNetwork',args)
            if (!(result_obj['error'] == true))
              logger.info("Successfully deleted resource #{@name}")
            else
              workitem[@name]['delete_error'] = true
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
end
    