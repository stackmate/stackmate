#require 'stackmate/logging'
require 'stackmate/intrinsic_functions'

module StackMate
  module Resolver
    @devicename_map=
    {
      '/dev/sdb' => '1',
      '/dev/sdc' => '2',
      '/dev/sdd' => '3',
      '/dev/sde' => '4',
      '/dev/sdf' => '5',
      '/dev/sdg' => '6',
      '/dev/sdh' => '7',
      '/dev/sdi' => '8',
      '/dev/sdj' => '9',
      '/dev/xvdb' => '1',
      '/dev/xvdc' => '2',
      '/dev/xvdd' => '3',
      '/dev/xvde' => '4',
      '/dev/xvdf' => '5',
      '/dev/xvdg' => '6',
      '/dev/xvdh' => '7',
      '/dev/xvdi' => '8',
      '/dev/xvdj' => '9',
      'xvdb' => '1',
      'xvdc' => '2',
      'xvdd' => '3',
      'xvde' => '4',
      'xvdf' => '5',
      'xvdg' => '6',
      'xvdh' => '7',
      'xvdi' => '8',
      'xvdj' => '9',
    }
    #comes from awsapi reference
    STRINGEXP = /.+/
    INTEXP = /[0-9]+/
    UUIDEXP = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
    @@intrinsics = ["Ref","Fn::Join","Fn::GetAtt","Fn::Select","Fn::FindInMap","Fn::Base64"]
    def get_resolved(lookup_data,workitem)
      case lookup_data
      when String
        lookup_data
      when Hash
        intrinsic(lookup_data,workitem)
      end
    end

    def validate_param(value,type)
      return true
      begin
        case type
        when "boolean"
          ["true","false"].include?(value)
        when "date"
          true
        when "imageformat"
          ["vhd","qcow"].include?(value)
        when "int"
          !INTEXP.match(value).nil?
        when "integer"
          !INTEXP.match(value).nil?
        when "list"
          #eval(value).kind_of?(Array)
          true
        when "long"
          !INTEXP.match(value).nil?
        when "map"
          #eval(value).kind_of?(Hash)
          true
        when "set"
          #eval(value).kind_of?(Array) and eval(value).uniq == eval(value)
          true
        when "short"
          !INTEXP.match(value).nil?
        when "state"
          true
        when "string"
          value.kind_of?(String)
        when "tzdate"
          true
        when "uuid"
          !UUIDEXP.match(value).nil?
        else
          true
        end
      rescue Exception => e
        false
      end
    end

    def get_named_tag(tag_name,properties,workitem,default)
      result = default
      unless properties['Tags'].nil?
        properties['Tags'].each do |tag|
          k = tag['Key']
          v = tag['Value']
          if k.eql?(tag_name)
            result = get_resolved(v,workitem)
          end
        end
      end
      result
    end

    def resolve_tags(tags_array,workitem)
      result = {}
      tags_array.each do |tag|
        k = tag['key']
        v = tag['value']
        resolved_v = get_resolved(v,workitem)
        result[k] = resolved_v
      end
      result
    end

    def resolve_to_deviceid(devicename)
      @devicename_map[devicename.downcase]
    end

    def recursive_resolve(lookup_data,workitem)
      case lookup_data
      when String
        lookup_data
      when Array
        return_array = []
        lookup_data.each do |data|
          return_array.push(recursive_resolve(data,workitem))
        end
        return_array
      when Hash
        return_hash = {}
        #key = lookup_data.keys[0]
        #p lookup_data.keys
        lookup_data.keys.each do |key|
          val = lookup_data[key]
          if(@@intrinsics.include?(key))
            #Intrinsic functions work without nesting and so return
            return intrinsic(lookup_data,workitem)
          else
            return_hash[key] = recursive_resolve(val,workitem)
          end
        end
        return return_hash
      end
    end
  end
end