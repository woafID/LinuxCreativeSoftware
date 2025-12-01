#!/usr/bin/env bash

# Code functionality is commented to help everybody, including Linux beginners to better understand what is being run on their system.

# Functionality to clean up if the user presses Ctrl+C to abort the installation. This prevents users from having an incomplete/broken setup.
trap '
    echo "Operation interrupted... Cleaning up..."

    # Remove temporary setup files
    rm -fr $HOME/affinity_setup_tmp

    # Remove Affinity-related files and directories
    rm -fr $HOME/LinuxCreativeSoftware
    rm $HOME/.local/share/applications/Affinity.desktop

    # Remove the rum command
    echo Due to insufficient permissions, please remove the following files manually:
    echo /usr/local/bin/rum
    echo /opt/wines

    exit 0
' SIGINT

# Check if the script is being run with sudo, and if so, exit.
if [ "$EUID" -eq 0 ]; then
    echo "Please run as regular user."
    exit 1
fi

# If users launch with --uninstall, revert all modifications.
if [ "$1" = "--uninstall" ]; then
  echo "Are you sure you want to remove Linux Affinity and all of its related files? (Y/N)"
  read -r response

  if [[ $response =~ ^[Yy]$ ]]; then
    rm -fr $HOME/affinity_setup_tmp
    rm -fr $HOME/LinuxCreativeSoftware
    rm -f $HOME/.local/share/applications/affinity_designer.desktop
    rm -f $HOME/.local/share/applications/affinity_photo.desktop
    rm -f $HOME/.local/share/applications/affinity_publisher.desktop
    rm -f $HOME/.local/share/applications/Affinity.desktop
    echo
    echo "Elevation is required to remove the following:"
    echo "/usr/local/bin/rum"
    echo "/opt/wines"
    echo

    sudo rm -f /usr/local/bin/rum
    sudo rm -fr /opt/wines
    echo Removal of Affinity has finished.
    exit 0
  else
    echo "Removal of Affinity has been cancelled."
    exit 0
  fi
fi


# An animated loading spinner, which is later invoked by the   spinner "Current_Task_Name_Here"   function.
spinner(){
  pid=$!
  local message=$1
  spin='-\|/'
  i=0
  while kill -0 $pid 2>/dev/null
  do
    i=$(( (i+1) %4 ))
    printf "\r$message ${spin:$i:1}"
    sleep .14
  done
  printf "\n"
}

# Determine which package manager is installed. Exit if nothing is found.
if command -v apt &> /dev/null; then
  PKG_MANAGER="apt"
else
  if command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
  else
    if command -v dnf &> /dev/null; then
      PKG_MANAGER="dnf"
    else
      echo "Error: Package manager (apt, pacman, or dnf) not found."
      exit 1
    fi
  fi
fi

# Declare dependecnies.
PACKAGES="git aria2 curl winetricks p7zip zenity"

# For Fedora specifically we add another package because it needs it for extracting archives.
if [ "$PKG_MANAGER" = "dnf" ]; then
    PACKAGES+=" p7zip-plugins"
fi

# We add only the new packages that are currently not installed on the system to the package manager command that follows.
NEW_PACKAGES=()

# Check if user has some of the packages already installed, then subtract those from the upcoming installation.
for PACKAGE in $PACKAGES; do
  if [ "$PKG_MANAGER" = "apt" ]; then
    if ! dpkg -s "$PACKAGE" &> /dev/null; then
      NEW_PACKAGES+=("$PACKAGE")
    fi
  elif [ "$PKG_MANAGER" = "pacman" ]; then
    if ! pacman -Q "$PACKAGE" &> /dev/null; then
      NEW_PACKAGES+=("$PACKAGE")
    fi
  elif [ "$PKG_MANAGER" = "dnf" ]; then
    if ! dnf list installed "$PACKAGE" &> /dev/null; then
      NEW_PACKAGES+=("$PACKAGE")
    fi
  fi
done


# Installing the new packages here, on whatever package manager the OS has. Skipping the step if no new packages are needed.
if [ ${#NEW_PACKAGES[@]} -gt 0 ]; then

  echo "Installing dependencies:" "${NEW_PACKAGES[@]}"
  sleep 0.4
  if [ "$PKG_MANAGER" = "apt" ]; then
    sudo apt install "${NEW_PACKAGES[@]}" -y
  elif [ "$PKG_MANAGER" = "pacman" ]; then
    sudo pacman -Syu "${NEW_PACKAGES[@]}" --noconfirm
  elif [ "$PKG_MANAGER" = "dnf" ]; then
    sudo dnf install "${NEW_PACKAGES[@]}" -y
  fi

  else
  echo "Nothing new to install. Proceeding.."
  sleep 0.4
fi

# Define some options for the aria2 download manager, so some of the following download commands are easier to read.
ARIA2_PARAMETERS="-x8 --console-log-level=error --dir $HOME/affinity_setup_tmp"

# Download then extract rum wine manager.
git clone https://gitlab.com/xkero/rum.git/ $HOME/affinity_setup_tmp/rum &>/dev/null &
spinner "Downloading rum"

sudo cp $HOME/affinity_setup_tmp/rum/rum /usr/local/bin/rum

# Download then extract custom wine binaries specifically made to run Affinity better.
echo "Downloading Wine:"
aria2c $ARIA2_PARAMETERS --out ElementalWarrior-wine.7z  https://github.com/woafID/LinuxCreativeSoftware/releases/download/wine9.13-p3/ElementalWarrior-wine.7z

7z x $HOME/affinity_setup_tmp/ElementalWarrior-wine.7z -o$HOME/affinity_setup_tmp/ &>/dev/null &
spinner "Extracting"

# Copy downloaded wine binary to the folder that rum recognises.
sudo mkdir -p "/opt/wines"
sudo cp --recursive "$HOME/affinity_setup_tmp/ElementalWarrior-wine/wine-install" "/opt/wines/ElementalWarrior-8.14"

# Link wine to fix an issue because it does not have a 64bit binary.
sudo ln -s /opt/wines/ElementalWarrior-8.14/bin/wine /opt/wines/ElementalWarrior-8.14/bin/wine64

zenity --info --text="You may get prompted to install Wine Mono, in the next section. Please proceed with installing it. Other parts of the installation will be silent. Be patient."

mkdir $HOME/LinuxCreativeSoftware

# Ignore the "command not found" error. This is how it defaults to "agree".
y | rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wineboot --init &>/dev/null &

spinner "Initializing Wine"

# Zenity stuff are implemented this way instead of piping the winetricks command into it, because winetricks will abort installing if we do that.
zenity --progress --pulsate --title="Installing Dependencies" --text="This will take a few minutes... If you're curious, you can see the running installers in the System Monitor app." --no-cancel | sleep infinity &

# Installing Affinity's dependencies, such as dotnet.
rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity winetricks -q dotnet48 corefonts vcrun2022 &>/dev/null &
spinner "Installing dotnet48, corefonts, vcrun2022"
rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wine winecfg -v win11 &>/dev/null &
spinner "Setting Windows version to 11"
killall zenity

# You can extract these files yourself manually from any windows 10 or 11 installation. Just copy the WinMetadata folder from System32 to this path i specified.
echo "Downloading WinMetadata..."
aria2c $ARIA2_PARAMETERS --out winmd.7z https://archive.org/download/WinMetadata/winmd.7z
7z x $HOME/affinity_setup_tmp/winmd.7z -o$HOME/LinuxCreativeSoftware/Affinity/drive_c/windows/system32/WinMetadata &>/dev/null &
spinner "Extracting"

# Affinity setup's official page is being directed into a variable.
affinity_url="https://downloads.affinity.studio/Affinity%20x64.exe"

# We now download the installers with aria2. This command is equivalent of something like "wget https://example.com/example.file"
 echo
 echo "Downloading installer..."
 echo
 aria2c $ARIA2_PARAMETERS --out "Affinity-x64.exe" "$affinity_url"


# We already create shortcuts for these Apps.
# This Establishes language independence, as "Desktop" is different in various languages.
DESKTOP=$(xdg-user-dir DESKTOP)

zenity --info --text="Please proceed with all of the installers."

# We run the genuine setups that has been downloaded.
rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wine $HOME/affinity_setup_tmp/Affinity-x64.exe &>/dev/null &
spinner "Installing Affinity"
rm -f $DESKTOP/Affinity.lnk

# Preventing crash reporting by renaming the binaries, because its not needed, and we dont want to report issues from unsupported OSes.
mv $HOME/LinuxCreativeSoftware/Affinity/drive_c/Program\ Files/Affinity/Affinity/crashpad_handler.exe $HOME/LinuxCreativeSoftware/Affinity/drive_c/Program\ Files/Affinity/Affinity/crashpad_handler.exe.bak

# We create launcher scripts that will be executed by the .desktop files once users click them.
echo "Creating launchers..."
mkdir $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers

echo 'rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wine "$HOME/LinuxCreativeSoftware/Affinity/drive_c/Program Files/Affinity/Affinity/Affinity.exe"' > $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/Affinity.sh

# Making launchers executable
chmod u+x $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/Affinity.sh

# Downloading icons from Serif's server.
mkdir -p $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/icos
echo "Creating icon..."
aria2c --console-log-level=warn --dir $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/icos/ --out Affinity.svg https://upload.wikimedia.org/wikipedia/commons/c/cf/Affinity_%28App%29_Logo.svg &>/dev/null
mkdir -p "$HOME/.local/share/applications"

#Create icons. There certainly is a better way to do this. We create .desktop files that launch the software.
#The backslashes (\) before and after the variable $HOME_DIR in the Exec line are used to escape the double quotes (") surrounding the path.
HOME_DIR=$HOME

DESKTOP_CONTENT="[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Exec=/bin/bash -c \"$HOME_DIR/LinuxCreativeSoftware/Affinity/drive_c/launchers/Affinity.sh\" %U
Name=Affinity
Icon=$HOME_DIR/LinuxCreativeSoftware/Affinity/drive_c/launchers/icos/Affinity.svg
Categories=ConsoleOnly;System;"

echo "$DESKTOP_CONTENT" > "$HOME/.local/share/applications/Affinity.desktop"

# Set renderrer to vulkan, to better support recent hardware. If you have issues, try replacing "vulkan" with "gl"
rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity winetricks renderer=vulkan &>/dev/null &
spinner "Switching API to Vulkan"

# Finally we remove the temporary directory.
rm -fr $HOME/affinity_setup_tmp
echo All done!
sleep 1.5
exit 0
