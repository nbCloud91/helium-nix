# Repackages upstream's signed x86_64 tarball; nothing is compiled.
# Tarball over AppImage: a plain patched binary, so Chromium's own sandbox
# doesn't nest inside appimageTools' bubblewrap FHS env.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  makeShellWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libGL,
  libgbm,
  libpulseaudio,
  libva,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  pango,
  pipewire,
  qt6,
  systemdLibs,
  widevine-cdm,
  withWidevine ? false,
  commandLineArgs ? "",
}: let
  pinned = lib.importJSON ./version.json;
in
  stdenv.mkDerivation {
    pname = "helium";
    inherit (pinned) version;

    src = fetchurl {
      url = "https://github.com/imputnet/helium-linux/releases/download/${pinned.version}/helium-${pinned.version}-x86_64_linux.tar.xz";
      inherit (pinned) hash;
    };

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
      # Shell wrapper, not binary: $NIXOS_OZONE_WL must expand at launch time.
      (wrapGAppsHook3.override {makeWrapper = makeShellWrapper;})
    ];

    buildInputs = [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libgbm
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxkbcommon
      libxrandr
      nspr
      nss
      pango
      qt6.qtbase
      systemdLibs
    ];

    dontWrapQtApps = true;
    dontWrapGApps = true;

    # Optional Qt5 theme shim; qt5 is not worth pulling in.
    autoPatchelfIgnoreMissingDeps = [
      "libQt5Core.so.5"
      "libQt5Gui.so.5"
      "libQt5Widgets.so.5"
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/opt/helium $out/bin $out/share/applications $out/share/icons/hicolor/256x256/apps
      cp -r ./* $out/opt/helium/
      cp $out/opt/helium/helium.desktop $out/share/applications/
      cp $out/opt/helium/product_logo_256.png $out/share/icons/hicolor/256x256/apps/helium.png

      ${lib.optionalString withWidevine ''
        ln -s ${widevine-cdm}/share/google/chrome/WidevineCdm $out/opt/helium/WidevineCdm
      ''}

      runHook postInstall
    '';

    # dlopen()ed at runtime, so autoPatchelf can't see them.
    # One --enable-features only: Chromium keeps the last one on the CLI, so a
    # second would silently drop VA-API decode (chrome://flags merges; CLI doesn't).
    preFixup = ''
      gappsWrapperArgs+=(
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [libGL libva pipewire libpulseaudio gtk3]}"
        --add-flags "--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+,WaylandWindowDecorations}}"
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-wayland-ime=true}}"
        --add-flags ${lib.escapeShellArg commandLineArgs}
      )
      makeWrapper $out/opt/helium/helium-wrapper $out/bin/helium "''${gappsWrapperArgs[@]}"
    '';

    meta = {
      description = "Helium browser (Chromium-based), repackaged from upstream's signed release tarball";
      homepage = "https://github.com/imputnet/helium";
      license = lib.licenses.gpl3Only;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["x86_64-linux"];
      mainProgram = "helium";
    };
  }
