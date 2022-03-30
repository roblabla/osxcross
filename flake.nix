{
  description = "OSXCross";

  nixConfig.bash-prompt = "\[\\u@osxcross:\\w\]$ ";

  inputs = {
    nixpkgs.url      = "github:nixos/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.libtapi = nixpkgs.legacyPackages.x86_64-linux.callPackage ./libtapi.nix { };
    packages.x86_64-linux.cctools = nixpkgs.legacyPackages.x86_64-linux.callPackage ./cctools.nix { libtapi = self.packages.x86_64-linux.libtapi; darwin_target = "darwin20.4"; };
    packages.x86_64-linux.osxcross-wrapper = nixpkgs.legacyPackages.x86_64-linux.stdenv.mkDerivation {
      name = "osxcross-wrapper";
      version = "";
      src = nixpkgs.legacyPackages.x86_64-linux.fetchFromGitHub {
        owner = "tpoechtrager";
        repo = "osxcross";
        rev = "be2b79f444aa0b43b8695a4fb7b920bf49ecc01c";
        sha256 = "sha256-3/dXHrzuLFXFL2h+P4hpCN1ejCp0RIcoZVISdFv9CVs=";
      } + "/wrapper";

      patches = [
        ./add-isystem.patch
        ./set_default_target.patch
        ./add-clang-intrinsic-path.patch
        ./ignore-target-arg.patch
      ];

      makeFlags = [ "LINKER_VERSION=609" ];

      installPhase = ''
        runHook preInstall

        install -D wrapper $out/bin/wrapper

        runHook postInstall
      '';
    };
    packages.x86_64-linux.macossdk_11_3 = nixpkgs.legacyPackages.x86_64-linux.fetchzip {
      url = "https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/MacOSX11.3.sdk.tar.xz";
      sha256 = "sha256-BoFWhRSHaD0j3dzDOFtGJ6DiRrdzMJhkjxztxCluFKo=";
    };

    packages.x86_64-linux.toolchain = self.lib.toolchain { llvmPackages = nixpkgs.legacyPackages.x86_64-linux.llvmPackages_13; };

    lib.toolchain = { llvmPackages }: nixpkgs.legacyPackages.x86_64-linux.runCommand "osxcross-toolchain" {
      buildInputs = [ nixpkgs.legacyPackages.x86_64-linux.makeWrapper ];
    } ''
      TARGET=darwin20.4
      mkdir -p $out/SDK
      ln -s ${self.packages.x86_64-linux.macossdk_11_3} $out/SDK/MacOSX11.3.sdk
      SDK_ROOT=$out/SDK/MacOSX11.3.sdk

      function create_wrapper_link
      {
        # arg 1:
        #  program name
        # arg 2:
        #  1: create a standalone link and links with the target triple prefix
        #  2: create links with target triple prefix and shortcut links such
        #     as o32, o64, ...
        #
        # example:
        #  create_wrapper_link osxcross 1
        # creates the following symlinks:
        #  -> osxcross
        #  -> x86_64-apple-darwinXX-osxcross
        #  -> x86_64h-apple-darwinXX-osxcross

        if [ $# -ge 2 ] && [ $2 -eq 1 ]; then
          makeWrapper "${self.packages.x86_64-linux.osxcross-wrapper}/bin/wrapper" \
            "$out/bin/$1" --argv0 "$1" --prefix PATH : $out/bin --set OSXCROSS_CLANG_INTRINSIC_PATH "${llvmPackages.clang-unwrapped.lib}/lib/clang/" --set OSXCROSS_TARGET "$TARGET" --set OSXCROSS_SDKROOT "$SDK_ROOT" --prefix PATH : "${llvmPackages.clang-unwrapped}/bin/"
        fi

        makeWrapper "${self.packages.x86_64-linux.osxcross-wrapper}/bin/wrapper" \
          "$out/bin/x86_64-apple-$TARGET-$1" --argv0 "x86_64-apple-$TARGET-$1" --prefix PATH : $out/bin --set OSXCROSS_CLANG_INTRINSIC_PATH "${llvmPackages.clang-unwrapped.lib}/lib/clang/" --set OSXCROSS_TARGET "$TARGET" --set OSXCROSS_SDKROOT "$SDK_ROOT" --prefix PATH : "${llvmPackages.clang-unwrapped}/bin/"

        if ([[ $1 != gcc* ]] && [[ $1 != g++* ]] && [[ $1 != *gstdc++ ]]); then
          makeWrapper "${self.packages.x86_64-linux.osxcross-wrapper}/bin/wrapper" \
            "$out/bin/x86_64h-apple-$TARGET-$1" --argv0 "x86_64h-apple-$TARGET-$1" --prefix PATH : $out/bin --set OSXCROSS_CLANG_INTRINSIC_PATH "${llvmPackages.clang-unwrapped.lib}/lib/clang/" --set OSXCROSS_TARGET "$TARGET" --set OSXCROSS_SDKROOT "$SDK_ROOT" --prefix PATH : "${llvmPackages.clang-unwrapped}/bin/"
      
          makeWrapper "${self.packages.x86_64-linux.osxcross-wrapper}/bin/wrapper" \
            "$out/bin/aarch64-apple-$TARGET-$1" --argv0 "aarch64-apple-$TARGET-$1" --prefix PATH : $out/bin --set OSXCROSS_CLANG_INTRINSIC_PATH "${llvmPackages.clang-unwrapped.lib}/lib/clang/" --set OSXCROSS_TARGET "$TARGET" --set OSXCROSS_SDKROOT "$SDK_ROOT" --prefix PATH : "${llvmPackages.clang-unwrapped}/bin/"
          makeWrapper "${self.packages.x86_64-linux.osxcross-wrapper}/bin/wrapper" \
            "$out/bin/arm64-apple-$TARGET-$1" --argv0 "arm64-apple-$TARGET-$1" --prefix PATH : $out/bin --set OSXCROSS_CLANG_INTRINSIC_PATH "${llvmPackages.clang-unwrapped.lib}/lib/clang/" --set OSXCROSS_TARGET "$TARGET" --set OSXCROSS_SDKROOT "$SDK_ROOT" --prefix PATH : "${llvmPackages.clang-unwrapped}/bin/"
          makeWrapper "${self.packages.x86_64-linux.osxcross-wrapper}/bin/wrapper" \
            "$out/bin/arm64e-apple-$TARGET-$1" --argv0 "arm64e-apple-$TARGET-$1" --prefix PATH : $out/bin --set OSXCROSS_CLANG_INTRINSIC_PATH "${llvmPackages.clang-unwrapped.lib}/lib/clang/" --set OSXCROSS_TARGET "$TARGET" --set OSXCROSS_SDKROOT "$SDK_ROOT" --prefix PATH : "${llvmPackages.clang-unwrapped}/bin/"
        fi
      
        if [ $# -ge 2 ] && [ $2 -eq 2 ]; then
          makeWrapper "${self.packages.x86_64-linux.osxcross-wrapper}/bin/wrapper" \
            "$out/bin/o64-$1" --argv0 "o64-$1" --prefix PATH : $out/bin --set OSXCROSS_CLANG_INTRINSIC_PATH "${llvmPackages.clang-unwrapped.lib}/lib/clang/" --set OSXCROSS_TARGET "$TARGET" --set OSXCROSS_SDKROOT "$SDK_ROOT" --prefix PATH : "${llvmPackages.clang-unwrapped}/bin/"
      
          if ([[ $1 != gcc* ]] && [[ $1 != g++* ]] && [[ $1 != *gstdc++ ]]); then
            makeWrapper "${self.packages.x86_64-linux.osxcross-wrapper}/bin/wrapper" \
              "$out/bin/o64h-$1" --argv0 "o64h-$1" --prefix PATH : $out/bin --set OSXCROSS_CLANG_INTRINSIC_PATH "${llvmPackages.clang-unwrapped.lib}/lib/clang/" --set OSXCROSS_TARGET "$TARGET" --set OSXCROSS_SDKROOT "$SDK_ROOT" --prefix PATH : "${llvmPackages.clang-unwrapped}/bin/"
          fi
      
          makeWrapper "${self.packages.x86_64-linux.osxcross-wrapper}/bin/wrapper" \
            "$out/bin/oa64-$1" --argv0 "oa64-$1" --prefix PATH : $out/bin --set OSXCROSS_CLANG_INTRINSIC_PATH "${llvmPackages.clang-unwrapped.lib}/lib/clang/" --set OSXCROSS_TARGET "$TARGET" --set OSXCROSS_SDKROOT "$SDK_ROOT" --prefix PATH : "${llvmPackages.clang-unwrapped}/bin/"
          makeWrapper "${self.packages.x86_64-linux.osxcross-wrapper}/bin/wrapper" \
            "$out/bin/oa64e-$1" --argv0 "oa64e-$1" --prefix PATH : $out/bin --set OSXCROSS_CLANG_INTRINSIC_PATH "${llvmPackages.clang-unwrapped.lib}/lib/clang/" --set OSXCROSS_TARGET "$TARGET" --set OSXCROSS_SDKROOT "$SDK_ROOT" --prefix PATH : "${llvmPackages.clang-unwrapped}/bin/"
        fi
      }


      create_wrapper_link clang 2
      create_wrapper_link clang++ 2
      create_wrapper_link clang++-libc++ 2
      create_wrapper_link clang++-stdc++ 2
      create_wrapper_link clang++-gstdc++ 2
      create_wrapper_link cc
      create_wrapper_link c++
      
      create_wrapper_link osxcross 1
      create_wrapper_link osxcross-conf 1
      create_wrapper_link osxcross-env 1
      create_wrapper_link osxcross-cmp 1
      create_wrapper_link osxcross-man 1
      create_wrapper_link pkg-config

      create_wrapper_link sw_vers 1

      create_wrapper_link xcrun 1
      create_wrapper_link xcodebuild 1

      for arch in "x86_64" "aarch64" "arm64" "arm64e" ; do
        for CCTOOL in ${self.packages.x86_64-linux.cctools}/bin/*; do
          CCTOOL_FNAME=$(basename $CCTOOL)
          ln -s "$CCTOOL" "$out/bin/$(echo "$CCTOOL_FNAME" | sed "s/x86_64/$arch/g")"
        done
      done
    '';
  };
}
