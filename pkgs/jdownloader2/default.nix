{
  lib,
  stdenv,
  writeShellApplication,
  jre,
  wget,
  ffmpeg,
  makeDesktopItem,
}:

let
  # The wrapper script that handles the mutable nature of JDownloader
  launcher = writeShellApplication {
    name = "jdownloader2";
    runtimeInputs = [
      jre
      wget
      ffmpeg
    ];
    text = ''
      # Fix for blank Java windows on some Wayland compositors
      export _JAVA_AWT_WM_NONREPARENTING=1

      JD_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/jdownloader2"
      JD_JAR="$JD_DIR/JDownloader.jar"

      mkdir -p "$JD_DIR"

      if [ ! -f "$JD_JAR" ]; then
        echo "Fetching the JDownloader2 base jar..."
        wget -O "$JD_JAR" "http://installer.jdownloader.org/JDownloader.jar"
      fi

      # JDownloader must run in its own directory to update itself natively
      cd "$JD_DIR"
      exec java -jar "$JD_JAR" "$@"
    '';
  };

  # Create a desktop entry for system GUI integration
  desktopItem = makeDesktopItem {
    name = "JDownloader2";
    desktopName = "JDownloader 2";
    exec = "jdownloader2";
    comment = "Download Manager";
    categories = [
      "Network"
      "FileTransfer"
    ];
    startupWMClass = "JDownloader";
  };

in
stdenv.mkDerivation {
  pname = "jdownloader2";
  version = "latest";

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin $out/share/applications

    # Link the launcher script
    ln -s ${launcher}/bin/jdownloader2 $out/bin/jdownloader2

    # Link the desktop file
    ln -s ${desktopItem}/share/applications/* $out/share/applications/
  '';
}
