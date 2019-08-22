#users=[]
#groups=[]
#user_map={}
#group_ids_map={}
#user_ids_map={}
#x = ''


import argparse
import sys

def main():
	global groups
	global users
	global group_ids_map
	global user_ids_map
	global user_map

	group_id_start_value=2000
	user_id_start_value=3000
	user_map={}
	groups=[]
	users=[]	
	group_ids_map={}
	user_ids_map={}
	with open("hadoop_users_map.txt") as f:
		 for line in f:
			if not line.startswith("#"):
				user=line.strip().split(":")[0]
				group=line.strip().split(":")[1].split(",")
				user_map[user]=group
				groups.extend(group)
				users.append(user)
	#groups = list(dict.fromkeys(groups)) ## remove dublicate
	for group_name in groups:
		group_id_start_value += 1
		group_ids_map[group_name]=group_id_start_value

	for user_name in users:
		user_id_start_value +=1
		user_ids_map[user_name] = user_id_start_value

def create_domain_suffix_and_ou():
	user_ou_name=ldap_user_profile_ou.split(",")[0].split("=")[1]
	group_ou_name=ldap_group_profile_ou.split(",")[0].split("=")[1]
	domain_lower=KRB_DOMAIN.lower().split(".")[0]
	line="""
#dn: {root_domain} 
#objectClass: dcObject
#objectClass: organization
#dc: {domain} 
#o: {domain} 

dn: {group_ou} 
objectclass: organizationalunit
ou: {group_ou_name}

dn: {user_ou} 
objectclass: organizationalunit
ou: {user_ou_name} 

	"""
	print(line.format(root_domain=root_dc,domain=domain_lower,group_ou=ldap_group_profile_ou,user_ou=ldap_user_profile_ou,group_ou_name=group_ou_name,user_ou_name=user_ou_name).strip())
	print("")
		

def create_user_ldif():
	for user in users:
		x = ''
		for group_id in user_map[user]:
			y = ("gidNumber: "+str(group_ids_map[group_id])+"\n")
			x = (x + y)
		a="""
dn: uid={username},{ou}
objectClass: top
objectClass: account
objectClass: posixAccount
objectClass: shadowAccount
cn: {username}
uid: {username}
uidNumber: {userid}
gidNumber: {gidno}
homeDirectory: /home/{username}
loginShell: /bin/bash
gecos: Hadoop users and groups
userPassword: {encypt_type}{username}@{KRB_DOMAIN}
shadowLastChange: 17058
shadowMin: 0
shadowMax: 99999
shadowWarning: 7
		"""
		print("")
		print(a.format(username=user,userid=user_ids_map[user],encypt_type="{SASL}",KRB_DOMAIN=KRB_DOMAIN,ou=ldap_user_profile_ou,gidno=group_ids_map[user]).strip())
		for group_id in user_map[user]:
			y = ("gidNumber: "+group_id)
		#	print(y)
			x = (x + y)
			#print("gidNumber: {}".format(group_id))

def create_group_ldif():
	global groups
	groups = list(dict.fromkeys(groups))
	for group in groups:
		print("dn: cn={},{}".format(group,ldap_group_profile_ou))
		print("objectClass: top")
		print("objectClass: posixGroup")
		print("gidNumber: {}".format(group_ids_map[group]))
		for k in user_map:
			if group in user_map[k]:
				print("memberUid: {}".format(k))
		print("")
	
def silent_mode_ldif_generate():
	global ldap_user_profile_ou
	global ldap_group_profile_ou
	global KRB_DOMAIN
	global root_dc

	KRB_DOMAIN=args.krb_domain
	ldap_user_profile_ou=args.ldap_user_ou
	ldap_group_profile_ou=args.ldap_group_ou
	root_dc=args.rootdc
	main()
	create_domain_suffix_and_ou()	
	create_group_ldif()
	create_user_ldif()
		

def generate_ldif_file():

        global ldap_user_profile_ou
        global ldap_group_profile_ou
        global KRB_DOMAIN
        global root_dc

	KRB_DOMAIN="TANU.COM"
	ldap_user_profile_ou="ou=People,dc=tanu,dc=com"
	ldap_group_profile_ou="ou=Groups,dc=tanu,dc=com"
	root_dc="dc=tanu,dc=com"

        main()
        create_domain_suffix_and_ou()
        create_group_ldif()
        create_user_ldif()
		
#KRB_DOMAIN="TANU.COM"
#ldap_user_profile_ou="ou=People,dc=tanu,dc=com"
#ldap_group_profile_ou="ou=Groups,dc=tanu,dc=com"
#root_dc="dc=tanu,dc=com"

ap=argparse.ArgumentParser()
ap.add_argument("--silent",required=False,help="silent installation from shell script",action='store_true')
ap.add_argument("--krb_domain",required='--silent' in sys.argv,help="keberos domain name ex. EXAMPLE.COM")
ap.add_argument("--rootdc",required='--silent' in sys.argv,help="root suffix of the ldap ex. dc=exmple,dc=com")
ap.add_argument("--ldap_user_ou",required='--silent' in sys.argv,help="OU of the user Profile ex. ou=peopls,dc=exmple,dc=com")
ap.add_argument("--ldap_group_ou",required='--silent' in sys.argv,help="OU of the Group Profile ex. ou=groups,dc=exmple,dc=com")
args=ap.parse_args()

if args.silent:
	silent_mode_ldif_generate()
else:
	generate_ldif_file()
	

#main()
#create_domain_suffix_and_ou()
#create_group_ldif()
#create_user_ldif()
