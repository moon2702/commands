#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# export GTK_IM_MODULE=ibus
# export XMODIFIERS=@im=ibus
# export QT_IM_MODULE=ibus

export http_proxy=http://127.0.0.1:10808
export https_proxy=http://127.0.0.1:10808
export all_proxy=socks5://127.0.0.1:10808

export PATH=/home/bowl/Software/Tools/bin:$PATH
export PATH=/home/bowl/Android/Sdk/platform-tools:$PATH

alias dddtools="/home/bowl/Code/ShellTools/script_dir/system_menu.sh"
alias dddtoolss="source /home/bowl/Code/ShellTools/script_dir/system_menu.sh"

# 桌面黑屏，需重启
alias dddcqzm="kquitapp6 plasmashell || killall plasmashell && setsid plasmashell > /dev/null 2>&1 &"

# 执行当前目录下的 commands
dddrun-cmd() {
  local file="commands"
  [ ! -f "$file" ] && { echo "❌ 找不到 $file"; return 1; }

  # 检查是否安装了 fzf
  if ! command -v fzf &> /dev/null; then
      echo "⚠️ 未安装 fzf，退回到手动模式..."
      # 这里可以保留你原来的 grep 帮助逻辑
      return 1
  fi

  local pattern=$1
  local selected=""

  # --- 交互选择模式：如果没有输入参数，或者参数匹配不到结果 ---
  if [ -z "$pattern" ]; then
    # 从文件中提取所有 # 注释，交给 fzf 选择
    selected=$(grep "^# " "$file" | sed 's/^# //' | fzf \
      --height 40% \
      --reverse \
      --header "🎯 选择要执行的操作 (ESC 退出):" \
      --border \
      --inline-info)

    [ -z "$selected" ] && return 0
    pattern="$selected"
  fi

  # --- 提取与执行逻辑 ---
  # 使用之前验证过的 sed 强保护逻辑
  cmd=$(grep -A 1 "$pattern" "$file" | grep -v "^#" | grep -v "^$" | tail -n 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ -z "$cmd" ]; then
    echo "❌ 未找到匹配 '$pattern' 的指令。"
    return 1
  fi

  echo -e "\033[1;32m🚀 执行中:\033[0m $cmd"
  /bin/bash -c "$cmd"
}
