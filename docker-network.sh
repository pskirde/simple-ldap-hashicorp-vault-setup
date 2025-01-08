#!/bin/bash
set -e  # Exit on error

echo "Creating Docker network..."
docker network create ldap-demo || true

echo "Connecting OpenLDAP to network..."
docker network connect ldap-demo openldap || true

echo "Network setup complete!"
