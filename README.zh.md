![maestro banner](assets/banner.png)

# 🎼 claude-code-maestro

**中文** | [English](README.md)

> 基于 Claude Code 的多 Agent 编排框架——用系统级 Hook 强制执行你的开发约定，而不是靠提示词。

**你是不是遇到过这些情况？**

- 测试全过了，上线还是出了 bug——因为测试是 Claude 对着自己写的代码反推的，根本不算数
- 项目开始时定好了编码规范，做着做着 Claude 就不遵守了，你得不停提醒
- 需求一复杂，Claude 就开始"创意发挥"，改了不该改的地方，你却不知道它动了哪里
- 多个模块只能排队跑，等前一个跑完才能开下一个，明明可以同时做的事情白白浪费时间
- session 中断之后，不知道做到哪了，只能从头看或者重来

这些问题的根源都一样：现有方案的本质是把规则写进提示词，靠 Claude 自觉遵守。上下文一长，规则就淡化了。

**maestro 的思路不一样：规则不靠模型记，靠系统强制执行。**

具体做了三件事：

**① 流程可量化**
需求经 `analyst-agent` 拆解成独立单元，与你确认后锁定，不是 Claude 自由发挥。

**② 无依赖单元全部并行**
`orchestrator` 按依赖图调度，没有依赖的单元同时执行。10 个模块不是排队跑 10 次，是同时跑。需求越大，优势越明显。

![并行 vs 串行对比](assets/parallel-comparison.png)

**③ 约定被强制执行，测试结果真正可信**
`/harness-init` 时你和 AI 谈好的每一条协议——测试要求、编码规范、安全检查——都被写进 Hook 脚本，任何写操作发生前系统先拦截校验，Claude 无法绕过。测试用例在实现代码存在之前就生成并锁定，结构上不可能"对着实现反推"。

→ [5 分钟上手](#快速上手)

---

## 先看效果

**没有 maestro**：把复杂需求甩给 Claude，改着改着把之前能跑的逻辑带崩了，或者测试是 Claude 自己写自己过的，出了问题根本不知道哪个环节的责任。

**有了 maestro**：

```
/analyst-agent   # 描述需求，拆解成独立单元，与你确认
/orchestrator    # 并行开发 + 测试 + 规范检查，全自动
```

然后你去喝咖啡。

---

## 内部是怎么跑的

```
你的需求描述
      ↓
/analyst-agent  →  单元边界文档（你确认后锁定）
      ↓
/orchestrator
  ├── test-agent（并行）        基于需求文档生成测试用例，此时实现不存在
  ├── dev-agent（按依赖图并行）  实现各单元，只能让测试通过，不能修改测试
  ├── test-agent（并行）        单元完成后立即验证
  ├── interface-test-agent      有 HTTP 接口时自动触发
  └── review-agent              全部通过后执行 /harness-init 约定的规范检查
```

每个 agent 只收到 `orchestrator` 显式传入的信息，没给就看不到，不靠自觉。

---

## 快速上手

### 第一步：安装

```bash
git clone https://github.com/SilentDawnAndDarkCrow/claude-code-maestro.git
cd claude-code-maestro
./install.sh
```

重启 Claude Code，三个 skill 即刻可用。

### 第二步：初始化项目

在你的项目目录打开 Claude Code（新项目和已有项目均可）：

```
/harness-init
```

回答几个问题（技术栈、目录结构、质量工具），自动生成：

- `CLAUDE.md`——项目规范主文件
- `.claude/rules/`——编码 / 测试 / 安全规范
- `.claude/hooks/`——任务门控 + 质量检查 Hook（所有约定的执行者）
- `.claude/skills/dev-agent/`、`.claude/skills/review-agent/`——项目内 sub-agent

### 第三步：描述需求

```
/analyst-agent
```

用自然语言描述要做什么，`analyst-agent` 拆解成独立业务单元，你确认后存入 `upgrade_plan/v{VERSION}/requirement_analysis.md`（版本号按运行次数自动递增）。

### 第四步：一键开发

```
/orchestrator
```

并行编码、测试、接口验证、规范检查——全自动。中断后再运行可断点续跑。

---

## 系统要求

- [Claude Code](https://claude.ai/code) 已安装，且支持 `Skill` 和 `Agent` 工具（需要 Max 或 Pro 订阅）

---

## License

[CC BY-NC 4.0](LICENSE) — 允许使用和修改，禁止商业用途。
