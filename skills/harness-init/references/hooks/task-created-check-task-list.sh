#!/bin/bash
# Hook: TaskCreated 时检查当前版本是否存在 TASK_LIST.md
# 触发时机：TaskCreated
# 数据来源：VERSION 文件（根目录）
# 退出码：0 = 允许，2 = 强制阻断

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VERSION_FILE="$PROJECT_ROOT/VERSION"

# ==== 从根目录 VERSION 文件获取当前版本 ====
if [ ! -f "$VERSION_FILE" ]; then
  echo "⚠️  [TaskCreated] 未找到 VERSION 文件，跳过 TASK_LIST 检查。" >&2
  exit 0
fi

CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')

if [ -z "$CURRENT_VERSION" ]; then
  echo "⚠️  [TaskCreated] VERSION 文件为空，跳过检查。" >&2
  exit 0
fi

TASK_LIST="$PROJECT_ROOT/upgrade_plan/v${CURRENT_VERSION}/TASK_LIST.md"

# ==== 检查 TASK_LIST.md 是否存在 ====
if [ ! -f "$TASK_LIST" ]; then
  echo "" >&2
  echo "⛔ Task 创建被阻止：当前版本 v${CURRENT_VERSION} 尚未建立 TASK_LIST.md" >&2
  echo "" >&2
  echo "  版本来源：VERSION 文件" >&2
  echo "  期望路径：upgrade_plan/v${CURRENT_VERSION}/TASK_LIST.md" >&2
  echo "" >&2
  echo "  创建 Task 之前，请先完成以下步骤：" >&2
  echo "  1. 新建 upgrade_plan/v${CURRENT_VERSION}/TASK_LIST.md" >&2
  echo "  2. 在文件中定义本版本的任务列表（格式见 CLAUDE.md）" >&2
  echo "  3. 再次创建 Task" >&2
  echo "" >&2
  exit 2
fi

# ==== 通过检查 ====
TOTAL=$(grep -c "^| T" "$TASK_LIST" 2>/dev/null || echo "0")
COMPLETED=$(grep -c "| completed |" "$TASK_LIST" 2>/dev/null || echo "0")
IN_PROCESS=$(grep -c "| in_progress |" "$TASK_LIST" 2>/dev/null || echo "0")

echo "✅ [TaskCreated] v${CURRENT_VERSION} — TASK_LIST 已存在（${COMPLETED}/${TOTAL} 完成，${IN_PROCESS} 进行中）" >&2
exit 0
