require 'stackmate/participants/cloudstack'

module StackMate
  class CloudStackTemplate < CloudStackResource

    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug("Creating resource #{@name}")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
          args['displaytext'] = get_displaytext
          args['ostypeid'] = get_ostypeid
          args['name'] = workitem['StackName'] +'-' +get_name
          args['snapshotid'] = get_snapshotid if @props.has_key?('snapshotid')
          args['details'] = get_details if @props.has_key?('details')
          args['virtualmachineid'] = get_virtualmachineid if @props.has_key?('virtualmachineid')
          args['requireshvm'] = get_requireshvm if @props.has_key?('requireshvm')
          args['ispublic'] = get_ispublic if @props.has_key?('ispublic')
          args['volumeid'] = get_volumeid if @props.has_key?('volumeid')
          args['bits'] = get_bits if @props.has_key?('bits')
          args['url'] = get_url if @props.has_key?('url')
          args['templatetag'] = get_templatetag if @props.has_key?('templatetag')
          args['isdynamicallyscalable'] = get_isdynamicallyscalable if @props.has_key?('isdynamicallyscalable')
          args['passwordenabled'] = get_passwordenabled if @props.has_key?('passwordenabled')
          args['isfeatured'] = get_isfeatured if @props.has_key?('isfeatured')

          logger.info("Creating resource #{@name} with following arguments")
          p args
          result_obj = make_async_request('createTemplate',args)
          resource_obj = result_obj['Template'.downcase]

          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('id'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],"Template") if @props.has_key?('tags')
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
            result_obj = make_async_request('deleteTemplate',args)
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
      
      def get_displaytext
        resolved_displaytext = get_resolved(@props["displaytext"],workitem)
        if resolved_displaytext.nil? || !validate_param(resolved_displaytext,"string")
          raise "Missing mandatory parameter displaytext for resource #{@name}"
        end
        resolved_displaytext
      end      
      
      def get_ostypeid
        resolved_ostypeid = get_resolved(@props["ostypeid"],workitem)
        if resolved_ostypeid.nil? || !validate_param(resolved_ostypeid,"uuid")
          raise "Missing mandatory parameter ostypeid for resource #{@name}"
        end
        resolved_ostypeid
      end      
      
      def get_name
        resolved_name = get_resolved(@props["name"],workitem)
        if resolved_name.nil? || !validate_param(resolved_name,"string")
          raise "Missing mandatory parameter name for resource #{@name}"
        end
        resolved_name
      end      
      
      def get_snapshotid
        resolved_snapshotid = get_resolved(@props['snapshotid'],workitem)
        if resolved_snapshotid.nil? || !validate_param(resolved_snapshotid,"uuid")
          raise "Malformed optional parameter snapshotid for resource #{@name}"
        end
        resolved_snapshotid
      end

      def get_details
        resolved_details = get_resolved(@props['details'],workitem)
        if resolved_details.nil? || !validate_param(resolved_details,"map")
          raise "Malformed optional parameter details for resource #{@name}"
        end
        resolved_details
      end

      def get_virtualmachineid
        resolved_virtualmachineid = get_resolved(@props['virtualmachineid'],workitem)
        if resolved_virtualmachineid.nil? || !validate_param(resolved_virtualmachineid,"uuid")
          raise "Malformed optional parameter virtualmachineid for resource #{@name}"
        end
        resolved_virtualmachineid
      end

      def get_requireshvm
        resolved_requireshvm = get_resolved(@props['requireshvm'],workitem)
        if resolved_requireshvm.nil? || !validate_param(resolved_requireshvm,"boolean")
          raise "Malformed optional parameter requireshvm for resource #{@name}"
        end
        resolved_requireshvm
      end

      def get_ispublic
        resolved_ispublic = get_resolved(@props['ispublic'],workitem)
        if resolved_ispublic.nil? || !validate_param(resolved_ispublic,"boolean")
          raise "Malformed optional parameter ispublic for resource #{@name}"
        end
        resolved_ispublic
      end

      def get_volumeid
        resolved_volumeid = get_resolved(@props['volumeid'],workitem)
        if resolved_volumeid.nil? || !validate_param(resolved_volumeid,"uuid")
          raise "Malformed optional parameter volumeid for resource #{@name}"
        end
        resolved_volumeid
      end

      def get_bits
        resolved_bits = get_resolved(@props['bits'],workitem)
        if resolved_bits.nil? || !validate_param(resolved_bits,"integer")
          raise "Malformed optional parameter bits for resource #{@name}"
        end
        resolved_bits
      end

      def get_url
        resolved_url = get_resolved(@props['url'],workitem)
        if resolved_url.nil? || !validate_param(resolved_url,"string")
          raise "Malformed optional parameter url for resource #{@name}"
        end
        resolved_url
      end

      def get_templatetag
        resolved_templatetag = get_resolved(@props['templatetag'],workitem)
        if resolved_templatetag.nil? || !validate_param(resolved_templatetag,"string")
          raise "Malformed optional parameter templatetag for resource #{@name}"
        end
        resolved_templatetag
      end

      def get_isdynamicallyscalable
        resolved_isdynamicallyscalable = get_resolved(@props['isdynamicallyscalable'],workitem)
        if resolved_isdynamicallyscalable.nil? || !validate_param(resolved_isdynamicallyscalable,"boolean")
          raise "Malformed optional parameter isdynamicallyscalable for resource #{@name}"
        end
        resolved_isdynamicallyscalable
      end

      def get_passwordenabled
        resolved_passwordenabled = get_resolved(@props['passwordenabled'],workitem)
        if resolved_passwordenabled.nil? || !validate_param(resolved_passwordenabled,"boolean")
          raise "Malformed optional parameter passwordenabled for resource #{@name}"
        end
        resolved_passwordenabled
      end

      def get_isfeatured
        resolved_isfeatured = get_resolved(@props['isfeatured'],workitem)
        if resolved_isfeatured.nil? || !validate_param(resolved_isfeatured,"boolean")
          raise "Malformed optional parameter isfeatured for resource #{@name}"
        end
        resolved_isfeatured
      end
  end
end
    