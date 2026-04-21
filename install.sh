#!/usr/bin/env bash
# claude-code-maestro 安装脚本
# 将 skills/ 目录下的所有 skill 复制到 ~/.claude/skills/

set -e

SKILLS_DIR="$(cd "$(dirname "$0")/skills" && pwd)"
TARGET_DIR="$HOME/.claude/skills"

echo "🎼 claude-code-maestro 安装开始"
echo "来源：$SKILLS_DIR"
echo "目标：$TARGET_DIR"
echo ""

# 检查 Claude Code 是否已安装（.claude 目录存在）
if [ ! -d "$HOME/.claude" ]; then
  echo "❌ 未检测到 ~/.claude 目录，请先安装 Claude Code。"
  echo "   https://claude.ai/code"
  exit 1
fi

mkdir -p "$TARGET_DIR"

# 逐个复制 skill，遇到同名目录时询问是否覆盖
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_dir")"
  target_skill="$TARGET_DIR/$skill_name"

  if [ -d "$target_skill" ]; then
    read -r -p "⚠️  $skill_name 已存在，覆盖？(y/N) " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "   跳过 $skill_name"
      continue
    fi
  fi

  cp -r "$skill_dir" "$target_skill"
  echo "   ✅ $skill_name"
done

echo ""
echo "🎼 安装完成！重启 Claude Code 后即可使用以下 skill："
echo ""
echo "   /harness-init    — 初始化新项目的 Multi-Agent 开发环境"
echo "   /analyst-agent   — 需求分析，划分可测试的业务单元"
echo "   /orchestrator    — 多 Agent 并行调度：开发 → 测试 → 规范检查"
