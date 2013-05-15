module StackMate
   CLASS_MAP = { 'AWS::EC2::Instance' => 'StackMate::CloudStackInstance',
              'AWS::CloudFormation::WaitConditionHandle' => 'StackMate::WaitConditionHandle',
              'AWS::CloudFormation::WaitCondition' => 'StackMate::WaitCondition',
              'AWS::EC2::SecurityGroup' => 'StackMate::CloudStackSecurityGroup'}
end
