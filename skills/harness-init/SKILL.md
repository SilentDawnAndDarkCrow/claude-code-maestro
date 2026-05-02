---
name: harness-init
description: >
  项目 Harness 初始化 skill。支持三种模式：全新项目（Mode A）、旧项目接入（Mode B）、
  已有 Harness 的补充（Mode C）。核心职责是生成 Multi-Agent Harness 所需的脚手架文件：
  CLAUDE.md、规范文件、hook 脚本、项目级 agent 定义（.claude/agents/）。
  规范内容来源：Mode A 由 LLM 根据技术栈生成 + 用户确认；
  Mode B 从现有代码库提取约定 + 用户确认；Mode C 追加补充。
  触发条件：用户说"初始化新项目"、"旧项目接入 harness"、"setup harness"、
  "新项目配置"，或明确运行 /harness-init。
---

# harness-init — 项目 Harness 初始化

## Skill 自身结构

本 skill 位于 `~/.claude/skills/harness-init/`，读取任何参考文件时必须使用绝对路径：

| 文件 | 绝对路径 | 用途 |
|------|---------|------|
| 通用 hook 文件（5个） | `~/.claude/skills/harness-init/references/hooks/*.sh` | Step 6 复制到新项目 .claude/hooks/ |
| agent 专用 hook | `~/.claude/skills/harness-init/references/hooks/block-test-modification.sh` | Step 6 复制，impl-worker 专用 |
| agent 专用 hook | `~/.claude/skills/harness-init/references/hooks/block-status-read.sh` | Step 6 复制，lint-checker 专用 |
| review_checks 骨架 | `~/.claude/skills/harness-init/references/review_checks_template.py` | Step 6 生成 review_checks.py |
| .gitignore 模板 | `~/.claude/skills/harness-init/references/gitignore-template` | Step 6 原样复制 |
| test-writer agent 模板 | `~/.claude/skills/harness-init/references/agents/test-writer-template.md` | Step 6 生成 .claude/agents/test-writer.md |
| impl-worker agent 模板 | `~/.claude/skills/harness-init/references/agents/impl-worker-template.md` | Step 6 生成 .claude/agents/impl-worker.md |
| test-runner agent 模板 | `~/.claude/skills/harness-init/references/agents/test-runner-template.md` | Step 6 生成 .claude/agents/test-runner.md |
| integration-test agent 模板 | `~/.claude/skills/harness-init/references/agents/integration-test-template.md` | Step 6 生成 .claude/agents/integration-test.md |
| interface-test agent 模板 | `~/.claude/skills/harness-init/references/agents/interface-test-template.md` | Step 6 生成 .claude/agents/interface-test.md |
| lint-checker agent 模板 | `~/.claude/skills/harness-init/references/agents/lint-checker-template.md` | Step 6 生成 .claude/agents/lint-checker.md |

> `tech-stack-rules.yaml` 不再作为规范内容的主要来源。Mode A 规范内容由 LLM 根据
> 技术栈直接生成；Mode B 规范内容从代码库提取。tech-stack-rules.yaml 可作为
> 补充参考，但不是必读文件。

---

## 产物清单

在项目根目录生成以下文件：

```
{项目根}/
├── VERSION                                    ← 初始版本号（1.0 或用户指定）
├── CLAUDE.md                                  ← 项目级规范主文件
├── .gitignore                                 ← Harness 完整性保护 + .env 屏蔽
├── .env.example                               ← 环境变量模板
└── .claude/
    ├── settings.json                          ← hook 注册配置
    ├── rules/specifications/
    │   ├── coding.md                          ← 编码规范
    │   ├── testing.md                         ← 测试规范（含测试模式参考区）
    │   └── security.md                        ← 安全规范
    ├── hooks/
    │   ├── pre-tool-use-check-tasks.sh
    │   ├── post-tool-use-check-completion.sh
    │   ├── task-started-update-task-list.sh
    │   ├── task-completed-update-task-list.sh
    │   ├── task-created-check-task-list.sh
    │   ├── block-test-modification.sh         ← impl-worker 专用
    │   ├── block-status-read.sh               ← lint-checker 专用
    │   ├── review_checks.py
    │   ├── [可选] post-tool-use-file-quality-check.sh
    │   └── [可选] task-completed-quality-check.sh
    └── agents/
        ├── test-writer.md
        ├── impl-worker.md
        ├── test-runner.md
        ├── integration-test.md
        ├── interface-test.md
        └── lint-checker.md
```

---

## 执行流程

### Step 0：模式检测

检测项目当前状态，向用户展示检测结果，由用户选择模式：

```
检测到：
  · .claude/ 目录：[存在 / 不存在]
  · manifest 文件或源码目录：[存在 / 不存在]

请选择模式：
  A. 全新项目         — 从零初始化
  B. 旧项目接入       — 已有代码库，首次引入 Harness
  C. 已有 Harness     — 追加技术栈组件、目录或修改约定
```

检测结果仅作参考，用户可自由选择，不强制跳转。

---

## Mode B：旧项目接入

> 旧项目已有代码，但还没有 Harness。规范内容应从代码库中提取，而不是凭空生成。

### Step B1：技术栈自动检测

扫描项目根目录，匹配以下文件，推断技术栈：

**Manifest 文件（语言/依赖声明）：**

| 文件 | 语言/生态 |
|------|---------|
| `requirements.txt`、`pyproject.toml`、`Pipfile`、`setup.py` | Python |
| `package.json`、`yarn.lock`、`pnpm-lock.yaml` | Node.js |
| `composer.json`、`composer.lock` | PHP |
| `go.mod`、`go.sum` | Go |
| `Gemfile`、`Gemfile.lock` | Ruby |
| `pom.xml`、`build.gradle`、`build.gradle.kts` | Java/Kotlin |
| `Cargo.toml` | Rust |
| `*.csproj`、`*.sln` | .NET |
| `pubspec.yaml` | Dart/Flutter |

**框架特征文件（比 manifest 更精确）：**

| 文件 | 框架 |
|------|------|
| `artisan` | Laravel |
| `manage.py` | Django |
| `app.py` / `main.py`（结合 requirements.txt） | Flask / FastAPI |
| `phpunit.xml` | PHPUnit |
| `pytest.ini`、`conftest.py` | pytest |
| `jest.config.js`、`vitest.config.ts` | Jest / Vitest |
| `.rspec` | RSpec |

**CI 配置（获取实际构建/测试命令）：**
- `.github/workflows/*.yml`
- `Jenkinsfile`、`.travis.yml`、`.gitlab-ci.yml`

综合推断后，向用户展示结果并确认：

```
检测到技术栈：
  语言：Python 3.x
  框架：FastAPI
  测试工具：pytest
  依赖管理：pip / requirements.txt
  CI：GitHub Actions（测试命令：pytest tests/）

是否正确？如有误请直接修改：
```

---

### Step B2：是否开启深度检查

```
代码库分析模式：

  A. 标准检查（默认）— 单 agent 采样，快速，适合代码风格一致的项目
  B. 深度检查        — 3 个 agent 各自读取不同代码区域，通过一致性对比
                       识别规范分歧，适合历史较长或多人维护的项目
                       （token 消耗约 3 倍）

选择：(A/b)
```

---

### Step B3：代码库采样

根据 Step B2 的选择执行：

**标准检查（单 agent）：**

读取以下文件作为样本（每类取 3-5 个，优先最近修改的）：
- 测试目录下的测试文件
- 每个源码子目录各取 1 个代表性文件
- 配置文件（`.env.example`、`config/`、`settings.py` 等）
- CI 配置文件

**深度检查（3 个 agent 并行，读取不同区域）：**

```
Agent 1：tests/unit/ 或等价目录 + src/core/ 或业务核心层
Agent 2：tests/integration/ 或等价目录 + src/api/ 或接入层
Agent 3：tests/ 边缘用例（fixtures、conftest）+ src/utils/ 或工具层
```

三个 agent 各自独立分析，不共享中间结果，避免相互影响。

---

### Step B4：约定提取与置信度标注

**单 agent 提取：**

从采样文件中识别以下约定：
- 测试写法（fixture 风格、mock 方式、断言习惯、测试命名规则）
- 异常处理（定义位置、抛出方式、HTTP 错误映射）
- 配置读取入口（统一入口还是分散读取）
- 命名约定（文件名、类名、函数名格式）
- 导入风格（绝对导入 vs 相对导入）

**深度检查时，主流程汇总三个 agent 的结果：**

| 一致性 | 置信度 | 展示方式 |
|--------|--------|---------|
| 三者一致 | 高 | 直接列为规范候选 |
| 两者一致 | 中 | 标注"大部分代码遵循，存在例外" |
| 三者分歧 | 低 | 标注"代码库存在不一致，需人工决策" |
| 某 agent 独有发现 | 参考 | 标注"仅在 X 区域发现" |

> **置信度是采样范围内的判断，不是全局保证。** 三方一致只说明三个样本集中未见例外，
> 不排除代码库其他区域存在违反。所有提取结果均需用户在 Step B5 最终确认后才成为规范。
>
> 低置信度和分歧项是旧项目历史债务的集中体现，需要用户在此明确做出选择：
> 采纳哪种约定，或接受现有不一致并标注为"历史遗留，新代码遵循 X"。

---

### Step B5：用户确认提取的约定

向用户展示提取结果，格式示例：

```
从代码库中提取到以下约定，请逐项确认：

[高置信度]
  ✓ 测试文件命名：test_{模块名}.py
  ✓ 异常统一定义在：src/exceptions.py
  ✓ 配置读取入口：src/config/settings.py

[中置信度 — 大部分遵循，存在例外]
  ? mock 方式：大部分用 unittest.mock.patch，tests/legacy/ 下用 pytest-mock
    → 采纳哪种作为规范？(patch / pytest-mock / 两者均可)

[低置信度 — 代码库存在不一致]
  ! 异步测试：部分用 pytest-asyncio auto 模式，部分用 asyncio.run()
    → 请决策统一使用哪种：

[仅在特定区域发现]
  ~ tests/integration/ 使用真实数据库，tests/unit/ 使用 SQLite in-memory
    → 是否保留这种分层策略？(y/N)
```

用户确认后，将所有已确认的约定作为规范内容来源，进入 Step 5 预览，再执行 Step 6。

---

## Mode A：全新项目

### Step 1：技术栈确认

按类别逐一询问，每类给出常见选项（用户可选择或自由输入）：

| 类别 | 询问示例 |
|------|---------|
| 编程语言 | Python / TypeScript / Go / Java / PHP / Ruby / Rust |
| Web 框架 | FastAPI / Django / Express / Spring Boot / Gin / Laravel |
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

### Step 1.5：关键运行时约定

技术栈确认后，**只询问 LLM 无法从技术栈本身推断、必须由用户明确的信息**：

| 触发条件 | 询问内容 | 写入位置 |
|---------|---------|---------|
| 选择了 Python | 最低兼容版本？（3.9 / 3.10 / 3.11 / 3.12+）| `coding.md` 语言约束区 |
| 选择了关系型数据库 + 测试框架 | 测试中使用真实 DB 还是 in-memory？ | `testing.md` |

> **不询问的内容**：FastAPI TestClient 写法、Celery 测试模式、pytest-asyncio 配置——
> 这些是 LLM 已知的技术栈惯例，直接写入 `testing.md` 的「测试模式参考」区，
> 由 test-writer 和 impl-worker 读取后按上下文自行判断，不需要用户提前决策。

### Step 2：目录结构确认

1. 询问源码根目录（`src/` / `app/` / `lib/` 或自定义）
2. 询问测试目录（`tests/` / `__tests__/` / `spec/` 或自定义）
3. 根据技术栈推荐标准子目录结构，展示后用户确认或修改
4. 确认每个子目录的职责（业务层 / 数据层 / 接入层 / 工具层…）

最终输出路径映射表（用于后续生成）：

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

根据技术栈展示推荐默认值，用户确认或修改：

- **异常/错误处理位置**：业务异常统一定义在哪个文件或目录？
  （推荐默认：Python → `src/exceptions.py`，Go → `internal/errors/`，Java → `src/main/.../exception/`）
- **配置读取路径**：配置模块的统一入口在哪里？
  （推荐默认：Python → `src/config/settings.py`，Go → `internal/config/config.go`，Node → `src/config/index.ts`）

这两个约定写入 `coding.md`，并在 `review_checks.py` 中生成对应的绕过检查。

### Step 4：质量工具确认

展示基于语言推荐的静态分析工具：

| 语言 | 推荐工具 |
|------|---------|
| Python | mypy / flake8 / bandit |
| TypeScript | tsc --noEmit / eslint |
| Go | go vet / staticcheck / gosec |
| Java | checkstyle / spotbugs |
| PHP | phpstan / psalm |
| Ruby | rubocop |

询问哪些工具已安装，是否纳入 `review_checks.py`。
未安装的工具生成单行 TODO 注释：`# TODO: install {tool} — 安装后在此处补充调用`。

### Step 4.5：（可选）增量质量门控 Hook

> 本步骤可跳过。跳过后仍可手动添加。

**背景**：全局 lint-checker 在每个开发批次结束时运行 `review_checks.py` 中的所有规则，是规则执行的最终权威。本步骤可额外设置两类轻量级增量检查：
- **PostToolUse Hook**：每次文件编辑完成后立即触发，针对单个文件运行少量高优先级规则
- **TaskCompleted Hook**：每个任务标记完成时触发，针对源码目录运行容易遗忘的规则

**核心约束：规则来源唯一性**

这两个 Hook 中的检查规则**只能从 Step 1–4 已确认、将写入 `review_checks.py` 的规则中选取**，不引入任何新规则。

**操作流程**：

**1. 询问用户是否需要增量质量门控**

```
是否需要在文件编辑完成后 / 任务完成时，运行增量质量检查？
（lint-checker 已会运行所有规则，此处是可选的即时补充）

  A. 设置 PostToolUse Hook（文件编辑后即时检查）
  B. 设置 TaskCompleted Hook（任务完成时检查）
  C. 两者都设置
  D. 跳过本步骤
```

**2. 向用户展示已确认的规则集，按推荐位置分类**

| 规则特征 | 推荐位置 |
|---------|---------|
| 单文件即可判断 | PostToolUse |
| 违规后立即可修正，代价低 | PostToolUse |
| 误报率低 | PostToolUse |
| 需要对比多个文件 | TaskCompleted |
| 上下文压缩后容易遗忘的约定 | TaskCompleted |
| 依赖外部工具（mypy/eslint） | Review-only（不建议放入 Hook） |

**3. 用户确认后记录选择**

- `post_tool_use_rules[]`
- `task_completed_rules[]`

Step 6 将根据这两个集合生成对应 Hook 文件。

> Step 4.5 可在 Mode C（补充模式）中通过选项 E 重新进入，用于首次跳过后的追加配置。

---

## Mode C：已有 Harness 的补充

用于项目已完成初始化后，后续追加技术栈组件、目录或调整约定。

**1. 读取现有配置，生成摘要**

依次读取：
- `CLAUDE.md` → 项目名称和技术栈概览
- `.claude/rules/specifications/coding.md` → 当前规范条目数
- `.claude/rules/specifications/testing.md` → 当前规范条目数
- `.claude/rules/specifications/security.md` → 当前规范条目数
- `.claude/agents/impl-worker.md` → 当前路径映射表

向用户展示摘要，询问补充方向：

```
你想补充什么？（可多选）
  A. 新增技术栈组件（如 Redis、RabbitMQ、Docker）
  B. 新增目录并分配规范
  C. 修改架构约定（异常位置 / 配置模块路径）
  D. 其他
  E. 重新配置增量质量门控 Hook（初始化时跳过，现在补设）
```

**2. 根据用户选择执行补充动作**

| 用户选择 | 执行动作 |
|---------|---------|
| A（新技术栈组件）| 询问新组件，由 LLM 生成对应规范条目，追加到规范文件（不覆盖已有内容）；将新 script_checks 追加到 review_checks.py |
| B（新增目录）| 询问目录名称和职责，更新路径映射表，重新生成 impl-worker.md 和 lint-checker.md 的映射表区间 |
| C（修改架构约定）| 仅更新 coding.md 中的对应约定行，以及 review_checks.py 中对应的检查 |
| E（重新配置 Hook）| 进入完整的 Step 4.5 子流程，生成或替换 post-tool-use-file-quality-check.sh 和 task-completed-quality-check.sh |

**3. 预览与确认**

展示将要变更的文件和具体内容差异，用户确认后写入。

**4. 补充完成**

输出变更摘要。

> 补充模式只更新受影响的文件，不会重新生成 VERSION、CLAUDE.md 或覆盖已有 Hook 文件。

---

## Step 5：预览与最终确认

（Mode A 和 Mode B 共用此步骤）

向用户展示将要生成的内容摘要：

1. **规范文件摘要**：每个 spec 文件的规则条数和关键条目，**标注每条来源**：
   - `[用户确认]` — Mode A 用户逐步确认的约定
   - `[代码库推断·高置信]` — Mode B 三方一致的提取结果
   - `[代码库推断·中置信]` — Mode B 多数一致，存在例外
   - `[代码库推断·待确认]` — Mode B 分歧项，用户尚未做出选择
2. **路径映射表**：完整的目录 → 规范文件对应关系
3. **脚本检查项**：`review_checks.py` 将包含的检查列表
4. **VERSION 初始值**：默认 `1.0`，用户可修改

> **[待确认] 条目必须在此步骤由用户做出决策后才能进入 Step 6。**
> 生成的规范文件不保留置信度标注，用户在此步骤完成最终确认后，所有条目均视为已确认规范。

用户确认后执行 Step 6。

---

## Step 6：生成所有产物

按以下顺序写入文件：

1. `VERSION` 文件
2. `CLAUDE.md`（根据以下要素自由生成内容）：
   - 项目名称和一句话功能描述
   - 技术栈列表
   - 目录结构说明
   - 任务管理规范（TASK_LIST.md 创建和状态流转规则）
   - 规范文件路径指引（指向 `.claude/rules/specifications/`）
   - testing.md 分区说明：`SPEC_START/END` 区间为强制规范（lint-checker 检验范围）；
     `PATTERNS_START/END` 区间为测试模式参考（test-writer / impl-worker 按上下文选用，不做检验）
3. `.claude/rules/specifications/coding.md`
4. `.claude/rules/specifications/testing.md`（结构见下方说明）
5. `.claude/rules/specifications/security.md`
6. `.claude/hooks/review_checks.py`（读取骨架模板，填入检查函数）
7. 复制 7 个 hook 文件到 `.claude/hooks/`
   - 复制后将 `block-test-modification.sh` 中的 `{{TEST_DIR}}` 替换为实际测试目录
7b. （若 Step 3.5 选择了 PostToolUse 规则）生成 `post-tool-use-file-quality-check.sh`
7c. （若 Step 3.5 选择了 TaskCompleted 规则）生成 `task-completed-quality-check.sh`
8. 生成 `.claude/settings.json`
9. **[必须执行]** 生成 6 个 agent 文件到 `.claude/agents/`
10. `.gitignore`（从模板原样复制）
11. `.env.example`（从安全规范中提取环境变量名）

---

### testing.md 结构说明

testing.md 分为两个区，用 HTML 注释标记边界（供 lint-checker 和 harness-init 补充模式定位）：

**规则区**（可被 script_check 检验的强制约定）：
```markdown
<!-- SPEC_START -->
## 测试规范

- 测试文件命名：test_{模块名}.py
- 每个测试函数只测一个行为
- 禁止在测试中 sleep()
- ...
<!-- SPEC_END -->
```

**测试模式参考区**（供 test-writer / impl-worker 按上下文选用，不强制检验）：
```markdown
<!-- PATTERNS_START -->
## 测试模式参考

> 本区内容为设计模式指引，不做规范检验。test-writer 和 impl-worker 应读取本区
> 内容后根据具体场景选用，而非机械照搬。本区由 harness-init 初始化后，
> test-writer 在生成复杂测试场景后可追加新模式。

### FastAPI 异常测试
使用 `raise_server_exceptions=False` 测试 5xx handler，
避免 TestClient 将服务端异常重新抛出到测试层。

### Celery 任务测试
三种模式及适用场景：
1. CELERY_TASK_ALWAYS_EAGER — 同步执行，适合端到端流程测试
2. unittest.mock.patch — mock task 对象，适合单元隔离测试；patch 作用于使用处而非定义处
3. celery.contrib.pytest fixture — 适合需要真实 worker 行为的集成测试

### pytest-asyncio
推荐 asyncio_mode = "auto"，避免每个异步测试函数手动标注 @pytest.mark.asyncio。
<!-- PATTERNS_END -->
```

> lint-checker 只检查 `SPEC_START / SPEC_END` 区间内的规则，不检查 `PATTERNS_START / PATTERNS_END` 区间。
> harness-init 补充模式追加规则时，同样只写入 SPEC 区间，不覆盖 PATTERNS 区间。

---

### 生成 agent 文件（Step 9）

对 6 个模板文件，依次 Read → 替换占位符 → Write 到 `.claude/agents/`：

| 模板文件 | 生成文件 | 特殊替换 |
|---------|---------|---------|
| `~/.claude/skills/harness-init/references/agents/test-writer-template.md` | `.claude/agents/test-writer.md` | `{SRC_DIR}`、`{TEST_DIR}` |
| `~/.claude/skills/harness-init/references/agents/impl-worker-template.md` | `.claude/agents/impl-worker.md` | `{SRC_DIR}`、`{TEST_DIR}`、路径映射表 |
| `~/.claude/skills/harness-init/references/agents/test-runner-template.md` | `.claude/agents/test-runner.md` | `{SRC_DIR}`、`{TEST_DIR}` |
| `~/.claude/skills/harness-init/references/agents/integration-test-template.md` | `.claude/agents/integration-test.md` | `{SRC_DIR}`、`{TEST_DIR}` |
| `~/.claude/skills/harness-init/references/agents/interface-test-template.md` | `.claude/agents/interface-test.md` | `{SRC_DIR}`、`{APP_DIR}` |
| `~/.claude/skills/harness-init/references/agents/lint-checker-template.md` | `.claude/agents/lint-checker.md` | `{SRC_DIR}`、路径映射表 |

占位符替换规则：
- `{SRC_DIR}`：Step 2 确认的源码根目录（如 `src`、`app`、`internal`）
- `{APP_DIR}`：同 `{SRC_DIR}`
- `{TEST_DIR}`：Step 2 确认的测试目录（如 `tests`、`__tests__`、`spec`）
- 路径映射表：将 `<!-- PATH_MAPPING_TABLE_START -->` 与 `<!-- PATH_MAPPING_TABLE_END -->` 之间的全部内容替换为 Step 2 生成的路径映射表，两行注释标记本身保留。
- 其余内容原样保留。

**agent 文件写入完成后，立即验证：**
```
.claude/agents/test-writer.md
.claude/agents/impl-worker.md
.claude/agents/test-runner.md
.claude/agents/integration-test.md
.claude/agents/interface-test.md
.claude/agents/lint-checker.md
```
若任何文件缺失，重新生成后再继续第 10 步。

---

### 生成 settings.json

```json
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Write|Edit|MultiEdit", "hooks": [{"type": "command", "command": "bash .claude/hooks/pre-tool-use-check-tasks.sh"}]}
    ],
    "PostToolUse": [
      {"matcher": "Write|Edit|MultiEdit", "hooks": [{"type": "command", "command": "bash .claude/hooks/post-tool-use-check-completion.sh"}]},
      // 若 Step 3.5 选择了 PostToolUse 规则，追加：
      {"matcher": "Write|Edit|MultiEdit", "hooks": [{"type": "command", "command": "bash .claude/hooks/post-tool-use-file-quality-check.sh"}]}
    ],
    "TaskStarted": [{"hooks": [{"type": "command", "command": "bash .claude/hooks/task-started-update-task-list.sh"}]}],
    "TaskCompleted": [
      {"hooks": [{"type": "command", "command": "bash .claude/hooks/task-completed-update-task-list.sh"}]},
      // 若 Step 3.5 选择了 TaskCompleted 规则，追加：
      {"hooks": [{"type": "command", "command": "bash .claude/hooks/task-completed-quality-check.sh"}]}
    ],
    "TaskCreated": [{"hooks": [{"type": "command", "command": "bash .claude/hooks/task-created-check-task-list.sh"}]}]
  },
  "permissions": {
    "allow": ["Read(**)", "Write(upgrade_plan/**)", "Write(.claude/rules/**)", "Write(.claude/agents/**)", "Write({SRC_DIR}/**)", "Bash(git *)", "Bash({TEST_CMD} *)", "Bash(python3 *)"]
  }
}
```

permissions 说明：
- `Write(.claude/rules/**)` 和 `Write(.claude/agents/**)` 允许 lint-checker 和 impl-worker 操作规范文件和 agent 定义；不使用 `Write(.claude/**)` 以避免 agent 在运行期间篡改 hooks 或 settings.json
- `Write({SRC_DIR}/**)` 根据 Step 2 确认的源码根目录调整
- `Bash({TEST_CMD} *)` 根据测试框架调整：pytest / npx jest / go test / php artisan test 等
- `Bash(python3 *)` 所有项目均保留，用于执行 `review_checks.py`
- agent 专用 hook 在各 agent 文件的 frontmatter 中注册，不在 settings.json 中注册

---

## 路径映射表生成逻辑

直接使用 Step 2 / Step B5 用户确认的职责结果生成映射表：

| 职责类型 | 对应规范文件 |
|---------|------------|
| 数据持久化 / ORM / Repository | `coding.md` + `security.md` |
| 缓存 / Session | `coding.md` + `security.md` |
| 消息队列 / Worker / Task | `coding.md` + `security.md` |
| AI / LLM / ML | `coding.md` + `security.md` |
| 配置加载 | `security.md` |
| 测试 | `testing.md` |
| `.env*` 文件 | `security.md` |
| 其余源码目录 | `coding.md` |

> 映射依据是职责，而非目录名称。同一目录兼有多个职责时取规范文件的并集。

---

## 参考文件

- `references/review_checks_template.py` — review_checks.py 接口骨架（Step 6 必须读取）
- `references/gitignore-template` — .gitignore 固定内容模板（Step 6 原样复制）
- `references/agents/test-writer-template.md` — test-writer agent 模板
- `references/agents/impl-worker-template.md` — impl-worker agent 模板
- `references/agents/test-runner-template.md` — test-runner agent 模板
- `references/agents/integration-test-template.md` — integration-test agent 模板
- `references/agents/interface-test-template.md` — interface-test agent 模板
- `references/agents/lint-checker-template.md` — lint-checker agent 模板
