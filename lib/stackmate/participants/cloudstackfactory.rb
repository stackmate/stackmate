$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../")
require 'json'
require 'cloudstack_ruby_client'
require 'yaml'
require 'stackmate/logging'
require 'stackmate/intrinsic_functions'
require 'resolver'
require 'ruote'

module StackMate

class CloudStackApiException < StandardError
    def initialize(msg)
        super(msg)
    end
end

class CloudStackResource < Ruote::Participant
  include Logging

  attr_reader :name

  def initialize(opts)
      return
      @opts = opts
      @url = opts['URL'] || ENV['URL'] or raise ArgumentError.new("CloudStackResources: no URL supplied for CloudStack API")
      @apikey = opts['APIKEY'] || ENV['APIKEY'] or raise ArgumentError.new("CloudStackResources: no api key supplied for CloudStack API")
      @seckey = opts['SECKEY'] || ENV['SECKEY'] or raise ArgumentError.new("CloudStackResources: no secret key supplied for CloudStack API")
      @client = CloudstackRubyClient::Client.new(@url, @apikey, @seckey, false)
  end

  def on_workitem
    p workitem.participant_name
    reply
  end

  protected

    def make_sync_request(cmd,args)
        begin
          logger.debug "Going to make async request #{cmd} to CloudStack server for resource #{@name}"
          resp = @client.send(cmd, args)
          return resp
        rescue => e
          logger.error("Failed to make request #{cmd} to CloudStack server while creating resource #{@name}")
          logger.error e.message + "\n " + e.backtrace.join("\n ")
          raise e
        rescue SystemExit
          logger.error "Rescued a SystemExit exception"
          raise CloudStackApiException, "Did not get 200 OK while making api call #{cmd}"
        end
    end

    def make_async_request(cmd, args)
        begin
          logger.debug "Going to make async request #{cmd} to CloudStack server for resource #{@name}"
          resp = @client.send(cmd, args)
          jobid = resp['jobid'] if resp
          resp = api_poll(jobid, 3, 3) if jobid
          return resp
        rescue => e
          logger.error("Failed to make request #{cmd} to CloudStack server while creating resource #{@name}")
          logger.error e.message + "\n " + e.backtrace.join("\n ")
          raise e
        rescue SystemExit
          logger.error "Rescued a SystemExit exception"
          raise CloudStackApiException, "Did not get 200 OK while making api call #{cmd}"
        end
    end
  
    def api_poll (jobid, num, period)
      i = 0 
      loop do 
        break if i > num
        resp = @client.queryAsyncJobResult({'jobid' => jobid})
        if resp
            return resp['jobresult'] if resp['jobstatus'] == 1
            return {'jobresult' => {}} if resp['jobstatus'] == 2
        end
        sleep(period)
        i += 1 
      end
    return {}
    end

end

class CloudStackFactory
	def self.create_class(class_name,required_fields,optional_fields)
		cloudstackResource = Class.new CloudStackResource do 
			include Logging
  		include Intrinsic
			require 'netaddr'

      required_fields.each do |required|
      end

      optional_fields.each do |optional|
      end

			define_method "create" do
				p @name
				p "In create"
        args = {}
			end

			define_method "delete" do
				p "in delete"
			end

			define_method "on_workitem" do
				workitem = {}
				workitem['participant_name']="CSVPC"
				workitem['params']={}
				workitem['params']['operation'] = 'create'
				#instance_variable_set(:@name,workitem['participant_name'])
				@name = workitem['participant_name']
				if workitem['params']['operation'] == 'create'
     				create
    			else
      				delete
    			end
    			#reply
  			end
		end
		p class_name
		Kernel.const_get("StackMate").const_set class_name,cloudstackResource
	end

  def self.print_class(class_name,create_tag,required_fields,optional_fields,create_async,delete_tag,delete_id_tag,delete_async)
    async={}
    async[true] = 'make_async_request'
    async[false] = 'make_sync_request'
    create_request = async[create_async]
    delete_request = async[delete_async]
    str = "   class CloudStack" + class_name + " < CloudStackResource"
    puts str
    puts "
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
    #treat maps differently
    required_fields.each do |required,type|
      puts "          args['#{required}'] = get_#{required}"
    end
    #populate optional fields
    optional_fields.each do |optional,type|
      puts "          args['#{optional}'] = get_#{optional} if @props.has_key?('#{optional}')"
    end
    #raise error if some required field is missing
    puts "  
        rescue Exception => e
          #logging.error(\"Missing required parameter for resource \#{@name}\")
          logger.error(e.message)
          raise e
        end
        "
    
    #make API call, populate workitem object
    puts "
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
    puts "
      def delete
        logger.debug(\"Deleting resource \#{@name}\")
        begin
          physical_id = workitem[@name]['physical_id'] if !workitem[@name].nil?
          if(!physical_id.nil?)
            args = {'#{delete_id_tag}' => physical_id
                  }
            result_obj = #{delete_request}('#{delete_tag}#{class_name}',args)
            if (!(result_obj['error'] == true)
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
      puts "
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
      puts"
      def get_#{optional}
        resolved_#{optional} = get_resolved(@props['#{optional}'],workitem)
        if resolved_#{optional}.nil? || !validate_param(resolved_#{optional},\"#{type}\")
          raise \"Malformed optional parameter #{optional} for resource \#{@name}\"
        end
        resolved_#{optional}
      end
      "
    end
    puts "end
    "
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
