# 我的GNU/Linux系统中安装的软件包

## 基础软件包

### Arch Linux 系统基础

- `base`
    - *systemd*（包含在*base*中）
- `base-devel`
- `linux-zen`
- `linux-zen-headers`
- `linux-firmware`
- `(intel/amd)-ucode`
    - 根据所使用的CPU制造商决定微码软件包

#### Bootloader

- `efibootmgr`
1. 使用GRUB2
    - `grub`
    - `os-prober`
        - 如果需要安装双系统则需要安装
2. 使用systemd-boot
    - `systemd-boot`
    - `systemd-boot-pacman-hook`(AUR)

### 系统应用

- `dkms`
- `dae`(archlinuxcn)
- `evtest`
- `wev`
- `git`
- `less`
- `tree`
- `curl`
- `wget`
- `lsof`
- `strace`
- `ltrace`
- `usbutils`
- `chezmoi`
- `pacman-contrib`
- `archlinuxcn-keyring`(archlinuxcn)
- `yay`(archlinuxcn)

#### GPU驱动

- 参考Arch Wiki进行安装
    - `mesa`
        - `mesa-utils`
    - `nvidia-dkms`
        - `nvidia-prime`
        - `nvidia-utils`
        - `nvtop`
    - `vulkan-intel`

#### 文件系统功能

- `sshfs`
- `openssh`
- `exfatprogs`
- `btrfs-progs`
    - btrfs中的子卷概念
        - 可以理解为文件系统命名空间
        - 子卷可以单独挂载到不同的目录位置
        - 子卷可以嵌套，形成类似文件目录的树状结构
            - 子卷可以嵌套在子卷下
            - 子卷可以嵌套在同btrfs分区的目录下
            - 如果子卷没有单独挂载，会自动以子卷嵌套结构显示为文件系统目录结构
        - btrfs分区具有id=5的顶层子卷，固定不可变，但不一定要被挂载为根目录
        - btrfs分区具有“默认子卷”，初始设置为顶层子卷，可以使用
            - 'btrfs get-default /path/to/a/subvolume'获取挂载在这个目录的子卷对应的btrfs分区的“默认子卷”
            - 'btrfs set-default /path/to/a/subvolume'设置挂载在这个目录的子卷为对应btrfs分区的“默认子卷”
    - btrfs具有快照功能，可以增量保存一个子卷的快照为另一个子卷
        - 快照指针对子卷，不能针对目录和文件
        - 嵌套子卷不会被父子卷的快照保留
        - 快照默认与原子卷相同权限，但原子卷权限缩紧后快照不会自动变更，可能导致**安全问题**
- `snapper`
    - 用于自动生成btrfs快照，默认生成只读快照
    - 添加新的快照设置：'snapper -c your_config_label create-config /path/to/subvolume'
        - 会在需要快照的子卷下生成名称为'.snapshots'的子卷用来存储快照
        - 新的快照会存储为名称为'.snapshots/X/snapshot'的子卷，其中X是快照数字编号
        - 创建新配置的时候需要确保'/path/to/subvolume'子卷下没有名字为'.snapshots'的子卷且没有名字为'.snapshots'的目录，否则都会与snapper创建存放快照的子卷的行为冲突
        - 当snapper配置创建好之后，可以将'/path/to/subvolume/.snapshots'目录挂载为其他自定义子卷，并将snapper默认创建的子卷删除
            - 'btrfs subvolume delete /path/to/subvolume/.snapshots'
            - 'mkdir /path/to/subvolume/.snapshots'
            - 'chmod 750 /path/to/subvolume/.snapshots'
            - 'sudo mount -o subvol=new_subvol_name /dev/your_partition /path/to/subvolume/.snapshots'
            - 如果需要默认挂载则重新生成fstab文件（记得先保留fstab的备份）：'sudo genfstab -U / | sudo t /etc/fstab'
        - snapper根据“配置文件中记录的目录”而非“子卷标识”索引需要快照的子卷与存放快照子卷的位置，因此目录如果挂载了变化的子卷，可能导致快照错误记录或者失败
    - 用来进行系统保护
        - 防止滚动更新或者系统目录文件修改破坏系统
        - 使用平铺布局（Flat Layout）组织子卷，不使用顶层子卷挂载到根目录'/'，而使用单独子卷例如'@'
        - 将'/home'、'/var/cache'、'/var/log'、'/var/lib/docker'：*Docker*、'/var/lib/machines'：*systemd-nspawn*、'/var/lib/postgres'：*PostgreSQL*等位置用单独子卷挂载避免快照记录过多无用数据
        - 将'/path/to/volume'改为'/'后创建snapper配置
        - 修改'.snapshots'挂载的子卷为单独子卷，例如与根目录子卷同级别的'@snapshots'子卷
        - 当系统损坏的时候：
            - 如果使用GRUB，可以在进入GRUB菜单后按下'c'进入控制台：
                - 'insmod btrfs'
                - 'ls'看有哪些磁盘分区，例如'(hd0,gpt2)'
                - 'ls (hd0,gpt2)'看文件系统类型与标签，确认是Btrfs分区
                - 'ls (hd0,gpt2)/'如果默认子卷是顶层，这里能看到'@'、'@snapshots'等
                - 'ls (hd0,gpt2)/@snapshots'列出其中的快照目录，找到所需快照
            - 在bootloader的启动options处添加'rootflags=subvol=@snapshots/X/snapshot'就可以以只读方式挂载系统快照
            - 'sudo mount /your/root/partition /mnt'，把btrfs分区的顶层子卷（并非日常使用的根文件系统子卷）挂载到'/mnt'
            - 'mv /mnt/@ /mnt/broken_root'
            - 'btrfs subvolume snapshot /mnt/@snapshots/X/snapshot /mnt/@'
    - 用来进行文件“备份”
        - 单一位置、单一机器存储并非安全“备份”，可以配合云同步系统实现备份

#### 电源与硬件管理

- `acpi`
- `brightnessctl`
- `btop`
    - 系统监控
- `cups`
- `powertop`
- `auto-cpufreq`(archlinuxcn)
- `thermald`

#### 音频

- `pipewire`
    - `pipewire-alsa`
    - `pipewire-audio`
    - `pipewire-jack`
    - `pipewire-pulse`
    - `alsa-utils`

#### 网络配置

- `iwd`
- `ufw`
- `socat`
    - 内核防火墙配置前端
1. 使用NetworkManager
    - `networkmanager`
2. 使用connman
    - 暂无

#### 蓝牙

- `bluez`
- `bluez-utils`

### GUI应用

#### 桌面环境

- `hyprland`
    - wayland合成器
    - `qt5-wayland`
    - `qt6-wayland`
    - `qt5ct`
    - `qt6ct`
    - `xdg-desktop-portal-hyprland`
    - `polkit-gnome`
- `xdg-user-dirs`
- `hypridle`
    - 闲置监控
- `hyprlock`
    - 锁屏界面
- `hyprpaper`
    - 壁纸设置
- `rofi`
    - 启动器以及多功能选择器
- `waybar`
- `hyprpicker`
    - 颜色提取器
- `swaync`
    - 通知中心
- `wayvnc`
    - vnc远程桌面

#### 截图、剪贴板管理

- `grim`
- `slurp`
- `swappy`
- `cliphist`

#### 图形化设置

- `nwg-displays`
- `nwg-look`
- `blueman`
- `pavucontrol`

1. 网络配置使用NetworkManager
    - `network-manager-applet`
2. 使用其他网络配置工具或者不需要applet情况
    - 暂无

### 终端应用

- `kitty`
- `bash`
- `zsh`
- `antigen`(AUR)
    - zsh plugin manager
- `tmux`
    - 终端复用器

### 字体

- `noto-fonts`
- `wqy-microhei`
- `wqy-zenhei`
- `awesome-terminal-fonts`
- `ttf-jetbrains-mono-nerd`

### 文件管理

- `thunar`
    - `thunar-archive-plugin`
    - `xarchiver`
    - `thunar-media-tags-plugin`
    - `thunar-shares-plugin`
    - `thunar-volman`
    - `gvfs`
    - `gvfs-mtp`
    - `gvfs-nfs`
    - `gvfs-smb`
- `yazi`
    - 使用TUI的多功能文件管理器
    - `7zip`
    - `jq`
    - `fd`
    - `fzf`
    - `ripgrep`
    - `ffmpegthumbnailer`
    - `zoxide`
1. 使用图形化pCloud客户端
    - `pcloud-drive`(AUR)
2. 使用命令行pCloud客户端
    - `pcloudcc-lneely`(AUR)

### 输入法

- `fcitx5`
- `fcitx5-chinese-addons`
- `fcitx5-configtool`
- `fcitx5-gtk`
- `fcitx5-qt`

### 文本编辑与编程

- `neovim`
- `nvim-lazy`(AUR)
- `vivify`(AUR)
- `bat`
- `picocom`
- `screen`
- `uv`
- `rustup`
- `python`
- `gdb`

### 文件浏览与编辑

- `ncmpcpp`
- `imv`
- `mpv`
- `zathura`
- `zathura-cb`
- `zathura-djvu`
- `zathura-pdf-poppler`
- `poppler`
- `imagemagick`
- `pandoc-bin`(archlinuxcn)
- `wps-office-cn`(AUR)
    - `wps-office-mui-zh-cn`(AUR)
    - `libtiff5`(archlinuxcn)
    - `ttf-wps-fonts`(AUR)
- `calibre`
- `libreoffice-fresh`

### 其他

- `firefox`
    - `vdhcoapp`(archlinuxcn)
- `aichat`

## 可选功能软件包

### Wine兼容层

1. 使用pacman管理
    - `wine`
    - `wine-mono`
    - `winetricks`
2. 使用bottles管理
    - `bottles`

#### Wine专业音频

- `wineasio`(AUR)
- `wineasio32`(AUR)

### 文件编辑

- `inkscape`
- `gimp`
- `davinci-resolve`

### 科研研究

- `zotero`
- `paraview`
- `fiji-bin`
- `texlive-basic`
    - `texlive-binextra`
    - `texlive-fontsextra`
    - `texlive-fontsrecommended`
    - `texlive-latex`
    - `texlive-latexextra`
    - `texlive-latexrecommended`
    - `texlive-mathscience`
    - `texlive-plaingeneric`

### 工程软件

- `kicad`
    - `kicad-library`
    - `kicad-library-3d`
- `wireshark`

### 音频开发

- `reaper`
- `sox`

### Android开发

- `android-tools`

### 其他

- `wechat`(AUR)
- `wemeet-bin`(AUR)
- `wemeet-wayland-screenshare-git`(AUR)
- `xunlei-bin`(AUR)
- `ollama`
    - 本地大语言模型运行包装

