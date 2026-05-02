#!/usr/bin/env bash
# lint-checker 专用 hook：阻止读取测试结果文件
# 触发事件：PreToolUse (Read)
# 原理：lint-checker 的检查结论必须独立于测试结果，防止"看到测试通过就放水"

set -euo pipefail

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")"

if [[ "$TOOL_NAME" != "Read" ]]; then
  exit 0
fi

FILE_PATH="$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
params = d.get('tool_input', {})
print(params.get('file_path', params.get('path', '')))
" 2>/dev/null || echo "")"

# 阻止读取 task_state.json 中的测试结果（lint-checker 不需要知道测试是否通过）
BLOCKED_PATTERNS=(
  "task_state.json"
  ".claude/maestro/status"
  "test_result"
  "pytest_cache"
  ".pytest_cache"
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "❌ [lint-checker] 禁止读取测试相关文件：$FILE_PATH" >&2
    echo "   lint-checker 的规范检查必须独立于测试结果。" >&2
    exit 2
  fi
done

exit 0
