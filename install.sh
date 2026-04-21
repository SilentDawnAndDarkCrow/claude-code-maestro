#!/usr/bin/env bash
# claude-code-maestro 安装脚本
# 将 skills/ 目录下的所有 skill 复制到 ~/.claude/skills/

set -e

SKILLS_DIR="$(cd "$(dirname "$0")/skills" && pwd)"
TARGET_DIR="$HOME/.claude/skills"
CLAUDE_DIR="$HOME/.claude"
BACKUP_CMD="cp -r \"$CLAUDE_DIR\" \"${CLAUDE_DIR}_backup_$(date +%Y%m%d_%H%M%S)\""

echo "🎼 claude-code-maestro 安装开始"
echo ""

# 检查 Claude Code 是否已安装
if [ ! -d "$CLAUDE_DIR" ]; then
  echo "❌ 未检测到 ~/.claude 目录，请先安装 Claude Code。"
  echo "   https://claude.ai/code"
  exit 1
fi

# 检查 skills/ 目录是否存在
if [ ! -d "$SKILLS_DIR" ]; then
  echo "❌ 未找到 skills/ 目录，请在项目根目录下执行此脚本。"
  exit 1
fi

# 检测哪些 skill 已存在
existing_skills=()
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_dir")"
  if [ -d "$TARGET_DIR/$skill_name" ]; then
    existing_skills+=("$skill_name")
  fi
done

# 如果有已存在的 skill，统一提醒备份
if [ ${#existing_skills[@]} -gt 0 ]; then
  echo "⚠️  检测到以下 skill 在 ~/.claude/skills/ 中已存在："
  echo ""
  for name in "${existing_skills[@]}"; do
    echo "   • $name"
  done
  echo ""
  echo "安装将覆盖上述目录。建议先备份你的 ~/.claude/ 目录："
  echo ""
  echo "   $BACKUP_CMD"
  echo ""
  read -r -p "已备份或确认不需要备份，继续安装？(y/N) " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "已取消安装。"
    exit 0
  fi
  echo ""
fi

mkdir -p "$TARGET_DIR"

# 复制所有 skill
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_dir")"
  target_skill="$TARGET_DIR/$skill_name"
  rm -rf "$target_skill"
  cp -r "$skill_dir" "$target_skill"
  echo "   ✅ $skill_name"
done

echo ""
echo "🎼 安装完成！重启 Claude Code 后即可使用以下 skill："
echo ""
echo "   /harness-init    — 初始化新项目的 Multi-Agent 开发环境"
echo "   /analyst-agent   — 需求分析，划分可测试的业务单元"
echo "   /orchestrator    — 多 Agent 并行调度：开发 → 测试 → 规范检查"
