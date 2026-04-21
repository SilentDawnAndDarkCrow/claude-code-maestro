#!/bin/bash
# Hook: TaskCompleted 时自动将 TASK_LIST.md 对应任务更新为 completed
# 触发时机：TaskCompleted
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

# 找出所有 in_progress 行的索引
in_progress_indices = []
for i, line in enumerate(lines):
    if '| in_progress |' in line and re.match(r'^\| T', line.strip()):
        in_progress_indices.append(i)

if not in_progress_indices:
    print(f'[TaskCompleted] v{version} — 没有 in_progress 任务，无需更新', file=sys.stderr)
    sys.exit(0)

# 确定要更新的行
target_index = None

if task_subject:
    # 优先：task_subject 与任务描述做子串匹配
    for i in in_progress_indices:
        line = lines[i]
        cols = [c.strip() for c in line.split('|')]
        # 表格列: ['', 'Tx', '描述', '状态', '备注', '']
        desc = cols[2] if len(cols) > 2 else ''
        if task_subject in desc or desc in task_subject:
            target_index = i
            break

# 没有匹配到但只有一个 in_progress 任务，直接更新
if target_index is None and len(in_progress_indices) == 1:
    target_index = in_progress_indices[0]

if target_index is None:
    print(f'[TaskCompleted] v{version} — 有多个 in_progress 任务，无法自动匹配，请手动更新 TASK_LIST.md', file=sys.stderr)
    for i in in_progress_indices:
        print(f'   {lines[i].rstrip()}', file=sys.stderr)
    sys.exit(0)

# 执行更新：in_progress → completed
old_line = lines[target_index]
new_line = old_line.replace('| in_progress |', '| completed |', 1)
lines[target_index] = new_line

with open(task_list_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

# 统计进度
total = sum(1 for l in lines if re.match(r'^\| T', l.strip()))
completed = sum(1 for l in lines if '| completed |' in l and re.match(r'^\| T', l.strip()))
remaining_in_progress = sum(1 for l in lines if '| in_progress |' in l and re.match(r'^\| T', l.strip()))
pending = sum(1 for l in lines if '| pending |' in l and re.match(r'^\| T', l.strip()))

cols = [c.strip() for c in new_line.split('|')]
task_id = cols[1] if len(cols) > 1 else '?'
task_desc = cols[2] if len(cols) > 2 else '?'

print(f'', file=sys.stderr)
print(f'✅ [TaskCompleted] v{version} — {task_id} 已标记为 completed', file=sys.stderr)
print(f'   {task_desc}', file=sys.stderr)
print(f'', file=sys.stderr)
print(f'   进度：{completed}/{total} 完成', end='', file=sys.stderr)
if remaining_in_progress > 0:
    print(f'，{remaining_in_progress} 进行中', end='', file=sys.stderr)
if pending > 0:
    print(f'，{pending} 待处理', end='', file=sys.stderr)
print(f'', file=sys.stderr)

if completed == total and total > 0:
    print(f'', file=sys.stderr)
    print(f'   🎉 所有任务已完成！可以更新 VERSION 并将状态标记为 ✅ 已完成。', file=sys.stderr)

print(f'', file=sys.stderr)
PYEOF

exit 0
