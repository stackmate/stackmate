 AWS_ATTRIBS = {'AWS::CloudFormation::WaitCondition' => [ 'Data'],
                'AWS::CloudFormation::Stack' => ['Outputs.EmbeddedStackOutputName'],
                'AWS::CloudFront::Distribution' => ['DomainName'],
                'AWS::EC2::EIP' => ['AllocationId'],
                'AWS::EC2::Instance' => ['AvailabilityZone', 'PrivateDnsName', 'PublicDnsName', 'PrivateIp', 'PublicIp'],
                'AWS::EC2::AWS::EC2::SubnetNetworkAclAssociation' => ['AssociationId'],
                'AWS::ElasticBeanstalk::Environment' => ['EndpointURL'],
                'AWS::ElasticLoadBalancing::LoadBalancer' => ['CanonicalHostedZoneName', 'CanonicalHostedZoneNameID', 
                                            'DNSName', 'SourceSecurityGroup.GroupName', 'SourceSecurityGroup.OwnerAlias'],
                'AWS::IAM::AccessKey' => ['SecretAccessKey'],
                'AWS::IAM::Group' => ['Arn'],
                'AWS::IAM::User' => ['Arn'],
                'AWS::RDS::DBInstance' => ['Endpoint.Address', 'Endpoint.Port'],
                'AWS::S3::Bucket' => ['DomainName', 'WebsiteURL', 'Arn'],
                'AWS::SQS::Queue' => ['Arn', 'QueueName']
  }

