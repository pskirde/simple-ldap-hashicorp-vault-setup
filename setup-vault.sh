#!/bin/bash
set -e  # Exit on error

echo "Starting Vault container..."
docker run -d \
  --name vault \
  --cap-add=IPC_LOCK \
  --network ldap-demo \
  -p 8200:8200 \
  -e 'VAULT_DEV_ROOT_TOKEN_ID=root' \
  -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' \
  hashicorp/vault:latest

echo "Waiting for Vault to start..."
sleep 5

# Set Vault address and token for CLI
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

echo "Enabling LDAP auth method..."
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @- \
    ${VAULT_ADDR}/v1/sys/auth/ldap <<EOF
{
  "type": "ldap"
}
EOF

echo "Configuring LDAP auth method..."
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @- \
    ${VAULT_ADDR}/v1/auth/ldap/config <<EOF
{
  "url": "ldap://172.21.0.2:389",
  "userdn": "ou=people,dc=example,dc=com",
  "groupdn": "ou=groups,dc=example,dc=com",
  "groupfilter": "(|(memberUid={{.Username}})(member={{.UserDN}})(uniqueMember={{.UserDN}}))",
  "userattr": "uid",
  "binddn": "cn=admin,dc=example,dc=com",
  "bindpass": "admin_password",
  "starttls": false
}
EOF

echo "Creating enhanced policies..."
# Create dev policy with full access to data and metadata
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request PUT \
    --data @- \
    ${VAULT_ADDR}/v1/sys/policies/acl/dev <<EOF
{
  "policy": "
    # Full access to dev secrets data
    path \"secret/data/dev/*\" {
      capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]
    }
    # Full access to dev secrets metadata
    path \"secret/metadata/dev/*\" {
      capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]
    }
    # Allow listing
    path \"secret/metadata/*\" {
      capabilities = [\"list\"]
    }
  "
}
EOF

# Create ops policy with full access to data and metadata
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request PUT \
    --data @- \
    ${VAULT_ADDR}/v1/sys/policies/acl/ops <<EOF
{
  "policy": "
    # Full access to ops secrets data
    path \"secret/data/ops/*\" {
      capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]
    }
    # Full access to ops secrets metadata
    path \"secret/metadata/ops/*\" {
      capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]
    }
    # Allow listing
    path \"secret/metadata/*\" {
      capabilities = [\"list\"]
    }
  "
}
EOF

echo "Mapping LDAP groups to policies..."
# Map dev group to dev policy
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @- \
    ${VAULT_ADDR}/v1/auth/ldap/groups/dev <<EOF
{
  "policies": ["dev"]
}
EOF

# Map ops group to ops policy
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @- \
    ${VAULT_ADDR}/v1/auth/ldap/groups/ops <<EOF
{
  "policies": ["ops"]
}
EOF

echo "Setup complete!"
echo "Testing LDAP authentication with adam (member of both groups)..."
VAULT_TOKEN=$(curl \
    --request POST \
    --data @- \
    ${VAULT_ADDR}/v1/auth/ldap/login/adam <<EOF | jq -r '.auth.client_token'
{
  "password": "adminpw"
}
EOF
)

echo "Retrieved token: $VAULT_TOKEN"
echo "Testing token capabilities..."
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    ${VAULT_ADDR}/v1/sys/capabilities-self \
    --request POST \
    --data @- <<EOF
{
  "paths": [
    "secret/data/dev/test",
    "secret/metadata/dev/test",
    "secret/data/ops/test",
    "secret/metadata/ops/test"
  ]
}
EOF

echo
echo "Vault is now configured with LDAP authentication!"
echo "Vault UI: http://localhost:8200"
echo "Vault Root Token: root"
echo
echo "You can login with any LDAP user, for example:"
echo "- adam (dev and ops groups)"
echo "- bob (dev group)"
echo "- enja (ops group)"
echo
echo "To use vault CLI with LDAP auth:"
echo "export VAULT_ADDR='http://127.0.0.1:8200'"
echo "vault login -method=ldap username=adam"
echo
echo "Example operations you can now perform:"
echo "# For dev group members:"
echo "vault kv get secret/dev/test"
echo "vault kv put secret/dev/test foo=bar"
echo "vault kv metadata get secret/dev/test"
echo "vault kv metadata put secret/dev/test max_versions=10"
echo
echo "# For ops group members:"
echo "vault kv get secret/ops/test"
echo "vault kv put secret/ops/test foo=bar"
echo "vault kv metadata get secret/ops/test"
echo "vault kv metadata put secret/ops/test max_versions=10"
