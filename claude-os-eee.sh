#!/usr/bin/env bash
# ClaudeOS – Debian 12 (32-bit) live ISO with a Claude-styled XFCE desktop (cream + clay).
#
#   ./claudeos-eee.sh build   build the ISO (run on Debian/Ubuntu, needs sudo, ~10 GB free)
#   ./claudeos-eee.sh vm      create and start a VirtualBox VM from that ISO
#
# Not tested end to end: expect to tweak package names or paths on first run.
set -euo pipefail

TOP="$PWD"
WORK="$TOP/claudeos-build"
CHR="$WORK/config/includes.chroot"
ISO="$TOP/claudeos.iso"

build() {
  sudo apt-get update
  sudo apt-get install -y live-build debian-archive-keyring
  mkdir -p "$WORK"; cd "$WORK"

  lb config --distribution bookworm --architectures i386 --linux-flavours 686-pae \
    --binary-images iso-hybrid --debian-installer none --memtest none \
    --archive-areas "main contrib non-free-firmware" \
    --iso-application ClaudeOS --iso-volume ClaudeOS \
    --bootappend-live "boot=live components username=claude hostname=claudeos quiet splash"

  mkdir -p config/package-lists
  cat > config/package-lists/claudeos.list.chroot <<'EOF'
xorg
xfce4
xfce4-terminal
thunar
alsa-utils
pulseaudio
firmware-misc-nonfree
firmware-atheros
lightdm
lightdm-gtk-greeter
plank
falkon
fonts-inter
fonts-lora
librsvg2-common
network-manager-gnome
EOF

  mkdir -p "$CHR/usr/share/backgrounds" "$CHR/usr/share/applications" \
           "$CHR/usr/share/icons/hicolor/scalable/apps" "$CHR/usr/local/bin" \
           "$CHR/etc/lightdm" "$CHR/etc/skel/.config/gtk-3.0" \
           "$CHR/etc/skel/.config/autostart" "$CHR/etc/skel/.config/plank/dock1/launchers" \
           "$CHR/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"

  # Wallpaper: warm gradient with a large spark in the corner
  cat > "$CHR/usr/share/backgrounds/claudeos.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080">
<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F3EDE2"/><stop offset="1" stop-color="#E2D3BF"/></linearGradient></defs>
<rect width="1920" height="1080" fill="url(#g)"/>
<g transform="translate(1520 780)" stroke="#CC785C" stroke-opacity=".3" stroke-width="22" stroke-linecap="round" fill="none">
<path d="M0 0V-340"/><path d="M0 0V-210" transform="rotate(36)"/><path d="M0 0V-300" transform="rotate(72)"/>
<path d="M0 0V-230" transform="rotate(108)"/><path d="M0 0V-330" transform="rotate(144)"/><path d="M0 0V-200" transform="rotate(180)"/>
<path d="M0 0V-320" transform="rotate(216)"/><path d="M0 0V-240" transform="rotate(252)"/><path d="M0 0V-310" transform="rotate(288)"/>
<path d="M0 0V-220" transform="rotate(324)"/></g></svg>
EOF

  # App icon for the Claude launcher
  cat > "$CHR/usr/share/icons/hicolor/scalable/apps/claudeos-spark.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect width="24" height="24" rx="7" fill="#CC785C"/>
<g fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round" transform="translate(12 12) scale(.62) translate(-12 -12)">
<path d="M12 12V2.5"/><path d="M12 12V5" transform="rotate(36 12 12)"/><path d="M12 12V3.4" transform="rotate(72 12 12)"/>
<path d="M12 12V4.8" transform="rotate(108 12 12)"/><path d="M12 12V2.8" transform="rotate(144 12 12)"/><path d="M12 12V5.4" transform="rotate(180 12 12)"/>
<path d="M12 12V3" transform="rotate(216 12 12)"/><path d="M12 12V4.6" transform="rotate(252 12 12)"/><path d="M12 12V3.2" transform="rotate(288 12 12)"/>
<path d="M12 12V5" transform="rotate(324 12 12)"/></g></svg>
EOF

  # Claude as a desktop app (the web app in its own window; sign in with your account)
  cat > "$CHR/usr/share/applications/claude.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Claude
Exec=falkon https://claude.ai
Icon=claudeos-spark
Categories=Network;Utility;
EOF

  # Colors: cream surfaces, clay accent (named colors the Adwaita GTK3 theme reads)
  cat > "$CHR/etc/skel/.config/gtk-3.0/gtk.css" <<'EOF'
@define-color theme_bg_color #FAF9F5;
@define-color theme_base_color #FFFFFF;
@define-color theme_fg_color #1F1E1D;
@define-color theme_text_color #1F1E1D;
@define-color theme_selected_bg_color #CC785C;
@define-color theme_selected_fg_color #FFFFFF;
@define-color borders rgba(31,30,29,0.14);
* { border-radius: 10px; }
EOF

  cat > "$CHR/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Adwaita"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Inter 10"/>
  </property>
</channel>
EOF

  cat > "$CHR/etc/lightdm/lightdm-gtk-greeter.conf" <<'EOF'
[greeter]
background=#EFE9DD
theme-name=Adwaita
font-name=Inter 11
EOF

  # Dock (Plank) with Claude first; wallpaper applied on login (monitor names differ per VM)
  for item in claude:claude falkon:org.kde.falkon thunar:thunar xfce4-terminal:xfce4-terminal; do
    printf '[PlankDockItemPreferences]\nLauncher=file:///usr/share/applications/%s.desktop\n' "${item#*:}" \
      > "$CHR/etc/skel/.config/plank/dock1/launchers/${item%%:*}.dockitem"
  done

  cat > "$CHR/usr/local/bin/claudeos-wallpaper" <<'EOF'
#!/bin/sh
sleep 3
for p in $(xfconf-query -c xfce4-desktop -l | grep last-image); do
  xfconf-query -c xfce4-desktop -p "$p" -s /usr/share/backgrounds/claudeos.svg
done
EOF
  chmod +x "$CHR/usr/local/bin/claudeos-wallpaper"

  printf '[Desktop Entry]\nType=Application\nName=Plank\nExec=plank\n' > "$CHR/etc/skel/.config/autostart/plank.desktop"
  printf '[Desktop Entry]\nType=Application\nName=ClaudeOS wallpaper\nExec=/usr/local/bin/claudeos-wallpaper\n' > "$CHR/etc/skel/.config/autostart/claudeos-wallpaper.desktop"

  sudo lb build 2>&1 | tee build.log
  mv live-image-i386.hybrid.iso "$ISO"
  echo "Done: $ISO  (live login: claude / live)"
}

vm() {
  [ -f "$ISO" ] || { echo "Missing $ISO – run './claudeos-eee.sh build' first"; exit 1; }
  VBoxManage createvm --name ClaudeOS --ostype Debian --register
  VBoxManage modifyvm ClaudeOS --memory 4096 --cpus 2 --vram 128 \
    --graphicscontroller vmsvga --nic1 nat --clipboard-mode bidirectional
  VBoxManage storagectl ClaudeOS --name SATA --add sata
  VBoxManage storageattach ClaudeOS --storagectl SATA --port 0 --device 0 \
    --type dvddrive --medium "$ISO"
  VBoxManage startvm ClaudeOS
}

case "${1:-}" in
  build) build ;;
  vm)    vm ;;
  *)     echo "Usage: $0 build | vm"; exit 1 ;;
esac
