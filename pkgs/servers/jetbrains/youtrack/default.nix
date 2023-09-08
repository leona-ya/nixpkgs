{ lib, stdenv, fetchurl, fetchzip, makeWrapper, jdk17, p7zip, gawk, baseStatePath ? "/var/lib/youtrack" }:
let
  meta = with lib; {
    description = "Issue tracking and project management tool for developers";
    maintainers = teams.serokell.members ++ [ lib.maintainers.leona ];
    sourceProvenance = with sourceTypes; [ binaryBytecode ];
    # https://www.jetbrains.com/youtrack/buy/license.html
    license = licenses.unfree;
  };
in {
  # We use the old YouTrack packaing still for 2022.3, because changing would
  # change the data structure.
  youtrack_2022_3 = stdenv.mkDerivation rec {
    pname = "youtrack";
    version = "2022.3.65371";
    baseVersion = "2022.3";

    jar = fetchurl {
      url = "https://download.jetbrains.com/charisma/${pname}-${version}.jar";
      sha256 = "sha256-NQKWmKEq5ljUXd64zY27Nj8TU+uLdA37chbFVdmwjNs=";
    };

    nativeBuildInputs = [ makeWrapper ];

    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      makeWrapper ${jdk17}/bin/java $out/bin/youtrack \
        --add-flags "\$YOUTRACK_JVM_OPTS -jar $jar" \
        --prefix PATH : "${lib.makeBinPath [ gawk ]}" \
        --set JRE_HOME ${jdk17}
      runHook postInstall
    '';

    inherit meta;
  };
}
