# robotControl

ROS 2 PC workspace for developing and running the capstone robot's control
software. The environment is intended for Ubuntu 26.04, including Ubuntu on
WSL2.

## First-time setup

```bash
git clone https://github.com/MREN403-CAPSTONE-GROUP9/robotControl.git
cd robotControl
./setup.sh
```

The setup script installs ROS 2 Lyrical Desktop, colcon, `direnv`, Python
venv support, and any additional ROS packages or Python dependencies listed
in `requirements.txt`. It configures Bash directory-based activation for
this project. Open a new terminal after setup.

## Daily use

With `direnv` enabled, entering this repository in Bash automatically
activates ROS and the project Python venv. To activate manually:

```bash
source ./activate.sh
```

Build packages from the workspace root with:

```bash
colcon build
source install/setup.bash
```

Add ROS 2 packages under `src/`. Declare package dependencies in each
package's `package.xml`; list additional Ubuntu ROS binary packages in
`requirements.txt` as `# ros: ros-lyrical-<package-name>`. Add pip
dependencies to the same requirements file.

## Environment portability

The local `.venv` is excluded from Git because virtual environments contain
machine-specific paths and executables. Each clone recreates it with
`./setup.sh` from the tracked requirements.

## WSL2

Install Ubuntu 26.04 from PowerShell with `wsl --install -d Ubuntu-26.04`,
then run the setup commands above inside Ubuntu. WSLg supports ROS GUI tools
such as RViz when available in the WSL installation.

## Layout

- `src/` — ROS 2 control packages
- `setup.sh` — one-time ROS and dependency setup
- `activate.sh` — manual ROS and venv activation
- `.envrc` — automatic activation when entering this directory with direnv
- `requirements.txt` — additional ROS apt packages and Python dependencies
