# 🚦 Semáforo do Claude Code

Uma janelinha flutuante que mostra o que o Claude Code está fazendo, para você não ficar olhando o terminal:

| Luz | Estado | Quando |
|---|---|---|
| 🟡 (pisca) | **Pensando…** | Você mandou uma mensagem ou ele está usando ferramentas |
| 🔴 | **Te esperando** | Ele precisa de aprovação, fez uma pergunta ou quer aprovar um plano |
| 🟢 | **Pronto!** | Terminou a resposta |
| 🔴 | **Erro** | A resposta falhou (erro de API, limite etc.) |
| ⚫ | **Offline** | A sessão foi encerrada |

Mostra também o nome do projeto e há quanto tempo está naquele estado, e toca um som quando muda para pronto, esperando ou erro.

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
plugins/semaforo/
├── hooks/hooks.json       # quais eventos do Claude Code mudam a luz
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
/plugin uninstall semaforo@semaforo
```

Para apagar também a posição salva e o estado: `rm -rf ~/.claude-semaforo ~/.claude/semaforo-pasta`.
