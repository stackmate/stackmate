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


AWS_FAKE_ATTRIB_VALUES = {'AWS::CloudFormation::WaitCondition' =>  {'Data' => '{ "Signal1" : "Step 1 complete." , "Signal2" : "Step 2 complete." } '},
                          'AWS::CloudFormation::Stack' => {'Outputs.EmbeddedStackOutputName' => 'FakeEmbeddedStackOutputName'},
                          'AWS::CloudFront::Distribution' => {'DomainName' => 'd2fadu0nynjpfn.cloudfront.net'},
                          'AWS::EC2::EIP' => {'AllocationId' => 'eipalloc-5723d13e'},
                          'AWS::EC2::Instance' => {'AvailabilityZone' => 'us-east-1b', 'PrivateDnsName' => 'ip-10-24-34-0.cs.internal', 'PublicDnsName' => 'cs-17-10-90-145.compute.acs.org.', 'PrivateIp' => '10.24.34.0', 'PublicIp' => '75.75.75.111'},
                          'AWS::EC2::AWS::EC2::SubnetNetworkAclAssociation' => {'AssociationId' => 'aclassoc-e5b95c8c'},
                          'AWS::ElasticBeanstalk::Environment' => {'EndpointURL' => 'eb-myst-myen-132MQC4KRLAMD-1371280482.us-east-1.elb.amazonaws.com'},
                          'AWS::ElasticLoadBalancing::LoadBalancer' => {'CanonicalHostedZoneName' => 'mystack-myelb-15HMABG9ZCN57-1013119603.us-east-1.elb.amazonaws.com', 'CanonicalHostedZoneNameID' => 'Z3DZXE0Q79N41H', 'DNSName' => 'mystack-myelb-15HMABG9ZCN57-1013119603.us-east-1.elb.amazonaws.com', 'SourceSecurityGroup.GroupName' => 'elb-ssg', 'SourceSecurityGroup.OwnerAlias' => 'elb-ssg-owner'},
                          'AWS::IAM::AccessKey' => {'SecretAccessKey' => 'c8alrXUtnYEMI/K7MDAZQ/bPxRfiCYzEXAMPLEKEY'},
                          'AWS::IAM::Group' => {'Arn' => 'arn:aws:iam::123456789012:group/mystack-mygroup-1DZETITOWEKVO'},
                          'AWS::IAM::User' => {'Arn' => 'mystack-myuser-1CCXAFG2H2U4D'},
                          'AWS::RDS::DBInstance' => {'Endpoint.Address' => 'mystack-mydb-1apw1j4phylrk.cg034hpkmmjt.us-east-1.rds.amazonaws.com', 'Endpoint.Port' => '3306'},
                          'AWS::S3::Bucket' => {'DomainName' => 'mystack-mybucket-kdwwxmddtr2g.s3.amazonaws.com', 'WebsiteURL' => 'http://mystack-mybucket-kdwwxmddtr2g.s3-website-us-east-1.amazonaws.com/', 'Arn' => 'arn:aws:s3::12345678901::root'},
                          'AWS::SQS::Queue' => {'Arn' => 'arn:aws:sqs:us-east-1:123456789012:mystack-myqueue-15PG5C2FC1CW8', 'QueueName' => 'mystack-myqueue-1VF9BKQH5BJVI'}
                          }