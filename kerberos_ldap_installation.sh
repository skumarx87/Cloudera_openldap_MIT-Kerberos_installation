#!/bin/bash

###Update the main function with your domain/root admin and password before proceed

main() {

KRB_DOMAIN_NAME="TANU.COM"
KDC_KEY_PASSWD=kdc123
KDC_ADMIN_PASSWD=admin123

ldap_root_dc="tanu"
openldap_secreat="support123"
ldap_olcSuffix=dc="${ldap_root_dc},dc=com"
ldap_olcRootDN="cn=admin,dc=${ldap_root_dc},dc=com"

root_ca_password="support123"
pem_key_password="support123"
kerberos_server_hostname="idm.tanu.com"

}

install_git() {

yum -y install git-core

}

check_file_exists(){

file_path=$1
Error_msg=$2

if [ ! -f ${file_path} ]
then
	echo "---------------------------------------------------"
	echo "$2
	echo "---------------------------------------------------"
	exit -1
fi
}

kerberos_installation() {

#git clone https://github.com/skumarx87/MIT-kerberos-installation.git
#chmod -R 755 MIT-kerberos-installation
#cd MIT-kerberos-installation
#sh -x install_mit_kerberos.sh server

yum -y install krb5-server krb5-libs

kdb5_ldap_util -D ${ldap_olcRootDN}  -H ldaps://${kerberos_server_hostname} create -subtrees ${ldap_olcSuffix} -sscope SUB -r ${KRB_DOMAIN_NAME} -P ${KDC_KEY_PASSWD}
[ -d /etc/krb5.d/ ] || mkdir -p /etc/krb5.d/ 

coproc kdb5_ldap_util -D ${ldap_olcRootDN} stashsrvpw -f /etc/krb5.d/service.keyfile ${ldap_olcRootDN} 
echo ${openldap_secreat} >&${COPROC[1]}
echo ${openldap_secreat} >&${COPROC[1]}
echo ${openldap_secreat} >&${COPROC[1]}

check_file_exists "/etc/krb5.d/service.keyfile" "ERROR: ldap stash file creation failed in /etc/krb5.d/service.keyfile location"
 
echo -e "\n Starting KDC services"
service krb5kdc start
service kadmin start
chkconfig krb5kdc on
chkconfig kadmin on
echo -e "\n Creating admin principal"
kadmin.local -q "addprinc -pw root123 root/admin"

}

create_root_ca_pair(){

### Creating Root key and Certificate ###
mkdir -p ca_root_key
openssl genrsa -des3 -out ca_root_key/MyRootCA.key -passout pass:${root_ca_password} 2048
openssl req -x509 -new -nodes -key ca_root_key/MyRootCA.key -sha256 -passin  pass:${root_ca_password} -days 5000 -out ca_root_key/MyRootCA.pem -subj "/C=US/ST=NY/L=NYC/O=Global Security/OU=IT Department/CN=Hadoop CA Authority"

[ -d /etc/ssl/certs/${kerberos_server_hostname} ] || mkdir -p /etc/ssl/certs/${kerberos_server_hostname}
cp -rv ca_root_key/MyRootCA.pem /etc/ssl/certs/${kerberos_server_hostname}/


}

creating_ldap_ssl_pair_pem(){

### Creating SSL pair for Kerberos and Ldap server with CA signed (Pem format) ##
mkdir ${kerberos_server_hostname}
openssl genrsa -des3 -out ${kerberos_server_hostname}/${kerberos_server_hostname}_tmp.key -passout pass:${pem_key_password} 2048
openssl rsa -in ${kerberos_server_hostname}/${kerberos_server_hostname}_tmp.key -out ${kerberos_server_hostname}/${kerberos_server_hostname}.key -passin  pass:${pem_key_password}
rm -f ${kerberos_server_hostname}/${kerberos_server_hostname}_tmp.key

openssl req -new -key ${kerberos_server_hostname}/${kerberos_server_hostname}.key -out ${kerberos_server_hostname}/${kerberos_server_hostname}.csr -subj "/C=US/ST=NY/L=NYC/O=Global Security/OU=IT Department/CN=${kerberos_server_hostname}"
openssl x509 -req -in ${kerberos_server_hostname}/${kerberos_server_hostname}.csr -CA ca_root_key/MyRootCA.pem -CAkey ca_root_key/MyRootCA.key -passin  pass:${root_ca_password} -CAcreateserial -out ${kerberos_server_hostname}/${kerberos_server_hostname}.pem -days 5000  -sha256

[ -d /etc/ssl/certs/${kerberos_server_hostname} ] || mkdir -p /etc/ssl/certs/${kerberos_server_hostname}
cp -rv ${kerberos_server_hostname}/${kerberos_server_hostname}.* /etc/ssl/certs/${kerberos_server_hostname}/
}

openldap_installation() {
yum -y install openldap-clients openldap-servers
systemctl start slapd
systemctl enable slapd
systemctl status slapd
ldap_secreat=$(slappasswd -s ${openldap_secreat})

cat > /tmp/my_config.ldif <<- "EOF"
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: ldap_olcSuffix 

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: ldap_olcRootDN 

EOF
sed -i "s/ldap_olcSuffix/${ldap_olcSuffix}/g" /tmp/my_config.ldif
sed -i "s/ldap_olcRootDN/${ldap_olcRootDN}/g" /tmp/my_config.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/my_config.ldif

# Adding root password

cat > /tmp/my_config2.ldif <<- "EOF"
#dn: olcDatabase={2}hdb,cn=config
#changeType: modify
#add: olcRootPW
#olcRootPW: ldap_secreat 

dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcRootPW
olcRootPW: ldap_secreat 
EOF

sed -i "s/ldap_secreat/"${ldap_secreat}"/g" /tmp/my_config2.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/my_config2.ldif

# replacing olcAccess attribute 

cat > /tmp/my_config3.ldif <<- "EOF"
dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external, cn=auth" read by dn.base="ldap_olcRootDN" read by * none
EOF

sed -i "s/ldap_olcRootDN/${ldap_olcRootDN}/g" /tmp/my_config3.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/my_config3.ldif

## Adding Object

cat > /tmp/my_config4.ldif <<- "EOF"
dn: ldap_olcSuffix 
objectClass: dcObject
objectClass: organization
dc: ldap_root_dc 
o: ldap_root_dc
EOF

sed -i "s/ldap_root_dc/${ldap_root_dc}/g" /tmp/my_config4.ldif
sed -i "s/ldap_olcSuffix/${ldap_olcSuffix}/g" /tmp/my_config4.ldif
ldapadd -h localhost -D "${ldap_olcRootDN}" -w ${openldap_secreat} -f /tmp/my_config4.ldif

###  Setup LDAP database
cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
chown ldap:ldap /var/lib/ldap/*
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif 
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif

## Enable logging #########
cat > /tmp/slapdlog.ldif <<- "EOF"
dn: cn=config
changeType: modify
replace: olcLogLevel
olcLogLevel: stats
EOF
ldapmodify -Y external -H ldapi:/// -f /tmp/slapdlog.ldif

cat > /etc/rsyslog.d/10-slapd.conf <<- "EOF"
$template slapdtmpl,"[%$DAY%-%$MONTH%-%$YEAR% %timegenerated:12:19:date-rfc3339%] %app-name% %syslogseverity-text% %msg%\n"
local4.*    /var/log/slapd.log;slapdtmpl
EOF

systemctl restart rsyslog.service


}

enable_ldap_tls(){


cat > /tmp/addcerts.ldif <<- "EOF"
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ssl/certs/kerberos_server_hostname/MyRootCA.pem
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ssl/certs/kerberos_server_hostname/kerberos_server_hostname.pem
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ssl/certs/kerberos_server_hostname/kerberos_server_hostname.key
EOF

sed -i "s/kerberos_server_hostname/${kerberos_server_hostname}/g" /tmp/addcerts.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/addcerts.ldif

grep "^SLAPD_URLS" /var/tmp/slapd |grep ldaps
retn_val=$?
if [ ${retn_val} != 0 ]
then
	sed -i "s/^SLAPD_URLS=/#SLAPD_URLS=/" /etc/sysconfig/slapd
	echo "SLAPD_URLS=\"ldapi:/// ldap:/// ldaps:///\"">>/etc/sysconfig/slapd
	systemctl restart slapd.service
fi	

grep "^TLS_CACERTDIR" /etc/openldap/ldap.conf
retn_val=$?
if [ ${retn_val} != 0 ]
then
        sed -i "s/^TLS_CACERTDIR/#TLS_CACERTDIR=/" /etc/openldap/ldap.conf
        echo "TLS_CACERT  /etc/ssl/certs/${kerberos_server_hostname}/MyRootCA.pem">>/etc/openldap/ldap.conf
fi

}

enable_kerberos_ldap_backend(){

yum -y install krb5-server-ldap
cp -v /usr/share/doc/krb5-server-ldap-1.15.1/kerberos.schema /etc/openldap/schema

cat > /tmp/schema_convert.conf <<- "EOF"

include /etc/openldap/schema/core.schema
include /etc/openldap/schema/collective.schema
include /etc/openldap/schema/corba.schema
include /etc/openldap/schema/cosine.schema
include /etc/openldap/schema/duaconf.schema
include /etc/openldap/schema/dyngroup.schema
include /etc/openldap/schema/inetorgperson.schema
include /etc/openldap/schema/java.schema
include /etc/openldap/schema/misc.schema
include /etc/openldap/schema/nis.schema
include /etc/openldap/schema/openldap.schema
include /etc/openldap/schema/ppolicy.schema
include /etc/openldap/schema/kerberos.schema

EOF

mkdir /tmp/ldif_output

slapcat -f /tmp/schema_convert.conf -F /tmp/ldif_output -n0 -s "cn={12}kerberos,cn=schema,cn=config" > /tmp/cn=kerberos.ldif

# Edit /tmp/cn=kerberos.ldif and replace
sed -i "s/{12}kerberos/kerberos/g" /tmp/cn=kerberos.ldif 
sed -i "/^modifyTimestamp:\|^modifiersName:\|^entryCSN:\|^createTimestamp:\|^creatorsName:\|^entryUUID:\|^structuralObjectClass:/d" /tmp/cn=kerberos.ldif 

ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /tmp/cn=kerberos.ldif

cat > /tmp/kerberos_index.ldif <<- "EOF"
dn: olcDatabase={2}hdb,cn=config
add: olcDbIndex
olcDbIndex: krbPrincipalName eq,pres,sub
EOF

ldapmodify -Y EXTERNAL  -H ldapi:/// -f /tmp/kerberos_index.ldif


}

main
#install_git
#kerberos_installation
#create_root_ca_pair
#creating_ldap_ssl_pair_pem
#openldap_installation
#enable_ldap_tls
enable_kerberos_ldap_backend

