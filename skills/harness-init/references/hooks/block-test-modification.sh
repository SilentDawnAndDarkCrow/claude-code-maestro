#!/usr/bin/env bash
# impl-worker 专用 hook：阻止对测试目录的任何写入
# 触发事件：PreToolUse (Write|Edit|MultiEdit)
# 原理：impl-worker 只能写业务代码，测试用例在锁定后不可修改

set -euo pipefail

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")"

if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "MultiEdit" ]]; then
  exit 0
fi

FILE_PATH="$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
params = d.get('tool_input', {})
print(params.get('file_path', params.get('path', '')))
" 2>/dev/null || echo "")"

TEST_DIR="{{TEST_DIR}}"

if [[ -n "$FILE_PATH" && "$FILE_PATH" == *"$TEST_DIR"* ]]; then
  echo "❌ [impl-worker] 禁止修改测试目录：$FILE_PATH" >&2
  echo "   测试用例在开发开始前已锁定，impl-worker 不可修改。" >&2
  exit 2
fi

exit 0
