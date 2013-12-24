require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackStaticNat < CloudStackResource

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
          args['virtualmachineid'] = get_virtualmachineid
          args['networkid'] = get_networkid if @props.has_key?('networkid')
          args['vmguestip'] = get_vmguestip if @props.has_key?('vmguestip')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_sync_request('enableStaticNat',args)
          resource_obj = result_obj['StaticNat'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"StaticNat") if @props.has_key?('tags')
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
            args = {'ipaddressid' => physical_id
                  }
            result_obj = make_async_request('disableStaticNat',args)
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
      
      def get_virtualmachineid
        resolved_virtualmachineid = get_resolved(@props["virtualmachineid"],workitem)
        if resolved_virtualmachineid.nil? || !validate_param(resolved_virtualmachineid,"uuid")
          raise "Missing mandatory parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end      
      
      def get_networkid
        resolved_networkid = get_resolved(@props['networkid'],workitem)
        if resolved_networkid.nil? || !validate_param(resolved_networkid,"uuid")
          raise "Malformed optional parameter networkid for resource #{@name}"
        end
        resolved_networkid
      end

      def get_vmguestip
        resolved_vmguestip = get_resolved(@props['vmguestip'],workitem)
        if resolved_vmguestip.nil? || !validate_param(resolved_vmguestip,"string")
          raise "Malformed optional parameter vmguestip for resource #{@name}"
        end
        resolved_vmguestip
      end
  end
end
    