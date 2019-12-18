#!/bin/bash

CLOUDERA_REPO_URL=https://archive.cloudera.com/cm6/6.3.1/redhat7/yum/cloudera-manager.repo
MYSQL_SECRET="mysqladmin"

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
echo -e "\n\\${MYSQL_SECRET}\n${MYSQL_SECRET}\n\n\nn\n\n " | mysql_secure_installation 2>/dev/null
