require 'stackmate/participants/cloudstack'

module StackMate
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
            result_obj = make_async_request('removeIpToNic',args)
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
end
    