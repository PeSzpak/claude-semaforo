# Semáforo flutuante do Claude Code
# Lê estado.txt (escrito pelos hooks) e acende a luz correspondente.
# Arraste para mover. Clique direito para fechar.
# -Pasta: onde está o estado.txt (padrão: a pasta deste script)

param([string]$Pasta = $PSScriptRoot)

$criado = $false
$mutex = New-Object System.Threading.Mutex($true, 'Global\ClaudeSemaforo', [ref]$criado)
if (-not $criado) { exit }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$arqEst = Join-Path $Pasta 'estado.txt'
$arqPos = Join-Path $Pasta 'posicao.txt'

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize"
        SizeToContent="WidthAndHeight" Title="Claude">
  <Border CornerRadius="18" Background="#E6181A1F" BorderBrush="#33FFFFFF" BorderThickness="1" Padding="12,14,12,10">
    <Border.Effect><DropShadowEffect BlurRadius="16" ShadowDepth="2" Opacity="0.5"/></Border.Effect>
    <StackPanel HorizontalAlignment="Center">
      <Ellipse x:Name="Vermelho" Width="30" Height="30" Margin="0,0,0,8"/>
      <Ellipse x:Name="Amarelo"  Width="30" Height="30" Margin="0,0,0,8"/>
      <Ellipse x:Name="Verde"    Width="30" Height="30"/>
      <TextBlock x:Name="Texto"   Foreground="#EEE" FontFamily="Segoe UI" FontSize="11" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,10,0,0"/>
      <TextBlock x:Name="Projeto" Foreground="#888" FontFamily="Segoe UI" FontSize="10" HorizontalAlignment="Center" MaxWidth="90" TextTrimming="CharacterEllipsis"/>
      <TextBlock x:Name="Tempo"   Foreground="#888" FontFamily="Consolas" FontSize="10" HorizontalAlignment="Center"/>
    </StackPanel>
  </Border>
</Window>
'@

$janela  = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$luzes   = @{ vermelho = $janela.FindName('Vermelho'); amarelo = $janela.FindName('Amarelo'); verde = $janela.FindName('Verde') }
$texto   = $janela.FindName('Texto')
$projeto = $janela.FindName('Projeto')
$tempo   = $janela.FindName('Tempo')

function Pincel($hex) { New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($hex)) }
$aceso  = @{ vermelho = '#FF3B30'; amarelo = '#FFCC00'; verde = '#34C759' }
$apagado = Pincel '#2E2F33'
$brilho = @{}
foreach ($k in $aceso.Keys) {
  $e = New-Object Windows.Media.Effects.DropShadowEffect
  $e.Color = [Windows.Media.ColorConverter]::ConvertFromString($aceso[$k]); $e.BlurRadius = 22; $e.ShadowDepth = 0; $e.Opacity = 0.9
  $brilho[$k] = $e
}

$mapa = @{
  pensando  = @{ luz = 'amarelo';  rotulo = 'Pensando…' }
  esperando = @{ luz = 'vermelho'; rotulo = 'Te esperando' }
  erro      = @{ luz = 'vermelho'; rotulo = 'Erro' }
  pronto    = @{ luz = 'verde';    rotulo = 'Pronto!' }
  offline   = @{ luz = $null;      rotulo = 'Offline' }
}

$script:ultimo = ''
$script:desde = 0

function Acender($estado) {
  $info = $mapa[$estado]; if (-not $info) { $info = $mapa['offline'] }
  foreach ($k in $luzes.Keys) {
    if ($k -eq $info.luz) { $luzes[$k].Fill = Pincel $aceso[$k]; $luzes[$k].Effect = $brilho[$k] }
    else { $luzes[$k].Fill = $apagado; $luzes[$k].Effect = $null }
  }
  $texto.Text = $info.rotulo
}

$pulso = 0
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(300)
$timer.Add_Tick({
  $linha = ''
  try { if (Test-Path $arqEst) { $linha = (Get-Content $arqEst -Raw -ErrorAction Stop).Trim() } } catch {}
  if (-not $linha) { $linha = 'offline|0|' }
  $partes = $linha.Split('|')
  $estado = $partes[0]
  if ($linha -ne $script:ultimo) {
    $anterior = ($script:ultimo.Split('|'))[0]
    $script:ultimo = $linha
    $script:desde = [int64]$partes[1]
    $projeto.Text = $partes[2]
    Acender $estado
    if ($anterior -and $anterior -ne $estado) {
      if ($estado -eq 'pronto') { [System.Media.SystemSounds]::Asterisk.Play() }
      elseif ($estado -eq 'esperando' -or $estado -eq 'erro') { [System.Media.SystemSounds]::Exclamation.Play() }
    }
  }
  # Amarelo pulsa enquanto pensa
  if ($estado -eq 'pensando') {
    $script:pulso = ($script:pulso + 1) % 6
    $luzes['amarelo'].Opacity = 0.55 + 0.45 * [math]::Abs(3 - $script:pulso) / 3
  } else { $luzes['amarelo'].Opacity = 1 }
  if ($script:desde -gt 0) {
    $s = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $script:desde
    $tempo.Text = '{0:00}:{1:00}' -f [math]::Floor($s / 60), ($s % 60)
  } else { $tempo.Text = '' }
})

$janela.Add_MouseLeftButtonDown({ $janela.DragMove() })
$janela.Add_MouseRightButtonUp({ $janela.Close() })
$janela.Add_Closing({ try { "$($janela.Left),$($janela.Top)" | Set-Content $arqPos } catch {} })
$janela.Add_Loaded({
  $area = [System.Windows.SystemParameters]::WorkArea
  $pos = $null
  try { if (Test-Path $arqPos) { $pos = (Get-Content $arqPos -Raw).Trim().Split(',') } } catch {}
  if ($pos -and $pos.Count -eq 2) { $janela.Left = [double]$pos[0]; $janela.Top = [double]$pos[1] }
  else { $janela.Left = $area.Right - $janela.ActualWidth - 24; $janela.Top = $area.Top + 120 }
})

Acender 'offline'
$timer.Start()
$janela.ShowDialog() | Out-Null
$mutex.ReleaseMutex()
