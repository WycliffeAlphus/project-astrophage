#!/usr/bin/env bash
# Sonic Shield — FPGA Toolchain Bootstrap
# Installs: yosys, nextpnr-ice40, IceStorm (icepack/iceprog), iverilog, gtkwave
#
# Run once on a fresh machine:
#   chmod +x scripts/bootstrap_toolchain.sh
#   ./scripts/bootstrap_toolchain.sh
#
# Tested on Ubuntu 22.04 / Debian 12.

set -e

echo "=== Sonic Shield FPGA Toolchain Bootstrap ==="
echo ""

DEPS="build-essential clang bison flex libreadline-dev gawk tcl-dev \
      libffi-dev git graphviz xdot pkg-config python3 python3-dev \
      libboost-all-dev zlib1g-dev cmake libeigen3-dev libftdi1-dev libusb-1.0-0-dev"

echo "[1/5] Installing build dependencies..."
sudo apt-get update -qq
sudo apt-get install -y $DEPS iverilog gtkwave

# nextpnr requires CMake >= 3.25. Ubuntu 22.04 ships 3.22 — upgrade via Kitware repo.
CMAKE_VERSION=$(cmake --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' | head -1)
CMAKE_MAJOR=$(echo "$CMAKE_VERSION" | cut -d. -f1)
CMAKE_MINOR=$(echo "$CMAKE_VERSION" | cut -d. -f2)
if [ "$CMAKE_MAJOR" -lt 3 ] || { [ "$CMAKE_MAJOR" -eq 3 ] && [ "$CMAKE_MINOR" -lt 25 ]; }; then
    echo "  CMake $CMAKE_VERSION too old — installing 3.25+ from Kitware apt repo..."
    sudo apt-get install -y ca-certificates gpg wget
    wget -qO- https://apt.kitware.com/keys/kitware-archive-latest.asc \
        | gpg --dearmor - \
        | sudo tee /usr/share/keyrings/kitware-archive-keyring.gpg > /dev/null
    # Detect Ubuntu codename (jammy, focal, etc.)
    CODENAME=$(. /etc/os-release && echo "$UBUNTU_CODENAME")
    echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] \
https://apt.kitware.com/ubuntu/ ${CODENAME} main" \
        | sudo tee /etc/apt/sources.list.d/kitware.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y cmake
    echo "  CMake upgraded: $(cmake --version | head -1)"
else
    echo "  CMake $CMAKE_VERSION OK"
fi

# --- Yosys ---
echo ""
echo "[2/5] Installing Yosys..."
if command -v yosys &>/dev/null; then
    echo "  already installed: $(yosys -V 2>&1 | head -1)"
else
    if apt-cache show yosys &>/dev/null; then
        sudo apt-get install -y yosys
    else
        echo "  building from source..."
        git clone --depth=1 https://github.com/YosysHQ/yosys.git /tmp/yosys_build
        make -j"$(nproc)" -C /tmp/yosys_build
        sudo make install -C /tmp/yosys_build
    fi
    echo "  yosys installed: $(yosys --version 2>&1 | head -1)"
fi

# --- Project IceStorm (icepack, iceprog) ---
echo ""
echo "[3/5] Installing IceStorm..."
# Check for timing files, not just icepack binary.
# The apt package installs to /usr/share/fpga-icestorm/ which nextpnr cannot find.
# Source build installs to /usr/local/share/icebox/ which nextpnr expects.
if [ -f "/usr/local/share/icebox/timings_up5k.txt" ]; then
    echo "  already installed (source build)"
else
    echo "  building from source (apt version has wrong directory layout)..."
    rm -rf /tmp/icestorm_build
    git clone --depth=1 https://github.com/YosysHQ/icestorm.git /tmp/icestorm_build
    make -j"$(nproc)" -C /tmp/icestorm_build
    sudo make install -C /tmp/icestorm_build
    echo "  IceStorm installed"
fi

# --- nextpnr-ice40 ---
echo ""
echo "[4/5] Installing nextpnr-ice40..."
if command -v nextpnr-ice40 &>/dev/null; then
    echo "  already installed: $(nextpnr-ice40 --version 2>&1 | head -1)"
else
    git clone --depth=1 https://github.com/YosysHQ/nextpnr.git /tmp/nextpnr_build
    # nextpnr requires out-of-tree build (-B flag)
    cmake /tmp/nextpnr_build -B /tmp/nextpnr_build/build \
          -DARCH=ice40 \
          -DICESTORM_INSTALL_PREFIX=/usr/local \
          -DBUILD_GUI=OFF
    cmake --build /tmp/nextpnr_build/build -j"$(nproc)"
    sudo cmake --install /tmp/nextpnr_build/build
    echo "  nextpnr-ice40 installed"
fi

# --- USB permissions for iceprog (UPduino uses FTDI FT232H) ---
echo ""
echo "[5/5] Setting USB permissions for UPduino..."
RULES_FILE=/etc/udev/rules.d/53-lattice-ftdi.rules
if [ ! -f "$RULES_FILE" ]; then
    echo 'ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6014", MODE="0660", GROUP="plugdev"' \
        | sudo tee "$RULES_FILE" > /dev/null
    sudo udevadm control --reload-rules
    sudo usermod -aG plugdev "$USER"
    echo "  udev rule added — log out and back in before flashing"
else
    echo "  udev rule already exists"
fi

echo ""
echo "=== Bootstrap complete ==="
echo ""
echo "Verify:"
echo "  yosys -V"
echo "  nextpnr-ice40 --version"
echo "  icepack --help 2>&1 | head -2"
echo "  iverilog -V 2>&1 | head -1"
echo ""
echo "First steps:"
echo "  make sim    # run testbenches (no hardware needed)"
echo "  make synth  # synthesize and check LUT count"
