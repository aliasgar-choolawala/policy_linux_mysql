require 'open3'
require 'chef/util/file_edit'

services = %w(httpd tomcat7 mysqld)
packages = ['apache2', 'tomcat-connectors-1.2.42-src', 'tomcat7', 'jdk-8u151-linux-i586', 'make', 'gcc']

# Download and install required packages
packages.each do |pack|
  package pack do
  end
end

# open port 80 for apache
stdout, _stderr, _status = Open3.capture3("iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT")

# retrieving jdk home folder name
jdk_path, _stderr, _status = Open3.capture3("ls /home/ubuntu | grep jdk")

# append java env variables to .bashrc
insert_at_end("/etc/ubuntu/.bashrc", "export JAVA_HOME=/home/ubuntu/#{jdk_path}")
insert_at_end("/etc/ubuntu/.bashrc", "export PATH=$JAVA_HOME/bin:$PATH")

execute 'configure modjk' do
  command './configure --with-apxs=/usr/sbin/apxs'
  cwd '/home/ubuntu/tomcat-connectors-1.2.42-src'
end

stdout, _stderr, _status = Open3.capture3("make")
stdout, _stderr, _status = Open3.capture3("make install")

httpd_conf_info = [] # new config content to be added to httpd.conf
old_file = [] # original contents of httpd.conf

File.foreach("/etc/httpd/conf/httpd.conf") {|line| old_file.push line.chomp}

httpd_conf_info.push "# Load the mod_jk module"
httpd_conf_info.push "LoadModule jk_module /etc/httpd/modules/mod_jk.so"

httpd_conf_info.push "# Specify path to worker configuration file"
httpd_conf_info.push "JkWorkersFile /etc/httpd/conf/workers.properties"

httpd_conf_info.push "# Configure logging and memory"
httpd_conf_info.push "JkShmFile 	/var/logs/httpd/mod_jk.shm"
httpd_conf_info.push "JkLogFile 	/var/logs//httpd/mod_jk.log"
httpd_conf_info.push "JkLogLevel 	debug"

httpd_conf_info.push "# Configure applications"
httpd_conf_info.push "JkMount /*		router"
httpd_conf_info.push "JkMount /jk_status	status"

httpd_conf_info.push "<filesmatch \"*\">"
httpd_conf_info.push "  FileETag None"
httpd_conf_info.push "  <ifmodule mod_headers.c>"
httpd_conf_info.push "     Header unset ETag"
httpd_conf_info.push "     Header set Cache-Control \"max-age=0, no-cache, no-store, must-revalidate\""
httpd_conf_info.push "     Header set Pragma \"no-cache\""
httpd_conf_info.push "     Header set Expires \"Sat, 11 Jan 2020 05:00:00 GMT\""
httpd_conf_info.push "  </ifmodule>"
httpd_conf_info.push "</filesmatch>"

old_file << httpd_conf_info

# append new configuration to httpd.conf
file "/etc/httpd/conf/httpd.conf" do
  content old_file.join("\n") + "\n"
end

workers_file = []
workers_config = []

File.foreach("/etc/httpd/conf/workers.properties") {|line| workers_file.push line.chomp}

workers_config.push "# Define worker names"
workers_config.push "worker.list=router,status"

workers_config.push "worker.tomcat1.port=8180"
workers_config.push "worker.tomcat1.host=localhost"
workers_config.push "worker.tomcat1.type=ajp13"
workers_config.push "worker.tomcat1.lbfactor=1"
workers_config.push "worker.tomcat1.local_worker=1"
workers_config.push "worker.tomcat1.sticky_session=0"
 
workers_config.push "worker.tomcat2.port=8181"
workers_config.push "worker.tomcat2.host=localhost"
workers_config.push "worker.tomcat2.type=ajp13"
workers_config.push "worker.tomcat2.lbfactor=1"
workers_config.push "worker.tomcat2.local_worker=0"
workers_config.push "worker.tomcat2.sticky_session=0"
 
workers_config.push "worker.router.type=lb"
workers_config.push "worker.router.balanced_workers=tomcat1,tomcat2"
workers_config.push "worker.router.local_worker_only=1"
 
workers_config.push "worker.status.type=status"

workers_file << workers_config

# append new configuration to workers.properties
file "/etc/httpd/conf/workers.properties" do
  content workers_file.join("\n") + "\n"
end

# create 2 tomcat home dir
tomcat1, _stderr, _status = Open3.capture3("ls /home/ubuntu | grep tomcat7")
tomcat2 = "#{tomcat1}_2"

# copying contents of tomcat1 to tomcat2
stdout, _stderr, _status = Open3.capture3("cp -a /home/ubuntu/#{tomcat1} /home/ubuntu/#{tomcat2}")

# retrieving server.xml path of both instances of tomcatboth tomcat instances
tomcat1_serverxml_path = Dir.glob("/home/ubuntu/#{tomcat1}/**/config/server.xml")
tomcat2_serverxml_path = Dir.glob("/home/ubuntu/#{tomcat2}/**/config/server.xml")

# retrieving web.xml path of both instances of tomcat
tomcat1_webxml_path = Dir.glob("/home/ubuntu/#{tomcat1}/**/server.xml")
tomcat2_webxml_path = Dir.glob("/home/ubuntu/#{tomcat2}/**/server.xml")

# editing server.xml file for both instances of tomcat
edit_file(tomcat1_serverxml_path, "protocol=\"AJP/1.3\"", "    <connector port=\"8180\" protocol=\"AJP/1.3\" redirectPort=\"8443\"></connector>")
edit_file(tomcat2_serverxml_path, "protocol=\"AJP/1.3\"", "    <connector port=\"8181\" protocol=\"AJP/1.3\" redirectPort=\"8443\"></connector>")
edit_file(tomcat1_serverxml_path, "<engine", "<engine name=\"Catalina\" defaultHost=\"localhost\" jvmRoute=\"tomcat1\"></engine>")
edit_file(tomcat2_serverxml_path, "<engine", "<engine name=\"Catalina\" defaultHost=\"localhost\" jvmRoute=\"tomcat2\"></engine>")
edit_file(tomcat1_serverxml_path, "<!-- cluster", "<cluster className=\"org.apache.catalina.ha.tcp.SimpleTcpCluster\"></cluster>")
edit_file(tomcat2_serverxml_path, "<!-- cluster", "<cluster className=\"org.apache.catalina.ha.tcp.SimpleTcpCluster\"></cluster>")

# addng <distributable> tag for web.xml for both instances of tomcat. This allows sharing of sessions among the Tomcat clustering instances.
edit_file(tomcat1_webxml_path, "</web>", "<distributable></distributable></web>")
edit_file(tomcat2_webxml_path, "</web>", "<distributable></distributable></web>")

def edit_file(filename, regex, line)
  ruby_block "editing #{filename}" do
    block do
      chef_file_edit = Chef::Util::FileEdit.new(filename)
      chef_file_edit.search_file_replace_line(regex, line)
      chef_file_edit.write_file
    end
  end
end

# adding catalina home env variable for both instances of tomcat
insert_at_end("/home/ubuntu/#{tomcat1}/bin/catalina.sh", "export CATALINA_HOME=/home/ubuntu/#{tomcat1}")
insert_at_end("/home/ubuntu/#{tomcat2}/bin/catalina.sh", "export CATALINA_HOME=/home/ubuntu/#{tomcat2}")

def insert_at_end(filename, line)
  ruby_block "editing #{filename}" do
    block do
      chef_file_edit = Chef::Util::FileEdit.new(filename)
      chef_file_edit.insert_line_if_no_match(line, line)
      chef_file_edit.write_file
    end
  end
end

# restarting the required services
services.each do |serv|
  service serv do
    action :restart
  end
end

# Locate mysql config file by running the mysql help command and looking for the config files in that order
mysqld_path = `which mysqld 2>/dev/null`.chomp

unless mysqld_path.empty?
  stdout, _stderr, _status = Open3.capture3("find $(#{mysqld_path} --help --verbose | grep cnf)")
  conffile = stdout.chomp

  # Get the SQL username and data directory from the configuration file

  username = `egrep "^user\s*=" #{conffile}`.chomp.split(/\s*=\s*/).last || 'root'
  sqldata = `egrep "^datadir\s*=" #{conffile}`.chomp.split(/\s*=\s*/).last || '/var/lib/mysql'

  # Get MySQL Home Directory

  mysql_home_dir, _stderr, _status = Open3.capture3("awk -F: -v v=\"#{username}\" '{if ($1==v) print $6}' /etc/passwd")
  mysql_home_dir.strip!

end
