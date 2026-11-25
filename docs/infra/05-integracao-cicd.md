# 5. Integração com o CI/CD da aplicação

| Fluxo | Responsável | Workflow | Entrada | Saída |
|---|---|---|---|---|
| CI/CD da aplicação | Zibiska Korp (existente) | `App \| Build e publicação das imagens` (representa o fluxo existente) | código em `apps/`, tag `v*` ou versão | imagens `ghcr.io/<dono>/kubeshop-api:<versão>` e `-frontend:<versão>` |
| Implantação da versão | Infraestrutura | `2 - Infra \| Operação` → `deploy-app` | `environment`, `docker_tag` | contêineres recriados e verificados |
| Infraestrutura | Infraestrutura | `1 - Infra \| Provisionar e configurar` | parâmetros §3.1 | VMs, rede, banco, backup e app configurados |

**Pontos de integração**

1. **Destino de implantação**: VM `vm-kubeshop-app-<env>`, contêineres `api` e `frontend` na rede Docker `kubeshop_web`. A aplicação não acessa o banco por outro caminho.
2. **Contrato**: o CI/CD da aplicação só precisa publicar as imagens com uma tag imutável (ex.: `1.0.1`) e informar essa tag ao pipeline de infraestrutura. Não deve usar `latest` em produção.
3. **Disparo**: manual (`deploy-app`) ou automático pelo próprio workflow de build (`deploy_env`), que chama `ops.yml` como *reusable workflow* com `secrets: inherit`.
4. **Configuração da aplicação** injetada pela infraestrutura: `MONGO_HOST` (IP privado do banco), `MONGO_USERNAME`, `MONGO_PASSWORD_FILE`, `APP_VERSION`.

**Segredos necessários (referências, sem valores)**

| Segredo | Escopo | Usado por |
|---|---|---|
| `GITHUB_TOKEN` (automático) | build | push no GHCR |
| `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` | repositório | Terraform e Azure CLI |
| `SSH_PRIVATE_KEY` | repositório | Ansible |
| `MONGO_ROOT_PASSWORD`, `MONGO_APP_PASSWORD` | environment | Ansible (banco e API) |
| `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` | repositório (opcional) | pull de imagens privadas |

Se a Zibiska Korp usar outro sistema de CI (GitLab, Azure DevOps), basta publicar as imagens em um registry acessível pela VM e disparar o `deploy-app` pela API do GitHub (`POST /repos/{owner}/{repo}/actions/workflows/ops.yml/dispatches`).
