require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackCondition < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
          args['threshold'] = get_threshold
          args['relationaloperator'] = get_relationaloperator
          args['counterid'] = get_counterid
          args['account'] = get_account if @props.has_key?('account')
          args['domainid'] = get_domainid if @props.has_key?('domainid')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('createCondition',args)
          resource_obj = result_obj['Condition'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"Condition") if @props.has_key?('tags')
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
            result_obj = make_async_request('deleteCondition',args)
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
      
      def get_threshold
        resolved_threshold = get_resolved(@props["threshold"],workitem)
        if resolved_threshold.nil? || !validate_param(resolved_threshold,"long")
          raise "Missing mandatory parameter threshold for resource #{@name}"
        end
        resolved_threshold
      end      
      
      def get_relationaloperator
        resolved_relationaloperator = get_resolved(@props["relationaloperator"],workitem)
        if resolved_relationaloperator.nil? || !validate_param(resolved_relationaloperator,"string")
          raise "Missing mandatory parameter relationaloperator for resource #{@name}"
        end
        resolved_relationaloperator
      end      
      
      def get_counterid
        resolved_counterid = get_resolved(@props["counterid"],workitem)
        if resolved_counterid.nil? || !validate_param(resolved_counterid,"uuid")
          raise "Missing mandatory parameter counterid for resource #{@name}"
        end
        resolved_counterid
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
  end
end
    