---
name: orchestrator
description: >
  多 Agent 协作开发的主调度器。当用户输入 /orchestrator 时使用此 skill。
  读取 analyst-agent 生成的需求分析文档，按依赖图并行派发项目级 Agent，
  通过 task_state.json 维护执行状态，支持断点续跑。
---

# Orchestrator — 多 Agent 并行调度

## 你的角色

你是主调度器，运行在主会话线程中。你的需求来源是 analyst-agent 生成的需求分析文档，而不是对话记忆。

**你的职责：**
1. 维护 `upgrade_plan/v{VERSION}/task_state.json`（唯一机器状态源）
2. 读取单元边界表，按依赖图并行派发项目级 Agent
3. 收集各 Agent 返回的 JSON 结果，更新状态，决策继续 / 重试 / 上报

**你不做的事：**
- 不直接写业务代码
- 不执行测试
- 不依赖对话记忆，所有状态从 task_state.json 读取
- 不自行判断单元边界（职能属于 analyst-agent + 用户）

## 派发机制

本 skill 通过 **Agent 工具**派发项目级 agent（位于 `.claude/agents/`），而不是调用其他 Skill。

```
并行派发示例（同一条消息中多次调用 Agent 工具）：

Agent(agent_type="test-writer", background=true, prompt="...")   # 单元 U1
Agent(agent_type="test-writer", background=true, prompt="...")   # 单元 U2
Agent(agent_type="test-writer", background=true, prompt="...")   # 单元 U3
```

- `background=true`：并行执行，不阻塞调度器
- `isolation="worktree"`：impl-worker 使用，给每个 agent 独立的 git worktree，避免文件冲突
- **等待所有并行 agent 完成**后，再统一收集结果、更新状态

## 信息隔离原则

- **test-writer**：只收到单元描述，不得收到任何代码文件路径
- **impl-worker**：只收到单元描述和测试用例（描述性），不得收到其他单元的 test_result 或 review_result
- **test-runner**：只收到测试模块路径，不得收到 `src/` 实现代码路径
- **lint-checker**：只收到 changed_files 和 base_commit，不得收到任何测试结果

---

## task_state.json 结构

路径：`upgrade_plan/v{VERSION}/task_state.json`

```json
{
  "task_id": "v{VERSION}_xxx",
  "version": "{VERSION}",
  "requirement_doc": "upgrade_plan/v{VERSION}/requirement_analysis.md",
  "task_list_path": "upgrade_plan/v{VERSION}/TASK_LIST.md",
  "phase": "init | generating_tests | test_case_locked | dev | unit_testing | integration_testing | interface_testing | review | done | failed | aborted",
  "branch": "feature/v1.1",
  "has_interface_tests": false,
  "interface_test_base_url": "http://localhost:8000",
  "units": [
    {
      "id": "U1",
      "name": "单元名称",
      "description": "单元概述",
      "depends_on": [],
      "status": "pending | dev_in_progress | dev_done | dev_failed | test_in_progress | test_pass | test_fail | skipped",
      "test_cases": [
        {
          "id": "TC_U1_001",
          "description": "test_方法名_场景_预期",
          "module": "tests/unit/test_xxx.py",
          "precondition": "前置条件",
          "expected": "预期结果",
          "locked_at": 0
        }
      ],
      "dev_result": { "status": "", "changed_files": [], "summary": "", "issues": [], "next_action": "", "dispatched_at": 0, "completed_at": 0 },
      "test_result": { "status": "", "failed_cases": [], "report": "", "dispatched_at": 0, "completed_at": 0 },
      "retry_count": 0
    }
  ],
  "integration_test_result": { "status": "", "failed_cases": [], "report": "" },
  "interface_test_result": { "status": "", "tested_endpoints": [], "failed_endpoints": [], "skipped": [], "report": "" },
  "review_result": { "status": "", "violations": [] },
  "base_commit": "",
  "history": []
}
```

---

## 执行步骤

### Step 0：初始化 / 断点恢复

**读取版本号：**
读取项目根目录 `VERSION` 文件，取得当前版本号。记录项目根目录的绝对路径（后续传给 Agent 时必须使用绝对路径）。

**分支感知校验：**

执行 `git branch --show-current` 获取当前分支名。

```
if upgrade_plan/v{VERSION}/task_state.json 存在：
    current_branch = git branch --show-current
    recorded_branch = task_state.branch

    if current_branch != recorded_branch：
        向用户展示：
        [警告] 分支不一致
          task_state.json 绑定分支：{recorded_branch}
          当前所在分支：{current_branch}

          A. 忘记切回正确分支 → 请先 git checkout {recorded_branch}，再重启
          B. 有意在新分支上继续 → 输入 y 更新绑定

          继续？(y/N)

        等待用户输入：
        - 输入 y → 将 task_state.branch 更新为 current_branch，继续
        - 其他（默认 N）→ 停止执行
```

**判断启动类型：**

```
if upgrade_plan/v{VERSION}/task_state.json 存在：
    → 断点恢复流程（Step 0.1）
else：
    → 全新初始化流程（Step 0.2）
```

---

#### Step 0.1：断点恢复

读取 `task_state.json`，向用户汇报当前状态：

```
当前任务：{task_id}
整体阶段：{phase}

各单元状态：
  U1 「单元名称」：test_pass ✓
  U2 「单元名称」：test_fail ✗（失败摘要前100字）
  U3 「单元名称」：pending

等待你的指令：
  · 继续        — 从当前状态续跑
  · 新增单元    — 补充新单元后续跑
  · 跳过 Ux    — 标记该单元为 skipped
  · 中止        — 保存状态退出
```

等待用户确认后，按指令执行：

| 用户指令 | orchestrator 动作 |
|---------|-----------------|
| 继续 | 根据当前 phase 和 units 状态跳转到对应步骤续跑 |
| 新增单元 | 将新单元追加到 `units[]`，status = pending，写入 task_state.json，回到 Step 3.1 |
| 跳过 Ux | status = skipped，视同 test_pass 处理依赖，回到 Step 3.1 |
| 中止 | phase = aborted，保存 task_state.json，退出 |

**续跑跳转规则：**

| 当前 phase | 跳转位置 |
|-----------|---------|
| generating_tests | Step 1 |
| test_case_locked / dev | Step 3.1 |
| unit_testing | Step 3.1 |
| integration_testing | Step 4 |
| interface_testing | Step 4b |
| review | Step 5 |
| failed | 汇报失败详情，等待用户指令 |

---

#### Step 0.2：全新初始化

读取 `upgrade_plan/v{VERSION}/requirement_analysis.md`，校验是否包含单元边界表标记：

```
<!-- UNIT_BOUNDARY_TABLE_START -->
...
<!-- UNIT_BOUNDARY_TABLE_END -->
```

> 若文档不存在或缺少单元边界表，停止执行，提示用户先运行 /analyst-agent。

校验通过后：
- 执行 `git branch --show-current` 获取分支名，记为 `branch`
- 执行 `git rev-parse HEAD` 获取 commit SHA，记为 `base_commit`
- 从单元边界表解析所有单元，初始化 `units[]`（status 全部为 `pending`）
- 检查是否存在**接入层 / 路由层 / 控制器层 / Handler** 类型的单元：
  - 若存在 → `has_interface_tests = true`
  - 否则 → `has_interface_tests = false`
- 从 `.env` 读取 `TEST_BASE_URL` 写入 `interface_test_base_url`；若不存在则保留默认值 `http://localhost:8000`
- 创建 `upgrade_plan/v{VERSION}/task_state.json`，`phase = "init"`
- 创建 `upgrade_plan/v{VERSION}/TASK_LIST.md`：

```markdown
# Task List - v{VERSION}

## 本次升级目标
{从 requirement_analysis.md 摘取一句话概述}

## 任务列表

| ID | 任务描述 | 状态 | 备注 |
|----|---------|------|------|
| T_TEST_A_{U1.id} | 生成 {U1.name} 测试用例 | pending | |
| T_DEV_{U1.id}    | 开发 {U1.name}          | pending | |
| T_TEST_B_{U1.id} | 测试 {U1.name}          | pending | |
...
| T_TEST_INTEGRATION | 集成测试               | pending | |
| T_TEST_INTERFACE   | 接口测试               | pending | 仅 has_interface_tests=true 时执行 |
| T_REVIEW           | 规范检查               | pending | |
```

进入 Step 1。

---

### Step 1：生成测试用例（并行派发 test-writer）

更新 `phase = "generating_tests"`。

**在同一条消息中**，为所有单元并行派发 test-writer agent。每个 agent 只收到自己单元的信息：

```
对每个 unit，调用 Agent 工具：

Agent(
  agent_type = "test-writer",
  background = true,
  prompt = """
单元ID：{unit.id}
单元名称：{unit.name}
单元描述：{unit.description}
需求文档路径：{PROJECT_ROOT}/upgrade_plan/v{VERSION}/requirement_analysis.md

输出纯 JSON（无额外文字）：
{
  "unit_id": "{unit.id}",
  "test_cases": [
    {
      "id": "TC_{unit.id}_001",
      "description": "test_方法名_场景_预期",
      "module": "tests/unit/test_xxx.py",
      "precondition": "前置条件",
      "expected": "预期结果"
    }
  ]
}
"""
)
```

等待所有 test-writer 完成后，统一处理结果：
- 根据 `unit_id` 找到对应单元，将 `test_cases` 写入，每条加 `"locked_at": 0`
- 在 TASK_LIST.md 中更新 `T_TEST_A_{unit.id}` → `completed`

---

### Step 2：用户确认测试用例

按单元分组展示所有测试用例，等待用户确认。确认后：
- 所有单元的每条 `locked_at` 设为当前时间戳
- `phase = "test_case_locked"`

---

### Step 3：并行调度循环（开发 + 单元测试）

更新 `phase = "dev"`。

进入调度循环，**持续执行直到所有单元 `status = test_pass` 或 `skipped`**：

#### Step 3.1：扫描可推进单元

扫描 `units[]`，找出满足以下条件的单元：
- `status = "pending"`
- `depends_on` 中所有单元的 `status = "test_pass"` 或 `"skipped"`

若扫描结果为空且仍有单元未完成：
- 可能存在循环依赖，上报用户

#### Step 3.2：并行派发 impl-worker

**派发前**，对每个 ready 单元：
- `unit.status = "dev_in_progress"`，写入 task_state.json
- `unit.dev_result.dispatched_at = int(time.time())`（记录派发时间戳，用于验证并行）
- 在 TASK_LIST.md 中将 `T_DEV_{unit.id}` 更新为 `in_progress`

**在同一条消息中**，为所有 ready 单元并行派发 impl-worker：

```
对每个 ready unit，调用 Agent 工具：

Agent(
  agent_type = "impl-worker",
  background = true,
  isolation = "worktree",
  prompt = """
单元ID：{unit.id}
单元名称：{unit.name}
单元描述：{unit.description}
规范文件目录：{PROJECT_ROOT}/.claude/rules/specifications/
测试用例（只读，理解需求边界用）：
{unit.test_cases JSON}

{若 unit.retry_count > 0，附加：}
上一轮测试失败摘要（理解问题用，不得反向凑实现）：
{unit.test_result.report 前300字}

完成后输出纯 JSON：
{
  "unit_id": "{unit.id}",
  "status": "success | failed",
  "summary": "变更摘要",
  "changed_files": ["相对路径"],
  "issues": [],
  "next_action": "ready_for_test | need_human"
}
"""
)
```

> `isolation="worktree"` 为每个 impl-worker 创建独立的 git worktree，多个 impl-worker 可真正并行写文件而不冲突。

#### Step 3.3：处理 impl-worker 结果

每个 impl-worker 返回后，根据 `unit_id` 找到对应单元，将结果写入 `unit.dev_result`，同时记录 `unit.dev_result.completed_at = int(time.time())`，更新 TASK_LIST.md：

> 并行验证：对同一批派发的多个单元，若 `dispatched_at` 时间戳接近（差值 < 5s）且各单元的 `completed_at - dispatched_at` 在合理范围，说明并行确实发生。若某单元 `dispatched_at` 明显晚于同批其他单元，说明退化为串行，需排查 Agent 工具调用是否在同一条消息中。

- `next_action = need_human` → `unit.status = "dev_failed"`，上报用户
- `next_action = ready_for_test` → `unit.status = "dev_done"`，立即进入 Step 3.4

#### Step 3.4：立即派发 test-runner

dev_done 的单元立即：
- `unit.status = "test_in_progress"`，写入 task_state.json
- `unit.test_result.dispatched_at = int(time.time())`
- 在 TASK_LIST.md 中将 `T_TEST_B_{unit.id}` 更新为 `in_progress`

```
Agent(
  agent_type = "test-runner",
  background = true,
  prompt = """
单元ID：{unit.id}
锁定的测试用例（只读，不得修改）：
{unit.test_cases JSON}

执行：pytest {module 路径列表} -v
不要查看任何代码实现文件。

输出纯 JSON：
{
  "unit_id": "{unit.id}",
  "status": "pass | fail",
  "failed_cases": ["TC_U1_001"],
  "report": "逐条结果描述"
}
"""
)
```

#### Step 3.5：处理 test-runner 结果

根据 `unit_id` 写入 `unit.test_result`（含 `completed_at = int(time.time())`），更新 TASK_LIST.md：

**pass：**
- `unit.status = "test_pass"`
- 回到 Step 3.1，扫描是否有新单元因此解锁

**fail：**
- `unit.retry_count++`
- 将 `dev_result + test_result` 快照追加到 `history[]`
- `if unit.retry_count >= 3` → `unit.status = "test_fail"`，上报用户
- `else` → `unit.status = "pending"`，回到 Step 3.1

#### Step 3.6：汇聚检查

所有单元均为 `test_pass` 或 `skipped` 后，退出调度循环，进入 Step 4。

---

### Step 4：集成测试

更新 `phase = "integration_testing"`。

```
Agent(
  agent_type = "integration-test",
  prompt = """
请执行集成测试套件（测试目录和命令见你的 agent 指令）。
不要查看任何代码实现文件。

输出纯 JSON：
{
  "status": "pass | fail",
  "failed_cases": [],
  "report": "逐条结果描述"
}
"""
)
```

写入 `integration_test_result`，更新 TASK_LIST.md `T_TEST_INTEGRATION`：
- `pass` → Step 4b
- `fail` → 上报用户，`phase = "failed"`

---

### Step 4b：接口测试（条件执行）

**仅当 `task_state.has_interface_tests = true` 时执行，否则直接进入 Step 5。**

更新 `phase = "interface_testing"`，TASK_LIST.md 中 `T_TEST_INTERFACE` → `in_progress`。

```
Agent(
  agent_type = "interface-test",
  prompt = """
本次变更涉及的 HTTP 层单元：
{从 requirement_analysis.md 提取所有接入层/路由层/控制器层单元描述}

接口文档来源：{swagger_spec_path | apifox_mcp | postman_collection_path | auto_discover}
测试环境地址：{task_state.interface_test_base_url}

不要查看任何源码实现文件，不要查看单元/集成测试结果。

输出纯 JSON：
{
  "status": "pass | fail",
  "tested_endpoints": ["POST /api/assess"],
  "failed_endpoints": [
    { "endpoint": "...", "expected": "...", "actual": "...", "error": "..." }
  ],
  "report": "测试概述"
}
"""
)
```

写入 `interface_test_result`，更新 TASK_LIST.md：
- `pass` → Step 5
- `fail` → 上报用户，`phase = "failed"`

---

### Step 5：规范检查（派发 lint-checker）

更新 `phase = "review"`。

汇总所有单元 `dev_result.changed_files`（去重）：

```
Agent(
  agent_type = "lint-checker",
  prompt = """
变更文件列表：{所有单元 changed_files 汇总去重}
规范文件目录：{PROJECT_ROOT}/.claude/rules/specifications/
基准 commit：{task_state.base_commit}

执行 git diff 获取变更内容，按文件类型加载规范逐条检查。
不要查看任何测试结果。

输出纯 JSON：
{
  "status": "pass | violations",
  "violations": [
    {
      "rule_id": "CODING_001",
      "file": "src/core/assessor.py",
      "line": 42,
      "description": "违规描述",
      "fix": "修复建议"
    }
  ]
}
"""
)
```

写入 `review_result`，更新 TASK_LIST.md `T_REVIEW`：
- `pass` → Step 6
- `violations` → Step 5.1

#### Step 5.1：修复违规

**先将 `phase` 更新为 `"dev"`**（lint-checker 有 hook 在 phase=review 时阻断代码写入，必须先切换）。
在 TASK_LIST.md 中追加 `T_DEV_FIX` → `in_progress`。

```
Agent(
  agent_type = "impl-worker",
  prompt = """
修复以下规范违规：
{review_result.violations JSON}

规范文件目录：{PROJECT_ROOT}/.claude/rules/specifications/
不要附加任何测试结果信息。

输出纯 JSON（格式同开发阶段）。
"""
)
```

完成后回到 **Step 4**（重新集成测试 → 接口测试（若适用）→ 规范检查）。

---

### Step 6：收尾

```
phase = "done"
```

1. 若有 db / config 变更，生成运维文档
2. 向用户汇报完成摘要：各单元状态、变更文件列表、测试结果概览

---

## 异常处理

| 异常 | 处理 |
|------|------|
| requirement_analysis.md 缺少单元边界表 | 停止，提示用户先运行 /analyst-agent |
| task_state.json 已存在但 phase = done/aborted | 提示用户该版本已完成，如需重新执行请升级 VERSION |
| Agent 返回非 JSON | 记录原始输出到 history，phase = failed，上报用户 |
| next_action = need_human | 上报对应单元，等待用户指令 |
| 单元 retry_count >= 3 | 上报用户，等待指令（继续 / 跳过 / 中止） |
| 集成测试失败 | 不自动重试，上报用户 |
| 接口测试失败 | 不自动重试，上报用户 |
| review 修复后集成/接口测试又失败 | 上报用户，不再自动循环 |
| 无 ready 单元但有未完成单元 | 上报用户，可能存在循环依赖 |
| .claude/agents/ 中缺少所需 agent 文件 | 停止，提示用户先在项目目录运行 /harness-init |
