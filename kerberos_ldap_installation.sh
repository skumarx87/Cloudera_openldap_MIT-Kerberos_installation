#!/bin/bash

###Update the main function with your domain/root admin and password before proceed

main() {

KRB_DOMAIN_NAME="TANU.COM"
KDC_KEY_PASSWD=kdc123
KDC_ADMIN_PASSWD=sathish123

ldap_root_dc="tanu"
openldap_secreat="support123"
ldap_olcSuffix=dc="${ldap_root_dc},dc=com"
ldap_olcRootDN="cn=admin,dc=${ldap_root_dc},dc=com"

root_ca_password="support123"
pem_key_password="support123"
KRB_DOMAIN_NAME="TANU.COM"
kerberos_server_hostname="idm.tanu.com"
ldap_server_host="idm.tanu.com"

ldap_user_profile_ou="ou=People,dc=${ldap_root_dc},dc=com"
ldap_user_test="user5"
ldap_user_test_passwd="test123"

client_hostname="client1.tanu.com"

}

server_presetup() {

yum -y install git-core net-tools krb5-workstation

hostnamectl set-hostname ${kerberos_server_hostname} 
sed -i '/^SELINUX/s/=.*$/=disabled/' /etc/selinux/config
echo 0 > /sys/fs/selinux/enforce
systemctl stop firewalld.service
systemctl disable firewalld.service
yum -y install git-core net-tools krb5-workstation


}

client_presetup() {

yum -y install git-core net-tools krb5-workstation

hostnamectl set-hostname ${client_hostname}
sed -i '/^SELINUX/s/=.*$/=disabled/' /etc/selinux/config
echo 0 > /sys/fs/selinux/enforce
systemctl stop firewalld.service
systemctl disable firewalld.service
yum -y install git-core net-tools krb5-workstation


}

check_file_exists(){

file_path=$1
Error_msg=$2

if [ ! -f ${file_path} ]
then
	echo "---------------------------------------------------"
	echo "$2						 "
	echo "---------------------------------------------------"
	exit -1
fi
}
banner_msg() {
	msg=$1
	echo "---------------------------------------------------"
	echo "${msg}						 "
	echo "---------------------------------------------------"
}

create_krb5_conf() {

banner_msg "INFO: creating krb5.conf file"

DOMAIN_UPPER=$(echo $KRB_DOMAIN_NAME|  tr '[:lower:]' '[:upper:]')
DOMAIN_LOWER=$(echo $KRB_DOMAIN_NAME|  tr '[:upper:]' '[:lower:]')


cat > /etc/krb5.conf <<- "EOF"
[libdefaults]
    default_realm = DOMAIN.COM
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    forwardable = true
    udp_preference_limit = 1000000
    default_tkt_enctypes = aes256-cts des-cbc-md5 des-cbc-crc des3-cbc-sha1
    default_tgs_enctypes = aes256-cts des-cbc-md5 des-cbc-crc des3-cbc-sha1
    permitted_enctypes = aes256-cts des-cbc-md5 des-cbc-crc des3-cbc-sha1

[realms]
    DOMAIN.COM = {
        kdc = ldap_server_host:88
        admin_keytab = /var/kerberos/krb5kdc/kadmin.keytab
        admin_server = ldap_server_host:749
        default_domain = domain.com
        database_module = openldap_ldapconf
    }

[domain_realm]
    .domain.com = DOMAIN.COM
     domain.com = DOMAIN.COM

[dbdefaults]
        ldap_kerberos_container_dn = cn=krbContainer,ldap_olcSuffix

[dbmodules]
        openldap_ldapconf = {
                db_library = kldap
                ldap_kdc_dn = "ldap_olcRootDN"

                # this object needs to have read rights on
                # the realm container, principal container and realm sub-trees
                ldap_kadmind_dn = "ldap_olcRootDN"

                # this object needs to have read and write rights on
                # the realm container, principal container and realm sub-trees
                ldap_service_password_file = /etc/krb5.d/service.keyfile
                ldap_servers = ldaps://ldap_server_host
                ldap_conns_per_server = 5
        }
[logging]
    kdc = FILE:/var/log/krb5kdc.log
    admin_server = FILE:/var/log/kadmin.log
    default = FILE:/var/log/krb5lib.log

EOF
 sed -i "s/DOMAIN.COM/${DOMAIN_UPPER}/"g /etc/krb5.conf
 sed -i "s/domain.com/${DOMAIN_LOWER}/"g /etc/krb5.conf
 sed -i "s/ldap_server_host/${ldap_server_host}/"g /etc/krb5.conf
 sed -i "s/ldap_server_host/${ldap_server_host}/"g /etc/krb5.conf
 sed -i "s/ldap_olcRootDN/${ldap_olcRootDN}/"g /etc/krb5.conf
 sed -i "s/ldap_olcRootDN/${ldap_olcRootDN}/"g /etc/krb5.conf
 sed -i "s/ldap_olcSuffix/${ldap_olcSuffix}/"g /etc/krb5.conf


}

install_kerberos_server() {

banner_msg "INFO: install_kerberos_server function"

#git clone https://github.com/skumarx87/MIT-kerberos-installation.git
#chmod -R 755 MIT-kerberos-installation
#cd MIT-kerberos-installation
#sh -x install_mit_kerberos.sh server
DOMAIN_UPPER=$(echo $KRB_DOMAIN_NAME|  tr '[:lower:]' '[:upper:]')
DOMAIN_LOWER=$(echo $KRB_DOMAIN_NAME|  tr '[:upper:]' '[:lower:]')

yum -y install krb5-server krb5-libs
yum -y install krb5-server-ldap

create_krb5_conf

}

create_root_ca_pair(){

banner_msg "INFO: Running create_root_ca_pair function"

### Creating Root key and Certificate ###
mkdir -p ca_root_key
openssl genrsa -des3 -out ca_root_key/MyRootCA.key -passout pass:${root_ca_password} 2048
openssl req -x509 -new -nodes -key ca_root_key/MyRootCA.key -sha256 -passin  pass:${root_ca_password} -days 5000 -out ca_root_key/MyRootCA.pem -subj "/C=US/ST=NY/L=NYC/O=Global Security/OU=IT Department/CN=Hadoop CA Authority"

[ -d /etc/ssl/certs/${kerberos_server_hostname} ] || mkdir -p /etc/ssl/certs/${kerberos_server_hostname}
cp -rv ca_root_key/MyRootCA.pem /etc/ssl/certs/${kerberos_server_hostname}/


}

creating_ldap_ssl_pair_pem(){

banner_msg "INFO: Running creating_ldap_ssl_pair_pem function"

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
banner_msg "INFO: Running openldap_installation function"
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

sed -i "s~ldap_secreat~"${ldap_secreat}"~g" /tmp/my_config2.ldif
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

banner_msg "INFO: Running enable_ldap_tls function"
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

grep "^SLAPD_URLS" /etc/sysconfig/slapd |grep ldaps
retn_val=$?
if [ ${retn_val} != 0 ]
then
	sed -i "s/^SLAPD_URLS=/#SLAPD_URLS=/" /etc/sysconfig/slapd
	echo "SLAPD_URLS=\"ldapi:/// ldap:/// ldaps:///\"">>/etc/sysconfig/slapd
	systemctl restart slapd.service
fi	

grep "^TLS_CACERTDIR" /etc/openldap/ldap.conf
retn_val=$?
if [ ${retn_val} == 0 ]
then
        sed -i "s/^TLS_CACERTDIR/#TLS_CACERTDIR=/" /etc/openldap/ldap.conf
        echo "TLS_CACERT  /etc/ssl/certs/${kerberos_server_hostname}/MyRootCA.pem">>/etc/openldap/ldap.conf
fi

}

enable_kerberos_ldap_backend(){

banner_msg "INFO: Running enable_kerberos_ldap_backend function"
yum -y install krb5-server-ldap

cp -v /usr/share/doc/krb5-server-ldap-*/kerberos.schema /etc/openldap/schema

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

creating_kerberos_db() {

#kdb5_ldap_util -D ${ldap_olcRootDN}  -H ldaps://${ldap_server_host} create -subtrees ${ldap_olcSuffix} -sscope SUB -r ${KRB_DOMAIN_NAME} -w ${openldap_secreat} -P ${KDC_KEY_PASSWD}
[ -d /etc/krb5.d/ ] || mkdir -p /etc/krb5.d/
banner_msg "INFO: type this password to create ldap stash password : ${openldap_secreat}"
kdb5_ldap_util -D ${ldap_olcRootDN} -w ${openldap_secreat} stashsrvpw -f /etc/krb5.d/service.keyfile ${ldap_olcRootDN}
banner_msg "INFO: Creating ${KRB_DOMAIN_NAME} KDC Database"
kdb5_util create -s -r ${KRB_DOMAIN_NAME}  -P ${KDC_KEY_PASSWD}
check_file_exists "/etc/krb5.d/service.keyfile" "ERROR: ldap stash file creation failed in /etc/krb5.d/service.keyfile location"
banner_msg "INFO: Creating kadmin.keytab. otherwise admin service won't start"
kadmin.local -q "ktadd -k /var/kerberos/krb5kdc/kadmin.keytab kadmin/admin kadmin/${kerberos_server_hostnam} kadmin/${kerberos_server_hostnam} kadmin/changepw"
kadmin.local -q "addprinc -pw ${KDC_ADMIN_PASSWD} root/admin@${KRB_DOMAIN_NAME}"
check_file_exists "/var/kerberos/krb5kdc/kadmin.keytab" "ERROR: kadmin.keytab file creation failed in var/kerberos/krb5kdc/kadmin.keytab location"

echo -e "\n Starting KDC services"
service krb5kdc start
service kadmin start
chkconfig krb5kdc on
chkconfig kadmin on

}

settingup_ldapclient_authentication() {

CLIENT_FQDN_HOST=$(hostname -f)

yum install -y openldap-clients nss-pam-ldapd net-tools krb5-workstation
authconfig --enableldap --enableldapauth --ldapserver=ldaps://${ldap_server_host} --ldapbasedn="${ldap_user_profile_ou}" --enablemkhomedir --update

ldap_user_test_passwd_encty=$(slappasswd -s ${ldap_user_test_passwd})

cat > /tmp/ldapusers.ldif <<- "EOF"
dn: ldap_user_profile_ou 
objectClass: organizationalUnit
ou: People

dn: uid=ldap_user_test,ldap_user_profile_ou
objectClass: top
objectClass: account
objectClass: posixAccount
objectClass: shadowAccount
cn: ldap_user_test
uid: ldap_user_test
uidNumber: 9998
gidNumber: 100
homeDirectory: /home/ldap_user_test
loginShell: /bin/bash
gecos: Linuxuser [Admin (at) HostAdvice]
userPassword: {SASL}ldap_user_test@KRB_DOMAIN_NAME
shadowLastChange: 17058
shadowMin: 0
shadowMax: 99999
shadowWarning: 7
EOF

sed -i "s/ldap_user_profile_ou/${ldap_user_profile_ou}/g" /tmp/ldapusers.ldif
sed -i "s/ldap_user_test/${ldap_user_test}/g" /tmp/ldapusers.ldif
sed -i "s/KRB_DOMAIN_NAME/"${KRB_DOMAIN_NAME}"/g" /tmp/ldapusers.ldif
ldapadd -h localhost -D "${ldap_olcRootDN}" -w ${openldap_secreat} -f /tmp/ldapusers.ldif 
echo "TLS_CACERT  /etc/ssl/certs/${kerberos_server_hostname}/MyRootCA.pem" >>/etc/nslcd.conf
echo "binddn ${ldap_olcRootDN}" >>/etc/nslcd.conf
echo "bindpw ${openldap_secreat}" >>/etc/nslcd.conf
systemctl restart nslcd.service


kadmin.local -q "addprinc -pw ${ldap_user_test_passwd} ${ldap_user_test}"
kadmin.local -q "addprinc -randkey host/${CLIENT_FQDN_HOST}@${KRB_DOMAIN_NAME}"
kadmin.local -q "ktadd -k /etc/krb5.keytab host/${CLIENT_FQDN_HOST}"
}

setting_kerberos_ldap_client(){

check_file_exists "/etc/ssl/certs/${kerberos_server_hostname}/MyRootCA.pem" "ERROR: ensure /etc/ssl/certs/${kerberos_server_hostname}/MyRootCA.pem file copied from kerberos server to all the client hosts in same folder path otherwise ldap connection(bind) will fail with ssl handshake error"
CLIENT_FQDN_HOST=$(hostname -f)
banner_msg "INFO: setting_kerberos_ldap_client installation/configuration"

yum install -y openldap-clients nss-pam-ldapd net-tools krb5-workstation
create_krb5_conf
authconfig --enableldap --enableldapauth --ldapserver=ldaps://${ldap_server_host} --ldapbasedn="${ldap_user_profile_ou}" --enablemkhomedir --update

banner_msg "INFO: Creating host keytab file"

kadmin -w ${KDC_ADMIN_PASSWD} -q "addprinc -pw ${ldap_user_test_passwd} ${ldap_user_test}"
kadmin -w ${KDC_ADMIN_PASSWD} -q "addprinc -randkey host/${CLIENT_FQDN_HOST}@${KRB_DOMAIN_NAME}"
kadmin -w ${KDC_ADMIN_PASSWD} -q "ktadd -k /etc/krb5.keytab host/${CLIENT_FQDN_HOST}"

echo "TLS_CACERT  /etc/ssl/certs/${kerberos_server_hostname}/MyRootCA.pem" >>/etc/nslcd.conf
echo "binddn ${ldap_olcRootDN}" >>/etc/nslcd.conf
echo "bindpw ${openldap_secreat}" >>/etc/nslcd.conf
systemctl restart nslcd.service

}

install_sasl_service(){

yum -y install cyrus-sasl

banner_msg "INFO: Creating /etc/sasl2/slapd.conf file for LDAP Sasl authencation"
banner_msg "INFO: dont fotget to copy /etc/ssl/certs/${kerberos_server_hostname}/MyRootCA.pem file from kerber server to all the client in same folder path otherwise LDAP bind will not work"

cat > /etc/sasl2/slapd.conf <<- "EOF"
mech_list: external gssapi plain
pwcheck_method: saslauthd
EOF

echo "SOCKETDIR=/var/run/saslauthd" >>/etc/sysconfig/saslauthd
echo "MECH=kerberos5" >>/etc/sysconfig/saslauthd
echo "KRB5_KTNAME=/etc/krb5.keytab" >>/etc/sysconfig/saslauthd
systemctl restart saslauthd.service

}

main
case "$1" in
	server_setup)
		server_presetup
		create_root_ca_pair
		creating_ldap_ssl_pair_pem
		openldap_installation
		install_sasl_service
		enable_ldap_tls
		install_kerberos_server
		enable_kerberos_ldap_backend
		creating_kerberos_db
		;;
	client_setup)
		client_presetup
		setting_kerberos_ldap_client
		;;
	*)
		echo $"Usage: $0 {server_setup|client_setup}"
		exit 2
		;;
esac

#server_presetup
#create_root_ca_pair
#creating_ldap_ssl_pair_pem
#openldap_installation
#install_sasl_service
#enable_ldap_tls
#install_kerberos_server
#enable_kerberos_ldap_backend
#creating_kerberos_db
#client_presetup
#setting_kerberos_ldap_client
#settingup_ldapclient_authentication
#create_krb5_conf
