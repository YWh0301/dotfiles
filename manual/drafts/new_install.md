# New Install

这里按照在一台新的计算机上配置我自己习惯的*archlinux*+*hyprland*+*yazi*+*waybar*+*tmux*+*kitty*+*neovim*的详细操作步骤进行记录。

The arch-wiki installation guide is [here](https://wiki.archlinux.org/title/Installation_guide).

## Pre-installation Preparation

- Go to [arch iso download site](https://archlinux.org/download/) or directly to [THU's mirror site](https://mirrors.tuna.tsinghua.edu.cn/archlinux/iso/2024.09.01/) to download the arch live usb iso.
- Make sure to have a usable wifi with english ssid or available netcable connection.
- Get a usable usb stick, make sure there is a big enough FAT32 formatted partition on it.
- Make sure the new machine uses uefi.
- On windows, create live usb medium with *rufus*.
- On linux, *mount* the FAT32 partition, and `sudo bsdtar -x -f archlinux-version-x86_64.iso -C /mount_point`.more info [here](https://wiki.archlinux.org/title/USB_flash_installation_medium#In_GNU/Linux_4). Or use ventoy to create a multi-boot usb and be able to use the usb to save file at the same time.
- Plug the usb into the new machine and turn it on, pressing F2 (or any key according to the mainboard vendor) to get into UEFI settings. Enable any virtulization utilities, disable secure boot. Change the boot sequence to first boot from usb.

Now, if everything goes well, you should be in arch live environment with a shell prompt on your screen.

## Installation

- List fonts available in console with `ls /usr/share/kbd/consolefonts/ter-* | less`, and choose one using *setfont* like `setfont ter-128b`.
- Backup the pacman mirror list to prevent new file overwriting it after getting internet connection by `cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.back`.
- Ensure your network interface is listed and enabled. Check detected interface with `ip link` (it's likely to be called 'wlan0'), and then do `ip link set interface_name up`.
- If using Ethernet, plug in the netcable.
- If using wifi, use *iwctl*. Do `station list` in *iwctl* to get station name, then do `station station_name scan` and `station station_name connect network_name`, then type in the password accordingly (note that the password won't appear on the screen when typing). Quit *iwctl* after connecting to wifi router.
- Start dhcpcd daemon, `systemctl start dhcpcd`.Wait for 5 seconds and then ping a website to check internet connection.
- Synchronize time, `timedatectl`, then set up NTP service, `timedatectl set-ntp true`.
- Partition the disk with fdisk. 
    - First use `fdisk -l` to check recognized storage devices.
    - Use `fdisk /dev/your_device` to edit the partition table of a device.Press `m` to get help.
    - Press `n` to create a boot partition. Allocate 1G of space is recommended.
    - Press `n` to create a root partition. Allocate a lot of the space.
    - If you are gonna install a Windows vitual machine, it's probably better to have a seperate partition just for windows, so you can do hard disk passthrough. Press `n` to create the last partition.
    - Press `w` to write the change into the device. Since we will use *swapfile* and *btrfs*, swap partition won't be needed.
- Format the partitions.
    - For boot partition, use *FAT32*,`mkfs.fat -F 32 /dev/your_device1`
    - For root partition, use *btrfs*, `mkfs.btrfs -L root /dev/your_device2`, assuming the second partition is the root partition.
    - If dual boot with Windows, use the same EFI partition, create only the root partition for linux.
- Mount the newly created file systems.`mount /dev/your_device2 /mnt` then `mount --mkdir /dev/your_device1 /mnt/boot`.
- Make a swapfile. Since we are using btrsfs, it needs to be done this way: `btrfs subvolume create /mnt/swap`, then `btrfs filesystem mkswapfile --size 64g(ram size) --uuid clear /mnt/swap/swapfile`, then `swapon /mnt/swap/swapfile`.
- Edit `/etc/pacman.d/mirrorlist.back` and put THU's mirror on top, and then replce the `mirrorlist` file with `mirrorlist.back`.
- Install some basic packages (and the kernel, which is linux-zen kernel here) to the new machine with `pacstrap -K /mnt base base-devel linux-zen linux-firmware intel(amd)-ucode networkmanager iwd dhcpcd neovim vim man-db man-pages zsh btrfs-progs tmux yazi fd ripgrep jq poppler zoxide ffmpegthumbnailer imagemagick git fzf 7zip unzip tesseract-data-eng tesseract-data-chi_sim zathura zathura-cb zathura-djvu zathura-pdf-mupdf openssh pacman-contrib usbutils ufw sshfs imv mpv thunar gvfs thunar-media-tags-plugin thunar-archive-plugin xarchiver thunar-volman tumbler tree`
- Generate fstab file for `init` to mount your disk upon booting: `genfstab -U /mnt >>/mnt/etc/fstab`.
- Chroot into the new system with `arch-chroot /mnt`.
- Check the timezone available: `ls /usr/share/zoneinfo`, and then set the timezone, `ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime`.Then do `hwclock --systohc`.
- Edit `/etc/locale.gen` and uncomment all the locales you want to use. Basically `en_US.UTF-8 UTF-8` and `zh_CN.UTF-8 UTF-8`. Then run `locale-gen`. Create `/etc/locale.conf` and add `LANG=en_US.UTF-8` to set the console language to english.
- Edit `/etc/hostname` and add `yourhostname` to name the machine.
- Set root password with `passwd`.
- Install *GRUB2*:
    - `pacman -S grub efibootmgr`;
    - `grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB`;
    - If dual boot with Windows, further install *os-prober* and edit `/etc/default/grub` to uncomment the line `GRUB_DISABLE_OS_PROBER=false`.
    - Edit other things in `/etc/default/grub` if you want. For example, set countdown time to 0 or let grub remeber last boot entry used.
    - Generate gurb config file: `grub-mkconfig -o /boot/grub/grub.cfg`.
    - Exit the arch-chroot environment, unmount everything with `umount /mnt/boot` and `umount /mnt`, then `reboot` and unplug your usb drive.

## Post Installation Configuration

### console stuff

- Create a new user and give it sudoer power. `usradd -m -G wheel -s /usr/bin/zsh yourusername`. Then `passwd yourusername`. Then, add symbolic link `ln -s /usr/bin/nvim /usr/bin/vi`, do `visudo` and give group *wheel* sudoer previledge.
- Set *agetty* to only prompt password requirements for default user to login in tty1 like [this](https://wiki.archlinux.org/title/Getty#Prompt_only_the_password_for_a_default_user_in_virtual_console_login).
- Use *NetworkManager* and `nmcli` to connect to Internet. Enable NetworkManager service.
- If using Windows dual boot, set Windows time so it's compatible with the linux way like [this](https://wiki.archlinux.org/title/Dual_boot_with_Windows#Time_standard).
- Add *archlinuxcn* source to pacman sources. See [this](https://mirrors.tuna.tsinghua.edu.cn/help/archlinuxcn/) for help.
- Install *dae* for proxy. The config file is located at `/etc/dae/config.dae`. Use `dae reload` or `dae suspend` to control proxy or reload after changing config. Check [specific notes](./usages.md#dae) for *dae*.
- Install *yay*.
- Install *kbct-git* with yay and create a config file for it. Check [specific notes](./usages.md#kbct) for *kbct*.
- Install *antigen* with yay. In `~/.zshrc` add `source /usr/share/zsh/share/antigen.sh`, and then edit the file according to [upstream instructions](https://github.com/zsh-users/antigen?tab=readme-ov-file#usage).
- Install userspace tool for hardware settings, backlight control, audio server, bluetooth control, acpi status:
    - Install *brightnessctl*.
    - Install *acpi*.
    - Install *bluez*,*bluez-utils*, then enable `bluetooth.service`.
    - Install *pipewire*, *pipewire-pulse*, *pipewire-jack*, *pipewire-alsa*, *pipewire-audio*, *pavucontrol*, *wireplumber*, *qpwgraph*. Now you can use *pactl* cli tool to adjust volume.
    - Install *powertop*, *thermald*(optional), *auto-cpufreq*(optional).
    - Install *btop*, *nvtop*, *neofetch*.
    - Install *cups*, then enable *cups.service* for printer control.
- Configure *zsh* with *antigen*.
- Configure *nvim* with input method switch functions and other stuff. Install *tree-sitter-grammars*.
- Add an ssh key for this machine.

### GUI stuff

- Install [fonts](./usages.md#fonts).
- Install [driver](./usages.md#graphical-drivers) for graphic cards. For nvidia, tune runtime d3 if available.
- Install *xdg-user-dirs* and config it according to [wiki](https://wiki.archlinux.org/title/XDG_user_directories) so later the directoires can be managed without a headache. Remember you need to not only change the directories in the config file but also manually move the original dirs to the place you want to put them, or else it will just clean the dirs set in the config file. Also, if you find any applications shitting in your home directory later, you can create a user desktop file with `env HOME=somewhereHidden some_shitty_app` to change the home directory the app sees (remeber to soft link all the config files under real home to the fake one, with `find ~/ -maxdepth 1 -name ".*" ! -name "." ! -name ".." -exec ln -s {} . \;`). These methods can help keeping home directory clean.
- Install hyprland according to [hyprlnd wiki](https://wiki.hyprland.org/Getting-Started/Master-Tutorial/).If you intend to use Nvidia GPU for Hyprland (it doesn't matter if you are just using Nvidia GPU for other programs but not the compositor), follow the specific instruction of [nvidia page](https://wiki.hyprland.org/Nvidia/), install *nvidia-dkms* along with *linux-zen-headers*, *dkms*, rather than *nvidia* to avoid the need to build *initramfs* everytime the kernel and *nvidia* updates. To install *nvidia-dkms*, one should also consider these [instructions](https://wiki.archlinux.org/title/Dynamic_Kernel_Module_Support#Installation). Then you can just follow the wiki of hyprland and do nothing else.
- Install input method: *fcitx5-im*, *fcitx5-chinese-addons*.
- Install *blueman*,*network-manager-applet* for bluetooth and network applets.
- For hyprland desktop environment: install *nwg-displays*, *hypridle*, *hyprlock*, *hyprpaper*, *swaync*, *xdg-desktop-portal-hyprland*, *polkit-gnome*, *qt5-wayland*, *qt6-wayland*, *grim*, *slurp*, *waybar*, *rofi-wayland*, *cliphist*, *wlogout*, *wev*.
- Configure the autostart applications. 
    - The first way is to do it from *hyprland* configuration file with `exec-once` functionality.
    - The second way is to use user space *systemd* files.
- Install *firefox* as default web browser and make sure hardware video accelaration is enabled.
- Install *yt-dlp* and *parabolic-gtk(aur)* for video download, or as an alternative, "video download helper" firefox extension with *vdhcoapp(AUR)*.
