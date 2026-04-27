#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return


alias ls='ls --color=auto'
ll() { ls -lh --color=always "$@"; }
la() { ls -la --color=always "$@"; }
lsa() { ls -d "$PWD"/*; }
# realpath *
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
export PATH=/home/bowl/.npm-global/bin:$PATH

alias notepad='kate'

# 定义函数
declare -a CLIP_ARRAY

wclip() {
  local tmp_file=$(mktemp)
  "$@" | tee "$tmp_file"
  clip_temp=$(cat "$tmp_file")
  mapfile -t CLIP_ARRAY < "$tmp_file"
  rm -f "$tmp_file"
}
rclip() {
  # 检查数组是否有内容
  if [ ${#CLIP_ARRAY[@]} -eq 0 ]; then
    echo -e "\e[31m[!] 剪贴板为空，请先运行 wclip [命令]\e[0m"
    return 1
  fi

  local target=""
  local cmd="$1"

  # 1. 确定目标 (Target)
  if [[ "$cmd" =~ ^[0-9]+$ ]]; then
    # 如果第一个参数是数字 (如 rclip 6 cd)
    target="${CLIP_ARRAY[$((10#$cmd - 1))]}"
    shift
    cmd="$1" # 更新真正的命令为第二个参数
  else
    # 方案一：直观选择模式 (如 rclip cd)
    # 弹出 fzf，按回车选中内容
    target=$(printf "%s\n" "${CLIP_ARRAY[@]}" | fzf --height 15% --reverse --border --prompt="选择目标 > ")
    # 如果用户按了 ESC 退出 fzf，则直接返回
    [ -z "$target" ] && return
  fi

  # 2. 执行逻辑
  if [ -z "$cmd" ]; then
    # 如果没给命令，只打印选中的内容
    echo "$target"
  else
    # 特殊处理内建命令 cd
    if [ "$cmd" = "cd" ]; then
      cd "$target"
    else
      # 执行外部命令或其他内建命令
      "$cmd" "$target"
    fi
  fi
}

# alias dddtools="/home/bowl/Code/ShellTools/script_dir/system_menu.sh"
# alias dddtoolss="source /home/bowl/Code/ShellTools/script_dir/system_menu.sh"

# 桌面黑屏，需重启
alias dddcqzm="kquitapp6 plasmashell || killall plasmashell && setsid plasmashell > /dev/null 2>&1 &"

# dddrun 功能拆分到独立脚本
[ -f "$HOME/.dddrun.sh" ] && source "$HOME/.dddrun.sh"
