#!/bin/bash

###Update the main function with your domain/root admin and password before proceed

main() {

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

kerberos_installation() {

git clone https://github.com/skumarx87/MIT-kerberos-installation.git
chmod -R 755 MIT-kerberos-installation
cd MIT-kerberos-installation
sh -x install_mit_kerberos.sh server

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
}

main
#install_git
kerberos_installation
create_root_ca_pair
creating_ldap_ssl_pair_pem
openldap_installation
enable_ldap_tls
