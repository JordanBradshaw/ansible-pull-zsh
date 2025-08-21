#!/bin/bash
set -euo pipefail
# Step 1: Setup
# source .env
# BOOTSTRAP_DIR="/opt/ansible-bootstrap"
BOOTSTRAP_DIR=$(mktemp -d)
VENV_DIR="$BOOTSTRAP_DIR/.venv"

echo "[+] Creating bootstrap directory: $BOOTSTRAP_DIR"
mkdir -p "$BOOTSTRAP_DIR"

echo "[+] Creating Python virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# Step 2: Install required Python packages
echo "[+] Installing Ansible and dependencies..."
pip install --upgrade pip >/dev/null
pip install ansible 

# Your SSH key stored in an environment variable (should be set securely)
# : "${ANSIBLE_SSH_KEY:?Environment variable ANSIBLE_SSH_KEY is not set}"

# Create a temporary file for the key
# KEY_FILE=$(mktemp)
# chmod 600 "$KEY_FILE"


# echo "$ANSIBLE_SSH_KEY" > "$KEY_FILE"

# # Export GIT_SSH_COMMAND to use that key
# export GIT_SSH_COMMAND="ssh -i $KEY_FILE -o StrictHostKeyChecking=no"

# mkdir -p  /etc/ansible/facts.d/
# tee /etc/ansible/facts.d/roles.fact<<EOF
# [root]
# tailscale = true
# [ansible-provisioner]
# email_service = true
# [ansible]
# zsh = true

# EOF


# chmod 644 /etc/ansible/facts.d/*.fact




# echo "$VAULT_PASS" > ~/.ansible/.vault_pass.txt
# echo "$SSH_KEY" > ~/.ssh/ansible_ed25519


# Step 3: Run your Ansible logic here
echo "[+] Running ansible-playbook example (dry run)"
ansible --version

# You could instead pull and run a repo:
ansible-pull -c local --directory /tmp/ansible-pull-zsh -U https://github.com/JordanBradshaw/ansible-pull-zsh.git site.yml

# Step 4: Cleanup
echo "[+] Deactivating and cleaning up..."
deactivate
rm -rf "$BOOTSTRAP_DIR"
# Clean up
# rm -f "$KEY_FILE"
echo "[✓] Done."



# curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
# unzip awscliv2.zip
# ./aws/install --bin-dir /home/ansible/ansible-provisioner/.venv/bin --install-dir /home/ansible/ansible-provisioner/.venv/lib/aws-cli --update
# AWS_ACCESS_KEY_ID	Your AWS access key (from IAM user or assumed role)
# AWS_SECRET_ACCESS_KEY	Your AWS secret key
# AWS_SESSION_TOKEN	Temporary token (required if using STS or assumed roles)
# AWS_DEFAULT_REGION	Default region (e.g., us-east-1)
# AWS_REGION	Region override for some tools (same as above)
# AWS_PROFILE	Named profile from ~/.aws/credentials or ~/.aws/config
# AWS_CONFIG_FILE	Path to the config file (default is ~/.aws/config)
# AWS_SHARED_CREDENTIALS_FILE	Path to the credentials file (default is ~/.aws/credentials)

# aws secretsmanager get-secret-value --region us-west-1 --secret-id ansible --query SecretString
# source .env


# mkdir /tmp/ansible-bootstrap
# source .venv/bin/activate
# SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$AWS_SECRET_ID" --query "$AWS_QUERY" --output text)
# echo "$SECRET_JSON"
# VAULT_PASS=$(echo "$SECRET_JSON" | jq -r '.["ansible-vault-pass"]')
# SSH_KEY=$(echo "$SECRET_JSON" | jq -r '.["ansible-ssh-key"]' | base64 -d)

# echo "$VAULT_PASS" > ~/.ansible/.vault_pass.txt
# echo "$SSH_KEY" > ~/.ssh/ansible_ed25519
# deactivate
# echo "$PASSWORD"


# aws sts assume-role --role-arn arn:aws:iam::074993325733:role/Ansible-Role --role-session-name ansible-pull-session
