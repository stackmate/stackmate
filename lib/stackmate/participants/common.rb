require 'json'
require 'yaml'
require 'stackmate/logging'
require 'stackmate/intrinsic_functions'
require 'stackmate/resolver'
require 'stackmate/stackpi'
require 'net/http'
require 'uri'
require 'time'
require 'stackmate/stackglobal'

module StackMate


# class ParamHandle < Ruote::Participant
#   include Logging
#   def on_workitem
#     logger.debug "Setting resolved parameter #{participant_name}"
#     workitem['ResolvedNames'][participant_name] = workitem['']
#   end
# end

class WaitConditionHandle < Ruote::Participant
  include Logging

  def create
    logger.debug "Entering #{participant_name} "
    workitem[participant_name] = {}
    presigned_url = 'http://localhost:4567/waitcondition/' + workitem.fei.wfid + '/' + participant_name
    workitem.fields['ResolvedNames'][participant_name] = presigned_url
    logger.info "Your pre-signed URL is: #{presigned_url} "
    logger.info "Try: \ncurl -X PUT --data 'foo' #{presigned_url}"
    WaitCondition.create_handle(participant_name, presigned_url)
    workitem[participant_name][:physical_id] = presigned_url
  end

  def delete
    #p workitem
    logger.info "In delete #{participant_name}"
    return nil if !workitem[participant_name]
    physical_id = workitem[participant_name][:physical_id]
    if physical_id
      workitem[participant_name] = {}
      WaitCondition.delete_handle(participant_name)
    end
  end

  def on_workitem
    if workitem['params']['operation'] == 'create'
      create
    else
      #rollback / delete
      delete
    end
    reply
  end
end

class WaitCondition < Ruote::Participant
  include Logging
  @@handles = {}
  @@conditions = []

  def create
    logger.debug "Entering #{workitem.participant_name} "
    workitem[participant_name] = {}
    @@conditions << self
    stackname = workitem.fields['ResolvedNames']['AWS::StackName']
    workitem[participant_name][:physical_id] =  stackname + '-' + 'WaitCondition'
  end

  def delete
    logger.info "In delete #{participant_name}"
    #no-op
  end

  def on_workitem
    if workitem['params']['operation'] == 'create'
      create
    else
      #rollback / delete
      delete
      reply
    end
  end

  def self.create_handle(handle_name, handle)
      @@handles[handle_name] = handle
  end

  def self.delete_handle(handle_name)
      @@handles.delete(handle_name)
  end

  def set_handle(handle_name)
      reply(workitem) if @@handles[handle_name]
  end

  def self.get_conditions()
      @@conditions
  end
end

class Output < Ruote::Participant
  include Logging
  include Intrinsic

  def on_workitem
    #p workitem.fields.keys
    logger.debug "Entering #{workitem.participant_name} "
    outputs = workitem.fields['Outputs']
    logger.debug "In StackMate::Output.on_workitem #{outputs.inspect}"
    outputs.each do |key, val|
      v = val['Value']
      constructed_value = intrinsic(v, workitem)
      val['Value'] = constructed_value
      logger.debug "Output: key = #{key}, value = #{constructed_value} descr = #{val['Description']}"
    end

    logger.debug "Output Done"
    reply
  end
end

class NoOpResource < Ruote::Participant
  include Logging

  def create
    logger.debug "Creating #{participant_name} wfid=#{workitem.fei.wfid} fei=#{workitem.fei.to_h}"
    workitem[participant_name] = {}
    stackname = workitem.fields['ResolvedNames']['AWS::StackName']
    logger.debug "physical id is  #{stackname}-#{participant_name} "
    workitem[participant_name][:physical_id] =  stackname + '-' + participant_name
    typ = workitem['Resources'][participant_name]['Type']
    if AWS_FAKE_ATTRIB_VALUES[typ]
      AWS_FAKE_ATTRIB_VALUES[typ].each do |k,v| 
        workitem[participant_name][k] = v
      end
    end
  end

  def delete
    logger.debug "Deleting #{participant_name} wfid=#{workitem.fei.wfid} fei=#{workitem.fei.to_h}"
  end

  def on_workitem
    @stackname = workitem['StackName']
    if workitem['params']['operation'] == 'create'
      create
    else
      delete
    end
    reply
  end
end

class StackNest < Ruote::Participant
  include Logging
  include Intrinsic
  include Resolver
  include StackPi

  def create
    logger.debug("Creating nested stack #{@stackname}")
    #Get template from URL
    #Call stackmate API for launching new stack
    #read outputs from predefined location
    #copy all critical fields from workitems

    #CAVEAT - needs file storage. may be move to database backed
    # needs a Outputs tag. Not a big deal since nested stacks anyways need 
    #outputs tags
    workitem[@stack_name] = {}
    params = workitem['ResolvedNames']
    stack_props = workitem['Resources'][@stack_name]['Properties']
    template_url = URI(get_resolved(stack_props['TemplateURL'],workitem))
    logger.debug("Fetching template for #{@stack_name} from URL #{template_url}")
    http = Net::HTTP.new(template_url.host,template_url.port)
    if template_url.scheme == 'https'
      http.use_ssl = true
    end
    http.start { 
      http.request_get(template_url.path) { |res|
        File.open("/tmp/#{@stack_name}.template", 'w') { |file| file.write(res.body) }
        }
    }      
    stack_props['Parameters'].each_key do |k|
      params[k] = get_resolved(stack_props['Parameters'][k],workitem)
    end
    params['stackrand'] = Time.now().to_i #TODO use subid from fei or something
    params['isnested'] = "True"
    StackMate::StackPi.create_stack("/tmp/#{@stack_name}.template",@stack_name,format_params(params),true)
    file_name = "/tmp/#{@stack_name}.workitem.#{params['stackrand']}"
    if(File.exists?(file_name))
      output_workitem = YAML.load(File.read(file_name))
      workitem[@stack_name]['ResolvedNames'] = output_workitem['ResolvedNames'].clone
      workitem[@stack_name]['Outputs'] = output_workitem['Outputs'].clone
      workitem[@stack_name]['Resources'] = output_workitem['Resources'].clone
      workitem[@stack_name]['IdMap'] = output_workitem['IdMap'].clone
      #copy all resources created
      output_workitem['Resources'].each_key do |resource|
        workitem[@stack_name][resource] = output_workitem[resource].clone
      end
      logger.debug("Successfully created nested stack #{@stack_name}")
    else
      logger.debug("Unable to create nested stack #{@stack_name}")
      raise "Nested Stack Failed"
    end
  end

  def delete
    logger.debug("Deleting stack #{@stack_name}")
    #TODO write code to roll back all stack info
    #Probably nothing needed since new engine launched takes care of it
    #No, need to clean up if parent stack fails after the nested stack is successfully created
  end

  def on_workitem
    @stack_name = workitem.participant_name
    if workitem['params']['operation'] == 'create'
      create
    else
      #rollback / delete
      delete
    end
    reply
  end

  def format_params(params)
    result = ""
    add_semi = false
    params.each_key do |k|
      result = result + ";" if add_semi
      result = result + k + "=" + params[k].to_s if !params[k].nil?
      add_semi = true
    end
    result
  end
end

end
