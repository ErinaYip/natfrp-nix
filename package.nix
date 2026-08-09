{
  lib,
  stdenvNoCC,
  fetchurl,
  gnutar,
  zstd,
  version,
  arch,
  hash,
}:

stdenvNoCC.mkDerivation {
  pname = "natfrp-launcher";
  inherit version;

  src = fetchurl {
    url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_${arch}.tar.zst";
    inherit hash;
  };

  nativeBuildInputs = [
    gnutar
    zstd
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    tar --use-compress-program="${zstd}/bin/zstd" -xf "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 frpc "$out/bin/frpc"
    install -Dm755 natfrp-service "$out/bin/natfrp-service"
    runHook postInstall
  '';

  meta = {
    description = "SakuraFrp Launcher service binaries";
    homepage = "https://www.natfrp.com/";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "natfrp-service";
    platforms = lib.platforms.linux;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
