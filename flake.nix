{
  description = "Qtile's flake, full-featured, hackable tiling window manager written and configured in Python";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: let 
    supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

    forAllSystems = function:
      nixpkgs.lib.genAttrs supportedSystems
        (system: let
          nixpkgs-settings = {
            inherit system;

          overlays = [
            (import ./nix/overlays.nix self)
          ];
        };

        in function (import nixpkgs nixpkgs-settings));

  in {
    overlays.default = import ./nix/overlays.nix self;

    packages = forAllSystems (pkgs: let
      qtile' = pkgs.python3Packages.qtile;
    in {
      default = self.packages.${pkgs.system}.qtile;

      qtile = qtile'.overrideAttrs (_: {
        name = "${qtile'.pname}-${qtile'.version}";
        passthru.unwrapped = qtile';
      });
    });

    devShells = forAllSystems (pkgs: let
      common-python-deps = ps: with ps; [
        # deps for running, same as NixOS package
        (cairocffi.override {withXcffib = true;})
        dbus-next
        iwlib
        mpd2
        psutil
        pulsectl-asyncio
        pygobject3
        python-dateutil
        pywayland
        pywlroots
        pyxdg
        xcffib
        xkbcommon

        # building ffi
        setuptools

        # migrate
        libcst

        # tests
        coverage
        pytest
      ];

      tests = {
        wayland = pkgs.writeScriptBin "qtile-run-tests-wayland" ''
          ./scripts/ffibuild -v
          pytest -x --backend=wayland
        '';

        x11 = pkgs.writeScriptBin "qtile-run-tests-x11" ''
          ./scripts/ffibuild -v
          pytest -x --backend=x11
        '';
      };

      common-system-deps = with pkgs; [
        # Gdk namespaces
        wrapGAppsHook
        gobject-introspection

        ## system deps
        libinput
        libxkbcommon
        xorg.xcbutilwm

        # x11 deps
        xorg.xorgserver
        xorg.libX11

        # wayland deps
        wayland
        wlroots_0_17
        # test/backend/wayland/test_window.py
        gtk-layer-shell
      ] ++ (builtins.attrValues tests);
    in {
      default = pkgs.mkShell {
        env = {
          QTILE_DLOPEN_LIBGOBJECT = "${pkgs.glib}/lib/libgobject-2.0.so.0";
          QTILE_DLOPEN_LIBPANGOCAIRO = "${pkgs.pango}/lib/libpangocairo-1.0.so.0";
          QTILE_DLOPEN_LIBPANGO = "${pkgs.pango}/lib/libpango-1.0.so.0";
          QTILE_DLOPEN_LIBXCBUTILCURSORS = "${pkgs.xcb-util-cursor}/lib/libxcb-cursor.so.0";
          QTILE_INCLUDE_LIBPIXMAN = "${pkgs.pixman}/include";
          QTILE_INCLUDE_LIBDRM = "${pkgs.libdrm.dev}/include/libdrm";
        };

        shellHook = ''
          export PYTHONPATH=$(readlink -f .):$PYTHONPATH
        '';

        packages = with pkgs; [
          (python3.withPackages common-python-deps)
          pre-commit
        ] ++ common-system-deps;
      };
    });
  };
}
