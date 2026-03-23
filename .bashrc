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
  local pattern=$1
  local file="commands"

  # --- 帮助模式：如果没有输入参数 ---
  if [ -z "$pattern" ]; then
    echo "💡 可用指令列表 (从 $file 提取):"
    echo "--------------------------------"
    # 提取以 # 开头的行，并去掉 # 符号和开头的空格
    grep "^# " "$file" | sed 's/^# //' | awk '{print "  • " $0}'
    echo "--------------------------------"
    echo "用法: dddrun-cmd [关键词]"
    return 0
  fi

  # --- 执行模式：如果有参数 ---
  # 匹配模式后的那一行，同时过滤掉注释行和空行
  cmd=$(grep -A 1 "$pattern" "$file" | grep -v "^#" | grep -v "^$" | tail -n 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ -z "$cmd" ]; then
    echo "❌ 错误: 未找到匹配 '$pattern' 的有效指令。"
    return 1
  fi

  echo "🚀 正在执行: $cmd"
  eval "$cmd"
  # /bin/bash -c "$cmd"
}
