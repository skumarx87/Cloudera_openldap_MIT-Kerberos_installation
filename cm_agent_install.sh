#!/bin/bash

CLOUDERA_REPO_URL=https://archive.cloudera.com/cm6/6.3.1/redhat7/yum/cloudera-manager.repo

CM_HOST=$1

if [ $# -ne 1 ]
then
        echo "Usage : $0 cm_hostname"
        exit -1
fi


function banner_msg() {
echo "------------------------------------------------------"
echo "$1                                                    "
echo "------------------------------------------------------"
}


banner_msg "Cloudera Manager Agent installation"

wget ${CLOUDERA_REPO_URL} -P /etc/yum.repos.d/
rpm --import https://archive.cloudera.com/cm6/6.3.1/redhat7/yum/RPM-GPG-KEY-cloudera
yum -y install oracle-j2sdk1.8

yum -y install cloudera-manager-agent

banner_msg "Mysql JDBC driver installation"

curl -L -o mysql-connector-java-5.1.46.tar.gz https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz
tar zxvf mysql-connector-java-5.1.46.tar.gz
mkdir -p /usr/share/java/
cd mysql-connector-java-5.1.46
cp -v mysql-connector-java-5.1.46-bin.jar /usr/share/java/mysql-connector-java.jar

sed -i "/#cloudera_mysql_connector_jar/s/^#//g" /etc/cloudera-scm-agent/config.ini
sed -i "s/\(server_host=\).*\$/\1${CM_HOST}/" /etc/cloudera-scm-agent/config.ini

systemctl enable cloudera-scm-agent
systemctl start cloudera-scm-agent
