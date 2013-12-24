require 'stackmate/participants/cloudstack'

module StackMate
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
            result_obj = make_async_request('deleteStaticRoute',args)
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
end
    