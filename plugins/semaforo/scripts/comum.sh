# Funções compartilhadas entre estado.sh e abrir.sh

# mac | linux | wsl | windows | outro
sistema() {
  case "$(uname -s)" in
    Darwin) echo mac ;;
    MINGW* | MSYS* | CYGWIN*) echo windows ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then echo wsl; else echo linux; fi
      ;;
    *) echo outro ;;
  esac
}

# Pasta onde o estado é gravado e lido pela janela.
# No WSL a janela roda no Windows, então a pasta fica no perfil do Windows.
# O resultado fica em cache porque chamar o cmd.exe a cada hook é lento.
pasta_estado() {
  local cache="$HOME/.claude/semaforo-pasta"
  if [ -s "$cache" ] && [ -d "$(cat "$cache")" ]; then
    cat "$cache"
    return
  fi

  local pasta="$HOME/.claude-semaforo"
  if [ "$(sistema)" = wsl ] && command -v cmd.exe >/dev/null; then
    local perfil
    perfil=$(cd /mnt/c 2>/dev/null && cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')
    [ -n "$perfil" ] && pasta="$(wslpath -u "$perfil")/.claude-semaforo"
  fi

  mkdir -p "$pasta" "$HOME/.claude" && printf '%s' "$pasta" >"$cache"
  echo "$pasta"
}
