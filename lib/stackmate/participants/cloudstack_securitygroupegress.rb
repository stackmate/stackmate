require 'stackmate/participants/cloudstack'

module StackMate
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
            result_obj = make_async_request('revokeSecurityGroupEgress',args)
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
end
    