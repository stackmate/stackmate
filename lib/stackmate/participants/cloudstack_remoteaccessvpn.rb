require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackRemoteAccessVpn < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
          args['publicipid'] = get_publicipid
          args['account'] = get_account if @props.has_key?('account')
          args['domainid'] = get_domainid if @props.has_key?('domainid')
          args['openfirewall'] = get_openfirewall if @props.has_key?('openfirewall')
          args['iprange'] = get_iprange if @props.has_key?('iprange')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('createRemoteAccessVpn',args)
          resource_obj = result_obj['RemoteAccessVpn'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"RemoteAccessVpn") if @props.has_key?('tags')
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
            args = {'publicipid' => physical_id
                  }
            result_obj = make_async_request('deleteRemoteAccessVpn',args)
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
      
      def get_publicipid
        resolved_publicipid = get_resolved(@props["publicipid"],workitem)
        if resolved_publicipid.nil? || !validate_param(resolved_publicipid,"uuid")
          raise "Missing mandatory parameter publicipid for resource #{@name}"
        end
        resolved_publicipid
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

      def get_openfirewall
        resolved_openfirewall = get_resolved(@props['openfirewall'],workitem)
        if resolved_openfirewall.nil? || !validate_param(resolved_openfirewall,"boolean")
          raise "Malformed optional parameter openfirewall for resource #{@name}"
        end
        resolved_openfirewall
      end

      def get_iprange
        resolved_iprange = get_resolved(@props['iprange'],workitem)
        if resolved_iprange.nil? || !validate_param(resolved_iprange,"string")
          raise "Malformed optional parameter iprange for resource #{@name}"
        end
        resolved_iprange
      end
  end
end
    