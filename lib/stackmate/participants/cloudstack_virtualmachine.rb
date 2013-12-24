require 'stackmate/participants/cloudstack'

module StackMate
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
          args['name'] = workitem['StackName'] +'-' +get_name if @props.has_key?('name')

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
          set_tags(@props['tags'],workitem[@name]['physical_id'],"UserVM") if @props.has_key?('tags')
          set_metadata if workitem['Resources'][@name].has_key?('Metadata')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        workitem[@name][:PrivateIp] = resource_obj['nic'][0]['ipaddress']

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
            result_obj = make_async_request('destroyVirtualMachine',args)
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
end
    