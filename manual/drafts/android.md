# Android Setup

由于安卓设备基于Linux内核，本质上是一个提供特定的Java运行时环境、IPC服务、更加严苛的权限管理模型、特定的用户态驱动模型的Linux发行版，因此在特定条件下，可以将安卓设备转换为Linux设备，运行Linux应用。然而，安卓本身的特性导致这样的使用方法受到诸多限制：

- 安卓采用SELinux强化权限管理，难以获得传统意义上的Root权限
- 安卓设备使用的芯片（联发科、高通）所带有的GPU芯片提供的用户空间驱动（OpenGL、Vulkan）支持不足
- 安卓默认的图形服务SurfaceFlinger抢占了内核的DRM/KMS接口，无法共用
- 安卓默认的音频服务抢占了内核的ALSA接口，无法共用
- 安卓的其余系统服务与桌面Linux环境差别较大

解决方法如下：

- 针对多数的用户空间系统服务而言，使用容器/虚拟机技术来隔离安卓和Linux环境，单独安装Linux所需的用户空间服务；
- 针对图形服务，使用VNC/Termux:X11作为安卓客户端，将隔离的Linux环境的图形转发并显示，但这就代表无法运行Wayland应用；
- 针对音频服务，使用pulse audio音频转发接入安卓音频服务，针对专业音频则使用外接声卡穿透并应用jack2；

在实现这些功能的过程中，根据安卓的本身的特性，有许多不同的方案：

1. 虚拟机方案：
    - 由于安卓设备SoC广泛设计原因，Linux内核支持的KVM本身是无法运行的，但是随着安卓13以来AVF的广泛推进，已经有了pKVM模式的虚拟机系统，可以运行虚拟机
2. 容器方案：
    - lxc容器，仅仅在安卓系统本身获取了系统的root权限之后才可以使用，并且可以选择是否给lxc容器中的应用root权限；
    - chroot,也需要安卓设备获取root权限
    - proot,不需要获取root权限，将一个安卓软件目录下的某个地址作为proot系统的根目录

对于安卓机器而言，获取了安卓的root权限后可以进行的细粒度管理与各种系统服务的hook和屏蔽较为重要。在获取root权限前，需要先解锁设备的bootloader锁，才能进行相关操作。这两步的难易程度与设备厂商的风格息息相关。由于目标是实现linux系统较为完善的功能，并且对于安卓机器有着较为清晰的控制手段和精度，同时保证两者之间无缝衔接，因此选用rooted lxc容器的技术，配备现有的安卓芯片GPU硬件加速驱动提供的图形API以及硬件解码API，使用pulse audio音频转发，将linux环境的GUI显示在termux:x11界面上。同时，可以使用root权限对安卓端的权限管理、UI逻辑进行多种定制，配合安卓上的root工具一并打造安卓+linux双环境的通用设备。

## 配置步骤

- 使用一加品牌的设备方便root，多次点击版本号打开开发者模式，打开停止限制子进程选项，解锁对于安卓应用子进程数量的限制
- 安卓上安装f-droid、google play商店作为包管理器
- 安装nekobox作为网络代理，开放电池管理与后台自启动最大权限
- 安装fennec浏览器，多次点击版本号进入开发者模式，使用firefox插件网站安装所需的插件
- 从f-droid上安装termux系列app，从github安装termux:x11
- 使用bitwarden作为密码管理器
- 使用vlc作为视频播放器
- 使用fcitx5小企鹅输入法

## drafts

### 学习资源

- termux
- magisk
- kernelSU

### 路径

- 先不考虑GUI
- 在安卓设备上实现一个自建的特权容器，chroot+namespace+cgroup方式脱离安卓系统的管理并且获得SELinux下的高级权限

### Root 相关

“ Root 概念”指的是在 Android 系统运行时获得 Linux 内核级别的 root 用户身份（UID 0/GID 0），并同时具备绕过或控制 SELinux 强制访问策略的能力。Android 的安全模型是传统 Linux 自主访问控制（DAC，基于用户/组）与强制访问控制（MAC，即 SELinux）的叠加。要实现对系统的完全掌控，必须在 DAC 层面成为 root，并在 MAC 层面获得相应的 SELinux 上下文（如 `u:r:magisk:s0` 或 `u:r:su:s0`）或直接禁用 SELinux 的强制模式。

安卓系统在用户空间的第一个进程 `init` 的执行过程中完成SELinux策略加载和初始上下文设置。该系统不使用systemd，而是由 `init` 进程根据 `/system/etc/selinux/` 下的策略文件，以及位于 `/system/etc/init/`、`/vendor/etc/init/` 等目录下的 `.rc` 脚本来启动服务并为其设置相应的用户/组身份、能力集以及SELinux安全上下文。这些脚本和策略文件位于运行时只读挂载的 `/system` 或 `/vendor` 分区（对于较新版本，部分关键脚本可能打包在 `initramfs` 中），因此在系统正常运行时无法通过Android环境内部直接修改。

需要强调的是，移动设备的存储通常为嵌入式或焊接式芯片，无法像传统硬盘那样物理拆卸并通过外部设备直接读写，因此对于存储芯片的物理访问通常受限于设备本身运行的固件。而在出厂系统中，存在从SoC的First Stage Bootloader开始的信任链。First Stage Bootloader是SoC厂商提供的固化在硬件ROM中的代码，构成了不可更改的信任根。它负责验证并加载经过签名的Second Stage Bootloader（SSBL）。SSBL通常由设备制造商（OEM）开发，需要满足相关标准，例如：使用OEM的公钥验证`vbmeta`分区的签名以实现Verified Boot；支持A/B分区以实现无缝系统更新；提供Fastboot协议并管理其解锁状态；维护基于eFuse的防回滚索引，防止系统降级到旧版本。

Android 的 Verified Boot 过程始于第二级引导加载程序（SSBL）对 `/vbmeta` 分区进行数字签名验证。验证通过后，SSBL 使用 `/vbmeta` 中存储的哈希值对 `/boot` 分区进行完整性校验，确认无误后加载其中的内核与 initramfs。内核启动后，initramfs 中的 First Stage Init 开始执行，它根据 `/vbmeta` 中的元数据指示内核的 dm-verity 模块，将 `/system` 和 `/vendor` 等只读分区所在的设备（例如 `/dev/block/mmcblk0p10` 或 `/dev/block/by-name/system`）封装为对应的虚拟块设备（例如 `/dev/block/dm-0`）。此后，所有对这些分区的数据读取都会由`dm-verity`内核驱动在块级别实时进行哈希验证，确保与 `/vbmeta` 中受保护的哈希树一致，从而在保障完整性的同时避免了启动时的整体校验延迟。接着，First Stage Init 将控制权移交给位于 `/system` 分区内的 Second Stage Init，由后者挂载这些受验证的虚拟设备到根文件目录下的对应位置（`/system`、`/vendor`），并逐步启动系统服务、加载 SELinux 策略，最终通过 `zygote` 孵化出所有 Android 应用进程，完成从硬件信任根到应用层的安全启动链。

安卓的安全启动链环环相扣，若要修改由 `init` 加载的 SELinux 策略和上下文，就必须打断这一信任链条。SSBL 实现的 `fastboot` 协议要求设备必须提供 OEM 解锁功能，解锁后 SSBL 将不再验证 `/boot` 分区的签名。因此，我们可以通过实现 OEM 解锁（即解锁 bootloader），然后为 `/boot` 分区打上补丁。这个补丁的核心在于修改 `initramfs` 中的内核（KernelSU）或者First Stage Init（Magisk），使其在加载位于 `/system` 中的原始 SELinux 策略时，能够动态注入允许用户获取 root 权限的规则或上下文，或者直接加载一个修改过的策略文件。这样，在保持内核主体功能不变的前提下，通过控制 SELinux 策略的加载环节，即可在系统启动早期获得持久的 root 权限。

在KernelSU的使用中，首先我们需要找到方法进行 OEM 解锁。OEM 解锁默认会清除所有数据，因此需要提前备份。不同设备厂商对于 OEM 解锁的政策不同，如果需要将设备 Root ，应当在购买前确认厂商政策，在购买之后尽可能早地完成解锁。其次，我们需要获取当前手机所用系统的`/boot`分区映像的拷贝。由于手机内部的`/boot`分区在缺乏 Root 权限的情况下是无法让用户读取的，因此一般而言我们通过找寻系统更新包来获得该映像。这个映像也可以用于在设备因为 Root 过程中的某些操作无法启动时的补救工作；一般而言只要`fastboot`功能仍然正常，设备可以通过重刷官方系统进行修复。下一步，将系统映像传到设备中，由于补丁工作需要设备本身的运行时环境，因此需要在已经 OEM 解锁的手机内使用 KernelSU 安卓软件完成补丁制作。KernelSU 默认对 A/B 分区中当前活动分区进行补丁，如果需要更新但仍保障 Root 权限，则可以在下载好更新内容、重启手机前点击 KernelSU 中`安装到未使用槽位（OTA后）`选项，而后在官方更新界面进行重启即可。

在Arch Linux中的操作：

1. 安装`android-tools`
2. 在设备上多次点击设置中的版本号启用开发者选项中
3. 在开发者选项中打开 OEM 解锁和 USB 调试选项
4. 根据厂商要求完成 OEM 解锁
    - 对于没有过多要求的厂商：
    - 再次确认所有数据均已备份
    - 在电脑上运行`adb reboot bootloader`，在设备上选择信任调试设备，等带设备重启后进入 `fastboot` 模式
    - `fastboot flashing unlock`，使用音量键选择解锁选项后按电源键确认
5. 对于 KernelSU 系的 Root 管理工具，从旧到新有如下选择，应当根据实际设备型号及他人的使用经验进行选择：
    - `KernelSU`
    - `KernelSU Next`
    - `SukiSU-Ultra`
6. 使用`SukiSU-Ultra`时，到 Github 下载最新的 release apk 文件，`adb push *.apk /storage/emulated/0/Download/`传输到设备
7. 下载符合系统版本的官方系统包
    - 可以到酷安相应设备专区搜索版本号
    - 建议备份全量包；如果是全量包则需要将`payload.bin`中的`init_boot.img`提取出来
8. 使用`SukiSU-Ultra`修补`init_boot`分区镜像
9. 将修补好的镜像拉取到电脑上`adb pull "/storage/emulated/0/Download/$(adb shell ls "/storage/emulated/0/Download/" | grep kernelsu_patched)" .`
10. `adb reboot bootloader`后`fastboot flash init_boot /path/to/patched/init_boot.img`，成功后按下电源键重启，完成Root

以上 Root 方法对应于 KernelSU LKM 方法进行的 Root，对于所有需要权限的场景已经足够。然而，如果需要针对游戏反外挂做出最尖端前沿的隐藏 Root 环境的设置，进一步刷写 AnyKernel3 实现 GSI 模式 Root 可能能够更进一步提升隐藏能力，但需要自行编译内核。出于其他理由而产生的替换自编译内核的需求，也可以学习 SukiSU 官网的附加连接中的资料。由于部分厂商并不使用GKI，因此内核并不一定能够通用，但各个厂商的内核源代码应许可证要求是开源的，可能需要仔细甄别后手动编译。

隐藏 Root 的需求：

1. Google Play Integrity 检测
    - 大部分外网软件往往只能通过 Google Play Store 下载，并且会检查 Integrity 状态，否则会登录失败或导致账号冻结
    - 使用外网软件前应当先用开源工具进行 Integrity API 自查
    - 通过加载 KernelSU Module 对抗检测
        - TEESimulator/TrickyStore
        - PlayIntegrityFix
    - 在 Google 没有强制要求 strong 级别的 Integrity Check 之前，理论上都可以软件绕过检测

移动设备从计算机科学的角度来说和个人电脑没有区别。然而，在短短二十年中，从设备形态上的差异出发，通过与社会文化、生产生活方式的相辅相成的演化，移动设备的软硬件生态和商业模式与个人电脑已经截然不同。电脑中的开放的可能性与移动设备中的封闭的逻辑形成的刺目对比总让我感到荒谬，但一恍然又似乎又觉得，从来如此，或许就应然如此。

Zygisk和Lsposed框架安装：

- ReZygisk
- Lsposed from JingMatrix
    - 安装的时候可能需要手动解压压缩包中的manager.apk安装后给予Root权限才可使用

其他模块：

- bindhosts
- Universal GMS Doze

