<#
  make_overlord_voice.ps1 – erzeugt die Sprachbausteine für "Overlord" (DynSEAD)
  Nutzt die Windows-Sprachausgabe. Ausführen in PowerShell:
      powershell -ExecutionPolicy Bypass -File .\make_overlord_voice.ps1
  Optional:  -Voice "Microsoft David Desktop"   -Rate 1   -OutDir .\overlord_voice
  Ergebnis: Ordner mit ov_*.wav + DynSEAD_voice.lua -> als ZIP hochladen
#>
param(
  [string]$OutDir = ".\overlord_voice",
  [string]$Voice  = "",
  [int]$Rate      = 1
)

Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

Write-Host "Installierte Stimmen:"
$synth.GetInstalledVoices() | Where-Object Enabled | ForEach-Object {
  "  {0}  ({1}, {2})" -f $_.VoiceInfo.Name, $_.VoiceInfo.Culture, $_.VoiceInfo.Gender
}

if ($Voice) {
  $synth.SelectVoice($Voice)
} else {
  $en = $synth.GetInstalledVoices() | Where-Object { $_.Enabled -and $_.VoiceInfo.Culture.Name -like 'en-*' } |
        Sort-Object { $_.VoiceInfo.Gender -ne 'Male' } | Select-Object -First 1
  if ($en) { $synth.SelectVoice($en.VoiceInfo.Name) }
  else { Write-Warning "Keine englische Stimme installiert! Windows-Einstellungen > Zeit und Sprache > Sprache > English (United States) hinzufügen." }
}
$synth.Rate = $Rate
Write-Host "Verwende Stimme: $($synth.Voice.Name)  Rate: $Rate"

$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050,
        [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,
        [System.Speech.AudioFormat.AudioChannel]::Mono)

$clips = [ordered]@{
  overlord='Overlord,'; all_players='all players,'; new_threat='new threat,'; area='area'
  plus_minus='plus minus'; kilometers='kilometers.'; meters='meters.'; hundred='hundred'
  update='update,'; now='now'; located='located,'; coords_f10='coordinates passed. Check F 10.'
  popup='pop-up threat!'; now_active='now active,'; check_six='check six, and defend.'
  gone_silent='has gone silent.'; back_up='is back up, emitting again,'
  heads_up='heads up,'; relocated='has relocated.'; new_emissions='new emissions,'
  prev_invalid='previous fix invalid.'; good_effect='good effect,'; site_destroyed='site destroyed.'
  down='down.'; new_picture='new picture, group'; contacts='contacts,'; angels='angels'
  hostile='hostile.'; splash='splash. Picture clean.'; new_objective='new objective,'
  airfield='airfield,'; now_friendly='is now friendly. Good work.'
  caution_manpads='caution, MANPADS reported,'; stay_above='stay above'; thousand='thousand.'
  new_cas='new C A S tasking,'; manpads_reported='MANPADS reported.'
  threat_picture='threat picture,'; sites='sites.'; no_sites='threat picture. No known SAM sites.'
  active='active.'; silent='silent.'; bullseye='bullseye'
  d0='zero'; d1='one'; d2='two'; d3='three'; d4='four'; d5='five'; d6='six'; d7='seven'; d8='eight'; d9='niner'
  n0='zero'; n1='one'; n2='two'; n3='three'; n4='four'; n5='five'; n6='six'; n7='seven'; n8='eight'; n9='nine'
  n10='ten'; n11='eleven'; n12='twelve'; n13='thirteen'; n14='fourteen'; n15='fifteen'; n16='sixteen'
  n17='seventeen'; n18='eighteen'; n19='nineteen'; n20='twenty'; n30='thirty'; n40='forty'; n50='fifty'
  n60='sixty'; n70='seventy'; n80='eighty'; n90='ninety'
  sa2='S A two'; sa3='S A three'; sa6='S A six'; sa8='S A eight'; sa11='S A eleven'; sa15='S A fifteen'
  mig23='Mig twenty-three,'; mig29='Mig twenty-nine,'; su27='Sukhoi twenty-seven,'
  af_anapavityazevo='Anapa'; af_krasnodarcenter='Krasnodar Center'; af_novorossiysk='Novorossiysk'
  af_krymsk='Krymsk'; af_maykopkhanskaya='Maykop'; af_gelendzhik='Gelendzhik'; af_sochiadler='Sochi'
  af_krasnodarpashkovsky='Krasnodar Pashkovsky'; af_sukhumibabushara='Sukhumi'; af_gudauta='Gudauta'
  af_batumi='Batumi'; af_senakikolkhi='Senaki'; af_kobuleti='Kobuleti'; af_kutaisi='Kutaisi'
  af_mineralnyevody='Mineralnye Vody'; af_nalchik='Nalchik'; af_mozdok='Mozdok'
  af_tbilisilochini='Tbilisi'; af_soganlug='Soganlug'; af_vaziani='Vaziani'; af_beslan='Beslan'
}

New-Item -ItemType Directory -Force $OutDir | Out-Null
$dir = (Resolve-Path $OutDir).Path
$inv = [Globalization.CultureInfo]::InvariantCulture
$lua = New-Object System.Text.StringBuilder
[void]$lua.AppendLine('DynSEAD_VOICE = { clips = {')
foreach ($k in $clips.Keys) {
  $path = Join-Path $dir "ov_$k.wav"
  $synth.SetOutputToWaveFile($path, $fmt)
  $synth.Speak($clips[$k])
  $synth.SetOutputToNull()
  $dur = ((Get-Item $path).Length - 44) / (22050 * 2)
  [void]$lua.AppendLine(('  ["{0}"] = {1},' -f $k, [math]::Round($dur, 3).ToString($inv)))
}
[void]$lua.AppendLine('} }')
[IO.File]::WriteAllText((Join-Path $dir 'DynSEAD_voice.lua'), $lua.ToString(), (New-Object Text.UTF8Encoding $false))

$zip = "$dir.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path (Join-Path $dir '*') -DestinationPath $zip
Write-Host ""
Write-Host "Fertig: $($clips.Count) Bausteine in $dir"
Write-Host "Zum Hochladen: $zip"
Write-Host "Probe hören:   start '$dir\ov_popup.wav'"
