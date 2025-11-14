# Specific Usages

## basic utils

### btrfs

#### resize a partition with btrfs (not the normal *resize2fs* now)

If decreasing the space: first decrease the file system, then decrease the partition. If increase the space: fist increase the partition, then increase the file system. For decrease the space of a btrfs formatted partition:

- `sudo btrfs filesystem resize -100G /mount/point`
- Fisrt `umount` the partition, then repartition it and give it a bigger size of the file system's current size (so it won't be cut off). If it's the root partition, it's recommended to shutdown the machine and repartition it in a live environment. I have succeeded without umounting the root partition and repartition it. Remember to choose `N` when it asks to remove the existing "btrfs label" of the new partition created, and keep the partition number of the original root partition not changed, then it's probably fine. You can always use the live environment to regenerate the fstab file with `rm /mnt/etc/fstab` then `genfstab -U /mnt > /mnt/etc/fstab` again.
- `sudo btrfs filesystem resize max /` to expand btrfs to the partition size.

### journalctl

- `-f` to check journal in real time.
- `-u` by service.
- `-t` by program.

### NetworkManager

- `nmcli dev wifi list`
- `nmcli dev wifi connect "your_ssid" password "your_password"`

### dae

In the config file, after adding the subscription info, you may need to set a group that filter out specific nodes. However, sometimes it's unable to use Chinese input method. In that case, it's possible to press `Ctrl+V` in insert mode and then input `u9999` and `Ctrl+V` then `u6e2f` to get '香港' and the same but `u7f8e` with `u56fd` to get '美国', therefore getting the right string used to filter nodes.

The *dae* example config has specific rule for NetworkManager but not for *dhcpcd* or *iwd* so maybe it's better to stick to NetworkManager.

### pacman

- fuzzy search package: `pacman -Ss package_name`
- fuzzy search package installed: `pacman -Qs package_name`
- get info on package (usefull to check dependencies): `pacman -Qi package_name`
- find the package for a specific command: `pacman -Fy command_name`
- get all explicitly installed packages: `pacman -Qe`
- find all inexplicitly installed and unrequired packages and uninstall all of them: `sudo pacman -Rns $(pacman -Qdtq)` (n: also delete config files; s: delete dependency no longer required by others; d:inexplicitly installed; t:unrequired; q:don't print version number), then check if anything has been damaged: `sudo pacman -Dk`
- delete all packages in a package group that's no longer needed and their dependency: `sudo pacman -Rus group_name`

### yay

#### installation

- `sudo pacman -S --needed git base-devel`
- `git clone https://aur.archlinux.org/yay-bin.git`
- `cd yay-bin`
- `makepkg -si`

Or alternatively replace yay-bin with yay.

#### Unable to use after pacman update

Sometimes when pacman gets update, yay won't be able to be used. You basically need to wait for yay in AUR to be updated by maintainers and reinstall it. Use `pacman -Rs yay-bin yay-bin-debug` (or *yay* and *yay-debug*) to remove old yay, and repeat installation.

### antigen

Install *antigen* with yay. In `~/.zshrc` add `source /usr/share/zsh/share/antigen.sh`, and then edit the file according to [upstream instructions](https://github.com/zsh-users/antigen?tab=readme-ov-file#usage).

An example `.zshrc` can be like:

```sh
# antigen
source /usr/share/zsh/share/antigen.zsh

# plugins
antigen usr oh-my-zsh

antigen bundle git
antigen bundle sudo 
antigen bundle vi-mode
antigen bundle tldr
antigen bundle copyfile
antigen bundle copypath
antigen bundle colored-man-pages

# other plugins
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-syntax-highlighting

# theming zsh with antigen
antigen theme consolemaverick/zsh2000
export ZSH_2000_DISABLE_RVM='true'

#antigen section end
antigen apply
```

#### kbct

Ensure kernel module *uinput* is loaded, if it's not, make sue it's loaded on boot like [this](https://wiki.archlinux.org/title/Kernel_module#Automatic_module_loading). Edit the *kbct* systemd service file to let kbct load certain config file when started by systemd, or soft link the file used by defualt `/etc/kbct/config.yml` to your config file.

For example, write these in `~/.config/kbct/kbct.yaml`:

```
- keyboards: ["your keyboard"]

  keymap:
    capslock: leftctrl
    leftctrl: capslock
    rightalt: esc
    leftalt: leftmeta
    leftmeta: rightctrl
    rightctrl: leftalt
  layers:
    - modifiers: ['leftmeta']
      keymap:
        k: up
        h: left
        j: down
        l: right
        c: copy
        v: paste
```

You can use `sudo kbct list-devices` to get the name of your keyboard.

### graphical drivers

See [archwiki](https://wiki.archlinux.org/title/Xorg#Driver_installation) for more info.

- Xorg drivers: drivers with prefix *xf86* are for xorg specifically, and may mot be needed if you use wayland. But since we still need *xwayland* to run a few things, it's better to install these.
- User side render and display library: you'll need user side driver for *OpenGL*, *Vulkan* for each card you have. Remember to also instll package *mesa-utils*.
- For amd and intel graphics cards kernel side drivers are already in the kernel source codes, but for nvidia you need to install proprietary kernel side drivers. Since we are using hyprland with *linux-zen* kernel, *nvidia-dkms* rather than *nvidia* is required. Install *nvidia-dkms*, *dkms*, and then *linux-zen-headers*. The nvidia dkms driver should be installed and loaded (`lsmod|grep nvidia` to check). If not, check [this](https://wiki.archlinux.org/title/Dynamic_Kernel_Module_Support#Installation).

### fonts

- `sudo pacman -S ttf-font-awesome awesome-terminal-fonts powerline-fonts` for icons.
- `sudo pacman -S ttf-jetbrains-mono-nerd` for one of the nerd fonts english font.
- `sudo pacman -S wqy-microhei wqy-zenhei adobe-source-han-serif-cn-fonts` for chinese fonts.

### fcitx5

- install
- configure
- xwayland

### hyprland

#### draft

- can set `LANG=zh_CN.UTF-8` environment variable to change language in desktop. dont do it in console to avoid strange behavier.

### xdg-desktop-portal

*xdg-desktop-portal-hyprland* [only covers screenshare but not file picker](https://wiki.archlinux.org/title/XDG_Desktop_Portal#List_of_backends_and_interfaces). It seems to be possible to install multiple portals, so maybe there is a way to configure a specific file picker.

## file specific utils

###  ranger (not using)

- `ranger --copy-config=all` then export environment variable `RANGER_LOAD_DEFAULT_RC` to false.
- Set `image_preview = true` in `~/.config/ranger/rc.conf`.

### yazi

- Also install *fd*, *ripgrep*,*jq*,*poppler*,*ffmpegthumbnailer*,*imagemagick* (should be installed according to new install manual) for file searching utils.
- *yazi* uses *xdg-open* for mime application opening in defualt. Edit `~/.config/mimeapps.list` and add these two lines: `[Default Applications]` and `application/pdf=org.pwmt.zathura.desktop` to use zathura as the defualt pdf reader.

### thunar

Install *thunar*, *gvfs*, *gvfs-mtp*,  *thunar-archive-plugin*, *thunar-media-plugin*, *thunar-shares-plugin*, *thunar-volman*.

### xwayland

For Xorg applications, if using GTK or QT, set `GDK_SCALE` or `QT_FACTOR_SCALE` environment variable may be able to change scailing.

## windows compatibility

### wine

#### installation

Configure Pacman to use `multilib` repository. Install `wine`, `wine-mono`, `wine-gecko`, `winetricks` and all the 32-bit version of OpenGL and Vulkan drivers for the GPU and 32-bit pipewire driver. If u need older versions of `wine`, u can use the Arch Linux Archive. Remerber the version needed of `wine-mono` is somewhat related to the version of `wine`, so wine may not recognize `wine-mono` when they are not compatible. Use `sudo pacman -Syu --ignore=wine --ignore=wine-mono` to upgrade the system.

Run `winecfg` with a specific wineprefix. A wineprefix makes a different wine location (default under home directory), so u may seperate each and every windows software on ur computer and delete them completely by removing the whole directory.

Install `realtime-privileges` then do `sudo usermod -aG realtime $(whoami)` to add current user into realtime group. Then install `wineasio(AUR)`.

### steam

### proton

## egineering

### freecad

### kicad

## music

### ALSA and pipewire/wireplumber

### reaper

### yabridge

## school work

### reading papers

- `grobid`
- `pdf2doi`

### writing papers

- document conversion: `pandoc`
- latex: `texlive-basic`, `texlive-latex`, `texlive-latexrecommended`, `texlive-mathscience`, `texlive-fontsrecommended`, `texlive-binextra`, `texlive-latexextra`, `texlive-fontsextra`, `texlive-bin`, `texlive-pictures`, `texlive-plaingeneric`
- neovim plugin: `vimtex`
- document managing: `zotero`
    - 以要写作的论文为单位，安排collection文件夹的内容，在zotero中工作完毕后导出bib及pdf，手动调整pdf的位置
    - 安装[zetero reference](https://github.com/MuiseDestiny/zotero-reference)插件自动获取pdf的引用文献
    - 安装[DOI manager](https://github.com/bwiernik/zotero-shortdoi) 插件自动获取DOI
    - 安装[better bibtex](https://github.com/retorquere/zotero-better-bibtex) 插件用来进行cite name管理和导出
        - file name conversion rule of `{{ authors max="2" name="given-family" initialize="given" name-part-separator="" join="," case="snake" suffix="-"  }}{{ year suffix="-" }}{{ title truncate="100"  case="snake" }}`
        - 在BBT设置中设置需要略去的bib条目为`file,note,keywords`
        - 在BBT设置中Export-postscript中自定义导出控制选项
