require 'rspec'
require '../lib/stackmate/intrinsic_functions.rb'

describe "intrinsic test" do
  include StackMate::Intrinsic
  before do
    @names = {"DomainFQDN"=>"ctxcloud.com", "InstanceType"=>"m1.large", "VPCName"=>"XenApp VPC", "StartingWorkerServers"=>2, "AvailabilityZonePref"=>"", "Octet1VPC"=>"10", "Octet2VPC"=>"0", "PublicSubnetOct"=>"0", "PrivateSubnetOct"=>"1", "NSCloudFormationURL"=>"https://cf-templates-5tx1cix0h0y1-us-east-1.s3.amazonaws.com/2013059tvE-NS_VPX_Tempate_v3.json", "DBName"=>"cloud", "DBUserName"=>"cloud", "SSHLocation"=>"75.75.75.0/24", "DBUsername"=>"cloud", "DBPassword"=>"cloud", "DBRootPassword"=>"cloud", "KeyName"=>"stackTest", "vpcofferingid"=>"1", "AWS::Region"=>"us-east-1", "AWS::StackName"=>"CSSTACK", "AWS::StackId"=>"CSSTACK"}
    @mappings = {"InstanceLookup"=>{"m1.large"=>{"Arch"=>"XenAppSnapShot"}}, "RegionMap"=>{"us-east-1"=>{"dc01Ami"=>"ami-0a4fd163", "w2k8Ami"=>"ami-deb22cb7", "xaAmi"=>"ami-deb22cb7", "natAmi"=>"ami-d8699bb1", "XenAppSnapShot"=>"snap-f277618d"}, "us-west-1"=>{"dc01Ami"=>"ami-be5e73fb", "w2k8Ami"=>"ami-885875cd", "xaAmi"=>"ami-885875cd", "natAmi"=>"ami-c7cc9e82", "XenAppSnapShot"=>"snap-f96769d6"}, "us-west-2"=>{"dc01Ami"=>"ami-68009558", "w2k8Ami"=>"ami-9e0d98ae", "xaAmi"=>"ami-9e0d98ae", "natAmi"=>"ami-6eff725e", "XenAppSnapShot"=>"snap-866c68ed"}, "eu-west-1"=>{"dc01Ami"=>"ami-649a9110", "w2k8Ami"=>"ami-3a9f944e", "xaAmi"=>"ami-3a9f944e", "natAmi"=>"ami-095b6c7d", "XenAppSnapShot"=>"snap-e3ece188"}, "ap-southeast-1"=>{"dc01Ami"=>"ami-f00945a2", "w2k8Ami"=>"ami-820945d0", "xaAmi"=>"ami-820945d0", "natAmi"=>"ami-00eb9352", "XenAppSnapShot"=>"snap-e7ff5388"}, "ap-southeast-2"=>{"dc01Ami"=>"ami-ca76e7f0", "w2k8Ami"=>"ami-3a79e800", "xaAmi"=>"ami-3a79e800", "natAmi"=>"ami-a1980f9b", "XenAppSnapShot"=>"snap-de4e2fee"}, "ap-northeast-1"=>{"dc01Ami"=>"ami-4d78f94c", "w2k8Ami"=>"ami-5f01805e", "xaAmi"=>"ami-5f01805e", "natAmi"=>"ami-12d86d13", "XenAppSnapShot"=>"snap-93a202fd"}, "sa-east-1"=>{"dc01Ami"=>"ami-8b2af196", "w2k8Ami"=>"ami-5b29f246", "xaAmi"=>"ami-5b29f246", "natAmi"=>"ami-0439e619", "XenAppSnapShot"=>"snap-cf7a00a7"}}}
    @resource = {"physical_id" => "uuid-something-1234"}
  end
  
  it "tests Ref function for parameter" do
    workitem = double("workitem")
    workitem.stub(:[]) do |arg|
      if arg == "ResolvedNames"
        @names
      else
        nil
      end
    end
  intrinsic({"Ref" => "VPCName"},workitem).should == "XenApp VPC"  
  end

  it "tests Ref function for resource" do
    workitem = double("workitem")
    workitem.stub(:[]).with("XenApp VPC").and_return(@resource)
    intrinsic({"Ref" => "XenApp VPC"},workitem).should == "uuid-something-1234"
  end

  it "tests Fn::Join" do
    workitem = double("workitem")
  workitem.stub(:[]) do |arg|
      if arg == "ResolvedNames"
        @names
      else
        nil
      end
    end
    intrinsic({"Fn::Join"=>["", [{"Fn::Join"=>[".", [{"Ref"=>"Octet1VPC"}, {"Ref"=>"Octet2VPC"}, "0", "0"]]}, "/", "16"]]},workitem).should == "10.0.0.0/16"
  end

  it "tests Fn::Map" do
    workitem = double("workitem")
  workitem.stub(:[]) do |arg|
      if arg == "ResolvedNames"
        @names
      elsif arg == "Mappings"
        @mappings
      else
        nil
      end
    end
    intrinsic({"Fn::FindInMap"=>["RegionMap", {"Ref"=>"AWS::Region"}, {"Fn::FindInMap"=>["InstanceLookup", {"Ref"=>"InstanceType"}, "Arch"]}]},workitem).should == "snap-f277618d"
  end

  it "tests Fn::Select" do
    workitem = double("workitem")
  workitem.stub(:[]) do |arg|
      if arg == "ResolvedNames"
        @names
      elsif arg == "XenApp VPC"
        @resource
      else
        nil
      end
    end
    intrinsic({"Fn::GetAtt"=>["XenApp VPC", "physical_id"]},workitem).should == "uuid-something-1234"
  end

  it "tests Fn::Select" do
  workitem = double("workitem")
  intrinsic({ "Fn::Select" => [ "1", [ "apples", "grapes", "oranges", "mangoes" ] ] }, workitem).should == "grapes"
  end

end
