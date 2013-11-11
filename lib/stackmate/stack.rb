require 'json'
require 'set'
require 'tsort'
require 'stackmate/logging'
require 'yaml'

module StackMate

  class Stacker
    include TSort
    include Logging

    attr_accessor :templ

    def initialize(stackstr, stackname, params)
      @stackname = stackname
      @resolved = params
      @templ = JSON.parse(stackstr)
      @templ['StackName'] = @stackname
      @param_names = @templ['Parameters']
      @deps = {}
      @pdeps = {}
      validate_param_values
      resolve_dependencies()
      validate_dependencies
      @allowed_param_vales = get_allowed_values(@param_names)
      @templ['ResolvedNames'] = populate_parameters(@param_names,@resolved)
      #@templ['ResolvedNames']['StackId'] = SecureRandom.urlsafe_base64
      @templ['IdMap'] = {}
    end

    def get_allowed_values(template_params)
      allowed = {}
      template_params.each_key do |k|
        #Type is mandatory???
        allowed[k] = {}
        allowed[k]['Type'] = template_params[k]['Type'] if template_params[k].has_key?('Type')
        allowed[k]['AllowedValues'] = template_params[k]['AllowedValues'] if template_params[k].has_key?('AllowedValues')
      end
      allowed
    end

    def populate_parameters(params,overrides)
      populated={}
      #Populate defaults
      params.each_key do |k|
        populated[k] = params[k]['Default']
      end
      #Then load local YAML mappings
      begin
        #TODO change to use stackid
        #file_name = @stackname+".yml"
        file_name = "local.yml"
        localized = YAML.load_file(file_name)
        localized.each_key do |k|
          populated[k] = localized[k]
        end
      rescue
        #raise "ERROR : Unable to load end point parameters"
        logger.info("CAUTION: Unable to load end point parameters")
      end
      #Then override
      overrides.each_key do |k|
        populated[k] = overrides[k]
      end
      populated
    end

    def validate_param_values
      #TODO CloudFormation parameters have validity constraints specified
      #Use them to validate parameter values (e.g., email addresses)
      #As of now used only in actual cloudstack calls
    end

    def validate_dependencies
      resources = @deps.keys
      @deps.each_key do |k|
        @deps[k].each do |resource|
          if !resources.include?(resource)
            raise "Bad reference or dependency on resource #{resource}"
          end
        end
      end
    end

    def resolve_dependencies
      @templ['Resources'].each { |key,val|
        deps = Set.new
        pdeps = Set.new
        find_refs(key, val, deps, pdeps)
        deps << val['DependsOn'] if val['DependsOn']
        #print key, " depends on ", deps.to_a, "\n"
        @deps[key] = deps.to_a
        @pdeps[key] = pdeps.to_a
      }
      unresolved = []
      @pdeps.keys.each do |k|
        unres = @pdeps[k] - @resolved.keys
        if ! unres.empty?
          unres.each do |u|
            deflt = @param_names[u]['Default']
            #print "Found default value ", deflt, " for ", u, "\n" if deflt
            @resolved[u] = deflt if deflt
          end
          unres = @pdeps[k] - @resolved.keys
          unresolved = unresolved + unres
          #throw :unresolved, (@pdeps[k] - @resolved.keys) if !unres.empty?
        end
      end
      throw :unresolved, unresolved.uniq if !unresolved.empty?
    end


    def find_refs (parent, jsn, deps, pdeps)
      case jsn
      when Array
        jsn.each {|x| find_refs(parent, x, deps, pdeps)}
        #print parent, ": ", jsn, "\n"
      when Hash
        jsn.keys.each do |k|
          #TODO Fn::GetAtt
          if k == "Ref"
            #only resolve dependencies on other resources for now
            if !@param_names.keys.index(jsn[k]) && !@resolved.keys.index(jsn[k]) && jsn[k] != 'AWS::Region' && jsn[k] != 'AWS::StackId' && jsn[k] != 'AWS::StackName'
              deps << jsn[k]
              #print parent, ": ", deps.to_a, "\n"
            else if @param_names.keys.index(jsn[k])
              pdeps << jsn[k]
            end
          end
          else
            find_refs(parent, jsn[k], deps, pdeps)
          end
        end
      end
      return deps
    end

    def tsort_each_node(&block)
      @deps.each_key(&block)
    end

    def tsort_each_child(name, &block)
      @deps[name].each(&block) if @deps.has_key?(name)
    end

  end

end