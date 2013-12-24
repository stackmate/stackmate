require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackVpnCustomerGateway < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
          args['esppolicy'] = get_esppolicy
          args['ikepolicy'] = get_ikepolicy
          args['ipsecpsk'] = get_ipsecpsk
          args['cidrlist'] = get_cidrlist
          args['gateway'] = get_gateway
          args['esplifetime'] = get_esplifetime if @props.has_key?('esplifetime')
          args['dpd'] = get_dpd if @props.has_key?('dpd')
          args['name'] = workitem['StackName'] +'-' +get_name if @props.has_key?('name')
          args['domainid'] = get_domainid if @props.has_key?('domainid')
          args['ikelifetime'] = get_ikelifetime if @props.has_key?('ikelifetime')
          args['account'] = get_account if @props.has_key?('account')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('createVpnCustomerGateway',args)
          resource_obj = result_obj['VpnCustomerGateway'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"VpnCustomerGateway") if @props.has_key?('tags')
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
            result_obj = make_async_request('deleteVpnCustomerGateway',args)
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
      
      def get_esppolicy
        resolved_esppolicy = get_resolved(@props["esppolicy"],workitem)
        if resolved_esppolicy.nil? || !validate_param(resolved_esppolicy,"string")
          raise "Missing mandatory parameter esppolicy for resource #{@name}"
        end
        resolved_esppolicy
      end      
      
      def get_ikepolicy
        resolved_ikepolicy = get_resolved(@props["ikepolicy"],workitem)
        if resolved_ikepolicy.nil? || !validate_param(resolved_ikepolicy,"string")
          raise "Missing mandatory parameter ikepolicy for resource #{@name}"
        end
        resolved_ikepolicy
      end      
      
      def get_ipsecpsk
        resolved_ipsecpsk = get_resolved(@props["ipsecpsk"],workitem)
        if resolved_ipsecpsk.nil? || !validate_param(resolved_ipsecpsk,"string")
          raise "Missing mandatory parameter ipsecpsk for resource #{@name}"
        end
        resolved_ipsecpsk
      end      
      
      def get_cidrlist
        resolved_cidrlist = get_resolved(@props["cidrlist"],workitem)
        if resolved_cidrlist.nil? || !validate_param(resolved_cidrlist,"string")
          raise "Missing mandatory parameter cidrlist for resource #{@name}"
        end
        resolved_cidrlist
      end      
      
      def get_gateway
        resolved_gateway = get_resolved(@props["gateway"],workitem)
        if resolved_gateway.nil? || !validate_param(resolved_gateway,"string")
          raise "Missing mandatory parameter gateway for resource #{@name}"
        end
        resolved_gateway
      end      
      
      def get_esplifetime
        resolved_esplifetime = get_resolved(@props['esplifetime'],workitem)
        if resolved_esplifetime.nil? || !validate_param(resolved_esplifetime,"long")
          raise "Malformed optional parameter esplifetime for resource #{@name}"
        end
        resolved_esplifetime
      end

      def get_dpd
        resolved_dpd = get_resolved(@props['dpd'],workitem)
        if resolved_dpd.nil? || !validate_param(resolved_dpd,"boolean")
          raise "Malformed optional parameter dpd for resource #{@name}"
        end
        resolved_dpd
      end

      def get_name
        resolved_name = get_resolved(@props['name'],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Malformed optional parameter name for resource #{@name}"
        end
        resolved_name
      end

      def get_domainid
        resolved_domainid = get_resolved(@props['domainid'],workitem)
        if resolved_domainid.nil? || !validate_param(resolved_domainid,"uuid")
          raise "Malformed optional parameter domainid for resource #{@name}"
        end
        resolved_domainid
      end

      def get_ikelifetime
        resolved_ikelifetime = get_resolved(@props['ikelifetime'],workitem)
        if resolved_ikelifetime.nil? || !validate_param(resolved_ikelifetime,"long")
          raise "Malformed optional parameter ikelifetime for resource #{@name}"
        end
        resolved_ikelifetime
      end

      def get_account
        resolved_account = get_resolved(@props['account'],workitem)
        if resolved_account.nil? || !validate_param(resolved_account,"string")
          raise "Malformed optional parameter account for resource #{@name}"
        end
        resolved_account
      end
  end
end
    