require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackAutoScaleVmProfile < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
          args['zoneid'] = get_zoneid
          args['serviceofferingid'] = get_serviceofferingid
          args['templateid'] = get_templateid
          args['otherdeployparams'] = get_otherdeployparams if @props.has_key?('otherdeployparams')
          args['destroyvmgraceperiod'] = get_destroyvmgraceperiod if @props.has_key?('destroyvmgraceperiod')
          args['autoscaleuserid'] = get_autoscaleuserid if @props.has_key?('autoscaleuserid')
          args['counterparam'] = get_counterparam if @props.has_key?('counterparam')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('createAutoScaleVmProfile',args)
          resource_obj = result_obj['AutoScaleVmProfile'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"AutoScaleVmProfile") if @props.has_key?('tags')
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
            result_obj = make_async_request('deleteAutoScaleVmProfile',args)
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
      
      def get_zoneid
        resolved_zoneid = get_resolved(@props["zoneid"],workitem)
        if resolved_zoneid.nil? || !validate_param(resolved_zoneid,"uuid")
          raise "Missing mandatory parameter zoneid for resource #{@name}"
        end
        resolved_zoneid
      end      
      
      def get_serviceofferingid
        resolved_serviceofferingid = get_resolved(@props["serviceofferingid"],workitem)
        if resolved_serviceofferingid.nil? || !validate_param(resolved_serviceofferingid,"uuid")
          raise "Missing mandatory parameter serviceofferingid for resource #{@name}"
        end
        resolved_serviceofferingid
      end      
      
      def get_templateid
        resolved_templateid = get_resolved(@props["templateid"],workitem)
        if resolved_templateid.nil? || !validate_param(resolved_templateid,"uuid")
          raise "Missing mandatory parameter templateid for resource #{@name}"
        end
        resolved_templateid
      end      
      
      def get_otherdeployparams
        resolved_otherdeployparams = get_resolved(@props['otherdeployparams'],workitem)
        if resolved_otherdeployparams.nil? || !validate_param(resolved_otherdeployparams,"string")
          raise "Malformed optional parameter otherdeployparams for resource #{@name}"
        end
        resolved_otherdeployparams
      end

      def get_destroyvmgraceperiod
        resolved_destroyvmgraceperiod = get_resolved(@props['destroyvmgraceperiod'],workitem)
        if resolved_destroyvmgraceperiod.nil? || !validate_param(resolved_destroyvmgraceperiod,"integer")
          raise "Malformed optional parameter destroyvmgraceperiod for resource #{@name}"
        end
        resolved_destroyvmgraceperiod
      end

      def get_autoscaleuserid
        resolved_autoscaleuserid = get_resolved(@props['autoscaleuserid'],workitem)
        if resolved_autoscaleuserid.nil? || !validate_param(resolved_autoscaleuserid,"uuid")
          raise "Malformed optional parameter autoscaleuserid for resource #{@name}"
        end
        resolved_autoscaleuserid
      end

      def get_counterparam
        resolved_counterparam = get_resolved(@props['counterparam'],workitem)
        if resolved_counterparam.nil? || !validate_param(resolved_counterparam,"map")
          raise "Malformed optional parameter counterparam for resource #{@name}"
        end
        resolved_counterparam
      end
  end
end
    