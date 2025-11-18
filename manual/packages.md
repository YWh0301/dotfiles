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
1. 使用btrfs
    - `btrfs-progs`
2. 使用其他文件系统
    - 暂无

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
- `pcloud-drive`(AUR)
    - pcloud云盘

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

### 其他

- `wechat`(AUR)
- `wemeet-bin`(AUR)
- `wemeet-wayland-screenshare-git`(AUR)
- `xunlei-bin`(AUR)
- `ollama`
    - 本地大语言模型运行包装

