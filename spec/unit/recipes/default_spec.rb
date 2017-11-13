#
# Cookbook:: policy_linux_mysql
# Spec:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.

require 'spec_helper'

describe 'policy_linux_mysql::default' do
  let(:chef_run) { ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '14.04').converge(described_recipe) }

  it 'restarts httpd service' do
    expect(chef_run).to restart_service('httpd')
    expect(chef_run).to_not restart_service('httpd')
  end

  it 'restarts tomcat7 service' do
    expect(chef_run).to restart_service('tomcat7')
    expect(chef_run).to_not restart_service('tomcat7')
  end

  it 'restarts mysqld service' do
    expect(chef_run).to restart_service('mysqld')
    expect(chef_run).to_not restart_service('mysqld')
  end

end
