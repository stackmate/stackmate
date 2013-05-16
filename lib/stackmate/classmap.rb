module StackMate
   PROFILES = ['CLOUDSTACK', 'NOOP']
   @profile = 'CLOUDSTACK'

   CS_CLASS_MAP = { 
              'AWS::CloudFormation::WaitConditionHandle' => 'StackMate::WaitConditionHandle',
              'AWS::CloudFormation::WaitCondition' => 'StackMate::WaitCondition',
              'AWS::EC2::Instance' => 'StackMate::CloudStackInstance',
              'AWS::EC2::SecurityGroup' => 'StackMate::CloudStackSecurityGroup'
   }

   def StackMate.class_for(cf_resource)
       case @profile
         when 'CLOUDSTACK'
           return CS_CLASS_MAP[cf_resource]
         when 'NOOP'
           return 'StackMate::NoOpResource'
       end
   end

   def StackMate.configure(profile)
       @profile = profile
   end

end
