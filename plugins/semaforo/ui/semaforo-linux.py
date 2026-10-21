#!/usr/bin/env python3
# Semáforo flutuante do Claude Code para Linux (Tkinter)
# Lê estado.txt (escrito pelos hooks) e acende a luz correspondente.
# Arraste para mover. Clique direito para fechar.
# Uso: python3 semaforo-linux.py <pasta do estado.txt>
import os
import sys
import time
import tkinter as tk

PASTA = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.claude-semaforo")
ARQ_EST = os.path.join(PASTA, "estado.txt")
ARQ_POS = os.path.join(PASTA, "posicao.txt")

L, A = 96, 176
FUNDO = "#141518"
APAGADO = "#2E2F33"
ACESO = {"vermelho": "#FF3B30", "amarelo": "#FFCC00", "verde": "#34C759"}
MAPA = {
    "pensando": ("amarelo", "Pensando…"),
    "esperando": ("vermelho", "Te esperando"),
    "erro": ("vermelho", "Erro"),
    "pronto": ("verde", "Pronto!"),
    "offline": (None, "Offline"),
}


def ler(arq):
    try:
        with open(arq, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""


def misturar(hex1, hex2, t):
    """Cor entre hex1 (t=0) e hex2 (t=1); o Tk não tem opacidade por item."""
    a = [int(hex1[i : i + 2], 16) for i in (1, 3, 5)]
    b = [int(hex2[i : i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(a, b))


raiz = tk.Tk()
raiz.title("Claude")
raiz.overrideredirect(True)
raiz.attributes("-topmost", True)
raiz.configure(bg=FUNDO)

pos = ler(ARQ_POS).split(",")
if len(pos) == 2 and all(p.lstrip("-").isdigit() for p in pos):
    x, y = int(pos[0]), int(pos[1])
else:
    x, y = raiz.winfo_screenwidth() - L - 24, 120
raiz.geometry(f"{L}x{A}+{x}+{y}")

tela = tk.Canvas(raiz, width=L, height=A, bg=FUNDO, highlightthickness=1, highlightbackground="#2A2B30")
tela.pack()

luzes = {}
for nome, topo in (("vermelho", 14), ("amarelo", 52), ("verde", 90)):
    cx = L // 2
    brilho = tela.create_oval(cx - 19, topo - 4, cx + 19, topo + 34, fill=FUNDO, outline="")
    luz = tela.create_oval(cx - 15, topo, cx + 15, topo + 30, fill=APAGADO, outline="")
    luzes[nome] = (luz, brilho)

rotulo = tela.create_text(L // 2, 136, fill="#EEEEEE", font=("Sans", 9, "bold"))
projeto = tela.create_text(L // 2, 152, fill="#8E8E93", font=("Sans", 8))
tempo = tela.create_text(L // 2, 166, fill="#8E8E93", font=("Monospace", 8))

estado_atual = {"linha": "", "desde": 0, "pulso": 0, "estado": "offline"}


def acender(estado):
    luz_acesa, texto = MAPA.get(estado, MAPA["offline"])
    for nome, (luz, brilho) in luzes.items():
        ligada = nome == luz_acesa
        tela.itemconfig(luz, fill=ACESO[nome] if ligada else APAGADO)
        tela.itemconfig(brilho, fill=misturar(FUNDO, ACESO[nome], 0.35) if ligada else FUNDO)
    tela.itemconfig(rotulo, text=texto)


def encurtar(texto, limite=14):
    return texto if len(texto) <= limite else texto[: limite - 1] + "…"


def tique():
    linha = ler(ARQ_EST) or "offline|0|"
    partes = (linha.split("|") + ["", "", ""])[:3]
    estado = partes[0]

    if linha != estado_atual["linha"]:
        anterior = estado_atual["estado"] if estado_atual["linha"] else ""
        estado_atual.update(linha=linha, estado=estado, desde=int(partes[1] or 0))
        tela.itemconfig(projeto, text=encurtar(partes[2]))
        acender(estado)
        if anterior and anterior != estado and estado in ("pronto", "esperando", "erro"):
            raiz.bell()

    # Amarelo pulsa enquanto pensa
    if estado == "pensando":
        estado_atual["pulso"] = (estado_atual["pulso"] + 1) % 6
        t = 0.55 + 0.45 * abs(3 - estado_atual["pulso"]) / 3
        tela.itemconfig(luzes["amarelo"][0], fill=misturar(FUNDO, ACESO["amarelo"], t))

    desde = estado_atual["desde"]
    if desde > 0:
        s = max(0, int(time.time()) - desde)
        tela.itemconfig(tempo, text=f"{s // 60:02d}:{s % 60:02d}")
    else:
        tela.itemconfig(tempo, text="")

    raiz.after(300, tique)


arrasto = {"x": 0, "y": 0}


def pegar(evento):
    arrasto.update(x=evento.x, y=evento.y)


def mover(evento):
    raiz.geometry(f"+{evento.x_root - arrasto['x']}+{evento.y_root - arrasto['y']}")


def fechar(_evento=None):
    try:
        with open(ARQ_POS, "w", encoding="utf-8") as f:
            f.write(f"{raiz.winfo_x()},{raiz.winfo_y()}")
    except OSError:
        pass
    raiz.destroy()


tela.bind("<ButtonPress-1>", pegar)
tela.bind("<B1-Motion>", mover)
tela.bind("<ButtonRelease-3>", fechar)

acender("offline")
tique()
raiz.mainloop()
