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

# 核心通用函数 (内部使用)
_dddrun_core() {
  local file="$1"
  local pattern="$2"
  [ ! -f "$file" ] && { echo "❌ 找不到文件: $file"; return 1; }

  # 1. 如果没有输入参数，进入 fzf 交互模式
  if [ -z "$pattern" ]; then
    # --preview 参数让你在选择时能看到注释下的那行指令内容
    pattern=$(grep "^# " "$file" | sed 's/^# //' | fzf \
      --height 40% \
      --reverse \
      --border \
      --header "🎯 选择操作 (ESC 退出)" \
      --preview "grep -F -A 1 {} $file | grep -v '^#' | grep -v '^$'" \
      --preview-window "bottom:2:wrap")

    [ -z "$pattern" ] && return 0
  fi

  # 2. 提取指令 (使用已验证的 sed 强保护逻辑)
  local cmd=$(grep -F -A 1 "$pattern" "$file" | grep -v "^#" | grep -v "^$" | tail -n 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ -z "$cmd" ]; then
    echo "❌ 未找到匹配 '$pattern' 的指令。"
    return 1
  fi

  # 3. 执行
  echo -e "\033[1;32m🚀 执行中:\033[0m $cmd"
  /bin/bash -c "$cmd"
}

# --- 用户调用接口 ---

# 执行当前目录下的 commands
dddrun-cmd() {
  _dddrun_core "commands" "$1"
}

# 执行全局配置 ~/.commands
dddrun-global() {
  _dddrun_core "$HOME/.commands" "$1"
}
