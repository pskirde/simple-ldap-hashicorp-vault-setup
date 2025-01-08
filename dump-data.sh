#!/bin/bash
set -e  # Exit on error

# Set Vault address and token
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

echo "Enabling KV secrets engine..."
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @- \
    ${VAULT_ADDR}/v1/sys/mounts/secret <<EOF
{
  "type": "kv",
  "options": {
    "version": "2"
  }
}
EOF

echo "Adding dev secrets..."
# Development API keys
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @- \
    ${VAULT_ADDR}/v1/secret/data/dev/api-keys <<EOF
{
  "data": {
    "development_api_key": "dev_api_12345",
    "staging_api_key": "stage_api_67890",
    "test_database_url": "postgresql://dev-db:5432/testdb"
  }
}
EOF

# Development config
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @- \
    ${VAULT_ADDR}/v1/secret/data/dev/config <<EOF
{
  "data": {
    "app_debug_mode": "true",
    "log_level": "DEBUG",
    "max_connections": "100",
    "feature_flags": {
      "new_ui": true,
      "beta_features": true
    }
  }
}
EOF

echo "Adding ops secrets..."
# Operations credentials
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @- \
    ${VAULT_ADDR}/v1/secret/data/ops/credentials <<EOF
{
  "data": {
    "production_db_password": "prod_db_pass_123",
    "monitoring_token": "mon_token_456",
    "backup_service_key": "backup_789"
  }
}
EOF

# Operations config
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @- \
    ${VAULT_ADDR}/v1/secret/data/ops/config <<EOF
{
  "data": {
    "backup_schedule": "0 2 * * *",
    "monitoring_endpoints": [
      "https://monitor1.example.com",
      "https://monitor2.example.com"
    ],
    "alert_thresholds": {
      "cpu_usage": 80,
      "memory_usage": 90,
      "disk_usage": 85
    }
  }
}
EOF

# Deployment information
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @- \
    ${VAULT_ADDR}/v1/secret/data/ops/deployment <<EOF
{
  "data": {
    "kubernetes_api_token": "k8s_token_xyz",
    "docker_registry_credentials": {
      "username": "deployment_user",
      "password": "deploy_pass_321"
    },
    "deployment_hooks": {
      "pre_deploy": "health_check.sh",
      "post_deploy": "notify_team.sh"
    }
  }
}
EOF

echo
echo "Secret data has been populated!"
echo
echo "Dev secrets available at:"
echo "- secret/dev/api-keys"
echo "- secret/dev/config"
echo
echo "Ops secrets available at:"
echo "- secret/ops/credentials"
echo "- secret/ops/config"
echo "- secret/ops/deployment"
echo
echo "To test access, you can use curl or the Vault CLI:"
echo "vault login -method=ldap username=adam"
echo "vault kv get secret/dev/api-keys"
echo "vault kv get secret/ops/config"
