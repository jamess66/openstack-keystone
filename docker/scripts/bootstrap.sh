#!/bin/bash
set -e

# Wait for DB
until mysql -h db -u root -ppassword --skip-ssl -e 'select 1'; do
  echo "Waiting for DB..."
  sleep 1
done

# Sync DB
keystone-manage db_sync

# Initialize Fernet keys
keystone-manage fernet_setup --keystone-user root --keystone-group root
keystone-manage credential_setup --keystone-user root --keystone-group root

# Bootstrap Keystone
keystone-manage bootstrap --bootstrap-password password \
  --bootstrap-admin-url http://keystone:5000/v3/ \
  --bootstrap-internal-url http://keystone:5000/v3/ \
  --bootstrap-public-url http://keystone:5000/v3/ \
  --bootstrap-region-id RegionOne

# Start Keystone in background
uwsgi --http 0.0.0.0:5000 --wsgi-file /app/keystone-source/docker/scripts/wsgi-app.py &
PID=$!

# Wait for Keystone
echo "Waiting for Keystone to start on port 5000..."
for i in {1..30}; do
  if ! kill -0 $PID 2>/dev/null; then
    echo "uwsgi process died!"
    exit 1
  fi
  if curl -s http://localhost:5000/v3/ > /dev/null; then
    echo "Keystone is up!"
    break
  fi
  echo "Waiting for Keystone... ($i/30)"
  sleep 2
done

if ! curl -s http://localhost:5000/v3/ > /dev/null; then
    echo "Keystone failed to start within timeout."
    exit 1
fi

export OS_USERNAME=admin
export OS_PASSWORD=password
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_DOMAIN_ID=default
export OS_AUTH_URL=http://localhost:5000/v3
export OS_IDENTITY_API_VERSION=3

echo "Configuring Swift in Keystone..."

# Create Member Role
openstack role create member || true

# Create Service Project
openstack project create --domain default --or-show service

# Create Swift User
openstack user create --domain default --password password --or-show swift
openstack role add --project service --user swift admin

# Create Swift Service
openstack service create --name swift --description "OpenStack Object Storage" object-store || true

# Create Swift Endpoints
openstack endpoint create --region RegionOne object-store public http://swift:8080/v1/AUTH_%\(tenant_id\)s || true
openstack endpoint create --region RegionOne object-store internal http://swift:8080/v1/AUTH_%\(tenant_id\)s || true
openstack endpoint create --region RegionOne object-store admin http://swift:8080/v1/AUTH_%\(tenant_id\)s || true

echo "Keystone configuration complete."

# Wait for uwsgi
wait $PID
