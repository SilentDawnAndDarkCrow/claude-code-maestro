#!/bin/bash
# Hook: TaskStarted 时自动将 TASK_LIST.md 对应任务从 pending 更新为 in_progress
# 触发时机：TaskStarted（TaskUpdate status=in_progress 时）
# 匹配逻辑：task_subject 与 TASK_LIST.md 任务描述做子串匹配
# 退出码：0 = 正常（不阻断）

INPUT=$(cat)
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VERSION_FILE="$PROJECT_ROOT/VERSION"

# ==== 从根目录 VERSION 文件获取当前版本 ====
if [ ! -f "$VERSION_FILE" ]; then
  exit 0
fi

CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
if [ -z "$CURRENT_VERSION" ]; then
  exit 0
fi

TASK_LIST="$PROJECT_ROOT/upgrade_plan/v${CURRENT_VERSION}/TASK_LIST.md"
if [ ! -f "$TASK_LIST" ]; then
  exit 0
fi

# ==== 使用 Python 完成匹配与更新 ====
HOOK_INPUT="$INPUT" HOOK_TASK_LIST="$TASK_LIST" HOOK_VERSION="$CURRENT_VERSION" python3 - <<'PYEOF'
import sys
import json
import re
import os

input_data = os.environ.get('HOOK_INPUT', '')
task_list_path = os.environ.get('HOOK_TASK_LIST', '')
version = os.environ.get('HOOK_VERSION', '')

# 解析 task_subject
try:
    data = json.loads(input_data)
    task_subject = data.get('task_subject', '').strip()
except Exception:
    task_subject = ''

# 读取 TASK_LIST.md
with open(task_list_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 找出所有 pending 行的索引
pending_indices = []
for i, line in enumerate(lines):
    if '| pending |' in line and re.match(r'^\| T', line.strip()):
        pending_indices.append(i)

if not pending_indices:
    print(f'[TaskStarted] v{version} — 没有 pending 任务，无需更新', file=sys.stderr)
    sys.exit(0)

# 确定要更新的行
target_index = None

if task_subject:
    # 优先：task_subject 与任务描述做子串匹配
    for i in pending_indices:
        line = lines[i]
        cols = [c.strip() for c in line.split('|')]
        # 表格列: ['', 'Tx', '描述', '状态', '备注', '']
        desc = cols[2] if len(cols) > 2 else ''
        if task_subject in desc or desc in task_subject:
            target_index = i
            break

# 没有匹配到但只有一个 pending 任务，直接更新
if target_index is None and len(pending_indices) == 1:
    target_index = pending_indices[0]

if target_index is None:
    print(f'[TaskStarted] v{version} — 有多个 pending 任务，无法自动匹配，请手动将对应任务改为 in_progress', file=sys.stderr)
    for i in pending_indices:
        print(f'   {lines[i].rstrip()}', file=sys.stderr)
    sys.exit(0)

# 执行更新：pending → in_progress
old_line = lines[target_index]
new_line = old_line.replace('| pending |', '| in_progress |', 1)
lines[target_index] = new_line

with open(task_list_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

# 统计进度
total = sum(1 for l in lines if re.match(r'^\| T', l.strip()))
completed = sum(1 for l in lines if '| completed |' in l and re.match(r'^\| T', l.strip()))
in_progress = sum(1 for l in lines if '| in_progress |' in l and re.match(r'^\| T', l.strip()))
pending = sum(1 for l in lines if '| pending |' in l and re.match(r'^\| T', l.strip()))

cols = [c.strip() for c in new_line.split('|')]
task_id = cols[1] if len(cols) > 1 else '?'
task_desc = cols[2] if len(cols) > 2 else '?'

print(f'', file=sys.stderr)
print(f'🔄 [TaskStarted] v{version} — {task_id} 已标记为 in_progress', file=sys.stderr)
print(f'   {task_desc}', file=sys.stderr)
print(f'', file=sys.stderr)
print(f'   进度：{completed}/{total} 完成', end='', file=sys.stderr)
if in_progress > 0:
    print(f'，{in_progress} 进行中', end='', file=sys.stderr)
if pending > 0:
    print(f'，{pending} 待处理', end='', file=sys.stderr)
print(f'', file=sys.stderr)
print(f'', file=sys.stderr)
PYEOF

exit 0
