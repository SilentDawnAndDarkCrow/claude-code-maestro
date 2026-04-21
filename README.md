# 🎼 claude-code-maestro

**Multi-Agent 开发方法论，让 Claude Code 自动完成需求分析 → 并行开发 → 测试 → 规范检查的完整流程。**

---

## 这是什么

claude-code-maestro 是一套基于 [Claude Code](https://claude.ai/code) 的 **Skill 集合**，提供三个核心指令：

| Skill | 作用 |
|-------|------|
| `/harness-init` | 初始化新项目，生成完整的 Multi-Agent 开发环境（规范文件、Hook、质量门控） |
| `/analyst-agent` | 分析需求，将功能拆解为独立的、可测试的业务单元 |
| `/orchestrator` | 按依赖图并行调度 dev-agent、test-agent、review-agent，自动驱动完整开发流程 |

---

## 工作流程

```
/harness-init          一次性初始化（新项目必做）
      ↓
/analyst-agent         描述需求 → 生成单元边界草案 → 用户确认
      ↓
/orchestrator          自动并行开发 → 单元测试 → 集成测试 → 规范检查
```

### /orchestrator 内部调度

```
orchestrator（主调度器）
  ├── test-agent 模式A    生成测试用例（并行，所有单元）
  ├── dev-agent           按依赖图并行开发各单元
  ├── test-agent 模式B    单元测试（dev 完成后立即触发）
  ├── interface-test-agent  接口测试（有 HTTP 层时触发）
  └── review-agent        规范检查（所有单元通过后）
```

---

## 快速开始

### 1. 安装

```bash
git clone https://github.com/your-username/claude-code-maestro.git
cd claude-code-maestro
./install.sh
```

重启 Claude Code 后，skill 即可使用。

### 2. 初始化新项目

在你的项目目录里打开 Claude Code，运行：

```
/harness-init
```

按提示确认技术栈、目录结构、质量工具，脚本自动生成：
- `CLAUDE.md`（项目规范主文件）
- `.claude/rules/specifications/`（编码/测试/安全规范）
- `.claude/hooks/`（任务门控 + 质量检查 Hook）
- `.claude/skills/dev-agent/`、`review-agent/`（项目内子 agent）

### 3. 分析需求

```
/analyst-agent
```

输入你的需求描述，analyst-agent 会将其拆解为独立业务单元，与你确认后写入：

```
upgrade_plan/v{VERSION}/requirement_analysis.md
```

### 4. 启动并行开发

```
/orchestrator
```

orchestrator 读取需求分析文档，自动完成完整开发流程，支持断点恢复。

---

## 目录结构

```
skills/
├── harness-init/              # 项目初始化 skill
│   ├── SKILL.md
│   └── references/            # 技术栈规则库、Hook 模板、Agent 模板
│       ├── tech-stack-rules.md
│       ├── tech-stack-rules.yaml
│       ├── dev-agent-template.md
│       ├── review-agent-template.md
│       ├── review_checks_template.py
│       ├── gitignore-template
│       └── hooks/             # 5 个通用 Hook 脚本
├── analyst-agent/             # 需求分析 skill
├── orchestrator/              # 主调度器 skill
├── dev-agent/                 # 开发子 agent
├── test-agent/                # 测试子 agent
├── review-agent/              # 规范检查子 agent
└── interface-test-agent/      # HTTP 接口测试子 agent
```

---

## 核心设计原则

**信息隔离**：每个子 agent 只收到自己职能范围内的信息
- dev-agent 不看测试结果
- test-agent 不看源码实现
- review-agent 不看测试结果

**测试用例先行**：开发前锁定测试用例，防止实现反向适配测试

**断点恢复**：所有状态持久化到 `task_state.json`，中断后可续跑

**质量门控**：Hook 在 Write/Edit 前校验任务状态，防止无序修改

---

## 系统要求

- [Claude Code](https://claude.ai/code) 已安装
- Claude Code 版本支持 `Skill` 工具和 `Agent` 工具

---

## License

MIT
