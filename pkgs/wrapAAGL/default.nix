{
  cabextract,
  libunwind,
  gnutls,
  gst_all_1,
  mangohud,
  callPackage,
  symlinkJoin,
  writeShellScriptBin,
  xdelta,
  stdenv,
  makeDesktopItem,
  nss_latest,
  git,
  p7zip,
  gamescope,
  unzip,
  unwrapped ? null,
  binName ? "",
  packageName ? "",
  desktopName ? "",
  meta ? {},
}:
let
  fakePkExec = writeShellScriptBin "pkexec" ''
    declare -a final
    for value in "$@"; do
      final+=("$value")
    done
    exec "''${final[@]}"
  '';

  # TODO: custom FHS env instead of using steam-run
  steam-run-custom = (callPackage ./fhsenv.nix {
      extraPkgs = _p: [cabextract gamescope git gnutls mangohud nss_latest p7zip xdelta unzip];
      extraLibraries = _p: [
        libunwind
      ] ++ (with gst_all_1; [
        # Needed for HSR cutscenes.
        gstreamer

        # Common plugins like "filesrc" to combine within e.g. gst-launch
        gst-plugins-base
        # Specialized plugins separated by quality
        gst-plugins-good
        gst-plugins-bad
        gst-plugins-ugly
        # Plugins to reuse ffmpeg to play almost every video format
        gst-libav
        # Support the Video Audio (Hardware) Acceleration API
        gst-vaapi
      ]);
      extraProfile = ''
        export PATH=${fakePkExec}/bin:$PATH
      '';
  }).passthru.run;

  wrapper = writeShellScriptBin binName ''
    ${steam-run-custom}/bin/steam-run ${unwrapped}/bin/${binName} "$@"
  '';

  icon = stdenv.mkDerivation {
    name = "${binName}-icon";
    buildCommand = let
      iconPath =
        if unwrapped.passthru.customIcon != null
        then unwrapped.passthru.customIcon
        else "${unwrapped.src}/assets/images/icon.png";
    in ''
      mkdir -p $out/share/pixmaps
      cp ${iconPath} $out/share/pixmaps/${packageName}.png
    '';
  };

  desktopEntry = makeDesktopItem {
    name = binName;
    inherit desktopName;
    genericName = desktopName;
    exec = "${wrapper}/bin/${binName}";
    icon = packageName;
    categories = ["Game"];
    startupWMClass = packageName;
    startupNotify = true;
  };
in
  symlinkJoin {
    inherit unwrapped meta;
    inherit (unwrapped) pname version name;
    paths = [icon desktopEntry wrapper];

    passthru = {
      inherit icon desktopEntry wrapper;
    };
  }
