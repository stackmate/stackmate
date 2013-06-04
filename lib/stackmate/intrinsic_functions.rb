module StackMate
  module Intrinsic

    def intrinsic (hash, workitem) 
        key =  hash.keys[0]
        value = hash[key]
        #logger.debug "Intrinsic: key = #{key}, value = #{value}"
        case key
        when 'Fn::Join'
            fn_join(value, workitem)
        when 'Fn::GetAtt'
            fn_getatt(value, workitem)
        when 'Fn::Select'
            fn_select(value)
        when 'Ref'
            fn_ref(value, workitem)
        end
    end

    def fn_join(value, workitem)
        delim = value[0]
        v = value[1]
        #logger.debug "Intrinsic: fn_join  value = #{v}"
        result = ''
        first_ = true
        v.each do |token|
            case token
            when String
                result = result + (first_ ? "" : delim) + token 
            when Hash
                result = result + (first_ ? "" : delim) + intrinsic(token, workitem)
            end
            first_ = false
        end
        result
    end

    def fn_getatt(array_value, workitem)
        resource = array_value[0]
        attribute = array_value[1]
        #logger.debug "Intrinsic: fn_getatt  resource= #{resource} attrib = #{attribute} wi[Resource] = #{workitem[resource]}"
        workitem[resource][attribute]
    end

    def fn_select(array_value)
        index = array_value[0].to_i #TODO unsafe
        values = array_value[1]
        #logger.debug "Intrinsic: fn_select  index= #{index} values = #{values.inspect}"
        values[index]
    end

    def fn_ref(value, workitem)
        #logger.debug "Intrinsic: fn_ref  value = #{value}"
        workitem[value]['physical_id'] #TODO only works with Resources not Params
    end

  end
end
