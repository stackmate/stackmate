namespace :generate do
  desc "Generate participants for CloudStack"
  task :participants,[:apis] do |t,args|
    args.with_defaults(:apis => "utils/apis_user.json")
    ruby "utils/apis.rb #{args[:apis]}"
  end
  desc "Generate JSON Docs"
  task :docs, [:apis] do |t,args|
    args.with_defaults(:apis => "utils/apis_user.json")
    ruby "utils/docs.rb #{args[:apis]}"
  end
end
