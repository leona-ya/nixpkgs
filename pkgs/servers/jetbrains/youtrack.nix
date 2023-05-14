{ lib, stdenv, fetchzip, makeWrapper, jdk17, p7zip, gawk, statePath ? "/var/lib/youtrack" }:

stdenv.mkDerivation rec {
  pname = "youtrack";
  version = "2023.1.9570";

  src = fetchzip {
    url = "https://download.jetbrains.com/charisma/youtrack-${version}.zip";
    sha256 = "sha256-vDwkwk15PBe1JQ3nOMZY/at5nxRYjzFbMl3JGULmdpE=";
  };

  nativeBuildInputs = [ makeWrapper p7zip ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/app
    cp -a . $out/app

    for path in "backups" "conf" "data" "logs" "temp"
    do
      rm -rf $out/app/$path
      ln -s ${statePath}/$path $out/app/$path
    done

    makeWrapper "$out/app/bin/youtrack.sh" "$out/bin/youtrack" \
      --prefix PATH : "$out/libexec/app:${lib.makeBinPath [ jdk17 gawk ]}" \
      --set FJ_JAVA_EXEC "${jdk17}/bin/java" \
      --set JRE_HOME ${jdk17}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Issue tracking and project management tool for developers";
    maintainers = teams.serokell.members ++ (with maintainers; [ leona ]);
    sourceProvenance = with sourceTypes; [ binaryBytecode ];
    # https://www.jetbrains.com/youtrack/buy/license.html
    license = licenses.unfree;
  };
}
