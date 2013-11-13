require 'rspec'
require '../lib/stackmate/resolver.rb'

describe "parameter validation test" do
  include StackMate::Resolver
  before do
    @str = "this is a string"
    @int = "9999999"
    @integer = "99999999"
    @booleans = ["true","false"]
    @imageformats = ["vhd","qcow"]
    @list = '["this", "is", "a","a","list"]'
    @long = "99999999999"
    @map = '{"a" => "b","c" =>"d"}'
    @set = '["this","is","a","set"]'
    @short = "77"
    @uuid = "88a1e565-bc2a-456b-be99-e95cacc3d069"
  end

  it "tests correct string resolution" do
    validate_param(@str,"string").should == true
  end

  it "tests incorrect string resolution" do
    #validate_param(999,"string").should == false
    #validate_param(true,"string").should == false
    #validate_param(eval(@list),"string").should == false
    #validate_param(eval(@map),"string").should == false
  end

  it "tests correct int resolution" do
    validate_param(@int,"int").should == true
    validate_param(@integer,"integer").should == true
  end

  it "tests incorrect int resolution" do
    #validate_param(@str,"int").should == false
  end

  it "tests correct booleans resolution" do
    validate_param(@booleans[0],"boolean").should == true
    validate_param(@booleans[1],"boolean").should == true
  end

  it "tests incorrect booleans resolution" do
    #validate_param(@str,"boolean").should == false
  end

  it "tests correct imageformat resolution" do
    validate_param(@imageformats[0],"imageformat").should == true
    validate_param(@imageformats[1],"imageformat").should == true
  end

  it "tests incorrect imageformat resolution" do
    #validate_param(eval(@list),"imageformat").should == false
  end

  it "tests correct list resolution" do
    validate_param(@list,"list").should == true
    validate_param(@set,"list").should == true
  end

  it "tests incorrect list resolution" do
    #validate_param(@map,"list").should == false
  end

  it "tests correct long resolution" do
    validate_param(@long,"long").should == true
  end

  it "tests incorrect long resolution" do
    #validate_param(@str,"long").should == false
  end

  it "tests correct map resolution" do
    validate_param(@map,"map").should == true
  end

  it "tests incorrect map resolution" do
    #validate_param(@set,"map").should == false
    #validate_param(@list,"map").should == false

  end

  it "tests correct set resolution" do
    validate_param(@set,"set").should == true
  end

  it "tests incorrect set resolution" do
    #validate_param(@str,"set").should == false
    #validate_param(@list,"set").should == false
  end

  it "tests correct short resolution" do
    validate_param(@short,"short").should == true
  end

  it "tests incorrect short resolution" do
    #validate_param(@str,"short").should == false
  end

  it "tests correct uuid resolution" do
    validate_param(@uuid,"uuid").should == true
  end

  it "tests incorrect uuid resolution" do
    #validate_param(@str,"uuid").should == false
    #validate_param(@int,"uuid").should == false
  end

end