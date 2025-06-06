#!/usr/bin/env zsh

# vim:filetype=zsh syntax=zsh tabstop=2 shiftwidth=2 softtabstop=2 expandtab autoindent fileencoding=utf-8

# file location: <anywhere; but advisable in the PATH>

# This script will export or import the settings from the location specified in the target directory defined down below. You can backup the files to any cloud storage and retrieve into the new laptop to then get back all settings as per the original machine. The only word of caution is to use it with the same OS version (I haven't tried in any situations where the old and new machines had different OS versions - so I cannot guarantee if that might break the system in any way)

# A trick to find the name of the app:
# Run `defaults read` in an empty window of a terminal app, then use the search functionality to search for a known word related to that app (like eg app visible name, author, some setting that's unique to that app, etc). Once you find this, trace back to the left-most child (1st of the top-level parent) in the printed JSON to then get the real unique name of the app where its settings are stored. Please note that one app might have multiple such groups / names at the top-level (for eg zoom). If this is the case, you will need to capture each name individually.

type is_non_zero_string &> /dev/null 2>&1 || source "${HOME}/.zshrc"

usage() {
  echo "$(red 'Usage'): $(yellow "${1} <e/i>")"
  echo "  $(yellow 'e')  --> Export from [old] system"
  echo "  $(yellow 'i')  --> Import into [new] system"
  exit 1
}

PERSONAL_CONFIGS_DIR=$DOTFILES_DIR/settings

[ $# -ne 1 ] && usage "${0}"

! is_non_zero_string "${PERSONAL_CONFIGS_DIR}" && warn "Env var 'PERSONAL_CONFIGS_DIR' is not defined; Aborting!!!" && return

local target_dir="${PERSONAL_CONFIGS_DIR}/defaults"
ensure_dir_exists "${target_dir}"

case "${1}" in
  "e" )
    operation='export'
    git_cleanup="git -C '${HOME}' rm -rf '${target_dir}'/*"
    git_stage="git -C '${HOME}' add '${target_dir}'"
    ;;
  "i" )
    operation='import'
    # shellcheck disable=SC2089
    git_cleanup="warn 'Skipping git cleanup'"
    # shellcheck disable=SC2089
    git_stage="warn 'Skipping git staging'"
    ;;
  * )
    echo "Unknown value entered: '${1}'"
    usage "${0}"
    ;;
esac

# echo "git_cleanup: '${git_cleanup}'"
# echo "git_stage: '${git_stage}'"

# shellcheck disable=SC2090
eval "${git_cleanup}"
ensure_dir_exists "${target_dir}"

# TODO: Need to add:
# PDFgear

# Note: A simple trick to find these names is to run `\ls -1 ~/Library/Preferences/*` in the command-line
app_array=(
  'app.zen-browser.zen'
  'ch.protonvpn.mac'
  'com.0804Team.KeyClu'
  'com.abhishek.Clocker'
  'com.apphousekitchen.aldente-pro'
  'com.apple.Accessibility-Settings.extension'
  'com.apple.Accessibility.Assets'
  'com.apple.accessibility.heard'
  'com.apple.Accessibility'
  'com.apple.AccessibilityHearingNearby'
  'com.apple.AccessibilityVisualsAgent'
  'com.apple.ActivityMonitor'
  'com.apple.AppleMultitouchMouse'
  'com.apple.AppleMultitouchTrackpad'
  'com.apple.assistant.backedup'
  'com.apple.assistant.support'
  'com.apple.assistant'
  'com.apple.assistantd'
  'com.apple.backgroundtaskmanagement.agent'
  'com.apple.Battery-Settings.extension'
  'com.apple.BatteryCenter.BatteryWidget'
  'com.apple.BezelServices'
  'com.apple.biomesyncd'
  'com.apple.bird'
  'com.apple.BluetoothSettings'
  'com.apple.bluetoothuserd'
  'com.apple.bookstoreagent'
  'com.apple.businessservicesd'
  'com.apple.commcenter.callservices'
  'com.apple.commcenter.data'
  'com.apple.commcenter'
  'com.apple.configurationprofiles.user'
  'com.apple.contactsd'
  'com.apple.contextsync.subscriptions'
  'com.apple.ControlCenter-Settings.extension'
  'com.apple.controlcenter.helper'
  'com.apple.controlcenter'
  'com.apple.coreauthd'
  'com.apple.coreservices.UASharedPasteboardProgressUI'
  'com.apple.coreservices.uiagent'
  'com.apple.coreservices.useractivityd.dynamicuseractivites'
  'com.apple.coreservices.useractivityd'
  'com.apple.corespotlightui'
  'com.apple.cseventlistener'
  'com.apple.dataaccess.babysitter'
  'com.apple.dataaccess.dataaccessd'
  'com.apple.Date-Time-Settings.extension'
  'com.apple.desktopservices'
  'com.apple.diagnosticextensionsd'
  'com.apple.DictionaryServices'
  'com.apple.DiskImageMounter'
  'com.apple.Displays-Settings.extension'
  'com.apple.dock.external.extra.arm64'
  'com.apple.dock.extra'
  'com.apple.dock'
  'com.apple.donotdisturbd'
  'com.apple.driver.AppleBluetoothMultitouch.mouse'
  'com.apple.driver.AppleBluetoothMultitouch.trackpad'
  'com.apple.driver.AppleHIDMouse'
  'com.apple.dt.Xcode'
  'com.apple.dt.xcodebuild'
  'com.apple.eap8021x.eaptlstrust'
  'com.apple.EmojiPreferences'
  'com.apple.ExtensionsPreferences.ShareMenu'
  'com.apple.fileproviderd'
  'com.apple.finder'
  'com.apple.findmy.findmylocateagent'
  'com.apple.findmy.fmfcore.notbackedup'
  'com.apple.findmy.fmipcore.notbackedup'
  'com.apple.findmy'
  'com.apple.FolderActionsDispatcher'
  'com.apple.frameworks.diskimages.diuiagent'
  'com.apple.gamecenter'
  'com.apple.gamed'
  'com.apple.gms.availability'
  'com.apple.helpd'
  'com.apple.homed.notbackedup'
  'com.apple.homed'
  'com.apple.homeenergyd'
  'com.apple.icloud.fmfd.notbackedup'
  'com.apple.icloud.fmfd'
  'com.apple.icloud.gm'
  'com.apple.icloud.searchpartyuseragent'
  'com.apple.iclouddrive.features'
  'com.apple.iCloudHelper'
  'com.apple.iCloudNotificationAgent'
  'com.apple.identityservicesd'
  'com.apple.ids.deviceproperties'
  'com.apple.ids.subservices'
  'com.apple.ids'
  'com.apple.imagecapture'
  'com.apple.imagent'
  'com.apple.imdpersistence.IMDPersistenceAgent'
  'com.apple.imessage.bag'
  'com.apple.imessage'
  'com.apple.inputAnalytics.IASGenmojiAnalyzer'
  'com.apple.inputAnalytics.IASSRAnalyzer'
  'com.apple.inputAnalytics.IASWTAnalyzer'
  'com.apple.inputAnalytics.serverStats'
  'com.apple.inputmethod.ironwood'
  'com.apple.intents.intents-helper'
  'com.apple.internal.ck'
  'com.apple.ipTelephony'
  'com.apple.Keyboard-Settings.extension'
  'com.apple.keyboardservicesd'
  'com.apple.keychainaccess'
  'com.apple.knowledge-agent'
  'com.apple.LocalAuthentication.UIAgent'
  'com.apple.LocalAuthenticationRemoteService'
  'com.apple.Lock-Screen-Settings.extension'
  'com.apple.LoginItems-Settings.extension'
  'com.apple.loginwindow'
  'com.apple.madrid'
  'com.apple.mail'
  'com.apple.mediaanalysisd'
  'com.apple.menuextra.battery'
  'com.apple.menuextra.clock'
  'com.apple.metrickitd'
  'com.apple.mlhost'
  'com.apple.mmcs'
  'com.apple.mobiletimer'
  'com.apple.mobiletimerd'
  'com.apple.nbagent'
  'com.apple.ncprefs'
  'com.apple.Network-Settings.extension'
  'com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension'
  'com.apple.Notifications-Settings.extension'
  'com.apple.parsecd'
  'com.apple.passd.class-d'
  'com.apple.passd'
  'com.apple.PersonalAudio'
  'com.apple.photos.shareddefaults'
  'com.apple.PowerChime'
  'com.apple.PowerManagement'
  'com.apple.preferences.extensions.ShareMenu'
  'com.apple.preferences.softwareupdate'
  'com.apple.Print-Scan-Settings.extension'
  'com.apple.print.add'
  'com.apple.print.custompresets.forprinter._10_134_3_151'
  'com.apple.print.custompresets.forprinter._10_134_3_152'
  'com.apple.print.custompresets'
  'com.apple.print.daemon.printtool'
  'com.apple.print.PrintingPrefs'
  'com.apple.printcenter'
  'com.apple.proactive.PersonalizationPortrait'
  'com.apple.ProblemReporter'
  'com.apple.Profiles-Settings.extension'
  'com.apple.protectedcloudstorage.protectedcloudkeysyncing'
  'com.apple.remotedesktop'
  'com.apple.replayd'
  'com.apple.Safari'
  'com.apple.scheduler'
  'com.apple.screencapture'
  'com.apple.screencaptureui'
  'com.apple.ScreenSaver-Settings.extension'
  'com.apple.screensaver'
  'com.apple.scriptmenu'
  'com.apple.ScriptMenuApp'
  'com.apple.SecurityAgent'
  'com.apple.seeding'
  'com.apple.ServicesMenu.Services'
  'com.apple.seserviced'
  'com.apple.settings.PrivacySecurity.extension'
  'com.apple.sharedfilelist'
  'com.apple.sharingd'
  'com.apple.sociallayerd.CloudKit.ckwriter'
  'com.apple.sociallayerd'
  'com.apple.Software-Update-Settings.extension'
  'com.apple.SoftwareUpdate'
  'com.apple.SoftwareUpdateNotificationManager'
  'com.apple.sound.beep.feedback'
  'com.apple.sound.beep.flash'
  'com.apple.sound.beep.sound'
  'com.apple.spaces'
  'com.apple.SpeakSelection'
  'com.apple.speech.recognition.AppleSpeechRecognition.CustomCommands'
  'com.apple.speech.recognition.AppleSpeechRecognition.prefs'
  'com.apple.speech.SpeechDataInstallerd'
  'com.apple.SpeechRecognitionCore'
  'com.apple.spotlight.mdwrite'
  'com.apple.Spotlight'
  'com.apple.spotlightknowledge'
  'com.apple.SpotlightResources.Defaults'
  'com.apple.springing.delay'
  'com.apple.springing.enabled'
  'com.apple.StatusKitAgent'
  'com.apple.stickersd'
  'com.apple.stockholm'
  'com.apple.stocks.stockskit'
  'com.apple.stocks2'
  'com.apple.storeagent'
  'com.apple.storeuid'
  'com.apple.studentd'
  'com.apple.suggestd'
  'com.apple.suggestions'
  'com.apple.swipescrolldirection'
  'com.apple.symbolichotkeys'
  'com.apple.syncdefaultsd'
  'com.apple.systemevents'
  'com.apple.systempreferences'
  'com.apple.systemsettings.extensions'
  'com.apple.systemuiserver'
  'com.apple.talagent'
  'com.apple.Terminal'
  'com.apple.textInput.keyboardServices.textReplacement'
  'com.apple.TextInputMenu'
  'com.apple.TextInputMenuAgent'
  'com.apple.TextInputSwitcher'
  'com.apple.TextInputUI.xpc.CursorUIViewService'
  'com.apple.textkit.nsattributedstringagent'
  'com.apple.tipsd'
  'com.apple.Touch-ID-Settings.extension'
  'com.apple.Trackpad-Settings.extension'
  'com.apple.trackpad.enableSecondaryClick'
  'com.apple.trackpad.fiveFingerPinchSwipeGesture'
  'com.apple.trackpad.forceClick'
  'com.apple.trackpad.fourFingerHorizSwipeGesture'
  'com.apple.trackpad.fourFingerPinchSwipeGesture'
  'com.apple.trackpad.fourFingerVertSwipeGesture'
  'com.apple.trackpad.momentumScroll'
  'com.apple.trackpad.pinchGesture'
  'com.apple.trackpad.rotateGesture'
  'com.apple.trackpad.scaling'
  'com.apple.trackpad.scrollBehavior'
  'com.apple.trackpad.threeFingerDragGesture'
  'com.apple.trackpad.threeFingerHorizSwipeGesture'
  'com.apple.trackpad.threeFingerTapGesture'
  'com.apple.trackpad.threeFingerVertSwipeGesture'
  'com.apple.trackpad.twoFingerDoubleTapGesture'
  'com.apple.trackpad.twoFingerFromRightEdgeSwipeGesture'
  'com.apple.translationd'
  'com.apple.transparencyd'
  'com.apple.triald'
  'com.apple.TrustedPeersHelper'
  'com.apple.UnifiedAssetFramework'
  'com.apple.universalaccess'
  'com.apple.universalaccessAuthWarning'
  'com.apple.UserNotificationCenter'
  'com.apple.Users-Groups-Settings.extension'
  'com.apple.voiceservices'
  'com.apple.voicetrigger.notbackedup'
  'com.apple.voicetrigger'
  'com.apple.Wallpaper-Settings.extension'
  'com.apple.wallpaper'
  'com.apple.weather.sensitive'
  'com.apple.widgets'
  'com.apple.wifi-settings-extension'
  'com.apple.wifi.WiFiAgent'
  'com.apple.xpc.activity2'
  'com.brave.Browser.beta'
  'com.brave.Browser.nightly'
  'com.brave.Browser'
  'com.cloudflare.1dot1dot1dot1.macos'
  'com.docker.docker'
  'com.electron.ollama'
  'com.github.Electron'
  'com.google.Chrome.beta'
  'com.google.Chrome.canary'
  'com.google.Chrome'
  'com.googlecode.iterm2.private'
  'com.googlecode.iterm2'
  'com.googlecode.munki.ManagedSoftwareCenter'
  'com.jordanbaird.Ice'
  'com.lowtechguys.ZoomHider'
  'com.macpaw.site.theunarchiver'
  'com.microsoft.autoupdate.fba'
  'com.microsoft.autoupdate2'
  'com.microsoft.rdc.macos'
  'com.microsoft.shared'
  'com.microsoft.teams2.helper'
  'com.microsoft.VSCodeInsiders'
  'com.mitchellh.ghostty'
  'com.parallels.Parallels Desktop'
  'com.qtproject'
  'com.raycast.macos'
  'com.titanium.OnyX.update'
  'com.titanium.OnyX'
  'com.visualstudio.code.oss'
  'com.vscodium.VSCodiumInsiders'
  'eu.exelban.Stats'
  'familycircled'
  'info.marcel-dierkes.KeepingYouAwake'
  'io.github.keycastr'
  'io.rancherdesktop.app'
  'keybase.Electron'
  'loginwindow'
  'mbuseragent'
  'menu.nomad.DEPNotify'
  'net.freemacsoft.AppCleaner'
  'net.sourceforge.Monolingual'
  'NSGlobalDomain'
  'org.cups.PrintingPrefs'
  'org.kde.KDiff3'
  'org.keepassxc.keepassxc'
  'org.libreoffice.script'
  'org.mozilla.betterbird'
  'org.mozilla.com.zen.browser'
  'org.mozilla.firefox'
  'org.mozilla.nightly'
  'org.mozilla.thunderbird-daily'
  'org.mozilla.thunderbird'
  'screencapture'
  'sharedfilelistd'
  'us.zoom.updater.config'
  'us.zoom.updater'
  'us.zoom.xos'
  'us.zoom.ZoomAutoUpdater'
  'us.zoom.ZoomClips'
  'ZoomChat'
)

echo "Running operation: $(green "${operation}")"
for app_pref in "${app_array[@]}"; do
  echo "Processing $(cyan "${app_pref}")"
  local target_file="${target_dir}/${app_pref}.defaults"
  touch "${target_file}"
  /usr/bin/defaults "${operation}" "${app_pref}" "${target_file}"
done

# shellcheck disable=SC2090
eval "${git_stage}"

unset target_dir
unset target_file
unset app_pref
unset git_stage
unset git_cleanup
unset operation
