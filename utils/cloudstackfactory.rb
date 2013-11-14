$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../")
require 'json'
require 'yaml'

module StackMate

  class CloudStackFactory

    def self.print_class(class_name,create_tag,required_fields,optional_fields,create_async,delete_tag,delete_id_tag,delete_async)
      async={}
      async[true] = 'make_async_request'
      async[false] = 'make_sync_request'
      create_request = async[create_async]
      delete_request = async[delete_async]
      api_name = class_name
      tag_name = class_name
      resource_tag = "result_obj['#{class_name}'.downcase]"
      class_name = class_name+"Ops" if ((class_name.include?("VirtualMachine") && create_tag.include?("start")) || (class_name.include?("Volume") && create_tag.include?("attach")))
      tag_name = "UserVM" if class_name.include?("VirtualMachine")
      id_tag = 'id'
      if (class_name.eql?("SecurityGroupIngress") || class_name.include?("SecurityGroupEgress"))
        gress = class_name.gsub("SecurityGroup","").downcase
        id_tag = 'ruleid'
        resource_tag = "result_obj['securitygroup']['#{gress}rule'.downcase][0]"
      end
      str = ""
      str = str + "require 'stackmate/participants/cloudstack'\n"
      str = str + "\nmodule StackMate\n"
      str = str + "  class CloudStack" + class_name + " < CloudStackResource\n"
      #puts str
      str = str + "
    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug(\"Creating resource \#{@name}\")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin\n"
      #get required fields
      #treat maps differently
      required_fields.each do |required,type|
        if required.eql?("name")
          str = str + "          args['#{required}'] = workitem['StackName'] +'-' +get_#{required}\n"
        else
          str = str + "          args['#{required}'] = get_#{required}\n"
        end
      end
      #populate optional fields
      optional_fields.each do |optional,type|
        if optional.eql?("name")
          str = str + "          args['#{optional}'] = workitem['StackName'] +'-' +get_#{optional} if @props.has_key?('#{optional}')\n"
        elsif optional.eql?("iptonetworklist")
          str = str + "
          if @props.has_key?('iptonetworklist')
            ipnetworklist = get_iptonetworklist
            #split
            list_params = ipnetworklist.split(\"&\")
            list_params.each do |p|
              fields = p.split(\"=\")
              args[fields[0]] = fields[1]
            end
          end\n"
        else
          str = str + "          args['#{optional}'] = get_#{optional} if @props.has_key?('#{optional}')\n"
        end
      end

      #make API call, populate workitem object
      str = str + "
          logger.info(\"Creating resource \#{@name} with following arguments\")
          p args
          result_obj = #{create_request}('#{create_tag}#{api_name}',args)
          resource_obj = " + resource_tag + "\n
          #doing it this way since it is easier to change later, rather than cloning whole object
          resource_obj.each_key do |k|
            val = resource_obj[k]
            if('#{id_tag}'.eql?(k))
              k = 'physical_id'
            end
            workitem[@name][k] = val
          end
          set_tags(@props['tags'],workitem[@name]['physical_id'],\"#{tag_name}\") if @props.has_key?('tags')
          workitem['ResolvedNames'][@name] = name_cs
          workitem['IdMap'][workitem[@name]['physical_id']] = @name
        "
      #set ip address for VMs
      str = str + "workitem[@name][:PrivateIp] = resource_obj['nic'][0]['ipaddress']\n" if class_name.eql?("VirtualMachine")
      #raise error if some required field is missing
      str = str + "
        rescue NoMethodError => nme
          logger.error(\"Create request failed for resource #{@name}. Cleaning up the stack\")
          raise nme
        rescue Exception => e
          logger.error(e.message)
          raise e
        end
        "
      #end method
      str = str +"
      end
      "
      str = str + "
      def delete
        logger.debug(\"Deleting resource \#{@name}\")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'#{delete_id_tag}' => physical_id
                  }
            result_obj = #{delete_request}('#{delete_tag}#{class_name}',args)
            if (!(result_obj['error'] == true))
              logger.info(\"Successfully deleted resource \#{@name}\")
            else
              logger.info(\"CloudStack error while deleting resource \#{@name}\")
            end
          else
            logger.info(\"Resource #{@name} not created in CloudStack. Skipping delete...\")
          end
        rescue Exception => e
          logger.error(\"Unable to delete resorce \#{@name}\")
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
      "
      #resolve
      required_fields.each do |required,type|
        str = str + "
      def get_#{required}
        resolved_#{required} = get_resolved(@props[\"#{required}\"],workitem)
        if resolved_#{required}.nil? || !validate_param(resolved_#{required},\"#{type}\")
          raise \"Missing mandatory parameter #{required} for resource \#{@name}\"
        end
        resolved_#{required}
      end      
      "
      end
      #Just keep separate for now
      optional_fields.each do |optional,type|
        str = str +"
      def get_#{optional}
        resolved_#{optional} = get_resolved(@props['#{optional}'],workitem)
        if resolved_#{optional}.nil? || !validate_param(resolved_#{optional},\"#{type}\")
          raise \"Malformed optional parameter #{optional} for resource \#{@name}\"
        end
        resolved_#{optional}
      end\n"
      end
      str = str + "  end
end
    "
      File.open("lib/stackmate/participants/cloudstack_" + class_name.downcase + ".rb" ,"w") { |file| file.write(str)}
    end

    def self.meta_class(class_name,create_tag,required_fields,optional_fields,create_async,delete_tag,delete_id_tag,delete_async)
      async={}
      async[true] = 'make_async_request'
      async[false] = 'make_sync_request'
      create_request = async[create_async]
      delete_request = async[delete_async]
      str = "   class CloudStack" + class_name + " < CloudStackResource"
      str = str + "\n
    include Logging
    include Intrinsic
    include Resolver
      def create
        logger.debug(\"Creating resource \#{@name}\")
        workitem[@name] = {}
        name_cs = workitem['StackName'] + '-' + @name
        args={}
        begin
        "
      #get required fields
      required_fields.each do |required,type|
        str = str + "          args['#{required}'] = get_#{required}\n"
      end
      #populate optional fields
      optional_fields.each do |optional,type|
        str = str + "          args['#{optional}'] = get_#{optional} if @props.has_key?('#{optional}')\n"
      end
      #raise error if some required field is missing
      str = str + "
        rescue Exception => e
          #logging.error(\"Missing required parameter for resource \#{@name}\")
          logger.error(e.message)
          raise e
        end
        "

      #make API call, populate workitem object
      str = str + "
        logger.info(\"Creating resource \#{@name} with following arguments\")
        p args
        result_obj = #{create_request}('#{create_tag}#{class_name}',args)
        resource_obj = result_obj['#{class_name}'.downcase]
        #doing it this way since it is easier to change later, rather than cloning whole object
        resource_obj.each_key do |k|
          val = resource_obj[k]
          if('id'.eql?(k))
            k = 'physical_id'
          end
          workitem[@name][k] = val
        end
        workitem['ResolvedNames'][@name] = name_cs
        workitem['IdMap'][workitem[@name]['physical_id']] = @name
      end
      "
      str = str + "
      def delete
        logger.debug(\"Deleting resource \#{@name}\")
        begin
          physical_id = workitem[@name]['physical_id']
          if(!physical_id.nil?)
            args = {'#{delete_id_tag}' => physical_id
                  }
            result_obj = #{delete_request}('#{delete_tag}#{class_name}',args)
            if (!result_obj.empty?)
              logger.info(\"Successfully deleted resource \#{@name}\")
            else
              logger.info(\"CloudStack error while deleting resource \#{@name}\")
            end
          else
            logger.info(\"Resource #{@name} not created in CloudStack. Skipping delete...\")
          end
        rescue Exception => e
          logger.error(\"Unable to delete resorce \#{@name}\")
        end
      end

      def on_workitem
        @name = workitem.participant_name
        @props = workitem['Resources'][@name]['Properties']
        @resolved_names = workitem['ResolvedNames']
        if workitem['params']['operation'] == 'create'
          create
        else
          delete
        end
        reply
      end
      "
      #resolve
      required_fields.each do |required,type|
        str = str + "
      def get_#{required}
        resolved_#{required} = get_resolved(@props[\"#{required}\"],workitem)
        if resolved_#{required}.nil? || !validate_param(resolved_#{required},\"#{type}\")
          raise \"Missing mandatory parameter #{required} for resource \#{@name}\"
        end
        resolved_#{required}
      end      
      "
      end
      #Just keep separate for now
      optional_fields.each do |optional,type|
        str = str + "
      def get_#{optional}
        resolved_#{optional} = get_resolved(@props['#{optional}'],workitem)
        if resolved_#{optional}.nil? || !validate_param(resolved_#{optional},\"#{type}\")
          raise \"Malformed optional parameter #{optional} for resource \#{@name}\"
        end
        resolved_#{optional}
      end
      "
      end
      str = str + "end
    "
      eval(str)
    end
    #CloudStackFactory.create_class("VPC",{},{})
    #CloudStackFactory.print_class("VPC","create",["name","networkdomain","cidr"],["displaytext","account"],"delete","vpcid")
  end

end
