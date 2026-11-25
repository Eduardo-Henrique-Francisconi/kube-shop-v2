# 4. Estimativa de custos mensais

## 4.1 Premissas

| Item | Valor |
|---|---|
| Provedor / região | Microsoft Azure, `eastus2` (Leste dos EUA 2) |
| Moeda | Dólar americano (USD), moeda de cobrança do Azure for Students |
| Data de referência | 25/11/2026 — Azure Retail Prices API (preços públicos *pay-as-you-go*, Linux) |
| Período | 1 mês = 730 horas, ambiente ligado 24×7 |
| Ambiente | 1 ambiente (`dev`), parâmetros padrão |
| Tráfego | < 100 GB/mês de saída (loja em lançamento, páginas leves) |

## 4.2 Composição

| Recurso | Qtde | Função / dimensionamento | Preço unitário | Mensal (USD) |
|---|---|---|---|---|
| VM Standard_B1ms (1 vCPU, 2 GiB) | 1 | Aplicação: Nginx + API (< 500 MiB em uso) | US$ 0,0208/h | 15,18 |
| VM Standard_B2s (2 vCPU, 4 GiB) | 1 | MongoDB: cache WiredTiger + cache do SO | US$ 0,0416/h | 30,37 |
| Disco SO Standard SSD E4 (32 GiB) | 2 | Sistema e imagens Docker | US$ 2,40/mês | 4,80 |
| Disco de dados Standard SSD E3 (16 GiB) | 1 | Pedidos (MongoDB) — dezenas de milhares de pedidos | US$ 1,20/mês | 1,20 |
| Transações dos discos Standard SSD | — | Estimativa para baixo volume | US$ 0,002/10 mil | ~0,20 |
| IP público Standard estático | 1 | Endereço da loja + DNS cloudapp gratuito | US$ 0,005/h | 3,65 |
| Blob Storage Hot LRS (state + backups) | < 1 GB | 30 backups diários pequenos + state | US$ 0,0184/GB | ~0,05 |
| Operações de Blob (uploads, listagens) | < 10 mil | Backups diários e execuções de pipeline | US$ 0,05/10 mil | ~0,05 |
| Saída de dados para a internet | < 100 GB | Primeiros 100 GB/mês gratuitos | US$ 0 | 0,00 |
| VNet, NSGs, sub-redes, DNS `cloudapp` | — | Sem cobrança | — | 0,00 |
| GitHub Actions / GHCR | — | Repositório público: minutos e pacotes públicos gratuitos | — | 0,00 |
| **Total estimado** | | | | **≈ US$ 55,50/mês** |

## 4.3 Variações e fatores que alteram o consumo

| Cenário | Diferença | Total aproximado |
|---|---|---|
| Ambiente desligado (VMs desalocadas) fora do horário (12 h/dia) | VMs pela metade | ≈ US$ 33/mês |
| Cenário 2 (app em B2s) | + US$ 15,19 | ≈ US$ 70,70/mês |
| NAT Gateway para a sub-rede do banco (`ENABLE_NAT_GATEWAY=true`) | + ~US$ 32,85 (US$ 0,045/h) + US$ 0,045/GB processado + IP público US$ 3,65 | ≈ US$ 92/mês |
| Tráfego acima de 100 GB/mês | US$ 0,087/GB | variável |
| Três ambientes (dev, homolog, prod) | ×3 (state/backup compartilhados) | ≈ US$ 166/mês |
| Reserva de 1 ano das VMs | redução típica de 30–40% nas VMs | — |

**Créditos e gratuidades (separados do custo recorrente):** o Azure for Students oferece crédito que cobre o ambiente por cerca de 1–2 meses; após o término, o valor recorrente da tabela 4.2 passa a ser cobrado. Os 100 GB gratuitos de saída e a gratuidade do GitHub para repositórios públicos são permanentes, mas mudam se o repositório for privado (2.000 min/mês gratuitos e cobrança de armazenamento de pacotes).

## 4.4 Justificativa

O valor é dominado pelas duas VMs (≈ 82%), exigidas pelo escopo (banco em servidor exclusivo). Foram escolhidos os menores tamanhos com memória suficiente para cada função; discos Standard SSD dão latência estável a baixo custo; não há balanceador, Bastion gerenciado (~US$ 140/mês) nem NAT Gateway por padrão, porque o acesso administrativo usa a VM da aplicação como bastion e o SSH é aberto apenas durante as execuções. Os backups lógicos são pequenos e expiram em 30 dias, o que mantém o armazenamento em centavos.

**Limitações da estimativa:** preços de tabela sem impostos; não inclui suporte pago, Log Analytics, TLS/domínio próprio nem picos de tráfego; preços do Azure podem mudar.

**Fontes:** Azure Retail Prices API (`prices.azure.com`, consultada em 25/11/2026: B1ms, B2s, Standard SSD E3/E4, IP público Standard, Blob Hot LRS) e página de preços de largura de banda do Azure.
