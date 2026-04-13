#!/usr/bin/env bash

[[ -n "${_DDDRUN_SH_LOADED:-}" ]] && return 0
_DDDRUN_SH_LOADED=1

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
  local color_name=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  local message="$2"
  local color_code="${COLORS[$color_name]}"

  if [[ -z "$color_code" ]]; then
    color_code="${COLORS["white"]}"
  fi

  echo -e "${color_code}${message}${COLORS["reset"]}"
}

_dddrun_block_locate() {
  local file="$1"
  local tag="# $2"

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

_dddrun_block_get() {
  local file="$1"
  local tag_name="$2"
  read -r s e exists < <(_dddrun_block_locate "$file" "$tag_name")

  [ "$exists" -eq 1 ] && [ "$e" -gt "$s" ] && sed -n "$((s + 1)),${e}p" "$file" | awk 'NF'
}

_dddrun_block_set() {
  local file="$1"
  local tag_name="$2"
  local new_content
  new_content=$(cat)
  read -r s e exists < <(_dddrun_block_locate "$file" "$tag_name")

  if [ "$exists" -eq 1 ]; then
    [ "$e" -gt "$s" ] && sed -i "$((s + 1)),${e}d" "$file"
    { echo "$new_content"; echo ""; } | sed -i "${s}r /dev/stdin" "$file"
  else
    echo -e "\n# $tag_name\n$new_content\n" >> "$file"
  fi
}

declare -A BLOCKS=(
  [1]="[COMMANDS_INIT]"
  [2]="[COMMANDS_CONFIGS]"
  [3]="[COMMANDS_HISTORY]"
)

_get_fresh_configs() {
  local block_list
  block_list=$(printf "%s\n" "${BLOCKS[@]}")

  grep "^# \[" "$file" | \
  grep -vFf <(echo "$block_list") | \
  sed 's/^# //'
}

_dddrun_confirm_section() {
  local section_name="$1"
  local section_cmd="$2"
  local TERMINAL="/dev/tty"
  local opt=""

  printf_color "blue" "\n📦 即将执行功能区: ${section_name}"
  # echo "$section_cmd"
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

  if [ "$in_section" -eq 1 ]; then
    _append_section "$current_name" "$current_body"
  fi

  if [[ -n "${outside_body//[[:space:]]/}" ]]; then
    _append_section "未标记区块-${auto_index}" "$outside_body"
  fi

  if [ "${#section_names[@]}" -eq 0 ]; then
    _append_section "默认区块" "$raw_cmd"
  fi

  for i in "${!section_names[@]}"; do
    section_name="${section_names[$i]}"
    section_body="${section_bodies[$i]}"

    _dddrun_confirm_section "$section_name" "$section_body"
    run_rc=$?
    case "$run_rc" in
      0)
        local final_cmd="${init_content}${init_content:+;}${section_body}"
        /bin/bash -c "$final_cmd" || return 1
        ran_any=1
        ;;
      2) printf_color "yellow" "⏭️ 已跳过: ${section_name}" ;;
      130) return 130 ;;
      *) return 1 ;;
    esac
  done

  [ "$ran_any" -eq 1 ] && return 0
  return 2
}

_dddrun_core() {
  local file="$1"
  local input_arg="$2"
  local pattern=""
  [ ! -f "$file" ] && { echo "❌ 找不到文件: $file"; return 1; }

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
      echo "    -l         快速执行最后一次选择的命令"
      echo "    -e         使用 vim 编辑当前的配置文件"
      echo "    -c         清空当前配置文件的 ${BLOCKS[3]} 区块"
      echo "    -h         显示本帮助信息"
      echo "    -f         刷新 ${BLOCKS[2]} 块"
      echo "    [string]   搜索包含该字符串的命令 并进入 fzf 交互模式"
      echo "-----------------------------------------------"
      echo "  功能区执行: 使用 '## [SECTION] 名称' 单行分段"
      echo "  文件结构建议: 包含 ${BLOCKS[1]} ${BLOCKS[2]} ${BLOCKS[3]} 结构块"
      return 0
      ;;
    "-f")
      echo "🔄 正在同步 ${BLOCKS[2]} 索引..."
      local new_configs=$(_get_fresh_configs)
      [ -z "$new_configs" ] && { echo "⚠️ 未在文件中发现任何有效的业务指令块。"; return 1; }
      echo "$new_configs" | _dddrun_block_set "$file" "${BLOCKS[2]}"
      echo "✅ 索引已刷新 ($(echo "$new_configs" | wc -l) 条记录)。"
      return 0
      ;;
    "-e") vim "$file"; return 0 ;;
    "-c")
      echo "" | _dddrun_block_set "$file" "${BLOCKS[3]}"
      echo "🧹 ${BLOCKS[3]} 块已清空"
      return 0
      ;;
    "-l")
      pattern=$(echo "$history_cmds" | head -n 1)
      if [ -z "$pattern" ]; then echo "❌ 暂无执行历史"; return 1; fi
      echo -n "$(printf_color "yellow" "🕒 自动加载最近一次命令: ")"
      echo "$pattern"
      ;;
    *) ;;
  esac

  if [ -z "$pattern" ]; then
    [ -z "$all_configs" ] && { printf_color "red" "🛑 ${BLOCKS[2]} 索引为空！请先使用 -f 刷新"; return 1; }
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

  local cmd=$(_dddrun_block_get "$file" "$pattern")
  [ -z "$cmd" ] && { echo "❌ 未找到匹配 '$pattern' 的指令。"; return 1; }

  # 选中后即写入历史，不再依赖执行结果。
  local old_history=$(_dddrun_block_get "$file" "${BLOCKS[3]}")
  local new_history=$( (echo "$pattern"; echo "$old_history") | awk 'NF && !vis[$0]++' )
  echo "$new_history" | _dddrun_block_set "$file" "${BLOCKS[3]}"

  _dddrun_execute_with_sections "$init_content" "$cmd"
  local exec_rc=$?

  case "$exec_rc" in
    0) printf_color "green" "✅ 命令执行成功";;
    2) printf_color "yellow" "⏭️ 所有功能区均被跳过，未执行任何命令" ;;
    130) printf_color "red" "🛑 用户终止执行"; return 130 ;;
    *) return "$exec_rc" ;;
  esac
}

dddrun-cmd() {
  _dddrun_core "commands" "$1"
}

dddrun-global() {
  _dddrun_core "$HOME/.commands" "$1"
}
