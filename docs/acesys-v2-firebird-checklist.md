# Checklist Firebird — liberação + login RO (v2)

Uso com a arquitetura Contabo + túnel: [`acesys-v2-tunnel-architecture.md`](./acesys-v2-tunnel-architecture.md).

## Vocabulário (PT-BR)

| Termo | Significa | Não confundir com |
|-------|-----------|-------------------|
| **Liberação** | Firebird escutando TCP (ex. 3050) para o túnel conectar | Login Windows; abrir 3050 na internet |
| **Login no banco** | Usuário/senha **Firebird** na connection string da VPS (`127.0.0.1:13050`) | Senha do playground; chave Cursor |

---

## A. Liberação (no PC do cliente)

1. Confirmar serviço Firebird em execução (Services / `net start` conforme a instalação Acesys).
2. Testar porta local:
   ```powershell
   Test-NetConnection 127.0.0.1 -Port 3050
   ```
   Esperado: `TcpTestSucceeded : True`.
3. Anotar path ou alias do `.fdb` (ex. pasta Acesys `...\BD\....FDB`). Se usar alias, confirmar que o alias existe no `aliases.conf` (ou equivalente) para clientes de rede.
4. Firewall: com SSH `-R`, basta **saída SSH** para a VPS. Não é obrigatório liberar 3050 inbound na internet.
5. Só então abrir o túnel (template `ops/tunnel/open-tunnel.bat` no repo).

---

## B. Login RO (criar usuário só leitura)

Preferir **não** usar SYSDBA no agente.

1. Conectar como SYSDBA (ou admin) **localmente** no cliente (isql / IBExpert / ferramenta habitual).
2. Criar usuário de leitura (nomes ilustrativos — trocar na visita):

   ```sql
   -- Sintaxe varia por versão Firebird; ajustar ao ambiente do cliente.
   CREATE USER acesys_ro PASSWORD 'trocar-na-visita';
   -- Grants: SELECT nas tabelas/views necessárias (evitar GRANT ALL).
   ```

3. Testar login RO **ainda no cliente** (isql local) com um `SELECT` simples.
4. Na VPS, após o túnel subir, colocar no `.env` (só VPS):

   ```env
   ACESYS_FB_HOST=127.0.0.1
   ACESYS_FB_PORT=13050
   ACESYS_FB_DATABASE=<mesmo path/alias do cliente>
   ACESYS_FB_USER=acesys_ro
   ACESYS_FB_PASSWORD=<senha da visita>
   ```

5. Na VPS, smoke test:
   - TCP: `nc -zv 127.0.0.1 13050` (ou equivalente)
   - `isql` / script Node `node-firebird` com o user RO
   - playground: tool `fb_connect` / `fb_list_tables`

6. Fim da visita: fechar túnel; se apropriado, `ALTER USER` / drop do RO e atualizar ou limpar senha no `.env` da VPS (ver revogação no doc de arquitetura).

---

## C. Ordem mínima de um teste ponta a ponta

1. Liberação OK (A)  
2. User RO OK local (B.1–3)  
3. Túnel SSH ativo  
4. Login RO via VPS `:13050` (B.4–5)  
5. Fechar túnel / revogar se acabou a visita  
