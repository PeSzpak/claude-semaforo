#!/usr/bin/env bash
# Abre a janela do semáforo do sistema atual (se já estiver aberta, não abre outra).
. "$(dirname "$0")/comum.sh"

# O hook manda JSON no stdin; não é usado aqui
[ -t 0 ] || cat >/dev/null

RAIZ=$(cd "$(dirname "$0")/.." && pwd)
pasta=$(pasta_estado)

# Mac e Linux: evita duas janelas pelo PID salvo
ja_aberta() { [ -f "$pasta/janela.pid" ] && kill -0 "$(cat "$pasta/janela.pid")" 2>/dev/null; }
iniciar() {
  nohup "$@" >/dev/null 2>&1 </dev/null &
  echo $! >"$pasta/janela.pid"
}

# Windows e WSL: Start-Process solta a janela do processo do hook.
# A segunda instância sai sozinha (mutex dentro do semaforo.ps1).
abrir_powershell() { # $1 = .ps1 e $2 = pasta, ambos em caminho do Windows
  powershell.exe -NoProfile -Command "Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-STA','-File','\"$1\"','-Pasta','\"$2\"'" \
    >/dev/null 2>&1 </dev/null
}

case "$(sistema)" in
  mac)
    ja_aberta || iniciar osascript -l JavaScript "$RAIZ/ui/semaforo-mac.js" "$pasta"
    ;;
  linux)
    [ -n "$DISPLAY$WAYLAND_DISPLAY" ] || exit 0
    ja_aberta || iniciar python3 "$RAIZ/ui/semaforo-linux.py" "$pasta"
    ;;
  wsl)
    command -v powershell.exe >/dev/null || exit 0
    # O PowerShell não roda bem scripts de dentro do WSL: copia para a pasta do Windows
    cp -f "$RAIZ/ui/semaforo.ps1" "$pasta/semaforo.ps1"
    abrir_powershell "$(wslpath -w "$pasta/semaforo.ps1")" "$(wslpath -w "$pasta")"
    ;;
  windows)
    abrir_powershell "$(cygpath -w "$RAIZ/ui/semaforo.ps1")" "$(cygpath -w "$pasta")"
    ;;
esac
exit 0
