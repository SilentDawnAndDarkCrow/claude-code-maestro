#!/bin/bash
# Hook: TASK_LIST.md 更新后检查任务完成情况
# 触发时机：PostToolUse（Write、Edit 针对 TASK_LIST.md）
# 退出码：0 = 正常（PostToolUse hook 不阻断操作，仅报告）

# 从 stdin 读取工具调用信息（JSON）
INPUT=$(cat)

# 提取工具名称
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name', ''))
except:
    print('')
" 2>/dev/null)

# 只处理 Write 和 Edit 操作
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "NotebookEdit" ]]; then
  exit 0
fi

# 提取目标文件路径
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    params = data.get('tool_input', {})
    print(params.get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# 只处理 TASK_LIST.md 的修改
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VERSION_FILE="$PROJECT_ROOT/VERSION"
if [ ! -f "$VERSION_FILE" ]; then
  exit 0
fi

VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
if [ -z "$VERSION" ]; then
  exit 0
fi

TASK_LIST="$PROJECT_ROOT/upgrade_plan/v${VERSION}/TASK_LIST.md"

# 检查操作的目标文件是否是 TASK_LIST.md
if [[ "$FILE_PATH" != *"upgrade_plan/v${VERSION}/TASK_LIST.md" ]]; then
  exit 0
fi

# ==== 统计任务状态 ====
if [ ! -f "$TASK_LIST" ]; then
  exit 0
fi

TOTAL=$(grep -c "^| T" "$TASK_LIST" 2>/dev/null || echo "0")
COMPLETED=$(grep -c "| completed |" "$TASK_LIST" 2>/dev/null || echo "0")
IN_PROCESS=$(grep -c "| in_progress |" "$TASK_LIST" 2>/dev/null || echo "0")
PENDING=$(grep -c "| pending |" "$TASK_LIST" 2>/dev/null || echo "0")

echo "" >&2
echo "📋 [TASK_LIST] v${VERSION} 任务进度：${COMPLETED}/${TOTAL} 已完成" >&2
echo "" >&2

# 显示进行中任务
if [ "$IN_PROCESS" -gt 0 ]; then
  echo "  🔄 进行中（in_progress）：" >&2
  grep "| in_progress |" "$TASK_LIST" | while IFS= read -r line; do
    echo "     $line" >&2
  done
fi

# 显示待处理任务
if [ "$PENDING" -gt 0 ]; then
  echo "  ⏳ 待处理（pending）：" >&2
  grep "| pending |" "$TASK_LIST" | while IFS= read -r line; do
    echo "     $line" >&2
  done
fi

# 全部完成时的提示
if [ "$COMPLETED" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
  echo "  🎉 所有任务已完成！可以更新 VERSION 并将状态标记为 ✅ 已完成。" >&2
fi

echo "" >&2
exit 0
