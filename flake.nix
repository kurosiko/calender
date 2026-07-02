{
  description = "Calender - Dart で作成したスケジュール管理アプリの Nix flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        # Dart SDK バージョン (mise.toml と nixpkgs#dart に合わせて固定)
        dartVersion = pkgs.dart.version;

        # Android SDK (APK ビルド用)
        androidsdk = (pkgs.androidenv.composeAndroidPackages {
          platformVersions = ["34"];
          buildToolsVersions = ["34.0.0"];
          includeEmulator = false;
          includeSystemImages = false;
          includeNDK = false;
          includeSources = false;
        }).androidsdk;

        # 配布物に含めるファイル/ディレクトリだけを残す。
        # テスト/debug HTML は web/dev/ 配下に隔離して除外。
        webSrc = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = path: type:
            let
              rel = pkgs.lib.removePrefix (toString ./. + "/") (toString path);
              base = pkgs.lib.baseNameOf rel;
            in
            # .git, result, build 成果物は除外
            (type != "directory" || base != ".git")
            && (type != "directory" || base != "android")
            && base != "result"
            && base != ".dart_tool"
            && base != "node_modules"
            && base != ".direnv"
            # web/ 配下の test_*, dom_inspector, iframe_test は除外
            && !(pkgs.lib.hasPrefix "web/test_" base)
            && base != "web/dom_inspector.html"
            && base != "web/iframe_test.html"
            # ビルド生成物 (dart compile js の出力) は除外
            && base != "web/main.dart.js"
            && base != "web/main.dart.js.deps"
            && base != "web/main.dart.js.map"
            # 一時ファイル
            && base != "*.lock.bak"
            && base != "dev";
        };

        # ビルドスクリプト (nix run .#build で呼ばれる)
        buildScript = pkgs.writeShellScriptBin "calender-build" ''
          set -euo pipefail
          cd "$(${pkgs.coreutils}/bin/dirname "$0")/.."
          export PATH="${pkgs.dart}/bin:${pkgs.bun}/bin:$PATH"
          ${pkgs.dart}/bin/dart pub get
          ${pkgs.dart}/bin/dart compile js web/main.dart -o web/main.dart.js
          echo "✅ Build complete: web/main.dart.js"
        '';

        # check 用に main.dart がコンパイル可能かだけ確認する derivation
        checkDrv = pkgs.stdenv.mkDerivation {
          name = "calender-dart-check";
          src = webSrc;
          nativeBuildInputs = [ pkgs.dart ];
          buildPhase = ''
            runHook preBuild
            export HOME=$TMPDIR
            ${pkgs.dart}/bin/dart pub get --offline || ${pkgs.dart}/bin/dart pub get
            ${pkgs.dart}/bin/dart compile js -o /tmp/main.dart.js web/main.dart
            runHook postBuild
          '';
          installPhase = ''
            mkdir -p $out
            touch $out/.check-ok
          '';
        };
      in
      {
        # ===== Dev Shell =====
        devShells = {
          default = pkgs.mkShell {
            name = "calender-dev";
            buildInputs = with pkgs; [
              dart
              bun
              nodejs_22
              coreutils
              git
              gnumake
              jdk
              gradle
              androidsdk
            ];

            shellHook = ''
              export DART_SDK="${pkgs.dart}/lib/dart-sdk"
              export PUB_CACHE="$HOME/.pub-cache"

              echo "📅 Calender dev shell (${system})"
              echo "  • dart: $(${pkgs.dart}/bin/dart --version 2>&1 | head -n1)"
              echo "  • bun:  $(${pkgs.bun}/bin/bun --version)"
              echo "  • node: $(${pkgs.nodejs_22}/bin/node --version)"
              echo ""
              echo "Quick commands:"
              echo "  nix build .#default  - web/ をビルド ($out/web/)"
              echo "  nix run   .#apk      - APK をビルド (calender.apk)"
              echo "  nix run   .#serve    - 静的サーバを起動"
              echo "  nix run   .#build    - 手動で dart compile js を再実行"
              echo "  nix flake check      - main.dart のコンパイルチェック"
              echo ""
            '';

            SHELL_PROMPT = "[calender] $ ";
          };

          minimal = pkgs.mkShell {
            name = "calender-dart";
            buildInputs = [ pkgs.dart ];
          };
        };

        # ===== Package: ビルド済み web/ =====
        packages = {
          default = pkgs.stdenv.mkDerivation {
            name = "calender-web-${dartVersion}";
            src = webSrc;

            nativeBuildInputs = [ pkgs.dart ];

            dontStrip = true;

            buildPhase = ''
              runHook preBuild
              export HOME=$TMPDIR
              ${pkgs.dart}/bin/dart pub get --offline || ${pkgs.dart}/bin/dart pub get
              ${pkgs.dart}/bin/dart compile js web/main.dart -o main.dart.js
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out
              # 本番に必要なファイルだけを選択的にコピー
              cp web/index.html $out/
              cp web/styles.css $out/
              cp web/manifest.json $out/
              cp main.dart.js $out/main.dart.js
              cp main.dart.js.deps $out/main.dart.js.deps 2>/dev/null || true
              cp main.dart.js.map $out/main.dart.js.map 2>/dev/null || true
              mkdir -p $out/assets
              cp -r web/assets/. $out/assets/
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "Calender アプリ (コンパイル済み web/)";
              license = licenses.mit;
              platforms = platforms.unix;
            };
          };
        };

        # ===== Checks =====
        checks = {
          inherit checkDrv;
          # flake 自体のメタチェック (nix flake check で実行)
          formatting = pkgs.runCommand "calender-fmt-check" { } ''
            ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./flake.nix} || (
              echo "flake.nix needs formatting. Run: nixpkgs-fmt flake.nix"
              exit 1
            )
            touch $out
          '';
        };

        # ===== Apps =====
        apps = {
          build = {
            type = "app";
            program = "${buildScript}/bin/calender-build";
            meta = {
              description = "Dart を JS にコンパイル";
              type = "build";
            };
          };
          apk = {
            type = "app";
            program = toString (pkgs.writeShellScript "calender-apk" ''
              set -euo pipefail

              SRC="${self}"
              WORK=$(mktemp -d)
              OUT_DIR="$PWD"
              trap "rm -rf $WORK" EXIT

              echo "🔨 Building web app..."
              cp -r "$SRC"/. "$WORK/"
              chmod -R u+w "$WORK"
              cd "$WORK"
              export HOME="$WORK/home"
              mkdir -p "$HOME"
              ${pkgs.dart}/bin/dart pub get
              ${pkgs.dart}/bin/dart compile js web/main.dart -o web/main.dart.js

              echo "📱 Copying web assets to Android project..."
              ANDROID_DIR="$WORK/android"
              ASSETS="$ANDROID_DIR/app/src/main/assets"
              rm -rf "$ASSETS"/*
              cp web/index.html "$ASSETS/"
              cp web/main.dart.js "$ASSETS/"
              cp web/styles.css "$ASSETS/"
              cp web/manifest.json "$ASSETS/"
              cp -r web/assets/. "$ASSETS/assets/"
              cp web/main.dart.js.deps "$ASSETS/" 2>/dev/null || true
              cp web/main.dart.js.map "$ASSETS/" 2>/dev/null || true

              export ANDROID_SDK_ROOT="${androidsdk}/libexec/android-sdk"
              echo "sdk.dir=$ANDROID_SDK_ROOT" > "$ANDROID_DIR/local.properties"

              echo "🏗️ Building APK with Gradle..."
              cd "$ANDROID_DIR"
              ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" \
              ${pkgs.gradle}/bin/gradle assembleDebug

              OUT="$OUT_DIR/calender.apk"
              cp app/build/outputs/apk/debug/app-debug.apk "$OUT"
              echo "✅ APK built: $OUT"
            '');
            meta = {
              description = "APK (Android WebView) をビルド";
              type = "build";
            };
          };
          serve = {
            type = "app";
            program = toString (pkgs.writeShellScript "calender-serve" ''
              export PATH="${pkgs.bun}/bin:$PATH"
              cd ${self}/web
              exec ${pkgs.bun}/bin/bunx browser-sync start --server . --files "*.js,*.css,*.html"
            '');
            meta = {
              description = "web/ を静的サーバ (browser-sync) で配信";
              type = "runtime";
            };
          };
          dev = {
            type = "app";
            program = toString (pkgs.writeShellScript "calender-dev" ''
              export PATH="${pkgs.dart}/bin:${pkgs.bun}/bin:$PATH"
              cd ${self}
              exec ${pkgs.bun}/bin/bun run dev
            '');
            meta = {
              description = "開発モード (watch + browser-sync)";
              type = "runtime";
            };
          };
        };
      });
}
