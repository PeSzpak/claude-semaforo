#!/usr/bin/env bash
# Grava o estado do agente para a janela do semáforo.
# Uso: estado.sh <pensando|esperando|pronto|erro|offline> [agente]   (JSON do hook no stdin)
# Sem agente é o Claude Code; com agente (Codex, Gemini...) o nome aparece antes do projeto.
. "$(dirname "$0")/comum.sh"

estado="$1"
agente="$2"
entrada=$(cat)

# Lê um campo de texto do JSON sem depender do jq
campo() {
  printf '%s' "$entrada" | tr -d '\n' |
    sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

if [ "$estado" = esperando ]; then
  # Notification "parado há 60s" não é pedido de aprovação: ignora
  [ "$(campo notification_type)" = idle_prompt ] && exit 0
  campo message | grep -qi "waiting for your input" && exit 0
fi

# Nome do projeto = última parte do cwd (aceita / e \ do Windows)
cwd=$(campo cwd)
cwd=${cwd:-$PWD}
cwd=${cwd%[\\/]}
projeto=${cwd##*[\\/]}
[ -n "$agente" ] && projeto="$agente · $projeto"

pasta=$(pasta_estado)
printf '%s|%s|%s\n' "$estado" "$(date +%s)" "$projeto" >"$pasta/estado.tmp" &&
  mv -f "$pasta/estado.tmp" "$pasta/estado.txt"
