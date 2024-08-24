{
  description = "Qtile's flake, full-featured, hackable tiling window manager written and configured in Python";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    forAllSystems = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];

    forAllSystems = function:
      nixpkgs.lib.genAttrs defaultSystems
      (system: function nixpkgs.legacyPackages.${system});

  in {
    formatter = forAllSystems (pkgs: pkgs.alejandra);

    overlays = import ./nix/overlays.nix self;

    packages = forAllSystems (pkgs: let
      pypkgs = pkgs.python3Packages;
      nixpkgs-qtile = pypkgs.qtile;

    in {
      default = self.packages.${pkgs.system}.qtile;
      qtile = nixpkgs-qtile.overrideAttrs (_: {
        name = "${nixpkgs-qtile.pname}-${nixpkgs-qtile.version}";
        passthru.unwrapped = nixpkgs-qtile;
      });
    });

    devShells = forAllSystems (pkgs: let
      common-shell = {
        env = {
          QTILE_DLOPEN_LIBGOBJECT = "${pkgs.glib}/lib/libgobject-2.0.so.0";
          QTILE_DLOPEN_LIBPANGOCAIRO = "${pkgs.pango}/lib/libpangocairo-1.0.so.0";
          QTILE_DLOPEN_LIBPANGO = "${pkgs.pango}/lib/libpango-1.0.so.0";
          QTILE_DLOPEN_LIBXCBUTILCURSORS = "${pkgs.xcb-util-cursor.out}/lib/libxcb-cursor.so.0";
          QTILE_INCLUDE_LIBPIXMAN = "${pkgs.pixman.outPath}/include";
          QTILE_INCLUDE_LIBDRM = "${pkgs.libdrm.dev.outPath}/include/libdrm";
        };
        
        shellHook = ''
          export PYTHONPATH=$(readlink -f .):$PYTHONPATH
        '';
      };

      common-python-deps = ps: with ps; [
        python-dateutil
      ] ++ [
        # tests
        coverage
        pytest
      ];

      common-system-deps = with pkgs; [
        # Gdk namespaces
        wrapGAppsHook
        gobject-introspection

        # x11 deps
        xorg.xorgserver
        xorg.libX11

        wlroots_0_17
        # test/backend/wayland/test_window.py
        gtk-layer-shell
      ] ++ [
        # some targets scripts run
        (pkgs.writeScriptBin "qtile-run-tests-wayland" ''
          ./scripts/ffibuild -v
          pytest -x --backend=wayland
        '')

        (pkgs.writeScriptBin "qtile-run-tests-x11" ''
          ./scripts/ffibuild -v
          pytest -x --backend=x11
        '')
      ];

    in {
      default = pkgs.mkShell {
        inherit (common-shell) env shellHook;

        packages = with pkgs; [
          (python3.withPackagescommon-python-deps)
          pre-commit
        ] ++ common-system-deps;
      };
    });
  };
}
