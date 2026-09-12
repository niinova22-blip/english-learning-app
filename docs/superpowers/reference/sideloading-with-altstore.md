# Sideloading EnglishApp via AltStore

1. Install AltServer on Windows (https://faq.altstore.io) and run it as
   administrator. Install iTunes + iCloud from apple.com (not the
   Microsoft Store version) first — AltServer needs them for device
   communication.
2. Connect the iPhone via USB once, trust the computer, and pair it
   with AltServer (right-click the AltServer tray icon).
3. Trigger a build with the `.ipa` artifact:
   `gh workflow run app-build.yml --ref <branch> -f export_ipa=true`
4. Download the `EnglishApp-unsigned` artifact from the completed run
   (`gh run download <run-id> -n EnglishApp-unsigned`) and unzip it to
   get `EnglishApp.ipa`.
5. Right-click the AltServer tray icon → Install → select
   `EnglishApp.ipa` → sign in with your Apple ID when prompted.
6. On the iPhone: Settings → General → VPN & Device Management → trust
   the developer profile. iOS 16+: also enable Developer Mode
   (Settings → Privacy & Security → Developer Mode) and reboot if
   prompted.
7. Launch EnglishApp from the home screen.

Free Apple IDs re-sign automatically over Wi-Fi roughly every 7 days as
long as AltServer is running on a machine on the same network as the
phone (or reachable via AltServer's background refresh). If the app
stops launching, reopen AltStore on the phone to trigger a refresh, or
re-run steps 3-5.
