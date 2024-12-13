#!/bin/bash

# Generate a random password
PASSWORD_ROOT=$(openssl rand -base64 32) # root password for mysql
PASSWORD_DUMMY=$(openssl rand -base64 32) # dummy password for drupal user

# Create the secrets directory if it doesn't exist
mkdir -p secrets

echo "$PASSWORD_ROOT" > secrets/mysql_root_password.txt
echo "$PASSWORD_DUMMY" > secrets/mysql_password.txt

chmod 600 secrets/*

echo "Secrets generated and saved to secrets/ directory."
