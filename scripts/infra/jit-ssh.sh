#!/usr/bin/env bash
# Acesso SSH temporário (just-in-time) do runner da pipeline à VM da aplicação.
# open : cria a regra NSG gha-ssh-<run> liberando a porta 22 apenas para o IP do runner
# close: remove a regra (executado sempre ao final, mesmo com falha)
# Uso: scripts/infra/jit-ssh.sh open|close <resource_group> <nsg_name> <app_private_ip>
set -euo pipefail
action="${1:?open|close}"; rg="${2:?}"; nsg="${3:?}"; dest="${4:-*}"
rule="gha-ssh-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}"

case "$action" in
  open)
    # Remove regras esquecidas de execuções anteriores
    for old in $(az network nsg rule list -g "$rg" --nsg-name "$nsg" --query "[?starts_with(name,'gha-ssh-')].name" -o tsv); do
      echo "Removendo regra antiga $old"; az network nsg rule delete -g "$rg" --nsg-name "$nsg" -n "$old" --output none
    done
    ip="$(curl -fsS --retry 3 https://api.ipify.org)"
    az network nsg rule create -g "$rg" --nsg-name "$nsg" -n "$rule" \
      --priority 300 --direction Inbound --access Allow --protocol Tcp \
      --source-address-prefixes "${ip}/32" --destination-address-prefixes "$dest" \
      --destination-port-ranges 22 --description "SSH temporario da pipeline (run ${GITHUB_RUN_ID:-local})" \
      --output none
    echo "SSH liberado temporariamente para o runner (${ip}/32) pela regra ${rule}"
    ;;
  close)
    if az network nsg rule show -g "$rg" --nsg-name "$nsg" -n "$rule" --output none 2>/dev/null; then
      az network nsg rule delete -g "$rg" --nsg-name "$nsg" -n "$rule" --output none
      echo "Regra ${rule} removida: SSH fechado"
    else
      echo "Regra ${rule} não existe (nada a remover)"
    fi
    ;;
  *) echo "ação inválida: $action" >&2; exit 1 ;;
esac
