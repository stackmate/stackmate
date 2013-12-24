require 'stackmate/participants/cloudstack'

module StackMate
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
            result_obj = make_async_request('deleteNetworkACL',args)
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
end
    