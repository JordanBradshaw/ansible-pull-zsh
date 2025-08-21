#!/bin/bash
set -euo pipefail

VENV_DIR="${HOME}/.venvs/ansible"

have() { command -v "$1" >/dev/null 2>&1; }

# 1) Ensure Python + venv tools exist (brew on macOS, apt/dnf/etc on Linux)
ensure_prereqs() {
  case "$(uname -s)" in
    Darwin)
      have brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      brew install -q python git >/dev/null
      ;;
    Linux)
      if   have apt-get; then sudo apt-get update -y && sudo apt-get install -y python3 python3-venv python3-pip git
      elif have dnf;     then sudo dnf install -y python3 python3-venv python3-pip git
      elif have yum;     then sudo yum install -y python3 python3-venv python3-pip git
      elif have pacman;  then sudo pacman -Sy --noconfirm python python-virtualenv git
      elif have zypper;  then sudo zypper --non-interactive in python3 python3-virtualenv git
      else echo "No supported package manager found"; exit 1; fi
      ;;
    *) echo "Unsupported OS"; exit 1;;
  esac
}

# 2) Create or reuse venv with Ansible inside
ensure_venv() {
  if [ ! -x "${VENV_DIR}/bin/python" ]; then
    python3 -m venv "${VENV_DIR}"
    "${VENV_DIR}/bin/python" -m pip install --upgrade pip wheel
    "${VENV_DIR}/bin/pip" install "ansible>=9" ansible-lint
  fi
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
}

# 3) If Ansible already on PATH, great; either way prefer the venv copy
if ! have ansible; then
  ensure_prereqs
fi

ensure_venv

# Use it
ansible --version



# Step 1: Setup
# source .env
# BOOTSTRAP_DIR="/opt/ansible-bootstrap"
# BOOTSTRAP_DIR=$(mktemp -d)
# VENV_DIR="$BOOTSTRAP_DIR/.venv"

# echo "[+] Creating bootstrap directory: $BOOTSTRAP_DIR"
# mkdir -p "$BOOTSTRAP_DIR"

# echo "[+] Creating Python virtual environment..."
# python3 -m venv "$VENV_DIR"
# source "$VENV_DIR/bin/activate"

# # Step 2: Install required Python packages
# echo "[+] Installing Ansible and dependencies..."
# pip install --upgrade pip >/dev/null
# pip install ansible 

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

echo "[+] Running ansible-playbook to get required packages. Will ask for root password so be ready!"
ansible-playbook -K -i localhost, -c local /dev/stdin <<'YAML'
---
- hosts: localhost
  gather_facts: true
  tasks:
    - name: Linux | update cache + install zsh & ansible
      when: ansible_system == 'Linux'
      become: true
      ansible.builtin.apt:
        name: [zsh]
        state: present
        update_cache: true
        cache_valid_time: 3600

    - name: macOS | install zsh & ansible with Homebrew
      when: ansible_system == 'Darwin'
      community.general.homebrew:
        name: [zsh]
        state: present
        update_homebrew: true
YAML

ansible-playbook -K -i localhost, -c local /dev/stdin <<'YAML'
---
- hosts: localhost
  gather_facts: true

  vars:
    ansible_pull_repo: "https://github.com/JordanBradshaw/ansible-pull-zsh.git"
    ansible_pull_playbook: "site.yml"
    ansible_pull_tags: "zsh"
    # Prefer explicit env, else current user
    zsh_user: >-
      {{
        lookup('env','ANSIBLE_SERVICE_ZSH_USER')
        | default(ansible_env.USER | default(ansible_user_id), true)
      }}

    # Home dir: explicit env -> shell expansion of ~user -> ansible_env.HOME -> $HOME
    zsh_user_home: >-
      {{
        lookup('env','ANSIBLE_SERVICE_ZSH_USER_HOME')
        | default(lookup('pipe','eval echo ~' ~ zsh_user), true)
        | default(ansible_env.HOME, true)
        | default(lookup('env','HOME'), true)
      }}

    # Config dir: macOS keeps ~/.config; Linux uses XDG if set else ~/.config
    zsh_user_config_dir: >-
      {{
        (ansible_system == 'Darwin')
          | ternary(zsh_user_home ~ '/.config',
                    (ansible_env.XDG_CONFIG_HOME | default(zsh_user_home ~ '/.config', true)))
      }}

    # Data dir: macOS Library path; Linux XDG if set else ~/.local/share
    zsh_user_data_dir: >-
      {{
        (ansible_system == 'Darwin')
          | ternary(zsh_user_home ~ '/Library/Application Support',
                    (ansible_env.XDG_DATA_HOME | default(zsh_user_home ~ '/.local/share', true)))
      }}

  tasks:
    - name: Install user-level ansible-pull Zsh service
      when: ansible_system == "Linux"
      block:
        - name: Get UID of {{ zsh_user }}
          ansible.builtin.command: "id -u {{ zsh_user | quote }}"
          register: zsh_user_uid

        - name: Create systemd user dir
          ansible.builtin.file:
            path: "{{ zsh_user_config_dir }}/systemd/user"
            state: directory
            mode: "0755"

        - name: Create ansible-pull-zsh working dir
          ansible.builtin.file:
            path: "{{ zsh_user_config_dir }}/ansible-pull-zsh"
            state: directory
            mode: "0755"

        - name: Compute tags from env
          set_fact:
            ansible_pull_tags: "{{ 'zsh,zsh-packages' if lookup('env','ANSIBLE_SERVICE_ZSH_PACKAGES') == 'true' else 'zsh' }}"

        - name: Optional extra environment for systemd (packages)
          set_fact:
            systemd_extra_environment: "{{ 'Environment=ANSIBLE_SERVICE_ZSH_PACKAGES=true' if lookup('env','ANSIBLE_SERVICE_ZSH_PACKAGES') == 'true' else '' }}"

        - name: Deploy ansible-pull-zsh.service
          ansible.builtin.copy:
            dest: "{{ zsh_user_config_dir }}/systemd/user/ansible-pull-zsh.service"
            mode: "0644"
            content: |
              [Unit]
              Description=Zsh Shell Provisioning with Ansible Pull
              After=network-online.target

              [Service]
              Type=oneshot
              WorkingDirectory={{ zsh_user_config_dir }}/ansible-pull-zsh
              Environment=ANSIBLE_SERVICE_ZSH=true
              Environment=ANSIBLE_SERVICE_ZSH_USER={{ zsh_user }}
              {{ systemd_extra_environment }}
              Environment="GIT_SSH_COMMAND=ssh -i %h/.ssh/ansible_ed25519 -o StrictHostKeyChecking=no"
              ExecStart=/usr/bin/env ansible-pull --only-if-changed -c local -i localhost, \
                -U {{ ansible_pull_repo }} {{ ansible_pull_playbook }} --tags {{ ansible_pull_tags }}

        - name: Deploy ansible-pull-zsh.timer
          ansible.builtin.copy:
            dest: "{{ zsh_user_config_dir }}/systemd/user/ansible-pull-zsh.timer"
            mode: "0644"
            content: |
              [Unit]
              Description=Run Ansible Pull periodically (user)

              [Timer]
              OnBootSec=1min
              OnUnitActiveSec=1h
              Persistent=true

              [Install]
              WantedBy=default.target

        - name: Enable & start ansible-pull-zsh.timer (user scope)
          become: false
          ansible.builtin.systemd:
            name: ansible-pull-zsh.timer
            enabled: true
            state: started
            scope: user
            daemon_reload: true

    #────────────────────────────────────────────────────────────
    # macOS: LaunchAgent
    #────────────────────────────────────────────────────────────
    - name: macOS LaunchAgent
      when: ansible_system == "Darwin"
      block:
        - name: Create LaunchAgents directory
          ansible.builtin.file:
            path: "{{ zsh_user_home }}/Library/LaunchAgents"
            state: directory
            mode: "0755"

        - name: Deploy com.example.ansible-zsh.plist
          ansible.builtin.copy:
            dest: "{{ zsh_user_home }}/Library/LaunchAgents/com.example.ansible-zsh.plist"
            mode: "0644"
            content: |
              <?xml version="1.0" encoding="UTF-8"?>
              <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
                "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
              <plist version="1.0">
              <dict>
                <key>Label</key>
                <string>com.example.ansible-zsh</string>
                <key>ProgramArguments</key>
                <array>
                  <string>/usr/bin/env</string>
                  <string>ansible-pull</string>
                  <string>-U</string>
                  <string>{{ ansible_pull_repo }}</string>
                  <string>{{ ansible_pull_playbook }}</string>
                  <string>--tags</string>
                  <string>{{ ansible_pull_tags }}</string>
                </array>
                <key>StartInterval</key>
                <integer>3600</integer>
                <key>RunAtLoad</key>
                <true/>
                <key>StandardOutPath</key>
                <string>/tmp/ansible-pull.out.log</string>
                <key>StandardErrorPath</key>
                <string>/tmp/ansible-pull.err.log</string>
              </dict>
              </plist>

        - name: Load (or reload) the LaunchAgent
          become: false
          ansible.builtin.shell: |
            launchctl unload {{ zsh_user_home | quote }}/Library/LaunchAgents/com.example.ansible-zsh.plist 2>/dev/null || true
            launchctl load   {{ zsh_user_home | quote }}/Library/LaunchAgents/com.example.ansible-zsh.plist
YAML

# # You could instead pull and run a repo:
# ansible-pull -U https://github.com/JordanBradshaw/ansible-pull-zsh.git -C main -i localhost -c local --directory /tmp/ansible-pull-zsh  --accept-host-key --full site.yml

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
