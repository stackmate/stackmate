require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackPortForwardingRule < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
          args['privateport'] = get_privateport
          args['protocol'] = get_protocol
          args['ipaddressid'] = get_ipaddressid
          args['virtualmachineid'] = get_virtualmachineid
          args['publicport'] = get_publicport
          args['privateendport'] = get_privateendport if @props.has_key?('privateendport')
          args['cidrlist'] = get_cidrlist if @props.has_key?('cidrlist')
          args['vmguestip'] = get_vmguestip if @props.has_key?('vmguestip')
          args['networkid'] = get_networkid if @props.has_key?('networkid')
          args['publicendport'] = get_publicendport if @props.has_key?('publicendport')
          args['openfirewall'] = get_openfirewall if @props.has_key?('openfirewall')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('createPortForwardingRule',args)
          resource_obj = result_obj['PortForwardingRule'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"PortForwardingRule") if @props.has_key?('tags')
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
            result_obj = make_async_request('deletePortForwardingRule',args)
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
      
      def get_privateport
        resolved_privateport = get_resolved(@props["privateport"],workitem)
        if resolved_privateport.nil? || !validate_param(resolved_privateport,"integer")
          raise "Missing mandatory parameter privateport for resource #{@name}"
        end
        resolved_privateport
      end      
      
      def get_protocol
        resolved_protocol = get_resolved(@props["protocol"],workitem)
        if resolved_protocol.nil? || !validate_param(resolved_protocol,"string")
          raise "Missing mandatory parameter protocol for resource #{@name}"
        end
        resolved_protocol
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
      
      def get_publicport
        resolved_publicport = get_resolved(@props["publicport"],workitem)
        if resolved_publicport.nil? || !validate_param(resolved_publicport,"integer")
          raise "Missing mandatory parameter publicport for resource #{@name}"
        end
        resolved_publicport
      end      
      
      def get_privateendport
        resolved_privateendport = get_resolved(@props['privateendport'],workitem)
        if resolved_privateendport.nil? || !validate_param(resolved_privateendport,"integer")
          raise "Malformed optional parameter privateendport for resource #{@name}"
        end
        resolved_privateendport
      end

      def get_cidrlist
        resolved_cidrlist = get_resolved(@props['cidrlist'],workitem)
        if resolved_cidrlist.nil? || !validate_param(resolved_cidrlist,"list")
          raise "Malformed optional parameter cidrlist for resource #{@name}"
        end
        resolved_cidrlist
      end

      def get_vmguestip
        resolved_vmguestip = get_resolved(@props['vmguestip'],workitem)
        if resolved_vmguestip.nil? || !validate_param(resolved_vmguestip,"string")
          raise "Malformed optional parameter vmguestip for resource #{@name}"
        end
        resolved_vmguestip
      end

      def get_networkid
        resolved_networkid = get_resolved(@props['networkid'],workitem)
        if resolved_networkid.nil? || !validate_param(resolved_networkid,"uuid")
          raise "Malformed optional parameter networkid for resource #{@name}"
        end
        resolved_networkid
      end

      def get_publicendport
        resolved_publicendport = get_resolved(@props['publicendport'],workitem)
        if resolved_publicendport.nil? || !validate_param(resolved_publicendport,"integer")
          raise "Malformed optional parameter publicendport for resource #{@name}"
        end
        resolved_publicendport
      end

      def get_openfirewall
        resolved_openfirewall = get_resolved(@props['openfirewall'],workitem)
        if resolved_openfirewall.nil? || !validate_param(resolved_openfirewall,"boolean")
          raise "Malformed optional parameter openfirewall for resource #{@name}"
        end
        resolved_openfirewall
      end
  end
end
    