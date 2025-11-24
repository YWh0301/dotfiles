# draft

## ideas

- 省电：不用*tlp*,用*auto-cpufreq* & *thermald*;但是powertop会让键盘suspend，因此可以在powertop的systemd file后面再执行一个不让键盘休眠的命令，具体命令可以在powertop中看到；
- 双系统时间设置
- *ssh* with *tmux* needs to install terminfo on server machine. when using *kitty* ,do `kitty +kitten ssh myserver` first to copy terminfo file to server automatically once.
- *wps* export to pdf not working: 缺少*libtiff5*。fix by either `ln -s /usr/lib/libtiff.so.6 /usr/lib/libtiff.so.5`or download aur package [libtiff5](https://aur.archlinux.org/packages/libtiff5). note that former approach may be risky.
- *pcloud*: `yay -S pcloud-drive` #pcloud would mount on a folder in home directory which is ugly so i change the home and created sim links for all the .folders-and-files (including .mozilla and .pki) in ~/ in the fake home folder to trick pcloud. remeber to also modify the exec in desktop entry of pcloud. furthermore pcloud only take absolute path so ~/ wont work.after this just set sync folder in the app then u can use it without any trouble.
- combine hyprland with scripts: use *hyprctl* and hyprland ipc, you can basically fulfill any requests that does not include a ui change in the compositor (a ui change requires plugins, which i dont intend to use).
- 不使用*wlogout*, instead use rofi-wayland to provide a shutdown menu
- printscreen: grim, slurp, swappy
- wps-office: yay -S ttf-wps-fonts wps-office-cn wps-office-mui-zh-cn libtiff5
- *firefox* hardware decoding:`media.hardware-video-decoding.force-enabled`
- runtime d3:*btop*,*nvidia-smi*,*nvtop*都会让nvidia gpu active；插入电源也会active；因此得在电池状态下用间接方法查看runtime d3
- 不使用*sddm*因为*sddm*似乎会在nvidia gpu上放一个xorg进程。可以配置tty默认用户，只需要输入密码,参考[archwiki:Getty](https://wiki.archlinux.org/title/Getty)；然后配置login shell的profile文件在tty1登陆后自动启动*Hyprland*，参考[archwiki:Xinit](https://wiki.archlinux.org/title/Xinit)；另外，可参考[archwiki:silent boot](https://wiki.archlinux.org/title/Silent_boot)；
- *neovim* *fcitx5* 自动切换输入法：使用*fcitx5-remote*工具，并编写lua脚本
- *neovim* markdown preview：*vivify*
- 设置关机强制关机时间，防止关机失败
- 减少nvim中plugin的使用以及plugin manager的使用，尽可能自己写lua文件
- config xdg-user-directories like [this](https://wiki.archlinux.org/title/XDG_user_directories#Creating_custom_directories)
- always try to use arch build system to install software, so *pacman* can manage all of them. try not to just copy a bunch of stuff in random places. if u dont know how to build package by urself, first try to find packages on aur. for example matlab/esp-idf/antigen/oh-my-zsh.
- user systemd file to start desktop environments: first start hyprland, but sleep 4s poststart.
- config *xdg-user-dirs* and other apps home directory, so that 各种软件不在home目录拉屎。 
- 使用rofi替代applet的功能？
    - rofi做wifi设置
    - rofi做音频设置
    - rofi做蓝牙设置
    - rofi做关机选项
    - rofi做dae控制
    - rofi做polkit
- hyprland xdg-desktop-portal: set file picker like [this](https://wiki.hyprland.org/Hypr-Ecosystem/xdg-desktop-portal-hyprland/#using-the-kde-file-picker-with-xdph). For firefox, like [this](https://wiki.archlinux.org/title/Firefox#XDG_Desktop_Portal_integration).
- linux游戏
- 使用btrfs快照进行：
    - 系统回滚支持：
        - 对/var和/home单独做子卷，对剩下的/进行快照，使得系统更新不至于损坏系统
    - 云同步盘备份
        - 对云同步盘同步位置进行定时快照，使得云同步文件即使被覆盖也不会丢失
- 使用wayvnc进行远程桌面
- 怎么使用impala？
- 像omarchy一样安装web应用
- 使用surf作为精简的web应用界面：surf-git(AUR)
- wtype直接输入
    - 非常危险，直接掌控键盘还停步下来，根本不能也不应该这么使用
- 读取剪贴板实现划词翻译
- 默认隐藏的waybar/无bar设计，使用单独的ctrl面板/桌面放置信息？使用rofi快速打开设置界面
- 使用软链接+云同步音乐库+ncmpcpp创建同步歌单音乐播放

