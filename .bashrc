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
    f && (/^[[:space:]]*$/ || /^# /) { exit }
    f { print }
  ' "$target_file"
}

# 核心通用函数 (内部使用)
_dddrun_core() {
  local file="$1"
  local input_arg="$2"
  local pattern=""
  [ ! -f "$file" ] && { echo "❌ 找不到文件: $file"; return 1; }

  # ---- 提取历史记录 ----
  # 从 [HISTORY_COMMANDS] 到文件结尾
  local history_cmds=$(awk '/^# \[HISTORY_COMMANDS\]/ {f=1; next} f {if(NF) print}' "$file" | tac)

case "$input_arg" in
    "-h")
      echo -e "\033[1;34m📖 dddrun 使用帮助:\033[0m"
      echo "  dddrun-cmd [args]    执行当前目录下的 commands"
      echo "  dddrun-global [args] 执行全局 ~/.commands"
      echo "-----------------------------------------------"
      echo "  可选参数 [args]:"
      echo "    (空)       进入 fzf 交互模式 (智能置顶历史记录)"
      echo "    -l         快速执行最后一次成功运行的命令"
      echo "    -e         使用 vim 编辑当前的配置文件"
      echo "    -c         清空当前配置文件的 [HISTORY_COMMANDS] 区块"
      echo "    -h         显示本帮助信息"
      echo "    [string]   搜索包含该字符串的命令 并进入 fzf 交互模式"
      echo "-----------------------------------------------"
      echo "  文件结构建议: 包含 #[INIT] 函数定义块 和 #[HISTORY_COMMANDS] 结尾块"
      return 0
      ;;
    "-e") vim "$file"; return 0 ;;
    "-c")
      sed -i '/^# \[HISTORY_COMMANDS\]/q' "$file"
      echo "🧹 历史记录已清空"; return 0 ;;
    "-l")
      pattern=$(echo "$history_cmds" | head -n 1)
      if [ -z "$pattern" ]; then echo "❌ 暂无执行历史"; return 1; fi
      echo -e "\033[1;33m🕒 自动加载最近一次命令: \033[0m$pattern" ;;
    *) pattern="$input_arg" ;;
  esac

  # ---- 交互模式 ----
  if [ -z "$pattern" ]; then
    local all_cmds=$(grep "^# " "$file" | grep -v "\[INIT\]" | grep -v "\[HISTORY_COMMANDS\]" | sed 's/^# //')
    # --preview 参数 实现命令预览
    pattern=$({ echo "$history_cmds"; echo "$all_cmds"; } | awk 'NF && !vis[$0]++' | fzf \
      --height 40% --reverse --border --query "$input_arg" \
      --header "🎯 选择操作 (ESC 退出)" --preview-window "bottom:3:wrap" \
      --preview "$(declare -f _dddrun_extract_cmd); _dddrun_extract_cmd $file {}")

    [ -z "$pattern" ] && return 0
  fi

  echo "${file} and ${pattern}"

  # ---- 提取 [INIT] 块 ----
  local init_content=$(_dddrun_extract_cmd "$file" "[INIT]")
  # ---- 正式提取命令 ----
  local cmd=$(_dddrun_extract_cmd "$file" "$pattern")

  # 判断 cmd 是否存在
  [ -z "$cmd" ] && { echo "❌ 未找到匹配 '$pattern' 的指令。"; return 1; }

  # ---- 最终执行 ----
  echo -e "\033[1;32m🚀 执行中:\033[0m"
  echo "$cmd"
  echo "-----------------------------------------------"

  # 将 [INIT] 与抓取到的命令拼接，交给子 Bash 执行
  # 如此 cmd 可以直接调用 [INIT] 中的定义
  local final_cmd="${init_content}${init_content:+;}${cmd}"

  # 执行 + 记录一条历史
  if /bin/bash -c "$final_cmd"; then
    if ! grep -q "^# \[HISTORY_COMMANDS\]" "$file"; then
        echo -e "\n# [HISTORY_COMMANDS]" >> "$file"
    fi
    local start_line=$(grep -n "^# \[HISTORY_COMMANDS\]" "$file" | cut -d: -f1)
    local escaped_pattern=$(echo "$pattern" | sed 's/[][\.*^$]/\\&/g')
    sed -i "$((start_line + 1)),\$ { /^$escaped_pattern$/d }" "$file"
    echo "$pattern" >> "$file"
  fi
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
