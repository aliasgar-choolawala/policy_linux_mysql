# Policy - Linux MySQL [policy_linux_mysql]

This cookbook restarts mysqld, httpd, tomcat7 services.

### Description

* This cookbook works as follows :
  * Downloads and installs required packages for mysql, apache, tomcat7
  * Set java environment variables if not set
  * Open port for apache
  * Configure tomcat connector(modjk)
  * Configure httpd.conf file
  * Configure workers.properties for 2 instances of tomcat
  * Configure server.xml and web.xml for both instances of tomcat
  * Restart mysqld, httpd, tomcat7 services
  * Get mysql username, data directory, home directory
* Note :
  * Links used for reference :
    * https://joshua14.homelinux.org/blog/?p=1838
	* https://www.systemcodegeeks.com/web-servers/apache/set-tomcat-apache-mod_jk-cluster/