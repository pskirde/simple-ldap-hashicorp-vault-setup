#!/bin/bash
set -e  # Exit on error

echo "Creating necessary directories..."
rm -rf ldap slapd.d
mkdir -p ldap slapd.d

echo "Creating LDAP configuration files..."

# Create structure.ldif for base structure
cat > structure.ldif << 'EOL'
# Create organizational units
dn: ou=people,dc=example,dc=com
objectClass: organizationalUnit
ou: people

dn: ou=groups,dc=example,dc=com
objectClass: organizationalUnit
ou: groups
EOL

# Create users-and-groups.ldif
cat > users-and-groups.ldif << 'EOL'
# Create dev group
dn: cn=dev,ou=groups,dc=example,dc=com
objectClass: groupOfNames
cn: dev
member: uid=adam,ou=people,dc=example,dc=com
member: uid=bob,ou=people,dc=example,dc=com
member: uid=claire,ou=people,dc=example,dc=com

# Create ops group
dn: cn=ops,ou=groups,dc=example,dc=com
objectClass: groupOfNames
cn: ops
member: uid=adam,ou=people,dc=example,dc=com
member: uid=denise,ou=people,dc=example,dc=com
member: uid=enja,ou=people,dc=example,dc=com

# Create users
dn: uid=adam,ou=people,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: adam
cn: Adam
sn: Smith
uidNumber: 10000
gidNumber: 10000
homeDirectory: /home/adam
userPassword: adminpw

dn: uid=bob,ou=people,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: bob
cn: Bob
sn: Johnson
uidNumber: 10001
gidNumber: 10000
homeDirectory: /home/bob
userPassword: adminpw

dn: uid=claire,ou=people,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: claire
cn: Claire
sn: Williams
uidNumber: 10002
gidNumber: 10000
homeDirectory: /home/claire
userPassword: adminpw

dn: uid=denise,ou=people,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: denise
cn: Denise
sn: Brown
uidNumber: 10003
gidNumber: 10000
homeDirectory: /home/denise
userPassword: adminpw

dn: uid=enja,ou=people,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: enja
cn: Enja
sn: Garcia
uidNumber: 10004
gidNumber: 10000
homeDirectory: /home/enja
userPassword: adminpw
EOL

# Create acl.ldif
cat > acl.ldif << 'EOL'
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read by dn.base="cn=admin,dc=example,dc=com" write by * read
EOL

echo "Starting OpenLDAP container..."
docker run -d \
  --name openldap \
  -p 389:389 \
  -p 636:636 \
  -e LDAP_ORGANISATION="Example Inc" \
  -e LDAP_DOMAIN="example.com" \
  -e LDAP_BASE_DN="dc=example,dc=com" \
  -e LDAP_ADMIN_PASSWORD="admin_password" \
  -v $(pwd)/ldap:/var/lib/ldap \
  -v $(pwd)/slapd.d:/etc/ldap/slapd.d \
  osixia/openldap:latest

echo "Waiting for OpenLDAP to start..."
sleep 5

echo "Copying configuration files to container..."
docker cp structure.ldif openldap:/tmp/structure.ldif
docker cp users-and-groups.ldif openldap:/tmp/users-and-groups.ldif
docker cp acl.ldif openldap:/tmp/acl.ldif

echo "Adding base structure..."
docker exec openldap ldapadd -x -D "cn=admin,dc=example,dc=com" -w admin_password -f /tmp/structure.ldif

echo "Adding users and groups..."
docker exec openldap ldapadd -x -D "cn=admin,dc=example,dc=com" -w admin_password -f /tmp/users-and-groups.ldif

echo "Configuring ACLs..."
docker exec openldap ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/acl.ldif

echo "Testing admin access..."
docker exec openldap ldapsearch -x -D "cn=admin,dc=example,dc=com" -w admin_password -b "dc=example,dc=com" "(objectclass=*)"

echo "Testing user (Adam) access..."
docker exec openldap ldapsearch -x -D "uid=adam,ou=people,dc=example,dc=com" -w adminpw -b "dc=example,dc=com" "(objectclass=*)"

echo "Setup complete!"
echo "You can now connect to LDAP on localhost:389"
echo "Admin DN: cn=admin,dc=example,dc=com"
echo "Admin password: admin_password"
echo "Sample user DN: uid=adam,ou=people,dc=example,dc=com"
echo "Sample user password: adminpw"
