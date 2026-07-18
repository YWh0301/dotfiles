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
- 切换到普通用户，以认证Bootstrap拉取并应用配置。原生`chezmoi init`会在验证Git签名之前解析仓库模板，因此不能直接用于首次拉取：
    ```sh
    su - pingzi
    git clone https://github.com/YWh0301/dotfiles.git d && \
      (cd d; B=$(chezmoi age decrypt -p b) && eval "$B")
    ```
  `b`是由高熵Passphrase认证加密的Bootstrap。它只在完整解密成功后运行，验证`main`的Commit CA签名，把临时仓库移动到`$(chezmoi source-path)`，安装仓库外的chezmoi验证Wrapper，然后才调用真正的`chezmoi init --apply`。明文Bootstrap只存在于Subshell内存，Subshell结束后自动消失。
- 首次Bootstrap依次只要求一次仓库HTTPS密码（当前GitHub Public阶段不需要）、一次age解密密码和一次共享CA密码。共享CA密码在内存中复用于相互独立的SSH User CA、Dotfiles Commit CA与Personal Git Commit CA，不写入命令行、环境变量或磁盘。
- Bootstrap会创建`~/.config/chezmoi/user.toml`并自动打开编辑器。检查hostname、机器类型、时区、locale、Feature、代理与软件包Profile；保存退出后Bootstrap会自动继续第二次Apply。
- `features.git_commit_signing`默认为`true`：为本机生成独立、无Passphrase且不能用于SSH登录的Dotfiles Commit叶子Key，由Dotfiles Commit CA签发证书，并在此仓库的`.git/config`中开启自动Commit/Tag签名。改为`false`后，下一次Apply会删除本机Commit证书并关闭自动签名；普通叶子Key保留以便以后重新启用。无论该Feature是否开启，chezmoi Wrapper都会继续拒绝未被Dotfiles Commit CA签名的源码状态，因此关闭它的机器只能安全消费配置，不能向受保护的`main`贡献合法Commit。
- `git.general_commit_signing`默认为`true`：使用相互独立的Personal Git Commit CA为本机签发`pingzi-git`叶子证书。`git.signed_origin_patterns`选择需要该策略的远端；当前同时匹配`git@github.com:YWh0301/**`和`https://github.com/YWh0301/**`，未来可追加自建Git的稳定SSH别名。匹配仓库中的普通`git commit`、`git tag`和Merge默认自动签名。
- `git.signature_policy`支持`warn`、`ask`和`enforce`。迁移期默认为`ask`：可信Hook会在Clone/Checkout、Commit、Merge/Pull、Rewrite和Push时检查当前或将要推送的Tip；旧仓库缺少可信签名时会显示醒目警告，并在有TTY时询问`[y/N]`。非交互任务仍按警告处理，避免突然破坏既有自动化；`enforce`才会无条件返回失败。Checkout、Merge等Post Hook发生时工作区可能已经更新，回答`N`会让Git命令返回失败但不会自动回滚，必须先检查`git log -1 --show-signature`。仓库自己的额外Hook可放在`.git/hooks-local/`，由可信Hook在签名检查后继续调用。
- 完成后退出并重启：
    ```sh
    exit
    exit
    umount -R /mnt
    reboot
    ```

## 第一次正常启动后

- 为保险起见，可以登录后再运行一次`chezmoi apply`检查并补齐配置。

### 已验证的日常操作

正常使用方式不变：

```sh
git -C "$(chezmoi source-path)" commit -m '...'
git -C "$(chezmoi source-path)" pull
chezmoi apply
```

当`features.git_commit_signing = true`时，Commit和Tag自动签名且不提示密码。`~/.local/bin/chezmoi`会在解析任何模板或执行任何Run Script前验证当前`HEAD`；如需在验证失败时只检查仓库，请直接使用`git -C "$(chezmoi source-path)" status`和`git log -1 --show-signature`。不要用`/usr/bin/chezmoi`绕过Wrapper。

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
