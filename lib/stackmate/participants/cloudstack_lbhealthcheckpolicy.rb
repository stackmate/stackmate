require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackLBHealthCheckPolicy < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
          args['lbruleid'] = get_lbruleid
          args['responsetimeout'] = get_responsetimeout if @props.has_key?('responsetimeout')
          args['unhealthythreshold'] = get_unhealthythreshold if @props.has_key?('unhealthythreshold')
          args['pingpath'] = get_pingpath if @props.has_key?('pingpath')
          args['description'] = get_description if @props.has_key?('description')
          args['intervaltime'] = get_intervaltime if @props.has_key?('intervaltime')
          args['healthythreshold'] = get_healthythreshold if @props.has_key?('healthythreshold')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('createLBHealthCheckPolicy',args)
          resource_obj = result_obj['LBHealthCheckPolicy'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"LBHealthCheckPolicy") if @props.has_key?('tags')
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
            result_obj = make_async_request('deleteLBHealthCheckPolicy',args)
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
      
      def get_lbruleid
        resolved_lbruleid = get_resolved(@props["lbruleid"],workitem)
        if resolved_lbruleid.nil? || !validate_param(resolved_lbruleid,"uuid")
          raise "Missing mandatory parameter lbruleid for resource #{@name}"
        end
        resolved_lbruleid
      end      
      
      def get_responsetimeout
        resolved_responsetimeout = get_resolved(@props['responsetimeout'],workitem)
        if resolved_responsetimeout.nil? || !validate_param(resolved_responsetimeout,"integer")
          raise "Malformed optional parameter responsetimeout for resource #{@name}"
        end
        resolved_responsetimeout
      end

      def get_unhealthythreshold
        resolved_unhealthythreshold = get_resolved(@props['unhealthythreshold'],workitem)
        if resolved_unhealthythreshold.nil? || !validate_param(resolved_unhealthythreshold,"integer")
          raise "Malformed optional parameter unhealthythreshold for resource #{@name}"
        end
        resolved_unhealthythreshold
      end

      def get_pingpath
        resolved_pingpath = get_resolved(@props['pingpath'],workitem)
        if resolved_pingpath.nil? || !validate_param(resolved_pingpath,"string")
          raise "Malformed optional parameter pingpath for resource #{@name}"
        end
        resolved_pingpath
      end

      def get_description
        resolved_description = get_resolved(@props['description'],workitem)
        if resolved_description.nil? || !validate_param(resolved_description,"string")
          raise "Malformed optional parameter description for resource #{@name}"
        end
        resolved_description
      end

      def get_intervaltime
        resolved_intervaltime = get_resolved(@props['intervaltime'],workitem)
        if resolved_intervaltime.nil? || !validate_param(resolved_intervaltime,"integer")
          raise "Malformed optional parameter intervaltime for resource #{@name}"
        end
        resolved_intervaltime
      end

      def get_healthythreshold
        resolved_healthythreshold = get_resolved(@props['healthythreshold'],workitem)
        if resolved_healthythreshold.nil? || !validate_param(resolved_healthythreshold,"integer")
          raise "Malformed optional parameter healthythreshold for resource #{@name}"
        end
        resolved_healthythreshold
      end
  end
end
    