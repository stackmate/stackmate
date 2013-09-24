module StackMate
   PROFILES = ['CLOUDSTACK', 'NOOP']
   @profile = 'CLOUDSTACK'

   CS_CLASS_MAP = { 
              'AWS::CloudFormation::WaitConditionHandle' => 'StackMate::WaitConditionHandle',
              'AWS::CloudFormation::WaitCondition' => 'StackMate::WaitCondition',
              'AWS::CloudFormation::Stack' => 'StackMate::StackNest',
              'AWS::EC2::Instance' => 'StackMate::CloudStackInstance',
              'AWS::EC2::SecurityGroup' => 'StackMate::CloudStackSecurityGroup',
              'AWS::EC2::VPC' => 'StackMate::CloudStackVPCNoOp',
              'AWS::EC2::DHCPOptions' => 'StackMate::CloudStackDHCPNoOp',
              'AWS::EC2::VPCDHCPOptionsAssociation' => 'StackMate::CloudStackVPC',
              'AWS::EC2::InternetGateway' => 'StackMate::CloudStackGatewayNoOp',
              #'AWS::EC2::VPCGatewayAttachment' => 'StackMate::CloudStackVPNGateway',
              'AWS::EC2::NetworkAcl' => 'StackMate::CloudStackNetworkACL',
              'AWS::EC2::InternetGateway' => 'StackMate::CloudStackInetGatewayNoOp',
              'AWS::EC2::VPCGatewayAttachment' => 'StackMate::CloudStackVPCGatewayAttachmentNoOp',
              'AWS::EC2::Subnet' => 'StackMate::CloudStackVPCNetwork',
              'AWS::EC2::Volume' => 'StackMate::CloudStackVolume',
              'AWS::EC2::VolumeAttachment' => 'StackMate::CloudStackVolumeAttachment',
              'AWS::EC2::NetworkInterface' => 'StackMate::NoOpResource',
              'AWS::EC2::EIP' => 'StackMate::NoOpResource',
              'AWS::EC2::EIPAssociation' => 'StackMate::NoOpResource',
              'Outputs' => 'StackMate::CloudStackOutput'
   }

   def StackMate.class_for(cf_resource)
       case @profile
         when 'CLOUDSTACK'
           return CS_CLASS_MAP[cf_resource]
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
