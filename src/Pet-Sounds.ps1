Add-Type -Path (Join-Path $PSScriptRoot 'Pet-Sounds.cs')
$script:lastSoundGesture=''
function Invoke-OrbySound {
 param([string]$Kind)
 if($script:waterPriority){return}
 if(-not $script:orbySettings.Sounds -or $script:orbySettings.Quiet){return}
 if($Kind -eq 'idle' -and ($script:avatarRenderer.MusicPlaying -or $script:orbySettings.ReducedMotion)){return}
 if($script:fullscreenHidden){return};try{[OrbyTones]::Play($Kind)}catch{Write-OrbitLog ('Sound unavailable: '+$_.Exception.Message)}
}
function Update-OrbyPetSounds {
 if(-not $script:avatarRenderer){return}
 $id=$script:avatarRenderer.ActiveId
 if($id -ne $script:lastSoundGesture){
  $script:lastSoundGesture=$id
  if($id -in @('idle_wiggle','idle_nod','idle_double_hop')){Invoke-OrbySound 'idle'}
 }
}
$window.Add_Closed({[OrbyTones]::Close()})

