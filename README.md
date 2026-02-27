# 🤖 AI Agent de Agendamento — Google Calendar + Supabase + n8n

> Assistente de agendamento inteligente baseado em linguagem natural. O usuário escreve frases como *"marque uma reunião amanhã às 14h com João"* e o sistema cria, edita, lê ou deleta eventos automaticamente no Google Calendar — com persistência no Supabase.

👽 Agente de IA para agendamento com n8n 2.8.x — gerencia o Google Calendar por linguagem natural (criar, ler, atualizar, deletar e listar eventos). Alimentado por GPT-4o com memória de sessão e persistência dos event IDs no Supabase. Inclui dois workflows prontos para importar + script SQL de configuração.

---

## 📋 Índice

- [Visão Geral](#-visão-geral)
- [Arquitetura](#-arquitetura)
- [Pré-requisitos](#-pré-requisitos)
- [Estrutura dos Arquivos](#-estrutura-dos-arquivos)
- [Tutorial de Implantação](#-tutorial-de-implantação)
  - [Passo 1 — Supabase: criar o banco](#passo-1--supabase-criar-o-banco)
  - [Passo 2 — Credenciais no n8n](#passo-2--credenciais-no-n8n)
  - [Passo 3 — Importar o Workflow Tool](#passo-3--importar-o-workflow-tool)
  - [Passo 4 — Importar o Workflow do Agente](#passo-4--importar-o-workflow-do-agente)
  - [Passo 5 — Conectar Tool ao Agente](#passo-5--conectar-tool-ao-agente)
  - [Passo 6 — Ativar e Testar](#passo-6--ativar-e-testar)
- [API Reference — Campos de Input](#-api-reference--campos-de-input)
- [Exemplos de Uso](#-exemplos-de-uso)
- [Integrações Possíveis](#-integrações-possíveis)
- [Troubleshooting](#-troubleshooting)
- [Segurança para Produção](#-segurança-para-produção)
- [Estrutura dos Nós](#-estrutura-dos-nós)

---

## 🧠 Visão Geral

Este projeto implementa um **agente de IA conversacional** capaz de gerenciar o Google Calendar de forma autônoma através de linguagem natural. É composto por dois workflows n8n que trabalham em conjunto:

| Workflow | Função |
|---|---|
| `🛠️ TOOL — Google Calendar CRUD + Supabase` | Executa as operações no Google Calendar e persiste dados no Supabase |
| `🤖 AGENTE — AI Assistente de Agendamento` | Recebe mensagens do usuário, interpreta a intenção e aciona a tool correta |

### O que o agente consegue fazer

- ✅ **Criar** eventos com título, descrição, horário e timezone
- 🔍 **Ler** detalhes de um evento pelo ID
- ✏️ **Atualizar** eventos existentes
- 🗑️ **Deletar** eventos com remoção simultânea do banco
- 📋 **Listar** os próximos 10 eventos futuros
- 💾 **Persistir** todos os `event_id` no Supabase para consulta posterior pelo seu app

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    WORKFLOW DO AGENTE                       │
│                                                             │
│  Webhook POST ──► Preparar Input ──► AI Agent              │
│                                         │                   │
│                         ┌──────────────┘                   │
│                         │  GPT-4o (LLM)                    │
│                         │  Buffer Memory (session_id)      │
│                         │  Workflow Tool ──────────────►   │
│                         │                                  │
│                    Webhook Response ◄── Formatar Resposta   │
└─────────────────────────────────────────────────────────────┘
                              │
                    (chama via Workflow Tool)
                              │
┌─────────────────────────────────────────────────────────────┐
│                    WORKFLOW TOOL                            │
│                                                             │
│  Execute Workflow Trigger                                   │
│         │                                                   │
│  Normalizar Input                                           │
│         │                                                   │
│  Switch (action) ──► CREATE ──► GCal Create ──► Supabase  │
│                  ──► READ   ──► GCal Get                   │
│                  ──► UPDATE ──► GCal Update                │
│                  ──► DELETE ──► GCal Delete ──► Supabase  │
│                  ──► LIST   ──► GCal GetAll ──► Agregar    │
│                                                             │
│                  (retorna campo `response` ao agente)       │
└─────────────────────────────────────────────────────────────┘
```

### Fluxo de uma mensagem do usuário

1. O usuário envia `POST /webhook/agendamento-ai` com o campo `message`
2. O **Agente AI** interpreta a intenção em linguagem natural
3. O agente seleciona a `action` correta e monta o payload
4. A **Workflow Tool** é invocada com os parâmetros extraídos
5. A tool executa no **Google Calendar API**
6. Se for `create` ou `delete`, o **Supabase** é atualizado simultaneamente
7. A tool retorna um campo `response` (texto) ao agente
8. O agente formula uma resposta amigável e devolve ao usuário via webhook

---

## 🧰 Pré-requisitos

Antes de começar, certifique-se de ter:

| Requisito | Versão / Detalhe |
|---|---|
| n8n | **2.8.3** ou superior |
| Conta Google | Com acesso ao Google Calendar |
| Projeto Supabase | Conta gratuita em [supabase.com](https://supabase.com) |
| API Key OpenAI | Conta em [platform.openai.com](https://platform.openai.com) |
| n8n acessível via HTTPS | Obrigatório para OAuth Google funcionar |

> **Dica:** Se estiver rodando n8n localmente, use [ngrok](https://ngrok.com/) ou [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/) para expor via HTTPS durante o desenvolvimento.

---

## 📁 Estrutura dos Arquivos

```
📦 projeto-agendamento-n8n/
├── 📄 workflow_tool_google_calendar.json   ← Workflow Tool (CRUD)
├── 📄 workflow_agent_agendamento.json      ← Workflow do Agente AI
├── 📄 supabase_setup.sql                   ← Script SQL do banco
└── 📄 README.md                            ← Este arquivo
```

---

## 🚀 Tutorial de Implantação

### Passo 1 — Supabase: criar o banco

1. Acesse [app.supabase.com](https://app.supabase.com) e faça login
2. Crie um novo projeto (anote a **URL** e a **Service Role Key** — você vai precisar em breve)
3. No menu lateral, acesse **SQL Editor**
4. Cole o conteúdo completo do arquivo `supabase_setup.sql` e execute

O script cria:

```sql
-- Tabela principal
CREATE TABLE calendar_events (
  id          uuid      DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id    text      UNIQUE NOT NULL,   -- ID do Google Calendar
  calendar_id text      DEFAULT 'primary',
  summary     text,
  description text,
  start_time  timestamptz,
  end_time    timestamptz,
  attendees   text,
  status      text      DEFAULT 'confirmed',
  html_link   text,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  deleted_at  timestamptz DEFAULT NULL     -- soft delete
);
```

5. Verifique em **Table Editor** se a tabela `calendar_events` aparece

> ⚠️ **Atenção ao RLS:** Por padrão o script deixa o Row Level Security **desabilitado**. Para produção, habilite o RLS e configure policies adequadas para o service role do n8n.

---

### Passo 2 — Credenciais no n8n

Você precisa cadastrar **3 credenciais** antes de importar os workflows.

#### 2a. Google Calendar OAuth2

1. No n8n, acesse **Settings → Credentials → Add Credential**
2. Busque por `Google Calendar OAuth2 API`
3. Siga o fluxo OAuth (o n8n vai abrir uma janela do Google para autorizar)
4. Anote o **nome exato** que você deu à credencial (ex: `Minha Conta Google`)

> Para configurar o OAuth, você precisa de um projeto no [Google Cloud Console](https://console.cloud.google.com/) com a **Google Calendar API** habilitada e as credenciais OAuth configuradas com o redirect URI do seu n8n.

#### 2b. OpenAI API

1. Acesse **Settings → Credentials → Add Credential**
2. Busque por `OpenAI API`
3. Insira sua **API Key** de [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
4. Anote o nome da credencial

#### 2c. Supabase API

1. Acesse **Settings → Credentials → Add Credential**
2. Busque por `Supabase`
3. Preencha:
   - **Host:** `https://XXXXXXXXXXXX.supabase.co` (sua URL do projeto)
   - **Service Role Secret:** chave `service_role` (em Settings → API no painel Supabase)
4. Anote o nome da credencial

---

### Passo 3 — Importar o Workflow Tool

1. No n8n, acesse **Workflows → Add Workflow → Import from file**
2. Selecione o arquivo `workflow_tool_google_calendar.json`
3. O workflow será importado — **ainda não ative**

#### Vincular as credenciais nos nós

Após a importação, os nós do Google Calendar e Supabase estarão com credenciais placeholder. Você precisa atualizar cada um:

**Nós do Google Calendar** (há 5 nós — Criar, Ler, Atualizar, Deletar, Listar):
- Clique em cada nó `GCal ...`
- No campo **Credential**, selecione sua credencial Google Calendar cadastrada no Passo 2a

**Nós do Supabase** (há 2 nós — Salvar e Remover):
- Clique em cada nó `Supabase ...`
- No campo **Credential**, selecione sua credencial Supabase cadastrada no Passo 2c

4. Salve o workflow
5. **Ative o workflow** (toggle no canto superior direito)
6. Anote o **ID do workflow** — você verá na URL do browser: `.../workflow/123` → o ID é `123`

---

### Passo 4 — Importar o Workflow do Agente

1. No n8n, acesse **Workflows → Add Workflow → Import from file**
2. Selecione o arquivo `workflow_agent_agendamento.json`

#### Vincular as credenciais

**Nó OpenAI GPT-4o:**
- Clique no nó `🧠 OpenAI GPT-4o`
- Selecione sua credencial OpenAI do Passo 2b

---

### Passo 5 — Conectar Tool ao Agente

Este é o passo mais importante. O Agente precisa saber qual workflow chamar como ferramenta.

1. Clique no nó `🛠️ Workflow Tool — Calendar Manager`
2. No campo **Workflow**, clique em **Select Workflow**
3. Selecione o workflow `🛠️ TOOL — Google Calendar CRUD + Supabase` importado no Passo 3

> Alternativamente, se quiser usar o ID diretamente, substitua o valor `"COLOQUE_O_ID_DO_WORKFLOW_TOOL_AQUI"` pelo ID numérico anotado no Passo 3 (ex: `"123"`).

4. Salve o workflow do Agente
5. **Ative o workflow** do Agente

---

### Passo 6 — Ativar e Testar

Com ambos os workflows ativos, obtenha a URL do webhook:

1. Clique no nó `🌐 Webhook — Entrada`
2. Copie a **Production URL** (será algo como `https://SEU_N8N/webhook/agendamento-ai`)

#### Teste 1 — Listar eventos

```bash
curl -X POST https://SEU_N8N/webhook/agendamento-ai \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Liste meus próximos eventos",
    "session_id": "user_teste_001",
    "user_name": "Teste"
  }'
```

#### Teste 2 — Criar evento

```bash
curl -X POST https://SEU_N8N/webhook/agendamento-ai \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Agende uma reunião de planejamento amanhã às 10h com duração de 1 hora",
    "session_id": "user_teste_001",
    "user_name": "Teste"
  }'
```

#### Teste 3 — Deletar evento (usando o event_id retornado no teste anterior)

```bash
curl -X POST https://SEU_N8N/webhook/agendamento-ai \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Delete o evento de ID abc123xyz",
    "session_id": "user_teste_001",
    "user_name": "Teste"
  }'
```

#### Resposta esperada

```json
{
  "success": true,
  "response": "✅ Evento criado com sucesso!\n- Título: Reunião de planejamento\n- Início: 2025-12-02T10:00:00-03:00\n- Event ID: abc123xyz\n- Link: https://calendar.google.com/...",
  "session_id": "user_teste_001",
  "timestamp": "2025-12-01T13:00:00.000Z"
}
```

---

## 📡 API Reference — Campos de Input

### Endpoint do Agente

```
POST https://SEU_N8N/webhook/agendamento-ai
Content-Type: application/json
```

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `message` | string | ✅ | Mensagem em linguagem natural do usuário |
| `session_id` | string | ✅ | ID único da sessão/usuário (mantém memória) |
| `user_name` | string | ❌ | Nome do usuário (usado no system prompt) |

### Campos internos da Tool (extraídos automaticamente pelo LLM)

| Campo | Tipo | Ações | Descrição |
|---|---|---|---|
| `action` | string | todas | `create` / `read` / `update` / `delete` / `list` |
| `summary` | string | create, update | Título do evento |
| `description` | string | create, update | Descrição detalhada |
| `start_time` | string ISO8601 | create, update | Ex: `2025-12-01T10:00:00-03:00` |
| `end_time` | string ISO8601 | create, update | Ex: `2025-12-01T11:00:00-03:00` |
| `event_id` | string | read, update, delete | ID retornado pelo Google Calendar |
| `timezone` | string | create, update | Default: `America/Sao_Paulo` |
| `calendar_id` | string | todas | Default: `primary` |

---

## 💬 Exemplos de Uso

O agente entende linguagem natural. Veja exemplos de frases que funcionam:

### Criar eventos
```
"Marque uma consulta médica na sexta às 15h"
"Crie uma reunião de equipe para amanhã às 9h com duração de 2 horas"
"Agende um almoço de negócios dia 15 de dezembro ao meio-dia"
"Coloque na agenda: treinamento de vendas, 20/12 das 9h às 18h"
```

### Listar eventos
```
"Quais são meus próximos eventos?"
"Mostre minha agenda da semana"
"O que tenho agendado?"
```

### Ler um evento específico
```
"Me mostre os detalhes do evento abc123"
"Qual é a descrição do evento abc123?"
```

### Atualizar eventos
```
"Mude o horário do evento abc123 para as 16h"
"Atualize o título do evento abc123 para Reunião de Diretoria"
```

### Deletar eventos
```
"Cancele o evento abc123"
"Delete a reunião de ID abc123"
"Exclua o evento abc123 da minha agenda"
```

---

## 🔌 Integrações Possíveis

O webhook do agente pode ser chamado por qualquer sistema. Veja como conectar:

### WhatsApp via Evolution API

Configure um webhook na Evolution API para redirecionar mensagens recebidas para o endpoint do agente. O campo `message` recebe o texto da mensagem e `session_id` recebe o número do telefone (para manter contexto por usuário).

### Telegram Bot

Use o nó **Telegram Trigger** do n8n no lugar do Webhook. Mapeie `message.text` para o campo `message` e `message.from.id` para o `session_id`.

### Chat embutido no site

Substitua o nó **Webhook** pelo nó **Chat Trigger** do n8n. Ele gera automaticamente uma interface de chat que pode ser embutida em qualquer site via iframe ou SDK.

### Aplicativo próprio

Faça chamadas `POST` diretamente ao webhook a partir do seu frontend ou backend. Armazene o `event_id` retornado para futuras operações de atualização ou cancelamento.

---

## 🔧 Troubleshooting

### ❌ "Could not find property option" ao importar

**Causa:** Versão de typeVersion incompatível com seu n8n.

**Solução:** Use o arquivo `workflow_tool_google_calendar.json` corrigido (versão atual deste repositório). As versões corretas são:
- `executeWorkflowTrigger`: typeVersion `1`
- `switch`: typeVersion `3`
- `googleCalendar`: typeVersion `1.2`
- `supabase`: typeVersion `1`
- `set`: typeVersion `3.3`

---

### ❌ Google Calendar retorna erro 403

**Causa:** A credencial OAuth não tem permissão para o calendário.

**Soluções:**
1. Verifique se a **Google Calendar API** está habilitada no Google Cloud Console
2. Refaça o fluxo OAuth clicando em **Reconnect** na credencial
3. Certifique-se que o escopo `https://www.googleapis.com/auth/calendar` está incluído

---

### ❌ Supabase retorna erro de autenticação

**Causa:** Chave errada ou URL incorreta.

**Solução:** No painel do Supabase, vá em **Settings → API** e confirme:
- Use a chave **service_role** (não a `anon`)
- A URL deve ser no formato `https://XXXX.supabase.co` (sem barra no final)

---

### ❌ O agente não chama a tool corretamente

**Causa:** O LLM não está interpretando bem a intenção, ou a descrição da tool está vaga.

**Soluções:**
1. Certifique-se de estar usando **GPT-4o** ou **Claude 3.5 Sonnet** — modelos menores têm dificuldade com function calling
2. Tente ser mais explícito na mensagem: em vez de *"marca algo"*, use *"crie um evento no calendário"*
3. Verifique se a conexão do nó Workflow Tool na porta `ai_tool` do Agent está correta

---

### ❌ Memória não funciona entre mensagens

**Causa:** `session_id` diferente em cada requisição.

**Solução:** Envie sempre o mesmo `session_id` para o mesmo usuário/conversa. O Buffer Memory usa esse campo como chave de sessão.

---

### ❌ O webhook retorna erro 404

**Causa:** O workflow do Agente não está ativo.

**Solução:** Abra o workflow do Agente no n8n e ative o toggle **Active** no canto superior direito. Workflows inativos não respondem em produção.

---

## 🔐 Segurança para Produção

Antes de expor o sistema ao público, implemente as seguintes medidas:

### Autenticação no Webhook

Adicione um **Header Auth** ao nó Webhook para que apenas chamadas com o header correto sejam aceitas:

```
Header Name:  X-API-Key
Header Value: SUA_CHAVE_SECRETA_AQUI
```

Todas as chamadas devem incluir:
```bash
curl -H "X-API-Key: SUA_CHAVE_SECRETA_AQUI" ...
```

### Rate Limiting

Configure um limite de requisições por `session_id` para evitar abuso. Isso pode ser feito com um nó **Code** antes do Agente que verifica um contador no Supabase.

### Row Level Security no Supabase

Habilite o RLS na tabela `calendar_events` e crie policies para que cada usuário acesse apenas seus próprios registros, usando o `session_id` ou um `user_id` como discriminador.

### Variáveis de Ambiente

Nunca deixe API keys hardcoded. Use variáveis de ambiente do n8n (`N8N_ENCRYPTION_KEY`, etc.) e o sistema nativo de credenciais para gerenciar chaves com segurança.

---

## 📐 Estrutura dos Nós

### Workflow Tool — nós e funções

```
🚀 Execute Workflow Trigger    ← Ponto de entrada (chamado pelo agente)
   │
⚙️ Normalizar Input            ← Padroniza campos, define defaults
   │
🔀 Switch Roteador de Ação     ← Distribui por action (5 saídas)
   │
   ├─ [CREATE] ──► GCal Criar Evento ──► Supabase Salvar ──► Resposta CREATE
   ├─ [READ]   ──► GCal Ler Evento   ──────────────────────► Resposta READ
   ├─ [UPDATE] ──► GCal Atualizar    ──────────────────────► Resposta UPDATE
   ├─ [DELETE] ──► GCal Deletar      ──► Supabase Remover ──► Resposta DELETE
   └─ [LIST]   ──► GCal Listar       ──► Agregar Eventos  ──► Resposta LIST
```

### Workflow Agente — nós e funções

```
🌐 Webhook Entrada             ← Recebe POST com message + session_id
   │
⚙️ Preparar Input              ← Normaliza payload de diferentes fontes
   │
🤖 AI Agent                   ← Interpreta intenção e aciona tools
   │  ├─ 🧠 OpenAI GPT-4o      ← Modelo de linguagem (function calling)
   │  ├─ 💾 Buffer Memory      ← Histórico por session_id
   │  └─ 🛠️ Workflow Tool      ← Chama o Workflow Tool do Calendar
   │
📤 Formatar Resposta           ← Padroniza o output
   │
📨 Webhook Response            ← Retorna JSON ao cliente
```

---

## 📝 Notas Técnicas

- **Timezone padrão:** `America/Sao_Paulo` — altere no nó de normalização se necessário
- **Limite de eventos listados:** 10 — ajuste o campo `limit` no nó `GCal Listar Eventos`
- **Janela de memória:** 10 mensagens (5 turnos) — ajuste `contextWindowLength` no Buffer Memory
- **Attendees:** A adição de convidados não está disponível na criação para evitar erros de serialização. Adicione via UPDATE após criar o evento
- **soft-delete:** O campo `deleted_at` na tabela Supabase existe para auditoria, mas o fluxo atual faz hard-delete. Adapte o nó Supabase Remover Registro para implementar soft-delete se necessário

---

## 📄 Licença

Este projeto é distribuído para uso livre. Adapte conforme sua necessidade.

---

*Gerado para n8n v2.8.3 — Google Calendar API v3 — Supabase v2*
