# 6. Roteiro de testes e relatório de validação

Preencha a coluna **Execução** com o link/número do *run* do GitHub Actions e salve os prints em `evidencias/` (nomes sugeridos entre parênteses).

## 6.1 Cenário 1 — Criação inicial

`1 - Infra | Provisionar e configurar`: `environment=dev`, `action=apply`, `instance_type=Standard_B1ms`, `db_instance_type=Standard_B2s`, `docker_tag=1.0.0`, `update_os=true`, `extra_packages=git, unzip`.

| Esperado | Execução / evidência |
|---|---|
| `Plan: N to add, 0 to change, 0 to destroy` (18 recursos com os valores padrão) | (`c1-plan.png`) |
| Ansible: Docker instalado, disco formatado e montado, MongoDB *healthy*, timer de backup, `api`/`frontend` *healthy*; PLAY RECAP `failed=0` | (`c1-recap.png`) |
| Loja abre na URL do resumo; catálogo; pedido criado e visível após recarregar (ACE-04) | (`c1-loja.png`, `c1-pedido.png`) |
| Smoke: "Porta 27017 no IP público: bloqueada" e inventário com 2 VMs, banco sem IP público (ACE-02, ACE-03) | (`c1-validacao.png`) |

## 6.2 Cenário 2 — Atualização

Antes: publique `1.0.1` com `App | Build e publicação das imagens`.
Execute `1 - Infra` com `instance_type=Standard_B2s` (infra), `docker_tag=1.0.1`, `extra_packages=git, unzip, htop` (manutenção), `update_os=false`.

| Esperado | Execução / evidência |
|---|---|
| `Plan: 0 to add, 1 to change, 0 to destroy` — `azurerm_linux_virtual_machine.app` *updated in-place* (`size`) | (`c2-plan.png`) |
| Ansible: `htop` instalado (*changed*), `api`/`frontend` recriados com `1.0.1` (*changed*), verificação mostra versão `1.0.1` | (`c2-recap.png`) |
| Pedido criado no cenário 1 continua na loja (ACE-05: persistência após alteração de infraestrutura) | (`c2-pedido.png`) |

*Alternativa de alteração no banco*: `db_instance_type=Standard_B2ms` ou `db_data_disk_gb=32` (resize do disco + `resizefs`) — os pedidos permanecem.

## 6.3 Cenário 3 — Reexecução sem alterações

Execute `1 - Infra` **com os mesmos parâmetros do cenário 2**.

| Esperado | Execução / evidência |
|---|---|
| Terraform: `No changes. Your infrastructure matches the configuration.` (apply é pulado) | (`c3-plan.png`) |
| Ansible: PLAY RECAP `changed=0` em `app1` e `db1` | (`c3-recap.png`) |

## 6.4 Critérios de aceite do escopo

| Critério | Como demonstrar | Execução / evidência |
|---|---|---|
| ACE-01 Reprodução | Cenário 1 a partir do zero, com pré-requisitos (cap. 2) | |
| ACE-02 Duas VMs | Inventário no resumo + portal (RG `rg-kubeshop-dev`) | |
| ACE-03 Isolamento | `verify`: 27017 só em `10.20.2.10`; smoke: 27017 público bloqueado; VM do banco sem IP público; API *ready* (conectada pela rede privada) | |
| ACE-04 Aplicação | Loja, catálogo, pedido, recarregar o navegador | |
| ACE-05 Persistência | Pedido mantido após `restart` (`service=all`) e após o cenário 2 | |
| ACE-06 CI/CD | `App | Build` publicando `1.0.1` + `deploy-app` | |
| ACE-07 Recuperação | `backup` → criar pedido novo → `restore` com o backup → contagem volta ao valor do backup (resumo mostra antes/depois) | |
| ACE-08 Administração | Execuções dos pipelines; regra `gha-ssh-*` criada/removida; logs sem senhas (`***`) | |
| ACE-09 Custos | Cap. 4 | |
| ACE-10 Transferência | Caps. 2, 3 e 5 | |

## 6.5 Teste de recuperação (ACE-07) passo a passo

1. `2 - Infra` → `backup` → anote `name=kubeshop-dev-AAAAmmddTHHMMSSZ.archive.gz` e `orders=X`.
2. Crie 1 ou 2 pedidos novos na loja (ou `routine=smoke`, que cria um pedido fictício).
3. `2 - Infra` → `restore`, `backup_name=<nome anotado>`, `confirm=RESTAURAR`.
4. Confira no resumo: `antes: orders=X+n` → `depois: orders=X`; recarregue a loja: os pedidos novos não aparecem.
