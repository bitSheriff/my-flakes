{
  description = "F1Tenth ROS 2 Jazzy development environment";

  inputs = {
    nix-ros-overlay.url = "github:lopsided98/nix-ros-overlay/master";
    nixpkgs.follows = "nix-ros-overlay/nixpkgs";
    nixgl.url = "github:nix-community/nixGL";
    nixgl.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-ros-overlay,
      nixgl,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgs = import nixpkgs {
        overlays = [ nix-ros-overlay.overlays.default ];
      };

      sharedRosPackages =
        ros: with ros; [
          ackermann-msgs
          diagnostic-aggregator
          geometry-msgs
          joint-state-publisher
          nav-msgs
          nav2-lifecycle-manager
          nav2-map-server
          plotjuggler-ros
          rosidl-default-generators
          rosidl-default-runtime
          sensor-msgs
          teleop-twist-keyboard
          tf2-geometry-msgs
          tf2-ros
          xacro
          nav2-mppi-controller # Model Predictive Controller
          navigation2
          nav2-controller
        ];

      sharedRosPythonDependencies = with pkgs; [
        # Python dependencies
        python3
        python3Packages.numpy
        python3Packages.transforms3d
        python3Packages.scikit-image
        python3Packages.pip
        python3Packages.numpy
        python3Packages.scikit-image
        python3Packages.transforms3d

      ];

    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ nix-ros-overlay.overlays.default ];
          };
          ros = pkgs.rosPackages.jazzy;

        in
        {
          clean = pkgs.stdenv.mkDerivation {
            name = "Clean";
            buildPhase = ''
              echo "Deleting directories"
              rm -rf install/
              rm -rf log/
            '';
          };

          default = pkgs.stdenv.mkDerivation {
            name = "f1tenth-build";
            src = ./.;

            dontUseCmakeConfigure = true;

            nativeBuildInputs = [
              ros.ros-environment
              ros.ament-cmake
              ros.ament-cmake-ros
              ros.ament-lint-auto
              pkgs.colcon
              pkgs.python3
              pkgs.python3Packages.setuptools
            ];

            propagatedBuildInputs = [
            ]
            ++ (sharedRosPackages ros)
            ++ (sharedRosPythonDependencies);

            buildPhase = ''
              export COLCON_EXTENSION_BLACKLIST=colcon_ros.prefix_path.ament
              export PYTHONPATH="${pkgs.python3Packages.setuptools}/${pkgs.python3.sitePackages}:$PYTHONPATH"

              colcon build --install-base $out
              colcon build --install-base $out --symlink-install --packages-select f1tenth_gym
              colcon build --install-base $out --symlink-install --packages-select f1tenth_gym_ros
            '';

            installPhase = ''
              mkdir -p $out/bin

              cp -r $src/install $out/
              cp -r $src/launch $out/
              cp -r $src/config $out/
            '';
          };
        }
      );

      #### APPS ####
      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = nixpkgs.lib;
          mkSimApp = launchFile: {
            type = "app";
            program = lib.getExe (
              pkgs.writeShellApplication {
                name = "run-${launchFile}";
                text = ''
                  echo "Starting ROS 2 simulation for ${launchFile}..."
                  set +u
                  # shellcheck disable=SC1091
                  source install/local_setup.bash
                  set -u
                  ros2 launch launch/${launchFile}
                '';
              }
            );
          };

        in
        {
          sim = mkSimApp "sim.py";
          pure_pursuit = mkSimApp "pure_pursuit_sim.py";
        }
      );

      #### DEV SHELL ####
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ nix-ros-overlay.overlays.default ];
          };
          rosShell = nix-ros-overlay.devShells.${system}.example-ros2-desktop-jazzy;
          ros = pkgs.rosPackages.jazzy;

          # Explicitly grab the nixGL wrapper for your system
          nixGLDefault = nixgl.packages.${system}.nixGLIntel;

          build_colcon = pkgs.writeShellScriptBin "build_colcon" ''
            colcon build
            colcon build --symlink-install --packages-select f1tenth_gym
            colcon build --symlink-install --packages-select f1tenth_gym_ros
          '';

          helper-script = pkgs.writeShellApplication {
            name = "helpers";
            runtimeInputs = [ pkgs.gum ];
            text = ''
              ACTIONS=("print tf tree" "build" "clean build")

              echo "Choose an action to perform:"
              CHOSEN=$(printf "%s\n" "''${ACTIONS[@]}" | gum choose)

              if [ "$CHOSEN" = "print tf tree" ]; then
                  gum style --foreground 212 "Printing the tf tree to a pdf file"
                  ros2 run tf2_tools view_frames

              elif [ "$CHOSEN" = "build" ]; then
                  gum style --foreground 57 "Building the application"
                  build_colcon

              elif [ "$CHOSEN" = "clean build" ]; then
                  gum style --foreground 82 "Doing a clean build"
                  rm -rf install/ logs/
                  build_colcon

              else
                  echo "No valid selection made."
                  exit 1
              fi
            '';
          };

          rviz2_wrapped = pkgs.writeShellScriptBin "rviz2" ''
            # Force EGL to fix FBConfig mismatch in Jazzy (Qt6)
            export QT_XCB_GL_INTEGRATION=xcb_egl
            exec ${nixGLDefault}/bin/nixGLIntel ${ros.rviz2}/bin/rviz2 "$@"
          '';

          rqt_wrapped = pkgs.writeShellScriptBin "rqt_reconfigure" ''
            exec ${nixGLDefault}/bin/nixGLIntel ${ros.rqt-reconfigure}/bin/rqt_reconfigure "$@"
          '';
        in
        {
          default = pkgs.mkShell {
            name = "f1tenth-jazzy-shell";
            inputsFrom = [ rosShell ];

            packages =
              with pkgs;
              [
                # Hardware Acceleration
                nixGLDefault
                glxinfo

                # Development tools
                bashInteractive
                just
                git
                gum
                tmux
                lazygit
                rsync
                python3

                # Scripts
                build_colcon
                helper-script
                rviz2_wrapped
                rqt_wrapped
              ]
              ++ (sharedRosPackages ros)
              ++ (sharedRosPythonDependencies);

            ROS_DOMAIN_ID = 69;

            shellHook = ''
              export COLCON_EXTENSION_BLACKLIST=colcon_ros.prefix_path.ament

              # --- Local Python Virtual Environment ---
              export LOCAL_PYTHON_ENV="$PWD/.venv"
              export PYTHONPATH="$LOCAL_PYTHON_ENV/lib/python3.13/site-packages:$PWD/gym:$PWD/f1tenth_gym/gym:$PYTHONPATH"
              export PATH="$LOCAL_PYTHON_ENV/bin:$PATH"

              if [ ! -d "$LOCAL_PYTHON_ENV" ]; then
                echo "Creating local Python virtual environment..."
                python3 -m venv "$LOCAL_PYTHON_ENV" --system-site-packages
                unset SOURCE_DATE_EPOCH
                "$LOCAL_PYTHON_ENV/bin/pip" install setuptools wheel
                if [ ! -d "gym" ]; then
                  git clone https://github.com/openai/gym -b 0.19.0 --depth 1
                  sed -i "/extras_require/d" gym/setup.py
                fi
                "$LOCAL_PYTHON_ENV/bin/pip" install -e ./gym

                if [ ! -d "f1tenth_gym" ]; then
                  git clone https://github.com/f1tenth/f1tenth_gym
                  sed -i "/numpy/d" f1tenth_gym/setup.py
                fi
                "$LOCAL_PYTHON_ENV/bin/pip" install -e ./f1tenth_gym
              fi
              # ----------------------------------------

              # --- Graphics Fix (via nixGL) ---
              export QT_QPA_PLATFORM=xcb
              export QT_XCB_GL_INTEGRATION=xcb_egl
              export Ogre_GL_Config=GLX

              # Set up nixGL and Mesa drivers
              export LIBGL_DRIVERS_PATH="${pkgs.mesa}/lib/dri"
              export LD_LIBRARY_PATH="${nixGLDefault}/lib:${pkgs.mesa}/lib:$LD_LIBRARY_PATH"

              # Add wrapped GUI tools to PATH
              export PATH="${rviz2_wrapped}/bin:${rqt_wrapped}/bin:$PATH"

              # --- Setup Consistency Symlinks ---
              mkdir -p src
              [ -L src/f1tenth_gym_ros ] || ln -s ../f1tenth_data src/f1tenth_gym_ros
              [ -L src/your_code ] || ln -s . src/your_code

              # Shell Aliases
              alias nv='nvim'
              alias lg='lazygit'

              # Dynamically patch sim.yaml in install space for local Nix usage
              ros2() {
                local target="install/f1tenth_gym_ros/share/f1tenth_gym_ros/config/sim.yaml"
                if [ -f "$target" ] && grep -q "/arc2026" "$target"; then
                  rm -f "$target"
                  sed "s|/arc2026|$PWD|g" src/f1tenth_gym_ros/config/sim.yaml > "$target"
                fi
                
                # Wrap GUI-heavy commands with nixGL to ensure rviz2/rqt work
                if [[ "$1" == "launch" || "$1" == "run" ]]; then
                  ${nixGLDefault}/bin/nixGLIntel ros2 "$@"
                else
                  command ros2 "$@"
                fi
              }

              echo "--- F1Tenth ROS 2 Jazzy (Nix) ---"
              echo "Graphics: Wrapped in nixGL (Impure mode)"
              echo "Aliases: nv -> nvim, lg -> lazygit"
            '';
          };
        }
      );
    };
}
