#
# Author:: Seth Vargo <sethvargo@gmail.com>
# Cookbook Name:: deployer
# Recipe:: default
#
# Copyright 2012, Seth Vargo
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

deployer = data_bag_item('deployers', 'default')

# GRP deploy
group deployer['group'] do
  action    :create
  gid       5000
end

# USER deploy
user deployer['user'] do
  comment   'The deployment user'
  uid       5000
  gid       deployer['group']
  shell     '/bin/bash'
  home      deployer['home']
  supports  :manage_home => true
end

# SUDO deploy
sudo deployer['user'] do
  user      deployer['user']
  group     deployer['group']
  commands  ['ALL']
  host      'ALL'
  nopasswd  true
end

# DIR /home/deploy/.ssh
directory "#{deployer['home']}/.ssh" do
  owner     deployer['user']
  group     deployer['group']
  mode      '0700'
  recursive true
end

collections = [:users, :deployers]

if Chef::Config[:solo]
  users = collections.collect do |bag_name|
    data_bag(bag_name).map do |name|
      u = data_bag_item(bag_name, name)
      !!u['deploy'] ? u : next
    end
  end.flatten.compact
else
  # SEL users and deployers that can deploy to this node
  query = "deploy:any OR deploy:#{node['fqdn']} OR deploy:#{node['ipaddress']}"
  users = collections.collect do |bag_name|
    # Because the data_bag may not exist, wrap in a safe search
    begin
      search(bag_name, query)
    rescue Net::HTTPServerException
      []
    end
  end.flatten.compact
end

# TMPL /home/deploy/.ssh/authorized_keys
template "#{deployer['home']}/.ssh/authorized_keys" do
  owner     deployer['user']
  group     deployer['group']
  mode      '0644'
  source    'authorized_keys.erb'
  variables \
    users: users
    ssh_keys: deployer['ssh_keys']
end

if deployer['private_key']
  file "#{deployer['home']}/.ssh/id_rsa" do
    owner deployer['user']
    group deployer['group']
    mode '0600'
    content deployer['private_key']
  end
end

if deployer['pub_key']
  file "#{deployer['home']}/.ssh/id_rsa.pub" do
    owner deployer['user']
    group deployer['group']
    mode '0600'
    content deployer['pub_key']
  end
end
