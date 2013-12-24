require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackSnapshotPolicy < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
          args['volumeid'] = get_volumeid
          args['maxsnaps'] = get_maxsnaps
          args['schedule'] = get_schedule
          args['intervaltype'] = get_intervaltype
          args['timezone'] = get_timezone

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_sync_request('createSnapshotPolicy',args)
          resource_obj = result_obj['SnapshotPolicy'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"SnapshotPolicy") if @props.has_key?('tags')
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
            result_obj = make_sync_request('deleteSnapshotPolicy',args)
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
      
      def get_volumeid
        resolved_volumeid = get_resolved(@props["volumeid"],workitem)
        if resolved_volumeid.nil? || !validate_param(resolved_volumeid,"uuid")
          raise "Missing mandatory parameter volumeid for resource #{@name}"
        end
        resolved_volumeid
      end      
      
      def get_maxsnaps
        resolved_maxsnaps = get_resolved(@props["maxsnaps"],workitem)
        if resolved_maxsnaps.nil? || !validate_param(resolved_maxsnaps,"integer")
          raise "Missing mandatory parameter maxsnaps for resource #{@name}"
        end
        resolved_maxsnaps
      end      
      
      def get_schedule
        resolved_schedule = get_resolved(@props["schedule"],workitem)
        if resolved_schedule.nil? || !validate_param(resolved_schedule,"string")
          raise "Missing mandatory parameter schedule for resource #{@name}"
        end
        resolved_schedule
      end      
      
      def get_intervaltype
        resolved_intervaltype = get_resolved(@props["intervaltype"],workitem)
        if resolved_intervaltype.nil? || !validate_param(resolved_intervaltype,"string")
          raise "Missing mandatory parameter intervaltype for resource #{@name}"
        end
        resolved_intervaltype
      end      
      
      def get_timezone
        resolved_timezone = get_resolved(@props["timezone"],workitem)
        if resolved_timezone.nil? || !validate_param(resolved_timezone,"string")
          raise "Missing mandatory parameter timezone for resource #{@name}"
        end
        resolved_timezone
      end      
        end
end
    