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
- 在目标磁盘中只安装可进入 chroot 并运行 chezmoi/pyinfra 的最小系统。内核仍由人在 pacstrap 阶段选择；以下示例使用 linux-zen。`nvim`用于编辑首次生成的机器配置和`visudo`：
    - `pacstrap -K /mnt base linux-zen linux-firmware sudo git openssh chezmoi uv python neovim`；

### 在 chroot 中由 chezmoi 与 pyinfra 完成系统

- 进入目标系统：`arch-chroot /mnt`；
- 设置root密码，以便进行本机维护和故障恢复：`passwd`；
- 创建临时使用Bash的普通用户并设置密码：
    ```sh
    useradd -m -G wheel -s /bin/bash pingzi
    passwd pingzi
    ```
- 使用原生`visudo`开启wheel组的sudo权限：
    ```sh
    ln -sf /usr/bin/nvim /usr/bin/vi
    visudo
    ```
    找到`%wheel ALL=(ALL:ALL) ALL`并删除行首注释。
- 切换到普通用户并拉取、应用配置：
    ```sh
    su - pingzi
    chezmoi init --apply https://github.com/YWh0301/dotfiles.git
    ```
- 首次运行会创建`~/.config/chezmoi/user.toml`并中止。使用`nvim ~/.config/chezmoi/user.toml`检查hostname、机器类型、时区、locale、Feature、代理与软件包Profile，然后再次运行`chezmoi apply`。
- 完成后退出并重启：
    ```sh
    exit
    exit
    umount -R /mnt
    reboot
    ```

## 第一次正常启动后

- 为保险起见，可以登录后再运行一次`chezmoi apply`检查并补齐配置。

### 针对应用进行用户空间设置

- 对firefox进行手动配置：
    - 登录*Mozilla*账号同步设置
        - 安装插件
        - 设置硬件视频解码
    - 为*github.com*添加*ssh*公钥
        - 拷贝已经由*chezmoi*脚本创建好的公钥：`echo ~/.ssh/id_ed25519.pub | wl-copy`
        - 按下默认`Alt_L+w`快捷键启动*firefox*，登录*github.com*（需要Authenticator给出2FA TOPT token），在设置 -> SSH and GPG keys -> New SSH key粘贴新机器的公钥；
- 配置*pCloud Drive*：
    - 手动登录，注意登录过程需要为*pcloud*开启代理，并提前准备好账号、密码以及2FA代码快速输入，否则可能登录超时导致失败
    - 将`$HOME/.config/reference/pcloud/sync_exclusion.txt`中的内容复制到*pcloud-drive*应用中的*Settings -> Exclusions*中排除文件的位置，点击*Apply*

### 尚未由pyinfra管理的Snapper设置

`features.snapper`目前只控制`snapper`软件包是否安装，以下Btrfs快照配置仍需手动完成：

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
