require 'stackmate/participants/cloudstack'

module StackMate
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
            result_obj = make_async_request('deleteIpForwardingRule',args)
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
end
    