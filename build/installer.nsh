; Custom NSIS script for enso man
; Register enso:// URL scheme

!macro customInstall
  ; Register URL protocol
  WriteRegStr HKCU "Software\Classes\enso" "" "URL:enso man Protocol"
  WriteRegStr HKCU "Software\Classes\enso" "URL Protocol" ""
  WriteRegStr HKCU "Software\Classes\enso\shell\open\command" "" '"$INSTDIR\enso-man.exe" "%1"'
!macroend

!macro customUnInstall
  ; Remove URL protocol registration
  DeleteRegKey HKCU "Software\Classes\enso"
!macroend
