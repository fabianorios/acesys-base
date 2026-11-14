# Acesys Base — arquitetura v2 (Contabo + túnel Firebird)

Modelo operacional preferido a partir de 2026-11: inteligência, Agent SDK / playground e chave Cursor ficam na Contabo. O cliente **não** instala Cursor key, MCP nem playground em disco.

**Decisão (2026-11-13, America/Sao_Paulo):** Fabiano tem **um** servidor — instalar `acesys-base` **na mesma VPS** onde já estão Gestão, Monitoramento, ERP, MCP, 6x1 e eSocial. Mesmo host/SSH (porta 22); **não** copiar chave root. User Linux `acesys-tunnel` só para túnel de campo; diretório próprio (ex. `/opt/acesys-base`).

**Túnel na VPS (feito):** `acesys-tunnel` só chave nova; só forward `127.0.0.1:13050`; shell/senha/outras portas bloqueados (teste: 22 negado). Privada na VPS em `/root/infra/acesys-tunnel/id_ed25519` (600); fingerprint `SHA256:79gOXM6whOD0JxLLeFMp8cfjM1GsTANpdJbAIySg45w`. Sem privada no git/chat.

Relacionado: checklist Firebird curto em [`acesys-v2-firebird-checklist.md`](./acesys-v2-firebird-checklist.md).  
Histórico v1 (instalador local): [`acesys-service-install.md`](./acesys-service-install.md) e [PR #1](https://github.com/fabianorios/acesys-base/pull/1).

---

## 1. Visão geral

```
┌─────────────────────────────┐         outbound SSH -R          ┌──────────────────────────────────────┐
│  Cliente (Windows / Acesys) │ ─────────────────────────────────► │  Contabo única (Gestão + Acesys)      │
│                             │                                    │  Gestão / Monit / ERP / MCP / …       │
│  Firebird :3050             │   remote forward:                  │  + /opt/acesys-base (novo)            │
│  .fdb no disco local        │   VPS:13050 → client:3050          │  localhost:13050 ← túnel              │
│                             │                                    │  playground + Cursor key (só Acesys)  │
│  Sem Cursor key             │                                    │  user acesys-tunnel (só forward)      │
│  Sem MCP / playground       │                                    │  Nginx bearer ou loopback/VPN         │
└─────────────────────────────┘                                    └──────────────────────────────────────┘
```

| Onde | O que fica |
|------|------------|
| **Cliente** | Só Firebird + túnel reverso de saída (SSH). Sem chave Cursor, sem MCP, sem playground. |
| **Mesma Contabo** | Serviços já existentes **+** `acesys-base` em pasta própria; segredos FB/Cursor só no `.env` do Acesys. |
| **SSH** | Mesmo `sshd`. User de gestão ≠ user de túnel de campo. Nunca reutilizar chave root no PC do cliente. |

**Opção A (preferida, visitas curtas):** SSH reverse tunnel (`ssh -R`).  
**Opção B (opcional, engajamentos longos):** Tailscale (ou VPN equivalente) — documentar quando o cliente já usa mesh estável; não é o caminho padrão de campo.

---

## 2. O que significam “liberação do Firebird” e “login no banco” (PT-BR)

Pergunta frequente no suporte. São **duas coisas diferentes**.

### Liberação do Firebird

Significa: o **serviço Firebird** no PC do cliente está **escutando TCP na porta 3050** (ou a porta configurada) de forma que um cliente de rede — aqui, o túnel — consegue abrir conexão TCP até o processo do banco.

Inclui, na prática:

1. Serviço Firebird (ou Classic/SuperServer) **em execução**.
2. Porta **3050** aceitando conexão (teste local: `Test-NetConnection 127.0.0.1 -Port 3050` ou `isql` local).
3. Com **SSH `-R`**, o firewall do cliente em geral só precisa permitir **SSH de saída** (22 ou a porta da VPS). Não é necessário abrir 3050 para a internet.
4. Se o caminho do `.fdb` for alias ou path absoluto com espaços, esse alias/path precisa ser válido para **clientes de rede** (não só para apps locais que abrem o arquivo pelo Explorer).

**Não** é: “liberar usuário Windows”, “abrir porta 3050 na internet”, nem “dar senha SYSDBA para o Fabiano no chat”.

### Login no banco

Significa: o **usuário e a senha Firebird** (protocolo do SGBD) usados na connection string do MCP/agente **na VPS**.

- Host visto pelo agente: `127.0.0.1`
- Porta: `13050` (lado VPS do túnel)
- Database: path/alias do `.fdb` **como o Firebird do cliente resolve** (ex.: `C:\Clientes AHR\Acesys\BD\Modelo.FDB` ou alias)
- User/password: preferir usuário **somente SELECT** (não SYSDBA)

Isso é **independente** de:

- login do Windows no PC do cliente;
- senha do playground / gate HTTP na VPS;
- chave da API Cursor.

Passo a passo: [`acesys-v2-firebird-checklist.md`](./acesys-v2-firebird-checklist.md).

---

## 3. Fluxo operacional SSH (Opção A)

### Pré-requisitos (uma vez na VPS)

1. Conta SSH dedicada para túnel (ex.: `acesys-tunnel`) — **sem shell útil**, só forward (ver §5).
2. Chave pública do operador/cliente autorizada nessa conta (`authorized_keys`).
3. `GatewayPorts` / bind: preferir listen **só em 127.0.0.1** na VPS para a porta remota (não expor 13050 na internet).
4. `acesys-base` instalado na VPS com Node; `.env` apontando para `127.0.0.1:13050` e user RO.

### Visita de campo (curta)

1. No cliente: confirmar **liberação** (Firebird up, 3050 local OK) e user RO criado (checklist).
2. No cliente: abrir túnel (template sem segredos em `ops/tunnel/open-tunnel.bat` no repo):

   ```bat
   ssh -N -R 127.0.0.1:13050:127.0.0.1:3050 acesys-tunnel@VPS_HOST
   ```

   Substituir `VPS_HOST` e usuário conforme o ambiente; chave em `IdentityFile` se necessário. **Não** colocar senhas nem IPs reais no template versionado.

3. Na VPS: testar TCP `127.0.0.1:13050`, depois `isql` / `node-firebird` com user RO.
4. Subir / usar playground do `acesys-base` na VPS; tools `fb_*` usam o `.env` da VPS.
5. Ao terminar: fechar o SSH no cliente; revogar se a visita encerrou de vez (§7).

### Engajamento longo (Opção B — opcional)

Tailscale (ou similar): máquina do cliente e VPS na mesma tailnet; Firebird acessível por IP Tailscale do cliente na porta 3050. Manter as mesmas regras: sem Cursor key no cliente; segredos FB só na VPS; preferir user RO. Documentar o peer e a ACL da tailnet fora deste repo (não inventar senhas Contabo).

---

## 4. Checklist Firebird (resumo)

Detalhe executável: [`acesys-v2-firebird-checklist.md`](./acesys-v2-firebird-checklist.md).

| # | Item |
|---|------|
| 1 | Serviço Firebird rodando; 3050 responde em localhost no cliente |
| 2 | Path/alias do `.fdb` conhecido e usável por cliente TCP |
| 3 | Criar usuário **somente leitura** (não SYSDBA) e grant SELECT nas tabelas necessárias |
| 4 | Túnel `-R 127.0.0.1:13050:127.0.0.1:3050` ativo |
| 5 | Na VPS: `isql` ou script Node contra `127.0.0.1/13050` com o user RO |
| 6 | `.env` da VPS: `ACESYS_FB_HOST=127.0.0.1`, `ACESYS_FB_PORT=13050`, user/senha RO — **só na VPS** |

---

## 5. Contabo `sshd` — usuário restrito a túnel (esboço)

Objetivo: a conta usada pelo cliente/operador **não** recebe shell interativo nem acesso a arquivos; só reverse forward para a porta Firebird espelhada.

Exemplo ilustrativo (`/etc/ssh/sshd_config.d/acesys-tunnel.conf`) — **placeholders**, sem IPs/senhas reais:

```text
# Match User acesys-tunnel
#   AllowTcpForwarding remote
#   PermitOpen 127.0.0.1:13050
#   X11Forwarding no
#   AllowAgentForwarding no
#   PermitTunnel no
#   ForceCommand /bin/false
#   # PasswordAuthentication no  (só chave)
#   # PermitListen 127.0.0.1:13050  (OpenSSH recente; preferir bind loopback)
```

Notas:

- Validar sintaxe com `sshd -t` antes de reload; aplicar só com credenciais e janela do Fabiano.
- Garantir que a porta remota **não** fique em `0.0.0.0` (evitar `GatewayPorts clientspecified` amplo sem necessidade).
- Snippet versionado comentado: `ops/tunnel/sshd-acesys-tunnel.conf.snippet` no repo.

**Não inventar** senhas root Contabo, usuários existentes ou IPs públicos neste documento.

---

## 6. Como o `acesys-base` roda na VPS

1. Clone do GitHub (`fabianorios/acesys-base`) em diretório na VPS (ex.: `/opt/acesys-base` — caminho a critério do operador).
2. Node (não Bun) + `npm install`; CLI via `agent-sdk` / `npx` conforme `AGENTS.md` do repo.
3. `.env` na VPS (nunca no cliente v2):

   ```env
   ACESYS_FB_HOST=127.0.0.1
   ACESYS_FB_PORT=13050
   ACESYS_FB_DATABASE=...   # path/alias como o Firebird do cliente espera
   ACESYS_FB_USER=acesys_ro
   ACESYS_FB_PASSWORD=...   # só na VPS
   CURSOR_API_KEY=...       # só na VPS
   ```

4. Playground / serve em loopback; expor só via **Nginx com bearer** e/ou **VPN / Tailscale**, não playground aberto na internet sem autenticação.
5. Tools `fb_*` conectam via `node-firebird` ao host/porta do `.env` — com o túnel ativo, isso alcança o Firebird do cliente.

Proteção HTTP (documentar no servidor, sem inventar configs Contabo):

- Nginx na frente com `Authorization: Bearer …` ou basic auth forte; ou
- Bind só `127.0.0.1` + acesso por SSH tunnel / Tailscale até o playground.

---

## 7. Revogação (fim da visita / incidente)

| Ação | Onde |
|------|------|
| Fechar sessão SSH do túnel | Cliente (Ctrl+C / matar `ssh`) |
| Remover chave do cliente de `authorized_keys` | VPS, user `acesys-tunnel` |
| Desabilitar / apagar user `acesys-tunnel` se não houver mais visitas | VPS |
| Rotacionar senha do user Firebird RO | Cliente (isql) + atualizar `.env` na VPS |
| Invalidar / rotacionar `CURSOR_API_KEY` se vazou no cliente (não deveria no v2) | Conta Cursor |
| Derrubar playground / parar `agent-sdk` se necessário | VPS |
| Remover peer Tailscale (se Opção B) | Admin Tailscale |

Após revogar, confirmar que `127.0.0.1:13050` na VPS **não** aceita mais conexão.

---

## 8. Relação com v1 — Setup / PR #1

| | **v1** (PR #1) | **v2** (este plano) |
|--|----------------|---------------------|
| Onde roda o agente | PC do cliente (`C:\acesys-base`, NSSM, Setup.exe) | Contabo VPS (ou máquina do Fabiano → MCP na VPS) |
| Cursor API key | Vault DPAPI no cliente | Só na VPS |
| Playground | `127.0.0.1:3000` no cliente | Na VPS, protegido |
| Firebird | LAN local / `.env` no cliente | Túnel reverso → `127.0.0.1:13050` na VPS |
| Instalador | Inno `AcesysBaseSetup.exe` | Cliente só precisa de SSH + Firebird |

**Decisão:** para uso de campo preferido, o instalador local v1 fica **estacionado / supersedido** como modelo operacional.  
[PR #1](https://github.com/fabianorios/acesys-base/pull/1) continua sendo o empacotamento v1 — **não mesclar/fechar sem pedido explícito**; manter o código como **fallback opcional** (cliente offline longo, laboratório, ou quando o túnel for inviável).

Doc de instalação v1 permanece em [`acesys-service-install.md`](./acesys-service-install.md) com nota de supersessão no topo (histórico preservado).

---

## 9. Próximos passos humanos

1. **Contabo:** criar user `acesys-tunnel`, aplicar snippet `sshd` (testar), instalar/atualizar `acesys-base`, configurar `.env` + proteção Nginx/loopback.
2. **Um cliente de teste:** liberação 3050 + user RO + `open-tunnel.bat` → na VPS, `isql`/query smoke → playground `fb_list_tables`.
3. Manter PR #1 aberto como pacote v1 até decisão explícita de merge/close.

---

## 10. Fora de escopo deste documento

- SSH na Contabo ou mudança em produção sem credenciais fornecidas pelo usuário.
- Senhas, IPs públicos ou chaves reais no Git / nestes docs.
- Migrar arquitetura *hosted* Agent SDK (`architecture: "v1"` → plataforma Cursor) — assunto separado do pivot operacional Contabo.
