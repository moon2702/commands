# dddrun 使用说明

`dddrun` 是一个基于文本配置的命令块执行器，支持：

- `fzf` 交互选择命令块
- 最近历史优先
- 按功能区逐段确认执行（`Y` 执行 / `S` 跳过 / `N` 终止）

---

## 入口命令

- `dddrun-cmd`：执行当前目录下的 `commands`
- `dddrun-global`：执行全局 `~/.commands`

常用参数（两者通用）：

- `-h`：查看帮助
- `-f`：刷新 `[COMMANDS_CONFIGS]` 索引
- `-l`：直接加载并执行最近一次成功记录
- `-e`：编辑当前配置文件
- `-c`：清空 `[COMMANDS_HISTORY]`
- `[关键词]`：带关键词进入筛选

---

## 配置文件结构

配置文件可以是 `commands` 或 `~/.commands`，推荐包含三个系统块：

- `# [COMMANDS_INIT]`：全局初始化脚本（函数、变量、环境）
- `# [COMMANDS_CONFIGS]`：可选标签索引（可通过 `-f` 自动刷新）
- `# [COMMANDS_HISTORY]`：历史记录（自动维护）

业务命令块以 `# [标签名]` 开始，例如：

- `# [T] TEST1`
- `# [Android] xxx`

---

## 功能区分段语法（当前方案）

在某个业务命令块内部，使用单行 SECTION 语法分段：

```bash
## [SECTION] 检查环境
echo "check env"

## [SECTION] 执行核心命令
echo "run main task"
```

说明：

- 支持 `## [SECTION]`
- 每个 SECTION 执行前都会询问一次
- `## [SECTION]` 后可留空，系统会自动命名为 `功能区-N`
- 若命令块没有 SECTION，整个块会作为一个默认区块确认执行

---

## 最小可用示例

```bash
# [COMMANDS_INIT]
echo ""

# [T] TEST3
## [SECTION] 检查用户
FILE="/etc/passwd"
while IFS=: read -r user x; do
  echo "正在检查用户: $user"
  break
done < "$FILE"

## [SECTION] 清理临时文件
echo "准备清理临时文件..."
rm -rf /tmp/test_cache

## [SECTION] 查询时间
date

# [COMMANDS_CONFIGS]
[T] TEST3

# [COMMANDS_HISTORY]
```

---

## 初始化建议

全局模式：

```bash
touch ~/.commands
dddrun-global -e
```

项目模式：

```bash
touch commands
dddrun-cmd -e
```

首次写完后建议执行一次：

```bash
dddrun-cmd -f
```

---

## 安全建议

- `commands` / `~/.commands` 建议只允许本人写入（如 `chmod 600`）
- 高危命令（刷机、分区写入、删除操作）建议单独 SECTION，避免误执行整块
- 执行前先看预览内容，确认当前选择的标签和功能区符合预期
