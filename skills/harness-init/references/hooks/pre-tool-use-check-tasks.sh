#!/bin/bash
# Hook: 强制要求在 Write/Edit 操作前满足任务管理规范
# 触发时机：PreToolUse（Write、Edit、NotebookEdit）
# 退出码：0 = 允许，2 = 强制阻断（Claude Code 规范）

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

# 只拦截 Write 和 Edit 操作
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

# 获取项目根目录（hook 运行时 cwd 为项目根）
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ==== 读取当前版本号（来源：VERSION 文件）====
VERSION_FILE="$PROJECT_ROOT/VERSION"
if [ ! -f "$VERSION_FILE" ]; then
  echo "⛔ [版本检查] 未找到 VERSION 文件，无法确认当前版本。" >&2
  exit 2
fi

VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
if [ -z "$VERSION" ]; then
  echo "⛔ [版本检查] VERSION 文件为空，无法确认当前版本。" >&2
  exit 2
fi

TASK_STATE="$PROJECT_ROOT/upgrade_plan/v${VERSION}/task_state.json"
TASK_LIST="$PROJECT_ROOT/upgrade_plan/v${VERSION}/TASK_LIST.md"
REQUIREMENT_DOC="$PROJECT_ROOT/upgrade_plan/v${VERSION}/requirement_analysis.md"

# ==== 豁免：TASK_LIST.md 本身的修改始终允许 ====
if [[ "$FILE_PATH" == *"upgrade_plan/v${VERSION}/TASK_LIST.md" ]]; then
  exit 0
fi

# ==== 豁免：~/.claude/ 路径（工具/eval 临时产物，不属于项目版本管理）====
if [[ "$FILE_PATH" == "$HOME/.claude/"* ]]; then
  exit 0
fi

# ==== 豁免：项目 .claude/ 目录（Harness 治理文件，由 harness-init 管理）====
# harness-init supplement 模式需要写入 hooks/、settings.json、规范文件、agent SKILL.md
# 这些是治理文件而非业务源码，不应受任务管理门控约束
if [[ "$FILE_PATH" == "$PROJECT_ROOT/.claude/"* ]] || [[ "$FILE_PATH" == ".claude/"* ]]; then
  exit 0
fi

# ==== 特殊处理：task_state.json 的写入 ====
if [[ "$FILE_PATH" == *"upgrade_plan/v${VERSION}/task_state.json" ]]; then
  # 若 task_state.json 已存在，说明是断点续跑，直接允许
  if [ -f "$TASK_STATE" ]; then
    exit 0
  fi

  # task_state.json 不存在，说明是首次初始化
  # 必须校验 requirement_analysis.md 包含单元边界表
  if [ ! -f "$REQUIREMENT_DOC" ]; then
    echo "" >&2
    echo "⛔ [需求分析检查] 禁止初始化 task_state.json：需求分析文档不存在。" >&2
    echo "" >&2
    echo "  期望路径：upgrade_plan/v${VERSION}/requirement_analysis.md" >&2
    echo "" >&2
    echo "  请先运行 /analyst-agent 完成需求分析，再启动 /orchestrator。" >&2
    echo "" >&2
    exit 2
  fi

  if ! grep -q "UNIT_BOUNDARY_TABLE_START" "$REQUIREMENT_DOC"; then
    echo "" >&2
    echo "⛔ [需求分析检查] 禁止初始化 task_state.json：需求分析文档缺少单元边界表。" >&2
    echo "" >&2
    echo "  文档路径：upgrade_plan/v${VERSION}/requirement_analysis.md" >&2
    echo "  缺少标记：<!-- UNIT_BOUNDARY_TABLE_START -->" >&2
    echo "" >&2
    echo "  请先运行 /analyst-agent 完成单元边界分析，用户确认后再启动 /orchestrator。" >&2
    echo "" >&2
    exit 2
  fi

  echo "✅ [需求分析] v${VERSION} — 单元边界表校验通过，允许初始化 task_state.json。" >&2
  exit 0
fi

# ==== Phase 白名单：禁止在测试/review 阶段修改代码文件 ====
if [ -f "$TASK_STATE" ]; then
  PHASE=$(python3 -c "
import sys, json
try:
    data = json.load(open('$TASK_STATE'))
    print(data.get('phase', ''))
except:
    print('')
" 2>/dev/null)

  if [[ "$PHASE" == "unit_testing" || "$PHASE" == "integration_testing" || "$PHASE" == "interface_testing" || "$PHASE" == "review" ]]; then
    echo "" >&2
    echo "⛔ 当前 phase=${PHASE}，禁止修改代码文件。" >&2
    echo "  该阶段只允许更新 TASK_LIST.md 或 task_state.json。" >&2
    echo "  目标文件：${FILE_PATH}" >&2
    echo "" >&2
    exit 2
  fi
fi

# ==== 检查1：TASK_LIST.md 是否存在 ====
if [ ! -f "$TASK_LIST" ]; then
  echo "" >&2
  echo "⛔ 操作被强制拒绝：未找到当前版本的 TASK_LIST.md" >&2
  echo "" >&2
  echo "  当前版本：v${VERSION}" >&2
  echo "  期望路径：upgrade_plan/v${VERSION}/TASK_LIST.md" >&2
  echo "" >&2
  echo "  必须先完成以下步骤才能进行任何代码修改：" >&2
  echo "  1. 在 upgrade_plan/v${VERSION}/TASK_LIST.md 中创建任务列表" >&2
  echo "  2. 将本次改动拆解为若干 TASK，状态初始为 pending" >&2
  echo "  3. 开始改动前将对应 TASK 状态更新为 in_progress" >&2
  echo "" >&2
  exit 2
fi

# ==== 检查2：是否有 in_progress 状态的任务 ====
IN_PROCESS_COUNT=$(grep -c "| in_progress |" "$TASK_LIST" 2>/dev/null || echo "0")

if [ "$IN_PROCESS_COUNT" -eq 0 ]; then
  echo "" >&2
  echo "⛔ 操作被强制拒绝：当前没有 in_progress 状态的任务" >&2
  echo "" >&2
  echo "  当前版本：v${VERSION}" >&2
  echo "  TASK_LIST：upgrade_plan/v${VERSION}/TASK_LIST.md" >&2
  echo "" >&2

  PENDING_TASKS=$(grep "| pending |" "$TASK_LIST" 2>/dev/null)
  if [ -n "$PENDING_TASKS" ]; then
    echo "  待处理任务（pending）：" >&2
    while IFS= read -r line; do
      echo "    $line" >&2
    done <<< "$PENDING_TASKS"
    echo "" >&2
    echo "  请先将要执行的任务状态更新为 in_progress，再进行代码修改。" >&2
  else
    COMPLETED_COUNT=$(grep -c "| completed |" "$TASK_LIST" 2>/dev/null || echo "0")
    echo "  所有任务均已完成（completed: ${COMPLETED_COUNT}）。" >&2
    echo "  若需继续修改，请在 TASK_LIST.md 中添加新任务并设为 in_progress。" >&2
  fi
  echo "" >&2
  exit 2
fi

# ==== 通过检查：显示当前进行中任务 ====
echo "✅ [TASK_LIST] v${VERSION} — 当前进行中任务：" >&2
grep "| in_progress |" "$TASK_LIST" | while IFS= read -r line; do
  echo "   $line" >&2
done

exit 0
