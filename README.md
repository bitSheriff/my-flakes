# My Nix Flakes

## Packages

## Templates

### Ros2 F1Tenth RoboRacer

```sh
nix flake init -t codeberg:bitSheriff/my-flakes#f1tenth
# or
nix flake init -t github:bitSheriff/my-flakes#f1tenth
```

Packages included:
- **ROS 2 Jazzy** Base (via `nix-ros-overlay`)
- **ROS Packages**: `ackermann-msgs`, `diagnostic-aggregator`, `plotjuggler-ros`, `nav2-lifecycle-manager`, `nav2-map-server`, `tf2-ros`, `xacro`, `joint-state-publisher`, `teleop-twist-keyboard`
- **Dev Tools**: `just`, `git`, `gum`, `tmux`, `lazygit`
- **Python**: `python3`, `pip`, `numpy`, `scikit-image`, `transforms3d`
- **Graphics**: `nixGL` (required for `rviz2`)
- **Custom Scripts**: `build_colcon`, `helpers` (interactive menu)

### Features
- **Automatic Environment Setup**: Automatically clones and sets up `gym` (0.19.0) and `f1tenth_gym` in a local `.venv` on first run.
- **Hardware Acceleration**: Includes `nixGL` for running GUI applications like RViz. Note: requires `nix develop --impure`.
- **Interactive Helpers**: Run `helpers` for a menu-driven interface to build, clean, or view TF trees.
- **Convenience Aliases**: `nv` for `nvim`, `lg` for `lazygit`, and a patched `ros2` command for local path resolution in simulation configs.

