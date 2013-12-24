require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackSSHKeyPair < CloudStackResource

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
          args['account'] = get_account if @props.has_key?('account')
          args['domainid'] = get_domainid if @props.has_key?('domainid')
          args['projectid'] = get_projectid if @props.has_key?('projectid')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_sync_request('createSSHKeyPair',args)
          resource_obj = result_obj['SSHKeyPair'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"SSHKeyPair") if @props.has_key?('tags')
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
            args = {'name' => physical_id
                  }
            result_obj = make_sync_request('deleteSSHKeyPair',args)
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
      
      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
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
  end
end
    