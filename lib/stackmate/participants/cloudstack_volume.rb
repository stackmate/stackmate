require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackVolume < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
          args['name'] = workitem['StackName'] +'-' +get_name
          args['maxiops'] = get_maxiops if @props.has_key?('maxiops')
          args['domainid'] = get_domainid if @props.has_key?('domainid')
          args['projectid'] = get_projectid if @props.has_key?('projectid')
          args['displayvolume'] = get_displayvolume if @props.has_key?('displayvolume')
          args['snapshotid'] = get_snapshotid if @props.has_key?('snapshotid')
          args['miniops'] = get_miniops if @props.has_key?('miniops')
          args['diskofferingid'] = get_diskofferingid if @props.has_key?('diskofferingid')
          args['size'] = get_size if @props.has_key?('size')
          args['account'] = get_account if @props.has_key?('account')
          args['zoneid'] = get_zoneid if @props.has_key?('zoneid')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('createVolume',args)
          resource_obj = result_obj['Volume'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"Volume") if @props.has_key?('tags')
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
            result_obj = make_sync_request('deleteVolume',args)
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
      
      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      
      def get_maxiops
        resolved_maxiops = get_resolved(@props['maxiops'],workitem)
        if resolved_maxiops.nil? || !validate_param(resolved_maxiops,"long")
          raise "Malformed optional parameter maxiops for resource #{@name}"
        end
        resolved_maxiops
      end

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end

      def get_projectid
        resolved_projectid = get_resolved(@props['projectid'],workitem)
        if resolved_projectid.nil? || !validate_param(resolved_projectid,"uuid")
          raise "Malformed optional parameter projectid for resource #{@name}"
        end
        resolved_projectid
      end

      def get_displayvolume
        resolved_displayvolume = get_resolved(@props['displayvolume'],workitem)
        if resolved_displayvolume.nil? || !validate_param(resolved_displayvolume,"boolean")
          raise "Malformed optional parameter displayvolume for resource #{@name}"
        end
        resolved_displayvolume
      end

      def get_snapshotid
        resolved_snapshotid = get_resolved(@props['snapshotid'],workitem)
        if resolved_snapshotid.nil? || !validate_param(resolved_snapshotid,"uuid")
          raise "Malformed optional parameter snapshotid for resource #{@name}"
        end
        resolved_snapshotid
      end

      def get_miniops
        resolved_miniops = get_resolved(@props['miniops'],workitem)
        if resolved_miniops.nil? || !validate_param(resolved_miniops,"long")
          raise "Malformed optional parameter miniops for resource #{@name}"
        end
        resolved_miniops
      end

      def get_diskofferingid
        resolved_diskofferingid = get_resolved(@props['diskofferingid'],workitem)
        if resolved_diskofferingid.nil? || !validate_param(resolved_diskofferingid,"uuid")
          raise "Malformed optional parameter diskofferingid for resource #{@name}"
        end
        resolved_diskofferingid
      end

      def get_size
        resolved_size = get_resolved(@props['size'],workitem)
        if resolved_size.nil? || !validate_param(resolved_size,"long")
          raise "Malformed optional parameter size for resource #{@name}"
        end
        resolved_size
      end

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end

      def get_zoneid
        resolved_zoneid = get_resolved(@props['zoneid'],workitem)
        if resolved_zoneid.nil? || !validate_param(resolved_zoneid,"uuid")
          raise "Malformed optional parameter zoneid for resource #{@name}"
        end
        resolved_zoneid
      end
  end
end
    