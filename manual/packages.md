# 我的GNU/Linux系统中安装的软件包

本文件同时是人类可读的软件包说明和 pyinfra 的软件包清单。每个粗体软件包条目后必须有一个 HTML 标签；HTML 标签在 Markdown 渲染结果中不可见。

- `<!-- pyinfra: always -->`：所有个人 Arch 机器都安装；
- `<!-- pyinfra: manual -->`：仅作记录，不由 pyinfra 安装；
- `<!-- pyinfra: feature=名称 -->`：对应 `user.toml` 中的 Feature 为 `true` 时安装；
- `<!-- pyinfra: hardware=名称 -->`：运行时检测到对应 CPU/GPU 或根文件系统时安装；
- `<!-- pyinfra: machine=laptop -->`或`machine=desktop`：匹配机器角色时安装；
- `<!-- pyinfra: profile=名称 -->`：名称出现在 `user.toml` 的 `packages.profiles`时安装。

普通仓库、ArchLinuxCN 和 Pro Audio 软件包由 Pacman 安装；标记为`(AUR)`或`(myPKGBUILDS)`的软件包只检查和报告，不阻塞基础恢复。没有标签、标签格式错误或重复条目冲突时，pyinfra 会停止而不是猜测。

## Basic Packages

基础软件包

### Basic Arch Linux System

- 内核由 pacstrap/人工选择；pyinfra 只为已安装内核补齐 Headers
    - **linux** <!-- pyinfra: manual -->
    - **linux-headers** <!-- pyinfra: hardware=kernel_linux -->
    - **linux-lts** <!-- pyinfra: manual -->
    - **linux-lts-headers** <!-- pyinfra: hardware=kernel_lts -->
    - **linux-zen** <!-- pyinfra: manual -->
    - **linux-zen-headers** <!-- pyinfra: hardware=kernel_zen -->
- **base** <!-- pyinfra: always -->
- **base-devel** <!-- pyinfra: always -->
- **arch-install-scripts** <!-- pyinfra: always -->
- **linux-firmware** <!-- pyinfra: always -->
- 根据所使用的CPU制造商决定微码软件包
    - **intel-ucode** <!-- pyinfra: hardware=cpu_intel -->
    - **amd-ucode** <!-- pyinfra: hardware=cpu_amd -->

#### Bootloader

- **efibootmgr** <!-- pyinfra: always -->
- **grub** <!-- pyinfra: always -->
- **os-prober** <!-- pyinfra: always -->
    - 如果需要安装双系统则需要安装

### System Applications

- **dkms** <!-- pyinfra: always -->
- **evtest** <!-- pyinfra: always -->
- **wev** <!-- pyinfra: always -->
- **git** <!-- pyinfra: always -->
    - **github-cli** <!-- pyinfra: always -->
- **less** <!-- pyinfra: always -->
- **tree** <!-- pyinfra: always -->
- **tree-sitter-cli** <!-- pyinfra: always -->
- **wget** <!-- pyinfra: always -->
- **curl** <!-- pyinfra: always -->
- **lsof** <!-- pyinfra: always -->
- **strace** <!-- pyinfra: always -->
- **ltrace** <!-- pyinfra: always -->
- **usbutils** <!-- pyinfra: always -->
- **chezmoi** <!-- pyinfra: always -->
    - 使用密码保护公共仓库中的隐私数据
        - 在`$HOME/.local/share/chezmoi`运行`chezmoi age-keygen |tee| chezmoi age encrypt --passphrase --output=key.txt.age`创建新的加密后的密钥文件，记录下来`Public key: yourpublickey`，并`echo key.txt.age >> .chezmoiignore`
        - 创建`$HOME/.local/share/chezmoi/run_onchange_before_decrypt-private-key.sh.tmpl`实现自动提示密码解密密钥：
            ```
            #!/bin/sh

            if [ ! -f "${HOME}/.config/chezmoi/key.txt" ]; then
                mkdir -p "${HOME}/.config/chezmoi"
                chezmoi age decrypt --output "${HOME}/.config/chezmoi/key.txt" --passphrase "{{ .chezmoi.sourceDir }}/key.txt.age"
                chmod 600 "${HOME}/.config/chezmoi/key.txt"
            fi
            ```
        - 在`$HOME/.local/share/chezmoi/.chezmoi.tomp.tmpl`中加入，并写入之前保存的`yourpublickey`：
            ```
            encryption = "age"
            [age]
                identity = "~/.config/chezmoi/key.txt"
                recipient = "yourpublickey"
            ```
        - 对于需要加密的data文件，运行`chezmoi add --encrpt /your/secret/file`
- **dialog** <!-- pyinfra: always -->
- **pacman-contrib** <!-- pyinfra: always -->
- **archlinux-keyring** <!-- pyinfra: always -->
- **archlinuxcn-keyring**(archlinuxcn) <!-- pyinfra: always -->
- **yay**(archlinuxcn) <!-- pyinfra: always -->

#### GPU Drivers

- **libvdpau-va-gl** <!-- pyinfra: hardware=gpu_open -->
- **libva-utils** <!-- pyinfra: hardware=gpu_any -->
- 参考Arch Wiki进行安装
- 对于AMD、Intel显卡
    - **mesa** <!-- pyinfra: hardware=gpu_open -->
        - **mesa-utils** <!-- pyinfra: hardware=gpu_open -->
    - **vulkan-tools** <!-- pyinfra: hardware=gpu_any -->
    - Intel
        - **vulkan-intel** <!-- pyinfra: hardware=gpu_intel -->
        - **intel-media-driver** <!-- pyinfra: hardware=gpu_intel -->
        - **libvpl** <!-- pyinfra: hardware=gpu_intel -->
        - **vpl-gpu-rt** <!-- pyinfra: hardware=gpu_intel -->
    - AMD
        - **vulkan-radeon** <!-- pyinfra: hardware=gpu_amd -->
- 对于Nvidia显卡
    - **nvidia-open** <!-- pyinfra: hardware=gpu_nvidia_open -->
    - **nvidia-open-lts** <!-- pyinfra: hardware=gpu_nvidia_open_lts -->
    - **nvidia-open-dkms** <!-- pyinfra: hardware=gpu_nvidia_open_dkms -->
        - **nvidia-prime** <!-- pyinfra: hardware=gpu_nvidia -->
        - **nvidia-utils** <!-- pyinfra: hardware=gpu_nvidia -->
        - **nvtop** <!-- pyinfra: hardware=gpu_nvidia -->
    - **egl-wayland** <!-- pyinfra: hardware=gpu_nvidia -->
    - **libva-nvidia-driver** <!-- pyinfra: hardware=gpu_nvidia -->

#### File System Utilities

- **sshfs** <!-- pyinfra: always -->
- **exfatprogs** <!-- pyinfra: always -->
- **btrfs-progs** <!-- pyinfra: hardware=fs_btrfs -->
    - btrfs中的子卷概念
        - 可以理解为文件系统命名空间
        - 子卷可以单独挂载到不同的目录位置
        - 子卷可以嵌套，形成类似文件目录的树状结构
            - 子卷可以嵌套在子卷下
            - 子卷可以嵌套在同btrfs分区的目录下
            - 如果子卷没有单独挂载，会自动以子卷嵌套结构显示为文件系统目录结构
        - btrfs分区具有id=5的顶层子卷，固定不可变，但不一定要被挂载为根目录
        - btrfs分区具有“默认子卷”，初始设置为顶层子卷，可以使用
            - `btrfs get-default /path/to/a/subvolume`获取挂载在这个目录的子卷对应的btrfs分区的“默认子卷”
            - `btrfs set-default /path/to/a/subvolume`设置挂载在这个目录的子卷为对应btrfs分区的“默认子卷”
    - btrfs具有快照功能，可以增量保存一个子卷的快照为另一个子卷
        - 快照指针对子卷，不能针对目录和文件
        - 嵌套子卷不会被父子卷的快照保留
        - 快照默认与原子卷相同权限，但原子卷权限缩紧后快照不会自动变更，可能导致**安全问题**
- **snapper** <!-- pyinfra: feature=snapper -->
    - 用于自动生成btrfs快照，默认生成只读快照
    - 添加新的快照设置：`snapper -c your_config_label create-config /path/to/subvolume`
        - 会在需要快照的子卷下生成名称为`.snapshots`的子卷用来存储快照
        - 新的快照会存储为名称为`.snapshots/X/snapshot`的子卷，其中X是快照数字编号
        - 创建新配置的时候需要确保`/path/to/subvolume`子卷下没有名字为`.snapshots`的子卷且没有名字为`.snapshots`的目录，否则都会与snapper创建存放快照的子卷的行为冲突
        - 当snapper配置创建好之后，可以将`/path/to/subvolume/.snapshots`目录挂载为其他自定义子卷，并将snapper默认创建的子卷删除
            - `btrfs subvolume delete /path/to/subvolume/.snapshots`
            - `mkdir /path/to/subvolume/.snapshots`
            - `chmod 750 /path/to/subvolume/.snapshots`
            - `sudo mount -o subvol=new_subvol_name /dev/your_partition /path/to/subvolume/.snapshots`
            - 如果需要默认挂载则重新生成fstab文件（记得先保留fstab的备份）：`sudo genfstab -U / | sudo t /etc/fstab`
        - snapper根据“配置文件中记录的目录”而非“子卷标识”索引需要快照的子卷与存放快照子卷的位置，因此目录如果挂载了变化的子卷，可能导致快照错误记录或者失败
    - 用来进行系统保护
        - 防止滚动更新或者系统目录文件修改破坏系统
        - 使用平铺布局（Flat Layout）组织子卷，不使用顶层子卷挂载到根目录`/`，而使用单独子卷例如`@`
        - 将`/home`、`/var/cache`、`/var/log`、`/var/lib/docker`：*Docker*、`/var/lib/machines`：*systemd-nspawn*、`/var/lib/postgres`：*PostgreSQL*等位置用单独子卷挂载避免快照记录过多无用数据
        - 将`/path/to/volume`改为`/`后创建snapper配置
        - 修改`.snapshots`挂载的子卷为单独子卷，例如与根目录子卷同级别的`@snapshots`子卷
        - 当系统损坏的时候：
            - 如果使用GRUB，可以在进入GRUB菜单后按下`c`进入控制台：
                - `insmod btrfs`
                - `ls`看有哪些磁盘分区，例如`(hd0,gpt2)`
                - `ls (hd0,gpt2)`看文件系统类型与标签，确认是Btrfs分区
                - `ls (hd0,gpt2)/`如果默认子卷是顶层，这里能看到`@`、`@snapshots`等
                - `ls (hd0,gpt2)/@snapshots`列出其中的快照目录，找到所需快照
            - 在bootloader的启动options处添加`rootflags=subvol=@snapshots/X/snapshot`就可以以只读方式挂载系统快照
            - `sudo mount /your/root/partition /mnt`，把btrfs分区的顶层子卷（并非日常使用的根文件系统子卷）挂载到`/mnt`
            - `mv /mnt/@ /mnt/broken_root`
            - `btrfs subvolume snapshot /mnt/@snapshots/X/snapshot /mnt/@`
    - 用来进行文件“备份”
        - 单一位置、单一机器存储并非安全“备份”，可以配合云同步系统实现备份

#### Hardware Management

- **acpi** <!-- pyinfra: machine=laptop -->
- **brightnessctl** <!-- pyinfra: machine=laptop -->
- **btop** <!-- pyinfra: always -->
    - 系统监控
- **cups** <!-- pyinfra: always -->
- **powertop** <!-- pyinfra: machine=laptop -->
- **auto-cpufreq**(archlinuxcn) <!-- pyinfra: machine=laptop -->
- **thermald** <!-- pyinfra: hardware=cpu_intel -->

#### Audio

- **pipewire** <!-- pyinfra: always -->
    - **pipewire-alsa** <!-- pyinfra: always -->
    - **pipewire-audio** <!-- pyinfra: always -->
    - **pipewire-jack** <!-- pyinfra: always -->
    - **pipewire-pulse** <!-- pyinfra: always -->
    - **alsa-utils** <!-- pyinfra: always -->
- **wireplumber** <!-- pyinfra: always -->

#### Networking

- **iwd** <!-- pyinfra: always -->
- **ufw** <!-- pyinfra: feature=firewall -->
- **socat** <!-- pyinfra: always -->
    - 内核防火墙配置前端
1. 使用NetworkManager
    - **networkmanager** <!-- pyinfra: always -->
2. 使用connman
    - 暂无
- **openssh** <!-- pyinfra: always -->
- **bind** <!-- pyinfra: always -->
- **dae-git**(archlinuxcn) <!-- pyinfra: always -->
- **flclash**(archlinuxcn) <!-- pyinfra: always -->
- **tailscale** <!-- pyinfra: always -->

#### Bluetooth

- **bluez** <!-- pyinfra: always -->
- **bluez-utils** <!-- pyinfra: always -->

### GUI

#### Desktop Environment

- 对于桌面环境而言，compositor、panel和launcher是最重要的三个组成部分，并且这三者的配置也会紧密结合，互相依赖
- **hyprland** <!-- pyinfra: always -->
    - wayland合成器
    - **qt5-wayland** <!-- pyinfra: always -->
    - **qt6-wayland** <!-- pyinfra: always -->
    - **qt5ct** <!-- pyinfra: always -->
    - **qt6ct** <!-- pyinfra: always -->
    - **xdg-desktop-portal-hyprland** <!-- pyinfra: always -->
    - **polkit-gnome** <!-- pyinfra: always -->
- **rofi** <!-- pyinfra: always -->
    - 启动器以及多功能选择器
- **waybar** <!-- pyinfra: always -->
    - 可自定义的panel bar
- **xdg-user-dirs** <!-- pyinfra: always -->
- **hypridle** <!-- pyinfra: always -->
    - 闲置监控
- **hyprlock** <!-- pyinfra: always -->
    - 锁屏界面
- **hyprpaper** <!-- pyinfra: always -->
    - 壁纸设置
- **hyprpicker** <!-- pyinfra: always -->
    - 颜色提取器
- **swaync** <!-- pyinfra: always -->
    - 通知中心
- **wayvnc** <!-- pyinfra: feature=wayvnc -->
    - vnc远程桌面
    - 通过`openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:secp384r1 -sha384 -days 3650 -nodes -keyout tls_key.pem -out tls_cert.pem -subj /CN=$(hostnamectl hostname)`生成TLS/SSL证书，可以实现VNC服务器认证
    - 通过`openssl x509 -in tls_cert.pem -fingerprint -sha1 -noout`查看服务器公钥的SHA1；只要客户端接受到的证书公钥和机器上的公钥一致，就能确定没有被中间人攻击
    - 配合wayvnc中设置强密码实现较高安全性

#### Screen Shot and Clipboard Managing

- **grim** <!-- pyinfra: always -->
- **slurp** <!-- pyinfra: always -->
- **swappy** <!-- pyinfra: always -->
- **cliphist** <!-- pyinfra: always -->
#### GUI Setting Tools

- **nwg-displays** <!-- pyinfra: always -->
- **nwg-look** <!-- pyinfra: always -->
- **blueman** <!-- pyinfra: always -->
- **pavucontrol** <!-- pyinfra: always -->
- **carla** <!-- pyinfra: always -->
1. 网络配置使用NetworkManager
    - **network-manager-applet** <!-- pyinfra: always -->
2. 使用其他网络配置工具或者不需要applet情况
    - 暂无

### Terminal

- **kitty** <!-- pyinfra: always -->
- **bash** <!-- pyinfra: always -->
- **zsh** <!-- pyinfra: always -->
- **antigen**(AUR) <!-- pyinfra: always -->
    - zsh plugin manager
- **tmux** <!-- pyinfra: always -->
    - 终端复用器

### Fonts

- **noto-fonts** <!-- pyinfra: always -->
- **wqy-microhei** <!-- pyinfra: always -->
- **wqy-zenhei** <!-- pyinfra: always -->
- **awesome-terminal-fonts** <!-- pyinfra: always -->
- **ttf-jetbrains-mono-nerd** <!-- pyinfra: always -->

### File Managing

- **thunar** <!-- pyinfra: always -->
    - **thunar-archive-plugin** <!-- pyinfra: always -->
    - **xarchiver** <!-- pyinfra: always -->
    - **thunar-media-tags-plugin** <!-- pyinfra: always -->
    - **thunar-volman** <!-- pyinfra: always -->
    - **gvfs** <!-- pyinfra: always -->
    - **gvfs-mtp** <!-- pyinfra: always -->
    - **gvfs-nfs** <!-- pyinfra: always -->
- **yazi** <!-- pyinfra: always -->
    - 使用TUI的多功能文件管理器
    - **7zip** <!-- pyinfra: always -->
    - **jq** <!-- pyinfra: always -->
    - **fd** <!-- pyinfra: always -->
    - **fzf** <!-- pyinfra: always -->
    - **ripgrep** <!-- pyinfra: always -->
    - **ffmpegthumbnailer** <!-- pyinfra: always -->
    - **zoxide** <!-- pyinfra: always -->
    - **resvg** <!-- pyinfra: always -->
- **localsend-bin**(AUR) <!-- pyinfra: always -->
    - 与iOS和Android设备进行局域网双向文件传输
    - Yazi通过`Shift+L`发送选中文件
- **pcloud-drive**(AUR) <!-- pyinfra: always -->

### Input Method

- **fcitx5** <!-- pyinfra: always -->
- **fcitx5-chinese-addons** <!-- pyinfra: always -->
- **fcitx5-configtool** <!-- pyinfra: always -->
- **fcitx5-gtk** <!-- pyinfra: always -->
- **fcitx5-qt** <!-- pyinfra: always -->

### Text Editing and Programming

- **neovim** <!-- pyinfra: always -->
- **nvim-lazy**(AUR) <!-- pyinfra: always -->
- **vivify**(AUR) <!-- pyinfra: always -->
- **bat** <!-- pyinfra: always -->
- **picocom** <!-- pyinfra: always -->
- **screen** <!-- pyinfra: always -->
- **uv** <!-- pyinfra: always -->
- **rustup** <!-- pyinfra: always -->
- **python** <!-- pyinfra: always -->
- **gdb** <!-- pyinfra: always -->
- **cmake** <!-- pyinfra: always -->

### File Browsing and Editing

- **ncmpcpp** <!-- pyinfra: always -->
- **imv** <!-- pyinfra: always -->
- **mpv** <!-- pyinfra: always -->
- **zathura** <!-- pyinfra: always -->
- **zathura-cb** <!-- pyinfra: always -->
- **zathura-djvu** <!-- pyinfra: always -->
- **zathura-pdf-mupdf** <!-- pyinfra: always -->
- **poppler** <!-- pyinfra: always -->
- **imagemagick** <!-- pyinfra: always -->
- **pandoc-bin**(archlinuxcn) <!-- pyinfra: always -->
- **wps-office-cn**(AUR) <!-- pyinfra: manual -->
    - 对于12.1.2.22571版本，存在二进制文件中的bug，无法通过绝对路径使用CLI打开文件；
        - 在wps界面左上角“WPS Office”内设置按钮中找到“切换窗口管理模式”，选择任意项点击确定后重启即可
    - **wps-office-mui-zh-cn**(AUR) <!-- pyinfra: manual -->
    - **libtiff5**(archlinuxcn) <!-- pyinfra: manual -->
    - **ttf-wps-fonts**(AUR) <!-- pyinfra: manual -->
- **calibre** <!-- pyinfra: always -->

### Others

- **firefox** <!-- pyinfra: always -->
    - **vdhcoapp**(archlinuxcn) <!-- pyinfra: always -->
- **aichat** <!-- pyinfra: always -->
- **pi-coding-agent**(AUR) <!-- pyinfra: always -->
    - **pi-ext-web-access**(AUR) <!-- pyinfra: always -->
    - **pi-ext-pdf**(myPKGBUILDS) <!-- pyinfra: always -->
        - **python-pdfplumber**(AUR) <!-- pyinfra: always -->
        - **python-pypdfium2**(AUR) <!-- pyinfra: always -->
    - **pi-ext-agent-browser-native**(myPKGBUILDS) <!-- pyinfra: always -->
        - **agent-browser-bin**(AUR) <!-- pyinfra: always -->
    - **pi-ext-multimodal-proxy**(myPKGBUILDS) <!-- pyinfra: manual -->
    - **pi-ext-ocr**(myPKGBUILDS) <!-- pyinfra: manual -->
- **qbittorrent** <!-- pyinfra: always -->## Additional Packages

### Wine

- **wine** <!-- pyinfra: profile=wine -->
- **wine-mono** <!-- pyinfra: profile=wine -->
- **winetricks** <!-- pyinfra: profile=wine -->

#### Wine Pro Audio

- **wineasio**(AUR) <!-- pyinfra: profile=proaudio -->
- **wineasio32**(AUR) <!-- pyinfra: profile=proaudio -->

### File Editing

- **inkscape** <!-- pyinfra: profile=multimedia -->
- **gimp** <!-- pyinfra: profile=multimedia -->
- **davinci-resolve** <!-- pyinfra: manual -->

### Scientific Research

- **zotero** <!-- pyinfra: profile=lab -->
    - 可以在设置中手动更改本地存储文件夹位置，而后手动移动文件夹内容到新位置
- **paraview** <!-- pyinfra: manual -->
- **fiji-bin**(AUR) <!-- pyinfra: manual -->
- **texlive-basic** <!-- pyinfra: profile=lab -->
    - **texlive-binextra** <!-- pyinfra: profile=lab -->
    - **texlive-fontsextra** <!-- pyinfra: profile=lab -->
    - **texlive-fontsrecommended** <!-- pyinfra: profile=lab -->
    - **texlive-latex** <!-- pyinfra: profile=lab -->
    - **texlive-latexextra** <!-- pyinfra: profile=lab -->
    - **texlive-latexrecommended** <!-- pyinfra: profile=lab -->
    - **texlive-mathscience** <!-- pyinfra: profile=lab -->
    - **texlive-plaingeneric** <!-- pyinfra: profile=lab -->

### Engineering

- **kicad** <!-- pyinfra: profile=engineering -->
    - **kicad-library** <!-- pyinfra: profile=engineering -->
    - **kicad-library-3d** <!-- pyinfra: profile=engineering -->
- **freecad** <!-- pyinfra: profile=engineering -->
- **wireshark** <!-- pyinfra: manual -->

### Audio Development

- **reaper** <!-- pyinfra: profile=proaudio -->
    - **sws** <!-- pyinfra: profile=proaudio -->
    - **reapack** <!-- pyinfra: profile=proaudio -->
- **sox** <!-- pyinfra: profile=proaudio -->
- **haskell-tidal** <!-- pyinfra: profile=proaudio -->
- **vcvrack**(pro-audio) <!-- pyinfra: profile=proaudio -->
    - **vcvrack-plugins**(pro-audio) <!-- pyinfra: profile=proaudio -->
    - **cardinal** <!-- pyinfra: profile=proaudio -->
- **lsp-plugins** <!-- pyinfra: profile=proaudio -->
- **dragonfly-reverb** <!-- pyinfra: profile=proaudio -->
- **avldrums.lv2** <!-- pyinfra: profile=proaudio -->
- **zynaddsubfx** <!-- pyinfra: profile=proaudio -->
- **yoshimi** <!-- pyinfra: manual -->
- **vital-synth**(AUR) <!-- pyinfra: profile=proaudio -->
- **surge-xt** <!-- pyinfra: profile=proaudio -->
- **guitarix** <!-- pyinfra: profile=proaudio -->
- **sfizz** <!-- pyinfra: profile=proaudio -->
- **infamousplugins** <!-- pyinfra: profile=proaudio -->
- **drumgizmo** <!-- pyinfra: profile=proaudio -->
- **setbfree** <!-- pyinfra: profile=proaudio -->
- **polyphone** <!-- pyinfra: profile=proaudio -->
- **qtractor** <!-- pyinfra: profile=proaudio -->
- **mixxx** <!-- pyinfra: profile=proaudio -->
    - **gnome-keyring** <!-- pyinfra: profile=proaudio -->
    - FOSS digital software for djing
- **beets** <!-- pyinfra: profile=proaudio -->
    - CLI FOSS music management and tagging software
- **quodlibet** <!-- pyinfra: manual -->
    - music management software and music player
- **musescore** <!-- pyinfra: manual -->
    - FOSS music sheet editor
    - **musescore-bin**(AUR) <!-- pyinfra: manual -->
    - If musescore encounter Qt bugs, use Appimage version (musescore-bin in AUR)
- **lilypond** <!-- pyinfra: profile=proaudio -->
    - GNU music sheet describing language with music xml converting function
    - **frescobaldi** <!-- pyinfra: manual -->

### Android Utilities

- **android-tools** <!-- pyinfra: manual -->

### Gaming

- **steam** <!-- pyinfra: manual -->

### Others

- **wechat**(AUR) <!-- pyinfra: manual -->
- **obs-studio** <!-- pyinfra: manual -->
- **wemeet-bin**(AUR) <!-- pyinfra: manual -->
- **wemeet-wayland-screenshare-git**(AUR) <!-- pyinfra: manual -->
- **xunlei-bin**(AUR) <!-- pyinfra: manual -->
- **ollama** <!-- pyinfra: manual -->
    - 本地大语言模型运行包装

