{ stdenv, fetchurl, python3, pkgs }:

let
  version = "0.7.0";
  src = fetchurl {
    url = "https://github.com/JoinMarket-Org/joinmarket-clientserver/archive/v${version}.tar.gz";
    sha256 = "0ha73n3y5lykyj3pl97a619sxd2zz0lb32s5c61wm0l1h47v9l1g";
  };

  python = python3.override {
    packageOverrides = self: super: let
      joinmarketPkg = pkg: self.callPackage pkg { inherit version src; };
    in {
      joinmarketbase = joinmarketPkg ./jmbase;
      joinmarketclient = joinmarketPkg ./jmclient;
      joinmarketbitcoin = joinmarketPkg ./jmbitcoin;
      joinmarketdaemon = joinmarketPkg ./jmdaemon;

      chromalog = self.callPackage ./chromalog {};
      bencoderpyx = self.callPackage ./bencoderpyx {};
      coincurve = self.callPackage ./coincurve {};
      urldecode = self.callPackage ./urldecode {};
      python-bitcointx = self.callPackage ./python-bitcointx {};
      secp256k1 = self.callPackage ./secp256k1 {};
    };
  };

  runtimePackages = with python.pkgs; [
    joinmarketbase
    joinmarketclient
    joinmarketbitcoin
    joinmarketdaemon
  ];

  genwallet = pkgs.writeScriptBin "genwallet" (builtins.readFile ./genwallet/genwallet.py);

  pythonEnv = python.withPackages (_: runtimePackages);
in
stdenv.mkDerivation {
  pname = "joinmarket";
  inherit version src genwallet;

  buildInputs = [ pythonEnv ];

  buildCommand = ''
    mkdir -p $src-unpacked $out/bin
    tar xzf $src --strip 1 -C $src-unpacked

    # add-utxo.py -> bin/jm-add-utxo
    cpBin() {
      cp $src-unpacked/scripts/$1 $out/bin/jm-''${1%.py}
    }
    cp $src-unpacked/scripts/joinmarketd.py $out/bin/joinmarketd
    cpBin add-utxo.py
    cpBin convert_old_wallet.py
    cpBin receive-payjoin.py
    cpBin sendpayment.py
    cpBin sendtomany.py
    cpBin tumbler.py
    cpBin wallet-tool.py
    cpBin yg-privacyenhanced.py
    cp $genwallet/bin/genwallet $out/bin/jm-genwallet

    chmod +x -R $out/bin
    patchShebangs $out/bin
  '';

  passthru = {
      inherit python runtimePackages pythonEnv;
  };
}
