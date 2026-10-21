// Semáforo flutuante do Claude Code para macOS (JavaScript for Automation, sem dependências)
// Lê estado.txt (escrito pelos hooks) e acende a luz correspondente.
// Arraste para mover. Clique direito para fechar.
// Uso: osascript -l JavaScript semaforo-mac.js <pasta do estado.txt>
ObjC.import('Cocoa');
ObjC.import('QuartzCore');
ObjC.import('CoreGraphics');

function run(argv) {
  const pasta = argv[0] || ObjC.unwrap($.NSHomeDirectory()) + '/.claude-semaforo';
  const arqEst = pasta + '/estado.txt';
  const arqPos = pasta + '/posicao.txt';

  const ler = (arq) =>
    ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(arq, $.NSUTF8StringEncoding, null)) || '';
  const gravar = (arq, texto) =>
    $(texto).writeToFileAtomicallyEncodingError(arq, true, $.NSUTF8StringEncoding, null);

  // NSColor.CGColor não atravessa a ponte do JXA; CGColorCreateGenericRGB sim
  const cor = (hex, alfa = 1) => {
    const n = parseInt(hex.slice(1), 16);
    return $.CGColorCreateGenericRGB(((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255, alfa);
  };

  const aceso = { vermelho: '#FF3B30', amarelo: '#FFCC00', verde: '#34C759' };
  const apagado = cor('#2E2F33');
  const mapa = {
    pensando: { luz: 'amarelo', rotulo: 'Pensando…' },
    esperando: { luz: 'vermelho', rotulo: 'Te esperando' },
    erro: { luz: 'vermelho', rotulo: 'Erro' },
    pronto: { luz: 'verde', rotulo: 'Pronto!' },
    offline: { luz: null, rotulo: 'Offline' },
  };
  const sons = { pronto: 'Glass', esperando: 'Ping', erro: 'Basso' };

  const L = 96;
  const A = 176;

  const app = $.NSApplication.sharedApplication;
  app.setActivationPolicy(1); // Accessory: sem ícone no Dock

  let janela;
  const fechar = () => {
    const o = janela.frame.origin;
    gravar(arqPos, `${Math.round(o.x)},${Math.round(o.y)}`);
    app.terminate(null);
  };

  // Arrastar move a janela, clique direito fecha
  ObjC.registerSubclass({
    name: 'SemaforoToque',
    superclass: 'NSView',
    methods: {
      'mouseDown:': {
        types: ['void', ['id']],
        implementation: function (evento) {
          this.window.performWindowDragWithEvent(evento);
        },
      },
      'rightMouseUp:': {
        types: ['void', ['id']],
        implementation: function () {
          fechar();
        },
      },
    },
  });

  // Posição salva ou canto superior direito da tela
  const tela = $.NSScreen.mainScreen.visibleFrame;
  let x = tela.origin.x + tela.size.width - L - 24;
  let y = tela.origin.y + tela.size.height - A - 120;
  const salva = ler(arqPos).trim().split(',').map(Number);
  if (salva.length === 2 && salva.every(Number.isFinite)) [x, y] = salva;

  janela = $.NSPanel.alloc.initWithContentRectStyleMaskBackingDefer(
    $.NSMakeRect(x, y, L, A),
    0 | 128, // Borderless | NonactivatingPanel
    2, // NSBackingStoreBuffered
    false,
  );
  janela.level = 3; // NSFloatingWindowLevel
  janela.opaque = false;
  janela.backgroundColor = $.NSColor.clearColor;
  janela.hasShadow = true;
  janela.hidesOnDeactivate = false;
  janela.collectionBehavior = 1 | 16 | 256; // todos os Spaces, fixa, sobre tela cheia

  // Fundo sólido (translúcido deixava a tela de trás vazar e ficava acinzentado)
  const fundo = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, L, A));
  fundo.wantsLayer = true;
  const base = fundo.layer;
  base.cornerRadius = 18;
  base.backgroundColor = cor('#141518');
  base.borderWidth = 1;
  base.borderColor = cor('#FFFFFF', 0.12);
  janela.contentView = fundo;

  const luzes = {};
  for (const [nome, yy] of [['vermelho', 132], ['amarelo', 94], ['verde', 56]]) {
    const luz = $.CALayer.layer;
    luz.frame = $.NSMakeRect((L - 30) / 2, yy, 30, 30);
    luz.cornerRadius = 15;
    luz.backgroundColor = apagado;
    luz.shadowColor = cor(aceso[nome]);
    luz.shadowOffset = $.NSMakeSize(0, 0);
    luz.shadowRadius = 10;
    luz.shadowOpacity = 0;
    base.addSublayer(luz);
    luzes[nome] = luz;
  }

  // Rótulos comuns: o JXA não aplica cor/fonte em CATextLayer.
  // O texto é centralizado medindo a largura, porque o valor de
  // NSTextAlignmentCenter muda entre Intel e Apple Silicon.
  const texto = (yy, tamanho, hex, negrito) => {
    const n = parseInt(hex.slice(1), 16);
    const t = $.NSTextField.labelWithString($(''));
    t.frame = $.NSMakeRect(4, yy, L - 8, tamanho + 5);
    t.font = negrito
      ? $.NSFont.boldSystemFontOfSize(tamanho)
      : $.NSFont.monospacedDigitSystemFontOfSizeWeight(tamanho, 0);
    t.textColor = $.NSColor.colorWithSRGBRedGreenBlueAlpha(
      ((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255, 1,
    );
    t.lineBreakMode = 4; // NSLineBreakByTruncatingTail
    fundo.addSubview(t);
    return {
      set string(valor) {
        t.stringValue = valor;
        t.sizeToFit;
        const largura = Math.min(t.frame.size.width, L - 8);
        t.frame = $.NSMakeRect((L - largura) / 2, yy, largura, tamanho + 5);
      },
    };
  };
  const rotulo = texto(34, 11, '#EEEEEE', true);
  const projeto = texto(19, 10, '#8E8E93', false);
  const tempo = texto(4, 10, '#8E8E93', false);

  // Camada transparente por cima de tudo: recebe o arrastar e o clique direito
  fundo.addSubview($.SemaforoToque.alloc.initWithFrame($.NSMakeRect(0, 0, L, A)));

  const acender = (estado) => {
    const info = mapa[estado] || mapa.offline;
    for (const nome of Object.keys(luzes)) {
      const ligada = nome === info.luz;
      luzes[nome].backgroundColor = ligada ? cor(aceso[nome]) : apagado;
      luzes[nome].shadowOpacity = ligada ? 0.9 : 0;
    }
    rotulo.string = $(info.rotulo);
  };

  let ultimo = '';
  let desde = 0;
  let pulso = 0;

  const tique = () => {
    const linha = ler(arqEst).trim() || 'offline|0|';
    const [estado, inicio, nomeProjeto = ''] = linha.split('|');

    if (linha !== ultimo) {
      const anterior = ultimo.split('|')[0];
      ultimo = linha;
      desde = Number(inicio) || 0;
      projeto.string = $(nomeProjeto);
      acender(estado);
      if (anterior && anterior !== estado && sons[estado]) {
        $.NSSound.soundNamed(sons[estado]).play;
      }
    }

    // Amarelo pulsa enquanto pensa
    if (estado === 'pensando') {
      pulso = (pulso + 1) % 6;
      luzes.amarelo.opacity = 0.55 + (0.45 * Math.abs(3 - pulso)) / 3;
    } else {
      luzes.amarelo.opacity = 1;
    }

    if (desde > 0) {
      const s = Math.max(0, Math.floor(Date.now() / 1000) - desde);
      const mm = String(Math.floor(s / 60)).padStart(2, '0');
      const ss = String(s % 60).padStart(2, '0');
      tempo.string = $(`${mm}:${ss}`);
    } else {
      tempo.string = $('');
    }
  };

  ObjC.registerSubclass({
    name: 'SemaforoRelogio',
    superclass: 'NSObject',
    methods: {
      'tique:': { types: ['void', ['id']], implementation: tique },
    },
  });
  const relogio = $.SemaforoRelogio.alloc.init;
  $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(0.3, relogio, 'tique:', null, true);

  acender('offline');
  tique();
  janela.orderFrontRegardless;
  app.run;
}
