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

DDD_HIST_FILE="$HOME/.dddrun_history"

# 核心通用函数 (内部使用)
_dddrun_core() {
  local file="$1"
  local input_arg="$2"
  local pattern=""
  [ ! -f "$file" ] && { echo "❌ 找不到文件: $file"; return 1; }

  case "$input_arg" in
    "-e") vim "$file"; return 0 ;;
    "-c")
      > "$DDD_HIST_FILE"
      echo "🧹 历史记录已清空"
      return 0
      ;;
    "-l")
      if [ -f "$DDD_HIST_FILE" ]; then
        # 读取最后一次该文件相关的历史（如果是 global 就读 global 的，cmd 就读 cmd 的）
        # 这里我们简单处理，读取全局最后一条记录
        pattern=$(tail -n 1 "$DDD_HIST_FILE")
        echo -e "\033[1;33m🕒 自动加载最近一次命令: \033[0m$pattern"
      else
        echo "❌ 暂无执行历史。"
        return 1
      fi
      ;;
    *)
      pattern="$input_arg"
      ;;
  esac

  local all_cmds=$(grep "^# " "$file" | grep -v "\[INIT\]" | sed 's/^# //')
  local history_cmds=""
  [ -f "$DDD_HIST_FILE" ] && history_cmds=$(tac "$DDD_HIST_FILE")

  # ---- 交互模式 ----
  if [ -z "$pattern" ]; then
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
  final_cmd="${init_content}${init_content:+;}${cmd}"

  # 执行 + 记录一条历史
  if /bin/bash -c "$final_cmd"; then
      touch "$DDD_HIST_FILE"
      sed -i "/^$pattern$/d" "$DDD_HIST_FILE"
      echo "$pattern" >> "$DDD_HIST_FILE"
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
