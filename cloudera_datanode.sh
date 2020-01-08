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

banner_msg "Installing Java 1.8 and JCE policy files"
yum -y install oracle-j2sdk1.8 unzip
cd /var/tmp/startup_dir/openldap_MIT-Kerberos_installation
unzip jce_policy-8.zip -d /usr/java/jdk1.8.0_181-cloudera/jre/lib/security
cp -r /usr/java/jdk1.8.0_181-cloudera/jre/lib/security/UnlimitedJCEPolicyJDK8/{local_policy.jar,US_export_policy.jar} /usr/java/jdk1.8.0_181-cloudera/jre/lib/security/

yum -y install cloudera-manager-agent

banner_msg "Mysql JDBC driver installation"

curl -L -o mysql-connector-java-5.1.46.tar.gz https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz
tar zxvf mysql-connector-java-5.1.46.tar.gz
mkdir -p /usr/share/java/
cd mysql-connector-java-5.1.46
cp -v mysql-connector-java-5.1.46-bin.jar /usr/share/java/mysql-connector-java.jar

sed -i "/#cloudera_mysql_connector_jar/s/^#//g" /etc/cloudera-scm-agent/config.ini
sed -i "s/\(server_host=\).*\$/\1${CM_HOST}/" /etc/cloudera-scm-agent/config.ini
hostname=$(hostname -f)
mkdir -p /opt/cloudera/certs/
curl -o ${hostname}.zip http://${CM_HOST}/node_certs/${hostname}.zip
unzip ${hostname}.zip
cp -r ${hostname}/* /opt/cloudera/certs/

systemctl enable cloudera-scm-agent
systemctl start cloudera-scm-agent

##For testing
mkdir -p /data/dfs/snn
mkdir -p /data/dfs/dn
