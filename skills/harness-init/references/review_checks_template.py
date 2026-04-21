#!/usr/bin/env python3
"""
review_checks.py — 确定性脚本检查层骨架
由 harness-init 生成，供 review-agent 调用。

调用约定：
    python3 .claude/hooks/review_checks.py <src_dir>

    - src_dir：要扫描的源码根目录（如 src/、internal/）
    - 输出：JSON violations 数组到 stdout
    - 退出码：0 = 正常完成（无论是否有违规），非 0 = 脚本自身出错

输出格式：
    [
      {
        "rule_id": "PY_001",
        "file": "src/core/tutor.py",
        "line": 42,
        "description": "发现 print() 调用",
        "fix": "改为 logger.info(...)"
      }
    ]
    若无违规，输出空数组 []
"""

import sys
import json
import re
from pathlib import Path


def grep_check(
    src_dir: Path,
    pattern: str,
    file_glob: str,
    rule_id: str,
    description: str,
    fix: str,
    exclude_glob: str = "",
) -> list[dict]:
    """
    在 src_dir 下递归扫描匹配 file_glob 的文件，
    检测每行是否匹配 pattern，返回违规列表。

    exclude_glob: 逗号分隔的文件名模式，匹配的文件跳过扫描（如 ".env.example,.env.*.example"）
    """
    violations = []
    regex = re.compile(pattern)
    exclude_patterns = [p.strip() for p in exclude_glob.split(",") if p.strip()]

    for glob_part in file_glob.split(","):
        for filepath in src_dir.rglob(glob_part.strip()):
            # 跳过排除列表中的文件
            if any(filepath.match(ep) for ep in exclude_patterns):
                continue
            try:
                lines = filepath.read_text(encoding="utf-8", errors="ignore").splitlines()
            except OSError:
                continue
            for lineno, line in enumerate(lines, start=1):
                if regex.search(line):
                    violations.append({
                        "rule_id": rule_id,
                        "file": str(filepath),
                        "line": lineno,
                        "description": description,
                        "fix": fix,
                    })

    return violations


def main(src_dir: str) -> None:
    root = Path(src_dir)
    if not root.exists():
        print(json.dumps([]))
        return

    all_violations: list[dict] = []

    # ===== 以下检查规则由 harness-init 根据技术栈自动生成 =====
    # 每条规则调用 grep_check()，将结果追加到 all_violations
    # 示例（实际内容由技术栈驱动）：
    #
    # all_violations += grep_check(
    #     root,
    #     pattern=r"^\s*print\(",
    #     file_glob="*.py",
    #     rule_id="PY_001",
    #     description="发现 print() 调用（应使用日志库）",
    #     fix="改为 logger.info(...) 或 logger.debug(...)",
    # )
    # ===== 规则结束 =====

    print(json.dumps(all_violations, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"用法: {sys.argv[0]} <src_dir>", file=sys.stderr)
        sys.exit(1)
    main(sys.argv[1])
