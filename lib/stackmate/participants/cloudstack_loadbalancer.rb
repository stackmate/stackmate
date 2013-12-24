require 'stackmate/participants/cloudstack'

module StackMate
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
          args['name'] = workitem['StackName'] +'-' +get_name
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
            result_obj = make_async_request('deleteLoadBalancer',args)
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
end
    