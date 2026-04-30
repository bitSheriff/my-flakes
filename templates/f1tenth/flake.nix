{
  description = "F1Tenth ROS 2 Jazzy development environment";

  inputs = {
    nix-ros-overlay.url = "github:lopsided98/nix-ros-overlay/master";
    nixpkgs.follows = "nix-ros-overlay/nixpkgs";
    nixgl.url = "github:nix-community/nixGL";
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

    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ nix-ros-overlay.overlays.default ];
          };
          rosShell = nix-ros-overlay.devShells.${system}.example-ros2-desktop-jazzy;

          # Explicitly grab the nixGL wrapper for your system
          nixGLDefault = nixgl.packages.${system}.nixGLDefault;

          build_colcon = pkgs.writeShellScriptBin "build_colcon" ''
            colcon build
            colcon build --symlink-install --packages-select f1tenth_gym
            source install/local_setup.bash
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

        in
        {
          default = pkgs.mkShell {
            name = "f1tenth-jazzy-shell";

            inputsFrom = [ rosShell ];

            packages = with pkgs; [
              # Hardware Acceleration
              nixGLDefault

              # ROS dependencies
              rosPackages.jazzy.ackermann-msgs
              rosPackages.jazzy.diagnostic-aggregator
              rosPackages.jazzy.plotjuggler-ros
              rosPackages.jazzy.nav2-lifecycle-manager
              rosPackages.jazzy.nav2-map-server
              rosPackages.jazzy.tf2-ros
              rosPackages.jazzy.xacro
              rosPackages.jazzy.joint-state-publisher
              rosPackages.jazzy.teleop-twist-keyboard

              # Development tools
              just
              git
              gum
              tmux
              lazygit
              python3
              python3Packages.pip
              python3Packages.numpy
              python3Packages.scikit-image
              python3Packages.transforms3d

              # Scripts
              build_colcon
              helper-script

            ];

            shellHook = ''
              export ROS_DOMAIN_ID=0
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
              # Note: requires 'nix develop --impure'
              export QT_QPA_PLATFORM=xcb
              # The binary is usually named 'nixGL' inside the nixGLDefault package
              alias rviz2='${nixGLDefault}/bin/nixGL rviz2'
              alias rviz='${nixGLDefault}/bin/nixGL rviz2'

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
                command ros2 "$@"
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
