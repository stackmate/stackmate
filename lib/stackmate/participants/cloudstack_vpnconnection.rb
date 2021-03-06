require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackVpnConnection < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
          args['s2scustomergatewayid'] = get_s2scustomergatewayid
          args['s2svpngatewayid'] = get_s2svpngatewayid

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('createVpnConnection',args)
          resource_obj = result_obj['VpnConnection'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"VpnConnection") if @props.has_key?('tags')
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
            result_obj = make_async_request('deleteVpnConnection',args)
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
      
      def get_s2scustomergatewayid
        resolved_s2scustomergatewayid = get_resolved(@props["s2scustomergatewayid"],workitem)
        if resolved_s2scustomergatewayid.nil? || !validate_param(resolved_s2scustomergatewayid,"uuid")
          raise "Missing mandatory parameter s2scustomergatewayid for resource #{@name}"
        end
        resolved_s2scustomergatewayid
      end      
      
      def get_s2svpngatewayid
        resolved_s2svpngatewayid = get_resolved(@props["s2svpngatewayid"],workitem)
        if resolved_s2svpngatewayid.nil? || !validate_param(resolved_s2svpngatewayid,"uuid")
          raise "Missing mandatory parameter s2svpngatewayid for resource #{@name}"
        end
        resolved_s2svpngatewayid
      end      
        end
end
    