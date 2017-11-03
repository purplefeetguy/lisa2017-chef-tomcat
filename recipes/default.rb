#
# Cookbook:: tomcat
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.
package 'java-1.7.0-openjdk-devel' do
  action :install
end

group 'tomcat' do
  action :create
end

user 'tomcat' do
  group 'tomcat'
  action :create
end

remote_file '/tmp/tomcat.tar.gz' do
  source 'http://chef.run/2wWavdE'
  action :create
end

directory '/opt/tomcat' do
  action :create
  recursive true
end

execute 'extract_tomcat' do
  command 'tar xvf tomcat.tar.gz -C /opt/tomcat --strip-components=1'
  cwd '/tmp'
end

execute 'chgrp -R tomcat /opt/tomcat/conf'

directory '/opt/tomcat/conf' do
  group 'tomcat'
  mode '0474'
  action :create
end

execute 'chmod g+r conf/*' do
  cwd '/opt/tomcat'
end

execute 'chown -R tomcat webapps/ work/ temp/ logs/ conf/' do
  cwd '/opt/tomcat'
end

execute 'chown -R tomcat webapps/ work/ temp/ logs/ conf/' do
  cwd '/opt/tomcat'
end

template '/etc/init.d/tomcat' do
  source 'tomcat.erb'
  mode '0755'
  action :create
end

service 'tomcat' do
  action :start
end
