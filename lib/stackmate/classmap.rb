module StackMate
  PROFILES = ['CLOUDSTACK', 'NOOP']
  @profile = 'CLOUDSTACK'

  CS_CLASS_MAP = {
    'AWS::CloudFormation::WaitConditionHandle' => 'StackMate::WaitConditionHandle',
    'AWS::CloudFormation::WaitCondition' => 'StackMate::WaitCondition',
    'AWS::EC2::Instance' => 'StackMate::CloudStackInstance',
    'AWS::EC2::SecurityGroup' => 'StackMate::CloudStackSecurityGroupAWS',
    'Outputs' => 'StackMate::CloudStackOutput',
  }

  def StackMate.class_for(cf_resource)
    #return cf_resource
    case @profile
    when 'CLOUDSTACK'
      if(cf_resource.start_with?("CloudStack::"))
        c = cf_resource.split('::')[1]
        "StackMate::CloudStack"+c
      elsif(CS_CLASS_MAP.has_key?(cf_resource))
        CS_CLASS_MAP[cf_resource]
      else
        cf_resource
      end
    when 'NOOP'
      if cf_resource == 'Outputs'
        'StackMate::Output'
      else
        'StackMate::NoOpResource'
      end
    end
  end

  def StackMate.configure(profile)
    @profile = profile
  end

end