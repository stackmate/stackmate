require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackLBStickinessPolicy < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
          args['methodname'] = get_methodname
          args['lbruleid'] = get_lbruleid
          args['name'] = workitem['StackName'] +'-' +get_name
          args['param'] = get_param if @props.has_key?('param')
          args['description'] = get_description if @props.has_key?('description')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('createLBStickinessPolicy',args)
          resource_obj = result_obj['LBStickinessPolicy'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"LBStickinessPolicy") if @props.has_key?('tags')
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
            result_obj = make_async_request('deleteLBStickinessPolicy',args)
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
      
      def get_methodname
        resolved_methodname = get_resolved(@props["methodname"],workitem)
        if resolved_methodname.nil? || !validate_param(resolved_methodname,"string")
          raise "Missing mandatory parameter methodname for resource #{@name}"
        end
        resolved_methodname
      end      
      
      def get_lbruleid
        resolved_lbruleid = get_resolved(@props["lbruleid"],workitem)
        if resolved_lbruleid.nil? || !validate_param(resolved_lbruleid,"uuid")
          raise "Missing mandatory parameter lbruleid for resource #{@name}"
        end
        resolved_lbruleid
      end      
      
      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      
      def get_param
        resolved_param = get_resolved(@props['param'],workitem)
        if resolved_param.nil? || !validate_param(resolved_param,"map")
          raise "Malformed optional parameter param for resource #{@name}"
        end
        resolved_param
      end

      def get_description
        resolved_description = get_resolved(@props['description'],workitem)
        if resolved_description.nil? || !validate_param(resolved_description,"string")
          raise "Malformed optional parameter description for resource #{@name}"
        end
        resolved_description
      end
  end
end
    