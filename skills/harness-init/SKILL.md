---
name: harness-init
description: >
  新项目初始化 skill。在全新项目目录下，引导用户逐步确认技术栈、目录结构、编码约定、
  质量工具，然后自动生成 Multi-Agent Harness v2 所需的全套配置文件。
  触发条件：用户说"初始化新项目"、"搭建项目harness"、"setup harness"、"新项目配置"，
  或明确运行 /harness-init。生成产物保证 dev-agent/review-agent SKILL.md 结构与标准模板完全一致，
  唯一可变部分为路径映射表。
---

# harness-init — 项目 Harness 初始化

## Skill 自身结构

本 skill 位于 `~/.claude/skills/harness-init/`，读取任何参考文件时必须使用绝对路径：

| 文件 | 绝对路径 | 用途 |
|------|---------|------|
| 技术栈规则（人类可读）| `~/.claude/skills/harness-init/references/tech-stack-rules.md` | Step 1 向用户推荐选项；理解规则设计意图 |
| 技术栈规则（机器可读）| `~/.claude/skills/harness-init/references/tech-stack-rules.yaml` | Step 6 解析规则、生成规范文件和 review_checks.py |
| dev-agent 模板 | `~/.claude/skills/harness-init/references/dev-agent-template.md` | Step 6 生成 dev-agent/SKILL.md |
| review-agent 模板 | `~/.claude/skills/harness-init/references/review-agent-template.md` | Step 6 生成 review-agent/SKILL.md |
| 通用 hook 文件（5个） | `~/.claude/skills/harness-init/references/hooks/*.sh` | Step 6 复制到新项目 .claude/hooks/ |
| review_checks 骨架 | `~/.claude/skills/harness-init/references/review_checks_template.py` | Step 6 生成 review_checks.py 的接口骨架 |
| .gitignore 模板 | `~/.claude/skills/harness-init/references/gitignore-template` | Step 6 原样复制为项目 .gitignore |

---

## 产物清单

在项目根目录生成以下文件：

```
{项目根}/
├── VERSION                                    ← 初始版本号（1.0 或用户指定）
├── CLAUDE.md                                  ← 项目级规范主文件
├── .gitignore                                 ← Harness 完整性保护 + .env 屏蔽（从模板复制）
├── .env.example                               ← 环境变量模板（由技术栈安全规则生成）
└── .claude/
    ├── settings.json                          ← hook 注册配置
    ├── rules/specifications/
    │   ├── coding.md                          ← 编码规范（由技术栈生成）
    │   ├── testing.md                         ← 测试规范（由测试框架生成）
    │   └── security.md                        ← 安全规范（由基础设施生成）
    ├── hooks/
    │   ├── pre-tool-use-check-tasks.sh        ← 通用：Write/Edit 前置门控（从模板复制）
    │   ├── post-tool-use-check-completion.sh  ← 通用：工具调用后完成检查（从模板复制）
    │   ├── task-started-update-task-list.sh   ← 通用：任务状态同步（从模板复制）
    │   ├── task-completed-update-task-list.sh ← 通用：任务状态同步（从模板复制）
    │   ├── task-created-check-task-list.sh    ← 通用：任务创建检查（从模板复制）
    │   ├── review_checks.py                   ← 项目特定：确定性脚本检查层（由骨架 + 技术栈生成）
    │   ├── [可选] post-tool-use-file-quality-check.sh  ← 文件编辑后即时规则检查（Step 3.5 用户确认后生成）
    │   └── [可选] task-completed-quality-check.sh      ← 任务完成时规则检查（Step 3.5 用户确认后生成）
    └── skills/
        ├── dev-agent/SKILL.md                 ← 从模板生成，填入路径映射表
        └── review-agent/SKILL.md              ← 从模板生成，填入路径映射表
```

> dev-agent 和 review-agent 的 SKILL.md 内容与标准模板逐字相同，唯一差异是路径映射表。
> 项目特定规则全部存放在规范文件中，不写入 SKILL.md。

---

## 执行流程

### Step 0：模式检测

进入执行前，先判断项目当前状态：

```
if 项目根目录下存在 .claude/ 目录:
    → 进入【补充模式】（见下方）
else:
    → 进入【初始化模式】，从 Step 1 开始
```

---

#### 补充模式

用于项目已完成初始化后，后续追加技术栈组件、目录或调整约定。

**1. 读取现有配置，生成摘要**

依次读取以下文件，提炼当前状态：
- `CLAUDE.md` → 获取项目名称和技术栈概览
- `.claude/rules/specifications/coding.md` → 当前编码规范条目数
- `.claude/rules/specifications/security.md` → 当前安全规范条目数
- `.claude/rules/specifications/testing.md` → 当前测试规范条目数
- `.claude/skills/dev-agent/SKILL.md` → 当前路径映射表（`PATH_MAPPING_TABLE_START` 到 `PATH_MAPPING_TABLE_END` 之间的内容）

向用户展示摘要，例如：

```
当前已有配置：
- 语言：Python
- 框架：FastAPI
- 数据库：PostgreSQL
- 日志库：loguru
- 路径映射：src/api → coding.md, src/db → coding.md + security.md ...

你想补充什么？（可多选）
  A. 新增技术栈组件（如 Redis、RabbitMQ、Docker）
  B. 新增目录并分配规范
  C. 修改架构约定（异常位置 / 配置模块路径）
  D. 其他
```

**2. 根据用户选择，执行对应的补充动作**

| 用户选择 | 执行动作 |
|---------|---------|
| A（新技术栈组件）| 从 Step 1 的技术栈列表中只询问新增部分，读取 `tech-stack-rules.yaml` 获取对应规则，追加到现有规范文件（不覆盖已有内容）；将新 `script_checks` 追加到 `review_checks.py`。若项目已存在 `post-tool-use-file-quality-check.sh` 或 `task-completed-quality-check.sh`，额外询问用户是否将新增规则纳入这两个 Hook，若是则追加对应 grep 块（规则同样只从新增的 `script_checks` 中选取）|
| B（新增目录）| 询问新目录名称和职责，按路径映射规则分配规范文件，重新生成 dev-agent/SKILL.md 和 review-agent/SKILL.md 的路径映射表（用更新后的完整表替换占位符区间）|
| C（修改架构约定）| 仅更新 `coding.md` 中的对应约定行，以及 `review_checks.py` 中对应的绕过检查 |

**3. 预览与确认**

展示本次将要变更的文件和具体内容差异（新增行 / 替换行），用户确认后写入。

**4. 补充完成**

输出变更摘要（哪些文件变更了、新增了哪些规则条目）。

> 补充模式只更新受影响的文件，不会重新生成 VERSION、CLAUDE.md 或覆盖已有的 Hook 文件。

---

### Step 1：技术栈确认

按类别逐一询问，每类给出常见选项（用户可选择或自由输入）：

| 类别 | 询问示例 |
|------|---------|
| 编程语言 | Python / TypeScript / Go / Java / PHP |
| Web 框架 | FastAPI / Django / Express / Spring Boot / Gin |
| 关系型数据库 | MySQL / PostgreSQL / SQLite / 无 |
| 缓存 | Redis / Memcached / 无 |
| 消息队列 | RabbitMQ / Kafka / Celery / 无 |
| 搜索引擎 | Elasticsearch / 无 |
| 对象存储 | S3 / OSS / 无 |
| ORM / 数据访问 | SQLAlchemy / Peewee / Prisma / MyBatis / GORM |
| 日志库 | loguru / logging / winston / zerolog / slf4j |
| 配置管理 | python-dotenv / viper / Spring Config / dotenv |
| 基础设施 | Docker / K8s / 无 |

每类可多选。完成后向用户展示汇总，确认无误后继续。

### Step 2：目录结构确认

1. 询问源码根目录（`src/` / `app/` / `lib/` 或自定义）
2. 询问测试目录（`tests/` / `__tests__/` / `spec/` 或自定义）
3. 根据技术栈推荐标准子目录结构（参考 `references/tech-stack-rules.md` 的 `dir_structure` 字段）
4. 展示推荐结构，用户确认或修改
5. 确认每个子目录的职责（业务层 / 数据层 / 接入层 / 工具层…）

最终输出一张映射表（用于后续生成）：

```
src/api/      → coding.md
src/db/       → coding.md + security.md
src/cache/    → coding.md + security.md
src/queue/    → coding.md + security.md
tests/unit/   → testing.md
tests/intg/   → testing.md
.env*         → security.md
```

### Step 3：架构约定确认

Step 1 确定了"用什么库"，Step 3 确定"代码放在哪"。根据技术栈展示推荐默认值，用户确认或修改：

- **异常/错误处理位置**：业务异常统一定义在哪个文件或目录？
  （推荐默认：Python → `src/exceptions.py`，Go → `internal/errors/`，Java → `src/main/.../exception/`）
- **配置读取路径**：配置模块的统一入口在哪里？
  （推荐默认：Python → `src/config/settings.py`，Go → `internal/config/config.go`，Node → `src/config/index.ts`）

这两个约定会写入 `coding.md` 规范，并在 `review_checks.py` 中生成对应的绕过检查。

### Step 4：质量工具确认

展示基于语言推荐的静态分析工具：

| 语言 | 推荐工具 |
|------|---------|
| Python | mypy / flake8 / bandit |
| TypeScript | tsc --noEmit / eslint |
| Go | go vet / staticcheck / gosec |
| Java | checkstyle / spotbugs |

询问哪些工具已安装，是否纳入 `review_checks.py`。
未安装的工具在脚本中生成单行 TODO 注释：`# TODO: install {tool} — 安装后在此处补充调用`，不生成调用代码。

### Step 3.5：（可选）增量质量门控 Hook

> 本步骤可跳过。跳过后仍可手动添加。

**背景**：全局 review-agent 在每个开发批次结束时运行 `review_checks.py` 中的所有规则，是规则执行的最终权威。本步骤可在此基础上额外设置两类轻量级增量检查：
- **PostToolUse Hook**：每次文件编辑完成后立即触发，针对单个文件运行少量高优先级规则，让 AI 就地修复
- **TaskCompleted Hook**：每个任务标记完成时触发，针对源码目录运行 AI 在大上下文下容易遗忘的规则

**核心约束：规则来源唯一性**

这两个 Hook 中的检查规则**只能从 Step 1–4 已确认、将写入 `review_checks.py` 的规则中选取**。不引入任何新规则，不添加未记录在文档中的规则——即使这些规则曾在讨论中提到。原因：若 Hook 中存在 `review_checks.py` 之外的规则，全局 review-agent 的检查就无法覆盖它们，质量门控的权威性将被分裂。

---

**操作流程**：

**1. 询问用户是否需要增量质量门控**

```
是否需要在文件编辑完成后 / 任务完成时，运行增量质量检查？
（全局 review-agent 已会运行所有规则，此处是可选的即时补充）

  A. 设置 PostToolUse Hook（文件编辑后即时检查，适合单文件规则）
  B. 设置 TaskCompleted Hook（任务完成时检查，适合跨文件一致性规则）
  C. 两者都设置
  D. 跳过本步骤
```

如果用户选择 D，直接进入 Step 5。

**2. 向用户展示已确认的规则集**

从 Step 1–4 已确认的 `script_checks` 规则中，提取完整列表，每条规则显示：
- `rule_id`：规则编号
- `description`：规则描述
- `file_glob`：适用文件类型
- **推荐位置**：基于下表给出推荐

| 规则特征 | 推荐位置 | 典型示例 |
|---------|---------|---------|
| 单文件即可判断，无需看其他文件 | PostToolUse | `print()` 禁用、命名格式 |
| 违规后立即可修正，代价低 | PostToolUse | 缺失类型注解、裸 Exception |
| 误报率低（极少在正常代码中触发） | PostToolUse | 硬编码密钥模式、危险 API 调用 |
| 需要对比多个文件才能判断 | TaskCompleted | 模块实例化方式、配置读取路径 |
| AI 上下文压缩后容易遗忘的约定 | TaskCompleted | 统一工厂方法、禁止直接路径实例化 |
| 修复代价较高，适合任务结束后统一处理 | TaskCompleted | 跨文件命名一致性 |
| 依赖外部工具（mypy/eslint），单文件运行慢 | Review-only（不建议放入 Hook） | 类型推导错误、lint 全量检查 |

向用户展示规则列表和推荐，例如：

```
以下是已确认的 script_checks 规则（共 N 条）：

  CODING_001  禁止使用 print()（*.py）              → 推荐：PostToolUse
  CODING_002  禁止裸抛 Exception（*.py）             → 推荐：PostToolUse
  CODING_003  配置必须通过 src/config/settings.py 读取（*.py）  → 推荐：TaskCompleted
  CODING_004  禁止绕过 src/llm/ 直接实例化 LLM（*.py）         → 推荐：TaskCompleted
  SECURITY_001 禁止硬编码 API Key（*.py, *.ts）      → 推荐：PostToolUse
  ...

请确认哪些规则放入 PostToolUse Hook，哪些放入 TaskCompleted Hook（输入规则编号，或直接确认推荐）：
```

**3. 用户确认后记录选择**

记录两个集合：
- `post_tool_use_rules[]`：用户选定放入 PostToolUse Hook 的规则（含 `grep_pattern` + `file_glob`）
- `task_completed_rules[]`：用户选定放入 TaskCompleted Hook 的规则

Step 6 将根据这两个集合生成对应 Hook 文件。

---

### Step 5：预览与最终确认

向用户展示将要生成的内容摘要：

1. **规范文件摘要**：每个 spec 文件的规则条数和关键条目
2. **路径映射表**：完整的目录 → 规范文件对应关系
3. **脚本检查项**：`review_checks.py` 将包含的检查列表
4. **VERSION 初始值**：默认 `1.0`，用户可修改

用户确认后执行 Step 6。

### Step 6：生成所有产物

按以下顺序写入文件：

1. `VERSION` 文件
2. `CLAUDE.md`（根据以下**必须包含的要素**自由生成内容，不使用固定模板）：
   - 项目名称和一句话功能描述
   - 技术栈列表（来自 Step 1 确认结果）
   - 目录结构说明（来自 Step 2 确认结果）
   - 任务管理规范（TASK_LIST.md 创建和状态流转规则）
   - 规范文件路径指引（指向 `.claude/rules/specifications/`）
3. `.claude/rules/specifications/coding.md`
4. `.claude/rules/specifications/testing.md`
5. `.claude/rules/specifications/security.md`
6. `.claude/hooks/review_checks.py`（读取 `references/review_checks_template.py` 作为骨架，按技术栈填入 `grep_check()` 调用）
7. 复制 5 个通用 hook 文件到 `.claude/hooks/`（依次 Read `references/hooks/` 下每个 .sh 文件，Write 到目标路径，内容不做任何修改）
7b. （若 Step 3.5 用户选择了 PostToolUse 规则）生成 `.claude/hooks/post-tool-use-file-quality-check.sh`：
   - 脚本骨架：读取 stdin JSON，提取 `tool_name` 和 `file_path`，只处理 Write/Edit，只处理已存在的文件
   - 对每条 `post_tool_use_rules[]` 中的规则，生成一段 if 块：
     ```bash
     if [[ "$FILE_PATH" == {file_glob} ]]; then
       if grep -qP "{grep_pattern}" "$FILE_PATH" 2>/dev/null; then
         echo "⚠️ [{rule_id}] {description}" >&2
         VIOLATIONS=$((VIOLATIONS + 1))
       fi
     fi
     ```
   - 脚本末尾：`[ "$VIOLATIONS" -gt 0 ]` 则 `exit 2`（向 Claude 发送修复信号），否则 `exit 0`
   - 文件头部注释注明：规则来源为 `review_checks.py`，与全局检查保持一致
7c. （若 Step 3.5 用户选择了 TaskCompleted 规则）生成 `.claude/hooks/task-completed-quality-check.sh`：
   - 脚本骨架：读取 `PROJECT_ROOT`，定位 `SRC_DIR`（来自 Step 2 确认的源码根目录）
   - 对每条 `task_completed_rules[]` 中的规则，生成一段递归 grep 检查：
     ```bash
     MATCHES=$(grep -rP "{grep_pattern}" "$SRC_DIR" --include="{file_glob_pattern}" 2>/dev/null)
     if [ -n "$MATCHES" ]; then
       echo "⚠️ [{rule_id}] {description}" >&2
       echo "$MATCHES" | head -5 >&2
       VIOLATIONS=$((VIOLATIONS + 1))
     fi
     ```
   - 脚本末尾：`[ "$VIOLATIONS" -gt 0 ]` 则输出汇总并 `exit 2`，否则 `exit 0`
   - 文件头部注释注明：规则来源为 `review_checks.py`，与全局检查保持一致
8. 生成 `.claude/settings.json`（注册所有 hook）
9. `.claude/skills/dev-agent/SKILL.md`（读模板 → 替换路径映射表）
10. `.claude/skills/review-agent/SKILL.md`（读模板 → 替换路径映射表）
11. `.gitignore`（Read `references/gitignore-template`，原样 Write 到项目根目录）
12. `.env.example`（从 yaml 各组件的 `security_rules` 中提取环境变量名，生成占位符模板）

> **生成 dev-agent / review-agent SKILL.md：**
> 读取 `~/.claude/skills/harness-init/references/dev-agent-template.md` 和 `~/.claude/skills/harness-init/references/review-agent-template.md`，
> 将 `<!-- PATH_MAPPING_TABLE_START -->` 与 `<!-- PATH_MAPPING_TABLE_END -->` 之间的**全部内容（包括 `{PATH_MAPPING_TABLE}` 占位符行本身）**
> 替换为 Step 2 生成的路径映射表（Markdown 表格行格式，如 `| src/api/ | coding.md |`）。
> `<!-- PATH_MAPPING_TABLE_START -->` 和 `<!-- PATH_MAPPING_TABLE_END -->` 这两行注释**必须保留**，供补充模式定位区间。
> 其余内容**原样保留**。
>
> **生成 settings.json：**
>
> 基础 hook 始终注册。若 Step 3.5 用户选择了质量门控 hook，在对应事件的 `hooks` 数组中追加条目：
>
> ```json
> {
>   "hooks": {
>     "PreToolUse": [
>       {"matcher": "Write|Edit|MultiEdit", "hooks": [{"type": "command", "command": "bash .claude/hooks/pre-tool-use-check-tasks.sh"}]}
>     ],
>     "PostToolUse": [
>       {"matcher": "Write|Edit|MultiEdit", "hooks": [{"type": "command", "command": "bash .claude/hooks/post-tool-use-check-completion.sh"}]},
>       // 若 Step 3.5 选择了 PostToolUse 规则，追加：
>       {"matcher": "Write|Edit|MultiEdit", "hooks": [{"type": "command", "command": "bash .claude/hooks/post-tool-use-file-quality-check.sh"}]}
>     ],
>     "TaskStarted": [{"hooks": [{"type": "command", "command": "bash .claude/hooks/task-started-update-task-list.sh"}]}],
>     "TaskCompleted": [
>       {"hooks": [{"type": "command", "command": "bash .claude/hooks/task-completed-update-task-list.sh"}]},
>       // 若 Step 3.5 选择了 TaskCompleted 规则，追加：
>       {"hooks": [{"type": "command", "command": "bash .claude/hooks/task-completed-quality-check.sh"}]}
>     ],
>     "TaskCreated": [{"hooks": [{"type": "command", "command": "bash .claude/hooks/task-created-check-task-list.sh"}]}]
>   },
>   "permissions": {
>     "allow": ["Read(**)", "Write(upgrade_plan/**)", "Write(.claude/**)", "Write(src/**)", "Bash(git *)", "Bash(pytest *)", "Bash(python3 *)"]
>   }
> }
> ```
> permissions 说明：
> - `Write(src/**)` 是 dev-agent 写业务代码的必要权限，源码根目录名称（`src/`、`app/`、`internal/` 等）根据 Step 2 确认的目录结构调整
> - `Bash(pytest *)` 根据测试框架调整：Jest 项目改为 `Bash(npx jest *)`，Go 项目改为 `Bash(go test *)`
> - `Bash(python3 *)` 所有项目均需保留，用于执行 `review_checks.py`

---

## 生成逻辑

### 规则收集

读取 `references/tech-stack-rules.yaml`，对 Step 1 确认的每个技术栈组件，收集对应规则，写入规范文件和 `review_checks.py`。

> **关于规则的定位**：`tech-stack-rules.yaml` 中的规则（除 `universal` 安全类外）均为**推荐默认值**，代表业界通行约定。它们是项目工程约定，不是 Harness 自身的强制要求。Harness 的职责是执行团队制定的规则，而不是规定团队应当遵守哪些工程规范。
>
> **生成后请告知用户**：`coding.md`、`testing.md` 中的内容来自推荐默认值，团队可按实际约定自由修改；`review_checks.py` 中对应的检查函数也应同步调整。`security.md` 和 `universal` 类检查（禁止提交密钥等）建议保留。

规则分类及写入目标：
- 收集 `coding_rules[]` → 合并入 `coding.md`
- 收集 `security_rules[]` → 合并入 `security.md`
- 收集 `testing_rules[]` → 合并入 `testing.md`
- 收集 `script_checks[]` → 生成 `review_checks.py` 的检查函数

**去重规则**：若同时选择了语言（如 Python）和对应日志库（如 loguru），且两者的 `script_checks` 中存在相同的 `grep_pattern + file_glob` 组合，只保留日志库的条目（rule_id 更具体，描述更精准）。

### 路径映射表生成

直接使用 Step 2 用户确认的职责结果生成映射表，不做目录名字符串推导。

| Step 2 确认的职责类型 | 对应规范文件 |
|---------------------|------------|
| 数据持久化 / ORM / Repository | `coding.md` + `security.md` |
| 缓存 / Session | `coding.md` + `security.md` |
| 消息队列 / Worker / Task | `coding.md` + `security.md` |
| AI / LLM / ML | `coding.md` + `security.md` |
| 配置加载 | `security.md` |
| 测试 | `testing.md` |
| `.env*` 文件 | `security.md` |
| 其余源码目录 | `coding.md` |

> 映射依据是用户在 Step 2 描述的职责，而非目录名称。
> 同一目录若兼有多个职责，取所有对应规范文件的并集。

---

## 参考文件

- `references/tech-stack-rules.md` — 人类可读版规则知识库，含规则意图说明和推荐目录结构（**Step 1 推荐选项时读取**）
- `references/tech-stack-rules.yaml` — 机器可读版规则数据，含完整 coding/security/testing/script_checks 字段（**Step 6 生成规范文件和 review_checks.py 时读取**）
- `references/review_checks_template.py` — review_checks.py 接口骨架，定义调用约定和 JSON 输出格式（**Step 6 生成 review_checks.py 时必须读取**）
- `references/gitignore-template` — .gitignore 固定内容模板（**Step 6 原样复制**）
- `references/dev-agent-template.md` — dev-agent SKILL.md 标准模板（Step 6 生成时必须读取）
- `references/review-agent-template.md` — review-agent SKILL.md 标准模板（Step 6 生成时必须读取）
