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

# 块定位函数
_dddrun_block_locate() {
  local file="$1"
  local tag="# $2"

  # 使用 awk 严格匹配字符串，完全无视正则特殊字符
  read -r s e exists < <(awk -v t="$tag" '
    {
        # 去掉当前行末尾的空白字符进行比较
        line = $0;
        sub(/[[:space:]]*$/, "", line);

        # 1. 寻找起始行 (完全匹配)
        if (line == t) {
            s = NR;
            f = 1;
            next;
        }

        # 2. 寻找结束行 (遇到下一个 # [ 停止)
        if (f && index($0, "# [") == 1) {
            e = NR - 1;
            exit;
        }
    }
    END {
        if (f) {
            if (e == 0) e = NR;
            print s, e, 1;
        } else {
            print "0 0 0";
        }
    }
  ' "$file")
  echo "$s $e $exists"
}

# 块提取函数 (Internal helper)
_dddrun_block_get() {
  local file="$1" tag_name="$2"
  read -r s e exists < <(_dddrun_block_locate "$file" "$tag_name")

  [ "$exists" -eq 1 ] && [ "$e" -gt "$s" ] && sed -n "$((s + 1)),${e}p" "$file" | awk 'NF'
}

# 块更新函数
_dddrun_block_set() {
  local file="$1" tag_name="$2"
  local new_content=$(cat)
  read -r s e exists < <(_dddrun_block_locate "$file" "$tag_name")

  if [ "$exists" -eq 1 ]; then
    # 删掉旧的 content 部分，保留 Tag 行
    [ "$e" -gt "$s" ] && sed -i "$((s + 1)),${e}d" "$file"
    # 在 Tag 行后插入新内容
    { echo "$new_content"; echo ""; } | sed -i "${s}r /dev/stdin" "$file"
  else
    # 没找到就追加到末尾
    echo -e "\n# [$tag_name]\n$new_content\n" >> "$file"
  fi
}

# 定义数据获取逻辑
_get_fresh_configs() {
    grep "^# \[" "$file" | \
    grep -vE "\[INIT\]|\[CONFIGS\]|\[HISTORY_COMMANDS\]" | \
    sed 's/^# //'
}

# 核心通用函数 (内部使用)
_dddrun_core() {
  local file="$1"
  local input_arg="$2"
  local pattern=""
  [ ! -f "$file" ] && { echo "❌ 找不到文件: $file"; return 1; }

  # ---- 提取相关内容 ----
  local init_content=$(_dddrun_block_get "$file" "[INIT]")
  local all_configs=$(_dddrun_block_get "$file" "[CONFIGS]")
  local history_cmds=$(_dddrun_block_get "$file" "[HISTORY_COMMANDS]" | tac)

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
      echo "    -f         刷新 [CONFIGS] 块"
      echo "    [string]   搜索包含该字符串的命令 并进入 fzf 交互模式"
      echo "-----------------------------------------------"
      echo "  文件结构建议: 包含 [INIT] [CONFIGS] [HISTORY_COMMANDS] 结构块"
      return 0 ;;
    "-f")
      echo "🔄 正在同步 [CONFIGS] 索引..."
      # 扫描块标题
      local new_configs=$(_get_fresh_configs)
      [ -z "$new_configs" ] && { echo "⚠️ 未在文件中发现任何有效的业务指令块。"; return 1; }
      # 更新 [CONFIGS] 块
      echo "$new_configs" | _dddrun_block_set "$file" "[CONFIGS]"
      echo "✅ 索引已刷新 ($(echo "$new_configs" | wc -l) 条记录)。"
      return 0 ;;
    "-e") vim "$file"; return 0 ;;
    "-c")
      # 将空内容传入块更新函数，实现“只清空该块、保留标签”的效果
      echo "" | _dddrun_block_set "$file" "[HISTORY_COMMANDS]"
      echo "🧹 [HISTORY_COMMANDS] 块已清空"
      return 0
      ;;
    "-l")
      pattern=$(echo "$history_cmds" | head -n 1)
      if [ -z "$pattern" ]; then echo "❌ 暂无执行历史"; return 1; fi
      echo -e "\033[1;33m🕒 自动加载最近一次命令: \033[0m$pattern" ;;
    *) ;;
  esac

  # ---- 交互模式 ----
  if [ -z "$pattern" ]; then
    # 如果 CONFIGS 块是空的，提醒用户刷新
    [ -z "$all_configs" ] && { echo -e "\033[1;31m🛑 [CONFIGS] 索引为空！请先使用 -f 刷新\033[0m"; return 1; }
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

  echo "${file} and ${pattern}"

  # ---- 正式提取命令 ----
  local cmd=$(_dddrun_block_get "$file" "$pattern")

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
    if [ $? -eq 0 ]; then
      local old_history=$(_dddrun_block_get "$file" "[HISTORY_COMMANDS]")
      local new_history=$( (echo "$old_history"; echo "$pattern") | awk 'NF && !vis[$0]++' )
      echo "$new_history" | _dddrun_block_set "$file" "[HISTORY_COMMANDS]"
    fi
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
