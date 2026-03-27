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

# 一个独立的提取函数 (Internal helper)
_dddrun_extract_cmd() {
  local target_file="$1"
  local search_pattern="# $2"

  # 使用 awk 的最稳健写法：不依赖外部转义
  awk -v p="$search_pattern" '
    index($0, p) == 1 { f=1; next }
    f && /^[[:space:]]*$/ { exit }
    f { print }
  ' "$target_file"
}

# 核心通用函数 (内部使用)
_dddrun_core() {
  local file="$1"
  local pattern="$2"
  [ ! -f "$file" ] && { echo "❌ 找不到文件: $file"; return 1; }

  # ---- 提取当前文件内的 [INIT] 块 ----
  # 先抓取头部的 [INIT] 定义
  local init_content=$(_dddrun_extract_cmd "$file" "[INIT]")

  # ---- 交互模式 ----
  if [ -z "$pattern" ]; then
    # --preview 参数 实现命令预览
    pattern=$(grep "^# " "$file" | grep -v "\[INIT\]" | sed 's/^# //' | fzf \
      --height 40% \
      --reverse \
      --border \
      --header "🎯 选择操作 (ESC 退出)" \
      --preview "$(declare -f _dddrun_extract_cmd); _dddrun_extract_cmd $file {}" \
      --preview-window "bottom:3:wrap")

    [ -z "$pattern" ] && return 0
  fi

  # ---- 正式提取命令 ----
  local cmd=$(_dddrun_extract_cmd "$file" "$pattern")

  if [ -z "$cmd" ]; then
    echo "❌ 未找到匹配 '$pattern' 的指令。"
    return 1
  fi

  # ---- 最终执行 ----
  echo -e "\033[1;32m🚀 执行中:\033[0m"
  echo "$cmd"
  echo "-----------------------------------------------"

  # 将 [INIT] 与抓取到的命令拼接，交给子 Bash 执行
  # 如此 cmd 可以直接调用 [INIT] 中的定义
  /bin/bash -c "${init_content}; ${cmd}"
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
