#!/bin/bash

CLOUDERA_REPO_URL=https://archive.cloudera.com/cm6/6.3.1/redhat7/yum/cloudera-manager.repo
MYSQL_SECRET="mysqladmin"
Hadoop_databases="scm amon rman hue metastore sentry nav navms oozie"

function banner_msg() {
echo "------------------------------------------------------"
echo "$1                                                    "
echo "------------------------------------------------------"
}

banner_msg "Cloudera manager installation"

wget ${CLOUDERA_REPO_URL} -P /etc/yum.repos.d/
rpm --import https://archive.cloudera.com/cm6/6.3.1/redhat7/yum/RPM-GPG-KEY-cloudera
yum -y install oracle-j2sdk1.8

yum -y install cloudera-manager-daemons cloudera-manager-agent cloudera-manager-server

banner_msg "Mysql database Installation"

curl -o  mysql-community-release-el7-5.noarch.rpm http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
rpm -ivh mysql-community-release-el7-5.noarch.rpm
#yum update
yum -y install mysql-server
systemctl start mysqld
systemctl enable mysqld
mysql -e "UPDATE mysql.user SET Password = PASSWORD('${MYSQL_SECRET}') WHERE User = 'root'"
mysql -e "DROP USER ''@'localhost'"
mysql -e "DROP USER ''@'$(hostname)'"
mysql -e "FLUSH PRIVILEGES"
banner_msg "Creating hadoop services databases"
for hd_database in ${Hadoop_databases}
        do
        banner_msg "Creating ${hd_database} database and user ${hd_database}"
        mysql -uroot -p${MYSQL_SECRET} -e "CREATE DATABASE ${hd_database} /*\!40100 DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;"
        mysql -uroot -p${MYSQL_SECRET} -e "CREATE USER ${hd_database}@'%' IDENTIFIED BY '${hd_database}';"
        mysql -uroot -p${MYSQL_SECRET} -e "GRANT ALL PRIVILEGES ON ${hd_database}.* TO '${hd_database}'@'%';"
        mysql -uroot -p${MYSQL_SECRET} -e "FLUSH PRIVILEGES;"
        done
banner_msg "Mysql JDBC driver installation"

curl -L -o mysql-connector-java-5.1.46.tar.gz https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz
tar zxvf mysql-connector-java-5.1.46.tar.gz
mkdir -p /usr/share/java/
cd mysql-connector-java-5.1.46
cp -v mysql-connector-java-5.1.46-bin.jar /usr/share/java/mysql-connector-java.jar

banner_msg "SCM database preparing"

/opt/cloudera/cm/schema/scm_prepare_database.sh mysql scm scm scm

banner_msg "Starting cloudera manager"

systemctl start cloudera-scm-server
