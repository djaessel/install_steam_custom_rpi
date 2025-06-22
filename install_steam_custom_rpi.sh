#!/bin/bash

STARTINGDIR=${PWD}
TEMPDIR="${STARTINGDIR}/temp"

if [ -d "${BOX86BUILDDIR}" ]; then
  rm -rf "${TEMPDIR}"
fi
mkdir "${TEMPDIR}"



# install box86
echo "Installing or updating box86..."
BOX86DIR="${PWD}/box86"
BOX86BUILDDIR="${BOX86DIR}/build"
if [ ! -d "${BOX86DIR}" ]; then
  echo "box86 does not exist - downloading necessary things:"
  sudo apt install gcc-arm-linux-gnueabihf
  git clone https://github.com/ptitSeb/box86.git
fi

cd "${BOX86DIR}"
gitLog=$(git pull)
gitUptodateTXTDE="Bereits aktuell"
gitUptodateTXTEN="Everything up-to-date"
if [[ ! $gitLog =~ $gitUptodateTXTDE ] || [ ! $gitLog =~ $gitUptodateTXTEN ] || [ ! -d "${BOX86BUILDDIR}" ]]; then

  if [ -d "${BOX86BUILDDIR}" ]; then
    cd "$BOX86BUILDDIR"
    sudo make uninstall
    sudo systemctl restart systemd-binfmt
    cd "${BOX86DIR}"
    rm -rf build
  fi

  mkdir build
  cd build
  cmake .. -DRPI4ARM64=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo # maybe dynamically change later for different rpi models
  make -j2
  sudo make install
  sudo systemctl restart systemd-binfmt
fi
echo "box86 all set-up!"


# reset to start dir
cd "${STARTINGDIR}"



# install box64
echo "Installing or updating box64..."
BOX64DIR="${PWD}/box64"
BOX64BUILDDIR="${BOX64DIR}/build"
if [ ! -d "${BOX64DIR}" ]; then
  echo "box64 does not exist - downloading necessary things:"
  #sudo apt install aarch64-w64-mingw32-clang aarch64-w64-mingw32-as # for WOW64
  git clone https://github.com/ptitSeb/box64.git
fi

cd "${BOX64DIR}"
gitLog=$(git pull)
gitUptodateTXTDE="Bereits aktuell"
gitUptodateTXTEN="Everything up-to-date"
if [[ ! $gitLog =~ $gitUptodateTXTDE ] || [ ! $gitLog =~ $gitUptodateTXTEN ] || [ ! -d "${BOX64BUILDDIR}" ]]; then

  if [ -d "${BOX64BUILDDIR}" ]; then
    cd "$BOX64BUILDDIR"
    sudo make uninstall
    sudo systemctl restart systemd-binfmt
    cd "${BOX64DIR}"
    rm -rf build
  fi

  mkdir build
  cd build
  cmake .. -D RPI5ARM64=1 -D CMAKE_BUILD_TYPE=RelWithDebInfo # maybe dynamically change later for different rpi models
  #cmake .. -DRPI5ARM64=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBOX32=ON -DBOX32_BINFMT=ON -DWOW64=ON # maybe dynamically change later for different rpi models
  make -j4 # maybe dynamically change later for different rpi models
  sudo make install
  sudo systemctl restart systemd-binfmt
fi
echo "box64 all set-up!"


# reset to start dir
cd "${STARTINGDIR}"


# add additional packages not already installed by box86/box64
echo "Installing additional packages..."
sudo dpkg --add-architecture armhf
sudo apt update
sudo apt install libnss3:armhf libnm0:armhf libdbus-glib-1-2:armhf libnspr4:armhf libgudev-1.0-0:armhf libxtst6:armhf libsm6:armhf libice6:armhf libusb-1.0-0:armhf libnss3 libnm0 libdbus-glib-1-2 libudev1 libnspr4 libgudev-1.0-0 libxtst6 libsm6 libice6 libusb-1.0-0 libibus-1.0-dev || exit 1


#if package_installed steam-devices ; then
#  echo "Removing steam-devices package because it conflicts with steam-launcher..."
#  apt_lock_wait
sudo apt purge -y steam-devices
#fi

#if package_installed steamlink ; then
#  echo "Removing steamlink package because it conflicts with steam-launcher..."
#  apt_lock_wait
sudo apt purge -y steamlink
#fi

#prevent lxterm dependency from becoming default terminal
default_terminal="$(readlink -f /usr/bin/x-terminal-emulator)"

echo "Installing steam_latest.deb"
# hardcode 1.0.0.81 which is the newest version that still uses the `all` dpkg architecture definition which allows steam to be installed on any architecture system without jumping through dpkg hoops
# the steam_latest.deb pointed to 1.0.0.81 until very recently
#install_packages https://repo.steampowered.com/steam/archive/stable/steam-launcher_1.0.0.81_all.deb || exit 1
cd temp
wget https://repo.steampowered.com/steam/archive/stable/steam-launcher_1.0.0.81_all.deb
sudo dpkg -i steam-launcher_1.0.0.81_all.deb


# reset to start dir
cd "${STARTINGDIR}"


#check if terminal choice was changed after steam was installed
if [ ! -z "$default_terminal" ] && [ "$(readlink -f /usr/bin/x-terminal-emulator)" != "$default_terminal" ];then
  #restore previous choice
  sudo update-alternatives --set x-terminal-emulator "$default_terminal"
fi

sudo mkdir -p /usr/local/bin /usr/local/share/applications
# if a matching name binary is found in /usr/local/bin it takes priority over /usr/bin
echo '#!/bin/bash
export STEAMOS=1
export STEAM_RUNTIME=1
export DBUS_FATAL_WARNINGS=0
BOX64_LOG=1 BOX86_LOG=1 BOX64_TRACE_FILE=stderr BOX86_TRACE_FILE=stderr BOX64_EMULATED_LIBS=libmpg123.so.0 /usr/lib/steam/bin_steam.sh -no-cef-sandbox steam://open/minigameslist "$@"

rm -f /home/${USER}/Desktop/steam.desktop' | sudo tee /usr/local/bin/steam || error "Failed to create steam launch script"

# set execution bit
sudo chmod +x /usr/local/bin/steam

#remove crashhandler.so from archive that is extracted to ~/.local/share/Steam/ubuntu12_32/crashhandler.so
#fixes first launch error
rm -rf /tmp/bootstraplinux_ubuntu12_32
mkdir -p /tmp/bootstraplinux_ubuntu12_32 || error "failed to make temp folder /tmp/bootstraplinux_ubuntu12_32"
tar -xf '/usr/lib/steam/bootstraplinux_ubuntu12_32.tar.xz' -C /tmp/bootstraplinux_ubuntu12_32 || error "failed to extract bootstraplinux_ubuntu12_32.tar.xz"
rm -f /tmp/bootstraplinux_ubuntu12_32/ubuntu12_32/crashhandler.so || error "failed to remove crashhandler.so"
#overwrite the archive (changes will be overwritten on steam.deb update, but this is only needed once for first setup to not fail)
sudo tar -cJf '/usr/lib/steam/bootstraplinux_ubuntu12_32.tar.xz' -C /tmp/bootstraplinux_ubuntu12_32 . || error "failed to compress new bootstraplinux_ubuntu12_32.tar.xz"
rm -rf ~/.local/share/Steam/ubuntu12_32/crashhandler.so /tmp/bootstraplinux_ubuntu12_32 #remove it in case it already exists

# move official steam.desktop file to /usr/local and edit it (move it so users ignoring the reboot warning cannot find the wrong launcher)
# we can't edit the official steam.desktop file since this will get overwritten on a steam update (steam adds its own apt repo)
# if a matching name .desktop file is found in /usr/local/share/applications it takes priority over /usr/share/applications
sudo mv -f /usr/share/applications/steam.desktop /usr/local/share/applications/steam.desktop
sudo sed -i 's:Exec=/usr/bin/steam:Exec=/usr/local/bin/steam:' /usr/local/share/applications/steam.desktop
#symlink to original location to prevent first-run steam exit when file is missing, and to prevent /usr/local/share in PATH from being a hard requirement (Chances are the user will reboot before steam.deb gets an update)
sudo ln -s /usr/local/share/applications/steam.desktop /usr/share/applications/steam.desktop

rm -f $HOME/Desktop/steam.desktop

