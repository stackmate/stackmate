require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackTags < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
          args['resourceids'] = get_resourceids
          args['tags'] = get_tags
          args['resourcetype'] = get_resourcetype
          args['customer'] = get_customer if @props.has_key?('customer')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('createTags',args)
          resource_obj = result_obj['Tags'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"Tags") if @props.has_key?('tags')
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
            args = {'resourcetype' => physical_id
                  }
            result_obj = make_async_request('deleteTags',args)
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
      
      def get_resourceids
        resolved_resourceids = get_resolved(@props["resourceids"],workitem)
        if resolved_resourceids.nil? || !validate_param(resolved_resourceids,"list")
          raise "Missing mandatory parameter resourceids for resource #{@name}"
        end
        resolved_resourceids
      end      
      
      def get_tags
        resolved_tags = get_resolved(@props["tags"],workitem)
        if resolved_tags.nil? || !validate_param(resolved_tags,"map")
          raise "Missing mandatory parameter tags for resource #{@name}"
        end
        resolved_tags
      end      
      
      def get_resourcetype
        resolved_resourcetype = get_resolved(@props["resourcetype"],workitem)
        if resolved_resourcetype.nil? || !validate_param(resolved_resourcetype,"string")
          raise "Missing mandatory parameter resourcetype for resource #{@name}"
        end
        resolved_resourcetype
      end      
      
      def get_customer
        resolved_customer = get_resolved(@props['customer'],workitem)
        if resolved_customer.nil? || !validate_param(resolved_customer,"string")
          raise "Malformed optional parameter customer for resource #{@name}"
        end
        resolved_customer
      end
  end
end
    