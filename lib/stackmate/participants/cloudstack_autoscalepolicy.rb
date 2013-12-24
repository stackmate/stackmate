require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackAutoScalePolicy < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
          args['action'] = get_action
          args['duration'] = get_duration
          args['conditionids'] = get_conditionids
          args['quiettime'] = get_quiettime if @props.has_key?('quiettime')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('createAutoScalePolicy',args)
          resource_obj = result_obj['AutoScalePolicy'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"AutoScalePolicy") if @props.has_key?('tags')
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
            result_obj = make_async_request('deleteAutoScalePolicy',args)
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
      
      def get_action
        resolved_action = get_resolved(@props["action"],workitem)
        if resolved_action.nil? || !validate_param(resolved_action,"string")
          raise "Missing mandatory parameter action for resource #{@name}"
        end
        resolved_action
      end      
      
      def get_duration
        resolved_duration = get_resolved(@props["duration"],workitem)
        if resolved_duration.nil? || !validate_param(resolved_duration,"integer")
          raise "Missing mandatory parameter duration for resource #{@name}"
        end
        resolved_duration
      end      
      
      def get_conditionids
        resolved_conditionids = get_resolved(@props["conditionids"],workitem)
        if resolved_conditionids.nil? || !validate_param(resolved_conditionids,"list")
          raise "Missing mandatory parameter conditionids for resource #{@name}"
        end
        resolved_conditionids
      end      
      
      def get_quiettime
        resolved_quiettime = get_resolved(@props['quiettime'],workitem)
        if resolved_quiettime.nil? || !validate_param(resolved_quiettime,"integer")
          raise "Malformed optional parameter quiettime for resource #{@name}"
        end
        resolved_quiettime
      end
  end
end
    