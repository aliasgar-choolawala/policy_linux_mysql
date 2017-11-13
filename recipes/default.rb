require 'open3'

services = ['httpd', 'tomcat7', 'mysqld']

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
