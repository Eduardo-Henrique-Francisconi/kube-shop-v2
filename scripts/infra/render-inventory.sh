#!/usr/bin/env bash
# Gera ~/.ssh/config e ansible/inventory/hosts.yml a partir dos outputs do Terraform.
# Uso: scripts/infra/render-inventory.sh <environment>   (executar na raiz do repositório)
set -euo pipefail
env_name="${1:?informe o ambiente}"
key_file="${SSH_KEY_FILE:-$HOME/.ssh/kubeshop}"

out="$(terraform -chdir=terraform output -json)"
get() { jq -r ".$1.value" <<<"$out"; }

app_ip="$(get app_public_ip)"
app_private_ip="$(get app_private_ip)"
db_ip="$(get db_private_ip)"
user="$(get admin_username)"
backup_url="$(get backup_container_url)"
[ "$app_ip" != "null" ] || { echo "::error::Outputs do Terraform vazios: o ambiente $env_name existe?"; exit 1; }

mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
cat > "$HOME/.ssh/config" <<CFG
Host kubeshop-app
  HostName ${app_ip}
  User ${user}
  IdentityFile ${key_file}
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  UserKnownHostsFile ~/.ssh/known_hosts_kubeshop

# Banco sem IP público: acesso administrativo pela VM da aplicação (bastion)
Host kubeshop-db
  HostName ${db_ip}
  User ${user}
  IdentityFile ${key_file}
  IdentitiesOnly yes
  ProxyJump kubeshop-app
  StrictHostKeyChecking accept-new
  UserKnownHostsFile ~/.ssh/known_hosts_kubeshop
CFG
chmod 600 "$HOME/.ssh/config"

cat > ansible/inventory/hosts.yml <<INV
# Gerado por scripts/infra/render-inventory.sh - não editar
all:
  vars:
    ansible_user: ${user}
    env_name: ${env_name}
    app_public_ip: ${app_ip}
    app_private_ip: ${app_private_ip}
    db_private_ip: ${db_ip}
    backup_container_url: ${backup_url}
  children:
    app:
      hosts:
        app1:
          ansible_host: kubeshop-app
    db:
      hosts:
        db1:
          ansible_host: kubeshop-db
INV
echo "Inventário gerado: app=${app_ip} db=${db_ip} (privado, via ProxyJump)"
