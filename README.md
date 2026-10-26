# 🚦 Semáforo do Claude Code

Uma janelinha flutuante que mostra o que o seu agente de IA está fazendo, para você não ficar olhando o terminal. Funciona com **Claude Code** (terminal e aba Code do app Claude Desktop), **Codex** (CLI e app) e **Gemini CLI**.

| Luz | Estado | Quando |
|---|---|---|
| 🟡 (pisca) | **Pensando…** | Você mandou uma mensagem ou ele está usando ferramentas |
| 🔴 | **Te esperando** | Ele precisa de aprovação, fez uma pergunta ou quer aprovar um plano |
| 🟢 | **Pronto!** | Terminou a resposta |
| 🔴 | **Erro** | A resposta falhou (erro de API, limite etc.) |
| ⚫ | **Offline** | A sessão foi encerrada |

Mostra também o nome do projeto (com `Codex ·` ou `Gemini ·` na frente quando não é o Claude) e há quanto tempo está naquele estado, e toca um som quando muda para pronto, esperando ou erro.

**Arraste** para mover (a posição fica salva). **Clique direito** fecha. Para reabrir: `/semaforo:abrir` ou abra uma nova sessão.

## Instalar

Dentro do Claude Code:

```
/plugin marketplace add PeSzpak/claude-semaforo
/plugin install semaforo@semaforo
```

Ou pelo terminal:

```bash
claude plugin marketplace add PeSzpak/claude-semaforo
claude plugin install semaforo@semaforo
```

Depois abra uma nova sessão do `claude`, e a janela aparece sozinha.

> Para testar a partir de uma cópia local, troque `PeSzpak/claude-semaforo` pelo caminho da pasta.

### Claude Desktop

A aba **Code** do app Claude Desktop roda o mesmo Claude Code e lê os plugins de `~/.claude`. Depois de instalar como acima, o semáforo também acompanha as sessões abertas por lá. O chat comum do app (fora da aba Code) não tem hooks, então ele não aparece no semáforo.

### Codex

```bash
codex plugin marketplace add PeSzpak/claude-semaforo
```

Depois, dentro do `codex`, abra `/plugins`, instale o **Semáforo** e comece uma nova sessão. O Codex só roda hooks que você aprovou: abra `/hooks` e confie nos hooks do semáforo. A janela aparece na próxima sessão, também no app Codex.

### Gemini CLI

```bash
gemini extensions install https://github.com/PeSzpak/claude-semaforo
```

Abra uma nova sessão do `gemini`. Se os hooks estiverem desligados, use `/hooks enable-all`.

### Outros agentes

Qualquer ferramenta que rode um comando em cada evento pode acender o semáforo. Chame `scripts/estado.sh` com o estado e o nome do agente, e `scripts/abrir.sh` para abrir a janela:

```bash
bash plugins/semaforo/scripts/estado.sh pensando MeuAgente </dev/null
```

Os estados são `pensando`, `esperando`, `pronto`, `erro` e `offline`.

## Sistemas

| Sistema | Janela | Precisa de |
|---|---|---|
| **macOS** | JavaScript nativo (`osascript`) | nada |
| **Windows** | PowerShell + WPF | nada (o Git Bash que o Claude Code já usa) |
| **WSL** | PowerShell + WPF, rodando no Windows | nada |
| **Linux** | Python + Tkinter | `python3-tk` (`sudo apt install python3-tk`) e uma sessão gráfica |

Os hooks e o estado são os mesmos em todos: `scripts/estado.sh` grava `estado|horário|projeto` em `~/.claude-semaforo/estado.txt` (no WSL, em `C:\Users\<você>\.claude-semaforo\`), e a janela lê esse arquivo a cada 300 ms. Não precisa de `jq`.

## Como funciona

```
gemini-extension.json      # extensão do Gemini CLI
hooks/hooks.json           # eventos do Gemini CLI
.agents/plugins/           # marketplace do Codex
plugins/semaforo/
├── .claude-plugin/        # manifesto do Claude Code
├── .codex-plugin/         # manifesto do Codex
├── hooks/hooks.json       # eventos do Claude Code
├── hooks/codex.json       # eventos do Codex
├── scripts/
│   ├── estado.sh          # grava o estado (chamado pelos hooks)
│   ├── abrir.sh           # abre a janela certa para o sistema
│   └── comum.sh           # detecta o sistema e a pasta do estado
├── ui/
│   ├── semaforo-mac.js    # macOS
│   ├── semaforo.ps1       # Windows e WSL
│   └── semaforo-linux.py  # Linux
└── commands/abrir.md      # /semaforo:abrir
```

Com várias sessões abertas ao mesmo tempo, a janela mostra a que mudou por último.

## Desinstalar

```
/plugin uninstall semaforo@semaforo        # Claude Code
gemini extensions uninstall semaforo       # Gemini CLI
```

No Codex, remova pelo `/plugins`.

Para apagar também a posição salva e o estado: `rm -rf ~/.claude-semaforo ~/.claude/semaforo-pasta`.
