!include "MUI2.nsh"

!define APP_NAME "TenMu"
!define APP_PACKAGE "TenMu"
!define APP_VERSION "1.0.2"
!define APP_BUILD "3"
!define APP_EXE "tenmu.exe"
!define INSTALL_DIR "$PROGRAMFILES64\TenMu"
!define PROTOCOL_NAME "tenmu"
!define PROTOCOL_DESC "URL:TenMu Protocol"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

Name "${APP_NAME} ${APP_VERSION}"
OutFile "TenMu-Setup-${APP_VERSION}.exe"
InstallDir "$PROGRAMFILES64\TenMu"
ShowInstDetails show
RequestExecutionLevel admin

Section "MainSection" SEC01
  SetOutPath "${INSTALL_DIR}"
  File /r "C:\Users\CG\Videos\Coding\tenmuv1.0\build\windows\x64\runner\Release\*.*"

  ; Buat shortcut di Start Menu
  CreateShortCut "$SMPROGRAMS\${APP_NAME}.lnk" "${INSTALL_DIR}\${APP_EXE}"

  ; Buat shortcut di Desktop
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "${INSTALL_DIR}\${APP_EXE}"

  ; Uninstaller
  WriteUninstaller "${INSTALL_DIR}\Uninstall.exe"
SectionEnd

Section "Uninstall"
  ; Hapus registrasi protokol
  DeleteRegKey HKCR "${PROTOCOL_NAME}\shell\open\command"
  DeleteRegKey HKCR "${PROTOCOL_NAME}\DefaultIcon"
  DeleteRegKey HKCR "${PROTOCOL_NAME}\shell"
  DeleteRegKey HKCR "${PROTOCOL_NAME}"

  ; Hapus shortcut
  Delete "$SMPROGRAMS\${APP_NAME}.lnk"
  Delete "$DESKTOP\${APP_NAME}.lnk"

  ; Hapus file instalasi
  Delete "${INSTALL_DIR}\*.*"
  RMDir "${INSTALL_DIR}"
SectionEnd
