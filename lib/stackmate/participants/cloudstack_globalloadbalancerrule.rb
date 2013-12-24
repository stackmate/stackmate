require 'stackmate/participants/cloudstack'

module StackMate
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
          args['name'] = workitem['StackName'] +'-' +get_name
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
            result_obj = make_async_request('deleteGlobalLoadBalancerRule',args)
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
end
    