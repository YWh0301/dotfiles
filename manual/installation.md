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
- swaync
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
    - 使用*FAT32*格式化*boot*分区`mkfs.fat -F 32 /dev/your_device1`（如果使用Windows系统的EFI分区则不要在此处格式化）；
    - 使用*btrfs*格式化*root*分区`mkfs.btrfs -L root /dev/your_device2`（此处假设第二个分区为*root*分区）；
- 挂载分区：
    - 先`mount /dev/your_device2 /mnt`；
    - 为之后的系统快照功能创建*btrfs*子卷：
        - `btrfs subvolume create /mnt/@`，使用单独子卷而非顶层子卷作为日后的根节点
        - `btrfs subvolume create /mnt/@swap`，创建交换文件使用的子卷
        - `btrfs subvolume create /mnt/@snapshots`，平铺布局，自定义用于快照存放的子卷
        - `btrfs subvolume create /mnt/@home`，家目录不进入系统快照
        - 保障`/var/lib/pacman`被快照保存，但剔除其他可以不进入系统快照的目录
            - `btrfs subvolume create /mnt/@var_log`
            - `btrfs subvolume create /mnt/@var_cache`
            - `/var/lib/docker`：*Docker*、`/var/lib/machines`：*systemd-nspawn*、`/var/lib/postgres`：*PostgreSQL*等可以按需处理
    - 重新挂载
        - `umount /mnt`
        - `mount -o subvol=@,noatime /dev/your_device2 /mnt`
    - 处理交换文件
        - `mount -o subvol=@swap,nodev,nosuid,noexec,noatime --mkdir /dev/your_device2 /mnt/swap`；
        - `btrfs filesystem mkswapfile --size 64g(ram size) --uuid clear /mnt/swap/swapfile`
        - `swapon /mnt/swap/swapfile`.
    - 挂载其余子卷
        - `mount --mkdir /dev/your_device1 /mnt/boot`；
        - `mount -o subvol=@snapshots,nodev,nosuid,noexec,noatime --mkdir /dev/your_device2 /mnt/.snapshots`
        - `mount -o subvol=@home,noatime --mkdir /dev/your_device2 /mnt/home`
        - `mount -o subvol=@var_log,noatime --mkdir /dev/your_device2 /mnt/var/log`
        - `mount -o subvol=@var_cache,noatime --mkdir /dev/your_device2 /mnt/var/cache`
    - 设置*btrfs*子卷的参数：
        - `btrfs property set /mnt compression zstd:3`
        - `btrfs quota enable /mnt`
        - `btrfs property set /mnt/home compression zstd:3`
        - `btrfs property set /mnt/var/log compression zstd:1`
        - `btrfs property set /mnt/var/cache compression none`
        - `btrfs property set /mnt/.snapshots compression zstd:3`

### 拉取软件包

- 使用*vim*编辑镜像列表备份文件`vim /etc/pacman.d/mirrorlist.back`，找到THU清华镜像源后放到最顶部，并覆盖*mirrorlist*文件`:w! /etc/pacman.d/mirrorlist`；
- 在新机器的磁盘当中安装基础软件包与linux-zen内核
    - `pacstrap -K /mnt base base-devel linux-zen linux-zen-headers linux-firmware (intel/amd)-ucode efibootmgr networkmanager git bash zsh openssh yazi neovim chezmoi dialog`；

### 新系统设置

- 为*init*进程生成磁盘挂载指示文件*fstab*：`genfstab -U /mnt >>/mnt/etc/fstab`；
- chroot到新系统中：`arch-chroot /mnt`；
- 查看并设置时区：`ls /usr/share/zoneinfo`而后`ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime`，并且`hwclock --systohc`；
- 使用*neovim*编辑*locale*文件，`nvim /etc/locale.gen`将所有想要使用的locale设定前的注释删除。一般而言是`en_US.UTF-8 UTF-8`与`zh_CN.UTF-8 UTF-8`两项。而后运行`locale-gen`并向`/etc/locale.conf`加入`echo "LANG=en_US.UTF-8" >> /etc/locale.conf`设置*console*环境语言。
- 向`/etc/hostname`写入该机器的*hostname*：`echo "yourhostname" >> /etc/hostname`。其中，*hostname*应当和此台机器的硬件相关联，因为系统用户配置文件使用*chezmoi*管理，其中的模板根据机器的*hostname*生成每台机器特定的配置文件；
    - 如果此台机器为笔记本电脑，其*hostname*应当以`Laptop`结尾；
    - 如果此台机器为台式机，其*hostname*应当以`Desktop`结尾；
    - 如果需要更改*hostname*：`sudo hostnamectl set-hostname "your_new_hostname"`；
- 设置*root*用户的密码`passwd`；

### 安装Bootloader

#### 选择一：使用GRUB2

- `pacman -S grub`；
    - 如果安装双系统，安装*os-prober* `pacman -S os-prober`；
- `grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB`；
- 编辑`/etc/default/grub`中有价值的内容
    - `GRUB_DEFAULT=0`仅一个*Linux*启动项情况下默认*Linux*启动
    - `GRUB_TIMEOUT=0`可以设置GRUB按照最短时间启动
        - 设置`GRUB_TIMEOUT_STYLE=menu`
        - 在`/etc/grub.d/40_cunstom`文件的末尾加入
            ```
            if keystatus --ctrl ; then
                set timeout=-1
            fi
            ```
        - 这种配置使得开机过程中长按*Ctrl*键即可显示菜单，否则菜单默认关闭
    - `GRUB_CMDLINE_LINUX_DEFAULT="rootflags=subvol=@ rw quiet splash loglevel=3 vt.global_cursor_default=0 systemd.show_status=0"`设置常用内核启动参数与根子卷
    - 如果安装Windows双系统，将其中`GRUB_DISABLE_OS_PROBER=false`一行前的注释去除；
        - 一种双系统的良好实践是判断启动时键盘的*Shift*有没有被按下决定是否启动Windows；
        - 先运行一次`grub-mkconfig -o /boot/grub/grub.cfg`；
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
        - 此后双系统默认进入Linux系统，在开机启动过程中若长按*Shift*键则进入Windows系统
- 生成GRUB的配置文件：`grub-mkconfig -o /boot/grub/grub.cfg`；
- 退出*chroot*环境`exit`，卸载所有挂载的磁盘`umount -R /mnt`后重启`reboot`并拔下U盘，完成基本安装。

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
- 获取根分区UUID并加入条目配置：`echo "options root=UUID=$(blkid -s UUID -o value $(findmnt -no SOURCE /)) rootflags=subvol=@ rw quiet splash loglevel=3 vt.global_cursor_default=0 systemd.show_status=0" | tee -a /boot/loader/entries/zen_arch.conf`；
    - 注意，由于我们使用的根位于单独子卷，且并不是*root*设备的默认子卷，因此在条目中需要加入`rootflags=subvol=@`这一*option*
- 运行`bootctl`检查配置文件正确性；
- 退出*chroot*环境`exit`，卸载所有挂载的磁盘`umount -R /mnt`后重启`reboot`并拔下U盘，完成基本安装。

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

### 连接网络与代理

- 连接网络
    - 启用*NetworkManager*`systemctl enable --now NetworkManager`
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
    - 从archlinuxcn仓库安装*dae*`pacman -S dae`；
    - 可以先尝试直接进行下一步的加载用户配置从*Github*拉取*chezmoi*仓库，如果成功则可以在`$HOME/.config/reference/dae`中找到*dae*的参考配置
        - `sudo cp $HOME/.config/reference/dae/config.dae /etc/dae/config.dae`
        - `sudo chown root /etc/dae/config.dae`
        - `sudo chmod 0600 /etc/dae/config.dae`
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
    - `systemctl enable --now dae`；
    - 检测网络连接`ping pornhub.com`

### 加载用户配置

- `su yourusername`以用户身份登录，按`q`忽略zsh提示，`cd`切换到家目录
- `chezmoi init https://github.com/YWh0301/dotfiles.git`，输入*chezmoi*配置仓库密码；
- `chezmoi apply`将配置仓库应用到本台计算机
    - 可以预先对配置仓库中*.tmpl*结尾模板文件中分机器配置的项目进行检查
    - 可选使用`chezmoi apply --interactive`交互式地应用配置文件

### 安装软件包

- 安装yay
    1. archlinuxcn中维护了yay二进制包，可以直接`pacman -S yay`
    2. 如果需要从AUR安装yay，可以安装二进制*yay-bin*：
        - `su yourusername`切换到普通用户执行命令，按`q`跳过*zsh*初始化的提示；
        - `cd`；
        - `git clone https://aur.archlinux.org/yay-bin.git`；
        - `cd yay-bin`；
        - `makepkg -si`;
        - `cd && rm-rf yay-bin`清理文件；
- 所需的软件包
    - 可以参考`($chezmoi source-path)/manual/installation.md`与`($chezmoi source-path)/manual/packages.md`进行安装；也可以使用`($chezmoi source-path)/scripts/installation.sh`脚本化必要包安装过程；
    - `sudo pacman -S --needed dkms evtest wev less tree wget lsof strace ltrace usbutils sshfs samba pacman-contrib iwd  bind exfatprogs btrfs-progs snapper acpi btop cups pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse alsa-utils ufw socat bluez bluez-utils hyprland qt5-wayland qt6-wayland qt5ct qt6ct xdg-desktop-portal-hyprland polkit-gnome xdg-user-dirs hypridle hyprlock hyprpaper rofi waybar hyprpicker swaync grim slurp swappy cliphist nwg-displays nwg-look blueman pavucontrol network-manager-applet kitty tmux wqy-microhei wqy-zenhei awesome-terminal-fonts ttf-jetbrains-mono-nerd thunar noto-fonts thunar-archive-plugin xarchiver thunar-media-tags-plugin thunar-shares-plugin thunar-volman gvfs gvfs-mtp gvfs-nfs gvfs-smb 7zip jq fd fzf ripgrep ffmpegthumbnailer zoxide fcitx5 fcitx5-chinese-addons fcitx5-configtool fcitx5-gtk fcitx5-qt bat picocom screen uv rustup python gdb cmake ncmpcpp imv mpv zathura zathura-cb zathura-djvu zathura-pdf-poppler poppler imagemagick pandoc-bin libtiff5 calibre libreoffice-fresh firefox aichat vdhcoapp`；
    - 如果使用笔记本，安装相应软件包`pacman -S brightnessctl powertop thermald auto-cpufreq`；
    - `yay -S antigen  nvim-lazy vivify wps-office-cn wps-office-mui-zh-cn ttf-wps-fonts`；
    - 安装*pCloud*客户端
        - 如果使用*pcloudcc*则安装`yay -S pcloudcc-lneely`，并在`($chezmoi source-path)/.chezmoi.toml.tmpl`中根据*hostname*配置*data.pcloud.client*参数为*pcloudcc*；
        - 如果使用*pcloud-drive*则安装`yay -S pcloud-drive`，并在`($chezmoi source-path)/.chezmoi.toml.tmpl`中根据*hostname*配置*data.pcloud.client*参数为*pcloud-drive*；
        - 修改`chezmoi.toml.tmpl`之后：
            - `chezmoi init --apply`
            - `git add .`、`git commit`、`git push`推到上游仓库
    - 如果使用systemd-boot作为bootloader，则`yay -S systemd-boot-pacman-hook`；
    - 安装所需的GPU驱动
        - 详情参见[ArchWiki](https://wiki.archlinux.org/title/Xorg#Driver_installation)。
        - 针对Nvidia的新款显卡，`sudo pacman -S nvidia-dkms nvidia-utils nvtop nvidia-prime egl-wayland libva-nvidia-driver libva-utils libvdpau-va-gl`；
        - 针对Intel或者AMD的显卡，安装`sudo pacman -S mesa mesa-utils vulkan-tools libva-utils libvdpau-va-gl`，然后分别安装`sudo pacman -S vulkan-intel intel-media-driver libvpl vpl-gpu-rt`、`sudo pacman -S vulkan-radeon`；
    - 安装*hyprland*相关插件
        - 将`$HOME/.local/chezmoi/pkgbuilds/`目录下的*hyprland*插件相关安装脚本复制到临时目录，并分别运行`makepkg -si`

### 针对应用进行用户空间设置

- 对firefox进行手动配置：
    - 登录*Mozilla*账号同步设置
        - 安装插件
        - 设置硬件视频解码
    - 为*github.com*添加*ssh*公钥
        - 拷贝已经由*chezmoi*脚本创建好的公钥：`echo ~/.ssh/id_ed25519.pub | wl-copy`
        - 按下默认`Alt_L+w`快捷键启动*firefox*，登录*github.com*（需要Authenticator给出2FA TOPT token），在设置 -> SSH and GPG keys -> New SSH key粘贴新机器的公钥；
- 若使用*pcloudcc*，需要主动输入密码并配置：`pcloudcc -u youremail@mail.com -m $HOME/.misc/pCloudDrive -s`并输入密码；
    - 使用`-d`参数后台运行*pcloudcc*，而后使用`-k`参数进入REPL配置同步文件夹；
    - 其中，同步文件夹的`<remote-path>`为`$HOME/.misc/pCloudDrive`起始的路径；
- 若使用*pcloud-drive*：
    - 手动登录，注意登录过程需要为*pcloud*开启代理，并提前准备好账号、密码以及2FA代码快速输入，否则可能登录超时导致失败
    - 将`$HOME/.config/reference/pcloud/sync_exclusion.txt`中的内容复制到*pcloud-drive*应用中的*Settings -> Exclusions*中排除文件的位置，点击*Apply*

### 进行系统级别设置

- 开启自动时间校准：`sudo timedatectl set-ntp true`；
- 开启蓝牙服务：`sudo systemctl enable --now bluetooth`；
- 如果电脑为笔记本，需要电源管理：
    - 添加*systemd* service执行`powertop --auto-tune`；
    - 添加*systemd* service执行`auto-cpufreq`；
    - 添加*systemd* service执行`thermald`；
- 使用*snapper*与*btrfs*快照进行系统自动备份设置：
    - 先确保`/.snapshots`不存在，使得*snapper*新配置不冲突：
        - `sudo umount /.snapshots`
        - `sudo rmdir /.snapshots`
    - 添加新的快照设置：`snapper -c system create-config /`
    - 将*snapper*自动生成的子卷删除并重建对应目录：
        - `sudo btrfs subvolume delete /.snapshots`
        - `sudo mkdir /.snapshots`
        - `sudo chmod 750 /.snapshots`
        - `sudo mount /.snapshots`
- 如果需要启用*samba*服务器：
    - 将`$HOME/.local/share/chezmoi/.chezmoi.toml.tmpl`中针对本机的`data.samba.enable`设置为`true`
    - `sudo cp $HOME/.config/reference/samba/smb.conf /etc/samba/smb.conf`；如果处在开放的网络环境，应当编辑*chezmoi*的参考配置文件采用强制加密的*SMB3*以上协议
    - `sudo smbpasswd -a yourusername`，把当前用户同时也添加到*smb*用户并设定*smb*密码；建议使用存储在*Bitwarden*中的强密码
    - `sudo systemctl enable --now smb nmb`
    - `smbclient //localhost/HomeShare -U yourusername`测试本地访问是否可行
    - 使用*HomeShare*为共享名，*yourusername*为用户名连接
- 如果需要，启用*wayvnc*服务器：
    - 将`$HOME/.local/share/chezmoi/.chezmoi.toml.tmpl`中针对本机的`data.wayvnc.enable`设置为`true`
    - `chezmoi init`后`chezmoi apply`，自动在59900端口开启wayvnc服务
- 如果需要，启动*ssh*服务器：
    - `sudo cp $HOME/.config/reference/ssh/sshd_config /etc/ssh/sshd_config`；按照默认的规则，应当仅允许密钥连接
    - `sudo systemctl enable --now sshd`
