require 'stackmate/participants/cloudstack'

module StackMate
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
          args['name'] = workitem['StackName'] +'-' +get_name
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
            result_obj = make_async_request('deleteLoadBalancerRule',args)
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
end
    