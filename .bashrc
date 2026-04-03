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

declare -A COLORS=(
  ["red"]="\033[1;31m"
  ["green"]="\033[1;32m"
  ["yellow"]="\033[1;33m"
  ["blue"]="\033[1;34m"
  ["purple"]="\033[1;35m"
  ["cyan"]="\033[1;36m"
  ["white"]="\033[1;37m"
  ["reset"]="\033[0m"
)
printf_color() {
  local color_name=$(echo "$1" | tr '[:upper:]' '[:lower:]') # 转小写
  local message="$2"
  local color_code="${COLORS[$color_name]}"

  # 默认白色
  if [[ -z "$color_code" ]]; then
    color_code="${COLORS["white"]}"
  fi

  echo -e "${color_code}${message}${COLORS["reset"]}"
}

# 块定位函数
_dddrun_block_locate() {
  local file="$1"
  local tag="# $2"

  # 使用 awk 严格匹配字符串，完全无视正则特殊字符
  read -r s e exists < <(awk -v t="$tag" '
      $0 == t { s=NR; f=1; next }
      f && /^# \[/ { e=NR-1; exit }
      END {
          if (!f) print 0,0,0
          else print s, (e?e:NR), 1
      }
  ' "$file")

  echo "$s $e $exists"
}

# 块提取函数 (Internal helper)
_dddrun_block_get() {
  local file="$1"
  local tag_name="$2"
  read -r s e exists < <(_dddrun_block_locate "$file" "$tag_name")

  [ "$exists" -eq 1 ] && [ "$e" -gt "$s" ] && sed -n "$((s + 1)),${e}p" "$file" | awk 'NF'
}

# 块更新函数
_dddrun_block_set() {
  local file="$1"
  local tag_name="$2"
  local new_content=$(cat)
  read -r s e exists < <(_dddrun_block_locate "$file" "$tag_name")

  if [ "$exists" -eq 1 ]; then
    # 删掉旧的 content 部分，保留 Tag 行
    [ "$e" -gt "$s" ] && sed -i "$((s + 1)),${e}d" "$file"
    # 在 Tag 行后插入新内容
    { echo "$new_content"; echo ""; } | sed -i "${s}r /dev/stdin" "$file"
  else
    # 没找到就追加到末尾
    echo -e "\n# $tag_name\n$new_content\n" >> "$file"
  fi
}

declare -A BLOCKS=(
  [1]="[COMMANDS_INIT]"
  [2]="[COMMANDS_CONFIGS]"
  [3]="[COMMANDS_HISTORY]"
)

# 定义数据获取逻辑
_get_fresh_configs() {
  local block_list=$(printf "%s\n" "${BLOCKS[@]}")

  # 使用 -F (固定字符串) 和 -v (排除)
  # -f /dev/stdin 表示从标准输入读取“排除名单”
  grep "^# \[" "$file" | \
  grep -vFf <(echo "$block_list") | \
  sed 's/^# //'
}

# 执行确认：返回码 0=执行 2=跳过 130=退出
_dddrun_confirm_section() {
  local section_name="$1"
  local section_cmd="$2"
  local TERMINAL="/dev/tty"
  local opt=""

  printf_color "blue" "\n📦 即将执行功能区: ${section_name}"
  echo "$section_cmd"
  while true; do
    read -n 1 -p "Action: [Y]Run | [S]Skip | [N]Abort: " opt < "$TERMINAL"
    echo
    case "$opt" in
      [yY]) return 0 ;;
      [sS]) return 2 ;;
      [nN]) return 130 ;;
      *) printf_color "red" "无效的输入，请输入 Y/S/N" ;;
    esac
  done
}

# 将命令块按功能区执行（单行 SECTION 写法）：
#   ## [SECTION] 区块名
#   ...命令...
# 未标记内容会自动作为独立区块处理
_dddrun_execute_with_sections() {
  local init_content="$1"
  local raw_cmd="$2"
  local line=""
  local in_section=0
  local current_name=""
  local current_body=""
  local outside_body=""
  local auto_index=1
  local section_name=""
  local section_body=""
  local run_rc=0
  local ran_any=0
  local i=0
  local -a section_names=()
  local -a section_bodies=()

  _append_section() {
    local name="$1"
    local body="$2"
    [[ -z "${body//[[:space:]]/}" ]] && return 0
    section_names+=("$name")
    section_bodies+=("$body")
  }

  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^##[[:space:]]*\[SECTION\](.*)$ ]]; then
      if [ "$in_section" -eq 1 ]; then
        _append_section "$current_name" "$current_body"
        auto_index=$((auto_index + 1))
      fi

      if [[ -n "${outside_body//[[:space:]]/}" ]]; then
        _append_section "未标记区块-${auto_index}" "$outside_body"
        auto_index=$((auto_index + 1))
        outside_body=""
      fi

      current_name="${BASH_REMATCH[1]}"
      current_name="${current_name#"${current_name%%[![:space:]]*}"}"
      [ -z "$current_name" ] && current_name="功能区-${auto_index}"
      current_body=""
      in_section=1
      continue
    fi

    if [ "$in_section" -eq 1 ]; then
      if [ -n "$current_body" ]; then current_body+=$'\n'; fi
      current_body+="$line"
    else
      if [ -n "$outside_body" ]; then outside_body+=$'\n'; fi
      outside_body+="$line"
    fi
  done <<< "$raw_cmd"

  # 单行 SECTION 自动收尾
  if [ "$in_section" -eq 1 ]; then
    _append_section "$current_name" "$current_body"
  fi

  if [[ -n "${outside_body//[[:space:]]/}" ]]; then
    _append_section "未标记区块-${auto_index}" "$outside_body"
  fi

  # 没有功能区标签时，整个块视为单区块
  if [ "${#section_names[@]}" -eq 0 ]; then
    _append_section "默认区块" "$raw_cmd"
  fi

  for i in "${!section_names[@]}"; do
    section_name="${section_names[$i]}"
    section_body="${section_bodies[$i]}"

    _dddrun_confirm_section "$section_name" "$section_body"
    run_rc=$?
    case "$run_rc" in
      0) local final_cmd="${init_content}${init_content:+;}${section_body}"
         /bin/bash -c "$final_cmd" || return 1; ran_any=1 ;;
      2) printf_color "yellow" "⏭️ 已跳过: ${section_name}" ;;
      130) return 130 ;;
      *) return 1 ;;
    esac
  done

  [ "$ran_any" -eq 1 ] && return 0
  return 2
}

# 核心通用函数 (内部使用)
_dddrun_core() {
  local file="$1"
  local input_arg="$2"
  local pattern=""
  [ ! -f "$file" ] && { echo "❌ 找不到文件: $file"; return 1; }

  # ---- 提取相关内容 ----
  local init_content=$(_dddrun_block_get "$file" "${BLOCKS[1]}")
  local all_configs=$(_dddrun_block_get "$file" "${BLOCKS[2]}")
  local history_cmds=$(_dddrun_block_get "$file" "${BLOCKS[3]}")

  case "$input_arg" in
    "-h")
      printf_color "blue" "📖 dddrun 使用帮助:"
      echo "  dddrun-cmd [args]    执行当前目录下的 commands"
      echo "  dddrun-global [args] 执行全局 ~/.commands"
      echo "-----------------------------------------------"
      echo "  可选参数 [args]:"
      echo "    (空)       进入 fzf 交互模式 (智能置顶历史记录)"
      echo "    -l         快速执行最后一次成功运行的命令"
      echo "    -e         使用 vim 编辑当前的配置文件"
      echo "    -c         清空当前配置文件的 ${BLOCKS[3]} 区块"
      echo "    -h         显示本帮助信息"
      echo "    -f         刷新 ${BLOCKS[2]} 块"
      echo "    [string]   搜索包含该字符串的命令 并进入 fzf 交互模式"
      echo "-----------------------------------------------"
      echo "  功能区执行: 使用 '## [SECTION] 名称' 单行分段"
      echo "  文件结构建议: 包含 ${BLOCKS[1]} ${BLOCKS[2]} ${BLOCKS[3]} 结构块"
      return 0 ;;
    "-f")
      echo "🔄 正在同步 ${BLOCKS[2]} 索引..."
      # 扫描块标题
      local new_configs=$(_get_fresh_configs)
      [ -z "$new_configs" ] && { echo "⚠️ 未在文件中发现任何有效的业务指令块。"; return 1; }
      # 更新 [CONFIGS] 块
      echo "$new_configs" | _dddrun_block_set "$file" "${BLOCKS[2]}"
      echo "✅ 索引已刷新 ($(echo "$new_configs" | wc -l) 条记录)。"
      return 0 ;;
    "-e") vim "$file"; return 0 ;;
    "-c")
      # 将空内容传入块更新函数，实现“只清空该块、保留标签”的效果
      echo "" | _dddrun_block_set "$file" "${BLOCKS[3]}"
      echo "🧹 ${BLOCKS[3]} 块已清空"; return 0 ;;
    "-l")
      pattern=$(echo "$history_cmds" | head -n 1)
      if [ -z "$pattern" ]; then echo "❌ 暂无执行历史"; return 1; fi
      echo -n "$(printf_color "yellow" "🕒 自动加载最近一次命令: ")"; echo "$pattern" ;;
    *) ;;
  esac

  # ---- 交互模式 ----
  if [ -z "$pattern" ]; then
    # 如果 CONFIGS 块是空的，提醒用户刷新
    [ -z "$all_configs" ] && { printf_color "red" "🛑 ${BLOCKS[2]} 索引为空！请先使用 -f 刷新"; return 1; }
    # --preview 参数 实现命令预览
    pattern=$({ echo "$history_cmds"; echo "$all_configs"; } | awk 'NF && !vis[$0]++' | fzf \
      --height 80% --reverse --border --query "$input_arg" \
      --header "🎯 选择操作 (ESC 退出)" --preview-window "bottom:8:wrap" \
      --preview "
          $(declare -f _dddrun_block_locate);
          $(declare -f _dddrun_block_get);
          _dddrun_block_get $file {}
      "
    )

    [ -z "$pattern" ] && return 0
  fi

  # 调试使用
  # echo "${file} and ${pattern}"

  # ---- 正式提取命令 ----
  local cmd=$(_dddrun_block_get "$file" "$pattern")

  # 判断 cmd 是否存在
  [ -z "$cmd" ] && { echo "❌ 未找到匹配 '$pattern' 的指令。"; return 1; }

  # ---- 最终执行 ----
  # printf_color "green" "🚀 执行中:"
  # echo "$cmd"
  # echo "-----------------------------------------------"

  # 按功能区逐段确认并执行；无功能区标签时，整个块视为单区块
  _dddrun_execute_with_sections "$init_content" "$cmd"
  local exec_rc=$?

  case "$exec_rc" in
    0) local old_history=$(_dddrun_block_get "$file" "${BLOCKS[3]}")
       local new_history=$( (echo "$pattern"; echo "$old_history") | awk 'NF && !vis[$0]++' )
       echo "$new_history" | _dddrun_block_set "$file" "${BLOCKS[3]}" ;;
    2) printf_color "yellow" "⏭️ 所有功能区均被跳过，未执行任何命令" ;;
    130) printf_color "red" "🛑 用户终止执行"; return 130 ;;
    *) return "$exec_rc" ;;
  esac
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
