# 系统安装与配置完全指南

## 介绍

这是一份从零开始在新设备上安装我的Arch Linux Setup的指南。内容包括系统安装、系统设置、软件包安装、用户空间配置文件以及云文件同步等内容。

我的习惯配置如下：

- Arch Linux
- Wayland
- Hyprland
- zsh
- kitty
- yazi
- firefox
- neovim
- waybar
- rofi

使用时可以参考[Arch Wiki](https://wiki.archlinux.org/title/Installation_guide)。

## 安装前准备

- 如果需要进行双系统安装，则一般先安装Windows系统。注意安装Windows系统时需要进入命令行设置2G大小的Boot分区。安装好Windows系统后，在Windows硬盘管理中压缩出一块格式化好的硬盘分区以备Linux系统的安装；
- 到[Archlinux 镜像下载站](https://archlinux.org/download/)或者[清华镜像](https://mirrors.tuna.tsinghua.edu.cn/archlinux/iso/2024.09.01/)下载Archlinux U盘安装介质ISO文件；
- 确保安装过程中有稳定的英文SSID与密码的WiFi连接或者可用的有线以太网连接；
- 获取一个有足够大FAT32文件系统格式分区的U盘；
- 确保需要安装的新设备使用UEFI启动；
- 如果使用Windows，可以使用*rufus*创建U盘安装介质；
- 如果使用Linux：
    - `sudo mount /dev/device_partition /mount_point` 挂载U盘FAT32分区；
    - `sudo bsdtar -x -f archlinux-version-x86_64.iso -C /mount_point`，可以参考[wiki](https://wiki.archlinux.org/title/USB_flash_installation_medium#In_GNU/Linux_4)；
    - 或者使用ventoy创建自带引导的多安装介质U盘；
- 在新设备中插入U盘后启动设备。确保在设备启动过程中按下相应键盘按键（一般是F1/F2/Esc/Delete等）使得设备进入UEFI设置页面。在设置界面中启动所有虚拟化支持相关项目，关闭Secure Boot安全启动项目，而后调整启动项使得U盘位于第一位。

如果一切顺利，应该可以进入Archlinux的Live环境，看见Shell提示符。

## 系统安装

- 在Console中列出可选的字体`ls /usr/share/kbd/consolefonts/ter-* | less`后使用*setfont*选择字体`setfont ter-128b`；
- 备份pacman镜像站点列表，防止联网后该列表被覆盖`cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.back`；

### 连接网络

- 确保网卡被检测到且已经启动。使用`ip link`查看网卡信息（如果是无线网络，大概率名称为“wlan0”），而后确保网卡开启`ip link set interface_name up`；
- 如果使用有线网络，插入网线；
- 如果使用无线网络，输入`iwctl`命令使用*iwd*工具。在*iwctl*中输入`station list`列出station名称，并输入`station station_name scan`扫描网络。输入`station station_name connect network_SSID`之后在提示中输入网络密码（注意密码输入的时候屏幕中没有变化是正常的）来连接无线网络。连接成功后输入`quit`推出*iwd*控制工具；
- `systemctl start dhcpcd`启动*dhcpcd*，等待5秒后`ping bing.com`检查网络是否成功连接；
- `timedatectl`同步时间，并`timedatectl set-ntp true`设置NTP服务；

### 磁盘分区与格式化

- 使用*fdisk*工具进行磁盘分区
    - `fdisk -l`查看预计按装系统的磁盘；
    - `fdisk /dev/your_device`编辑该磁盘分区表（按`m`查看帮助信息）；
    - 如果设备本身有分区表，但希望格式化设备，可以按`g`创建新分区表；
    - 按`n`创建新的*boot*分区。分配 2G 空间。注意如果安装Windows双系统，则不需要单独创建*boot*分区，而在之后使用Windows的EFI分区；
    - 按`n`创建新的*root*分区。分配剩余空间；
    - 如果需要安装Windows虚拟机，则可以单独分配一个分区，使得虚拟机可以使用专门的硬盘分区来进行硬盘直通获得更好的性能。
    - 按`w`来写入分区表；
- 格式化分区：
    - 使用*FAT32*格式化*boot*分区`mkfs.fat -F 32 /dev/your_device1`；
    - 使用*btrfs*格式化*root*分区`mkfs.btrfs -L root /dev/your_device2`（此处假设第二个分区为*root*分区）；
- 挂载分区：
    - 先`mount /dev/your_device2 /mnt`；
    - 而后`mount --mkdir /dev/your_device1 /mnt/boot`；
- 在*btrfs*文件系统中创建交换文件，大小为内存大小：
    - `btrfs subvolume create /mnt/swap`
    - `btrfs filesystem mkswapfile --size 64g(ram size) --uuid clear /mnt/swap/swapfile`
    - `swapon /mnt/swap/swapfile`.

### 拉取软件包

- 使用*vim*编辑镜像列表备份文件`vim /etc/pacman.d/mirrorlist.back`，找到THU清华镜像源后放到最顶部，并覆盖*mirrorlist*文件`:w! /etc/pacman.d/mirrorlist`；
- 在新机器的磁盘当中安装基础软件包与linux-zen内核
    - `pacstrap -K /mnt base base-devel linux-zen linux-zen-headers linux-firmware (intel/amd)-ucode efibootmgr networkmanager git pacman-contrib iwd zsh yazi neovim`；
    - 如果安装双系统，安装*os-prober* `pacstrap -K /mnt os-prober`；

### 新系统设置

- 为*init*进程生成磁盘挂载指示文件*fstab*：`genfstab -U /mnt >>/mnt/etc/fstab`；
- chroot到新系统中：`arch-chroot /mnt`；
- 查看并设置时区：`ls /usr/share/zoneinfo`而后`ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime`，并且`hwclock --systohc`；
- 使用*neovim*编辑*locale*文件，`nvim /etc/locale.gen`将所有想要使用的locale设定前的注释删除。一般而言是`en_US.UTF-8 UTF-8`与`zh_CN.UTF-8 UTF-8`两项。而后运行`locale-gen`并向`/etc/locale.conf`加入`echo "LANG=en_US.UTF-8" >> /etc/locale.conf`设置*console*环境语言。
- 向`/etc/hostname`写入该机器的*hostname*：`echo "yourhostname" >> /etc/hostname`；
- 设置*root*用户的密码`passwd`；

### 安装Bootloader

#### 选择一：使用GRUB2

- `pacman -S grub`；
- `grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB`；
- 如果安装Windows双系统，编辑`nvim /etc/default/grub`并将其中`GRUB_DISABLE_OS_PROBER=false`一行前的注释去除；
- 编辑其他`/etc/default/grub`中有价值的内容
    - 一种双系统的良好实践是，设置`GRUB_DEFAULT=0`使得系统默认启动Linux，同时设置`GRUB_TIMEOUT=0`避免选择窗口出现，然后先运行一次下方的`grub-mkconfig`；
    - 而后查看生成的配置文件中Windows条目的ID：`grep "Windows" /boot/grub/grub.cfg | grep -o "osprober-efi-[^']*"`，返回应该类似于“osprober-efi-8202-EB9C”；
    - 在`/etc/grub.d/40_cunstom`文件的末尾加入，其中“osprober”部分替换为获得的Windows条目ID
        ```
        if keystatus --shift ; then
            set default="osprober-efi-8202-EB9C"
        else
            set default="0"
        fi
        ```
    - 重新生成GRUB的配置文件：`grub-mkconfig -o /boot/grub/grub.cfg`；
    - 此后双系统默认进入Linux系统，在开机启动过程中若长安*Shift*键则进入Windows系统
- 生成GRUB的配置文件：`grub-mkconfig -o /boot/grub/grub.cfg`；
- 退出*chroot*环境`exit`，卸载所有挂载的磁盘`umount /mnt/boot`与`umount /mnt`后重启`reboot`并拔下U盘，完成基本安装。

#### 选择二：使用systemd-boot

- 使用`ls /sys/firmware/efi/efivars`并确认目录存在来确定使用了UEFI启动；
- 运行`bootctl install`；
- 编辑`nvim /boot/loader/loader.conf`，比如设置
    ```
    default  zen_arch.conf
    timeout  0
    ```
- 编辑`nvim /boot/loader/entries/zen_arch.conf`，并加入：
    ```
    title   Zen Arch Linux
    linux   /vmlinuz-linux-zen
    initrd  /initramfs-linux-zen.img
    ```
- 获取根分区UUID并加入条目配置：`echo "options root=UUID=$(blkid -s UUID -o value $(findmnt -no SOURCE /)) rw quiet splash loglevel=3 vt.global_cursor_default=0 systemd.show_status=0" | tee -a /boot/loader/entries/zen_arch.conf`；
- 运行`bootctl`检查配置文件正确性；
- 退出*chroot*环境`exit`，卸载所有挂载的磁盘`umount /mnt/boot`与`umount /mnt`后重启`reboot`并拔下U盘，完成基本安装。

## 安装后操作

- 如果安装了Windows双系统，将Windows系统时间设置[调整到与Linux的方式相同](https://wiki.archlinux.org/title/Dual_boot_with_Windows#Time_standard)；

### 创建新用户

- `useradd -m -G wheel -s /usr/bin/zsh yourusername`;
- `passwd yourusername`设置密码；
- `ln -s /usr/bin/nvim /usr/bin/vi`；
- `visudo`找到`%wheel ALL=(ALL:ALL) ALL`一行把注释去掉。

### 设置自动登录

- 创建目录`mkdir /etc/systemd/system/getty@tty1.service.d/`；
- 编辑文件`nvim /etc/systemd/system/getty@tty1.service.d/autologin.conf`：
    ```
    [Service]
    ExecStart=
    ExecStart=-/sbin/agetty --skip-login --nonewline --noissue --autologin yourusername --noreset --noclear - ${TERM}
    ```

### 安装必要软件包

- 连接网络
    - 启用*NetworkManager*`systemctl enable --now Networkmanager`
    - `nmcli d wifi connect "WiFiSSID" password "WiFiPassword"`
- 添加*archlinuxcn*仓库
    - 参考[清华源指南](https://mirrors.tuna.tsinghua.edu.cn/help/archlinuxcn/)；
    - 在`/etc/pacman.conf`末尾加入
        ```
        [archlinuxcn]
        Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch
        ```
    - 运行`pacman -Sy archlinuxcn-keyring`加载密钥；
- 安装*dae*实现透明代理
    - `pacman -S dae`；
    - `systemctl enable --now dae`；
    - 编辑`cp /etc/dae/config.dae.example /etc/dae/config.dae`后`nvim /etc/dae/config.dae`；
        - 主要编辑*subscription*、*group*和*routing*部分；
        - group示例如下：
            ```
            group {
              hongkong {
                filter: name(keyword: '香港')
                policy: min_moving_avg
              }
              us {
                filter: name(keyword: '美国')
                policy: min_moving_avg
              }
            }
            ```
        - 对于终端无法中文输入‘香港’与‘美国’，使用在nvim输入模式下先按`Ctrl+V`，再按顺序按`u9999`重复`Ctrl+V`后`u6e2f`来输入‘香港’两个字与使用`u7f8e`和`u56fd`输入‘美国’的方法输入；
        - routing的示例如下：
            ```
            routing {
              pname(NetworkManager) -> direct
              pname(pcloud) -> direct
              pname(spotify) -> direct
              dip(224.0.0.0/3, 'ff00::/8') -> direct
              l4proto(udp) && dport(443) -> block
              dip(geoip:private) -> direct
              dip(geoip:cn) -> direct
              domain(geosite:cn) -> direct
              domain(suffix:pku.edu.cn) -> direct
              domain(suffix:pcloud.com) -> direct
              domain(suffix:spotify.com) -> direct

              fallback: us
            }
            ```
        - 配置完毕运行`dae reload`
        - 检测网络连接`ping pornhub.com`
- 安装*yay-bin*
    - `su yourusername`切换到普通用户执行命令，按`q`跳过*zsh*初始化的提示；
    - `cd`；
    - `git clone https://aur.archlinux.org/yay-bin.git`；
    - `cd yay-bin`；
    - `makepkg -si`;
    - `cd && rm-rf yay-bin`清理文件；
- 所需的软件包
    - `sudo pacman -S --needed dkms evtest wev less tree curl wget lsof strace ltrace usbutils chezmoi sshfs openssh exfatprogs btrfs-progs acpi btop cups pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse alsa-utils ufw socat bluez bluez-utils hyprland qt5-wayland qt6-wayland qt6ct xdg-desktop-portal-hyprland polkit-gnome xdg-user-dirs hypridle hyprlock hyprpaper rofi waybar hyprpicker swaync grim slurp swappy cliphist nwg-displays nwg-look blueman pavucontrol network-manager-applet kitty tmux wqy-microhei wqy-zenhei awesome-terminal-fonts ttf-jetbrains-mono-nerd thunar noto-fonts thunar-archive-plugin xarchiver thunar-media-tags-plugin thunar-shares-plugin thunar-volman gvfs gvfs-mtp gvfs-nfs gvfs-smb 7zip jq fd fzf ripgrep ffmpegthumbnailer zoxide fcitx5 fcitx5-chinese-addons fcitx5-configtool fcitx5-gtk fcitx5-qt bat picocom screen uv rustup python gdb ncmpcpp imv mpv zathura zathura-cb zathura-djvu zathura-pdf-poppler poppler imagemagick pandoc-bin libtiff5 calibre libreoffice-fresh firefox aichat`；
    - 如果使用笔记本，安装相应软件包`pacman -S brightnessctl powertop thermald`；
    - `rustup default stable`下载工具链，为后续要用到的软件安装做准备；
    - `yay -S systemd-boot-pacman-hook kbct-git antigen pcloud-drive nvim-lazy vivify wps-office-cn wps-office-mui-zh-cn ttf-wps-fonts vdhcoapp-bin`；
    - 安装所需的GPU驱动
        - 详情参见[ArchWiki](https://wiki.archlinux.org/title/Xorg#Driver_installation)。
        - 针对Nvidia的新款显卡，安装*nvidia-dkms*、*nvidia-utils*、*nvtop*、*nvidia-prime*;
        - 针对Intel或者AMD的显卡，安装*mesa*、*mesa-utils*，然后分别安装*vulkan-intel*、*vulkan-radeon*

### 进入桌面环境

- `exit && exit`并自动登录到*yourusername*，按`q`忽略zsh提示，运行`Hyprland`进入桌面环境；












    - 生成*ssh key*：`ssh-keygen -t ed25519 -C "yuwenhao@stu.pku.edu.cn"`，默认回车直到生成密钥；
