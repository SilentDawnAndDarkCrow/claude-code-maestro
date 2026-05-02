#!/usr/bin/env bash
# claude-code-maestro 安装脚本
# 将 skills/ 目录下的所有 skill 复制到 ~/.claude/skills/

set -e

SKILLS_DIR="$(cd "$(dirname "$0")/skills" && pwd)"
TARGET_DIR="$HOME/.claude/skills"
CLAUDE_DIR="$HOME/.claude"

echo "claude-code-maestro 安装开始"
echo ""

# 检查 Claude Code 是否已安装
if [ ! -d "$CLAUDE_DIR" ]; then
  echo "[ERROR] 未检测到 ~/.claude 目录，请先安装 Claude Code。"
  echo "   https://claude.ai/code"
  exit 1
fi

# 检查 skills/ 目录是否存在
if [ ! -d "$SKILLS_DIR" ]; then
  echo "[ERROR] 未找到 skills/ 目录，请在项目根目录下执行此脚本。"
  exit 1
fi

mkdir -p "$TARGET_DIR"

# 逐个安装，已存在则询问是否覆盖
updated=()
skipped=()
installed=()

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_dir")"
  target_skill="$TARGET_DIR/$skill_name"

  if [ -d "$target_skill" ]; then
    read -r -p "   [已存在] $skill_name — 覆盖？(y/N) " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
      rm -rf "$target_skill"
      cp -r "$skill_dir" "$target_skill"
      updated+=("$skill_name")
    else
      skipped+=("$skill_name")
    fi
  else
    cp -r "$skill_dir" "$target_skill"
    installed+=("$skill_name")
  fi
done

echo ""

if [ ${#installed[@]} -gt 0 ]; then
  echo "新安装："
  for name in "${installed[@]}"; do
    echo "   [OK] $name"
  done
fi

if [ ${#updated[@]} -gt 0 ]; then
  echo "已覆盖更新："
  for name in "${updated[@]}"; do
    echo "   [OK] $name"
  done
fi

if [ ${#skipped[@]} -gt 0 ]; then
  echo "已跳过："
  for name in "${skipped[@]}"; do
    echo "   [--] $name"
  done
fi

echo ""
echo "安装完成！重启 Claude Code 后即可使用以下 skill："
echo ""
echo "   /harness-init    — 初始化项目，生成规范文件、hook 和 agent 定义"
echo "   /analyst-agent   — 需求分析，划分可测试的业务单元"
echo "   /orchestrator    — 真正并行调度：开发 -> 测试 -> 规范检查（使用项目级 agents）"
