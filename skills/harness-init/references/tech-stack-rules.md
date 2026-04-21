# 技术栈规则知识库（人类可读版）

> 本文件供 Step 1 推荐选项参考，以及辅助理解规则背后的设计意图。
> **Step 6 生成文件时，请读取 `tech-stack-rules.yaml` 获取机器可解析的规则数据。**

---

## 语言

### Python

**编码规范**：Python 是强动态类型语言，缺少类型注解会让大型代码库难以维护。要求所有函数签名带类型注解（参数和返回值），并遵循 PEP 8 命名规范：类 PascalCase、函数/变量 snake_case、常量 UPPER_SNAKE_CASE。禁止通配符导入（`import *`），因为它会污染命名空间、使依赖关系不透明。单函数不超过 50 行，公共方法必须有 docstring，导入顺序遵循标准库 → 第三方 → 本地。

**测试规范**：测试命名格式 `test_<方法>_<场景>_<预期结果>`，便于直接从函数名理解测试意图。单元测试必须 Mock 所有外部依赖（LLM、数据库、HTTP），集成测试标记 `@pytest.mark.integration` 以便 CI 分层运行。单元测试套件须在 10 秒内完成。

**脚本检查**：检测 `print()` 调用（应使用日志库）。

**推荐目录结构**：
```
src/core/     — 核心业务逻辑
src/api/      — 接入层（路由/控制器）
src/db/       — 数据持久化
src/config/   — 配置加载
src/utils/    — 工具函数
src/exceptions.py — 统一异常定义
tests/unit/        — 单元测试
tests/integration/ — 集成测试
```

---

### TypeScript / Node.js

**编码规范**：禁止使用 `any` 类型——它等同于关掉了 TypeScript 的核心价值。优先使用 `interface` 定义对象结构（比 type alias 更易扩展），启用 `strict` 模式。命名规范：类 PascalCase、函数/变量 camelCase、常量 UPPER_SNAKE_CASE，禁止通配符导入。

**测试规范**：测试文件命名 `*.spec.ts` 或 `*.test.ts`，单元测试用 `jest.mock()` 隔离外部依赖，集成测试标记 `@group integration`。

**脚本检查**：检测 `console.log/warn/error/debug` 调用（应使用日志库），检测 `: any` 类型使用。

**推荐目录结构**：
```
src/controllers/  — 路由控制器
src/services/     — 业务服务
src/repositories/ — 数据访问
src/config/       — 配置
src/utils/        — 工具
src/errors/       — 统一错误定义
tests/unit/       — 单元测试
tests/integration/— 集成测试
```

---

### Go

**编码规范**：Go 的错误处理是显式的——禁止 `_ = err` 忽略错误，每个 error 必须处理或向上传递。公共函数必须有 godoc 格式注释。包名小写单词，不含下划线。接口定义在使用方（依赖倒置原则），而非在实现方，这是 Go 惯用法。

**测试规范**：测试函数命名 `TestXxx_场景_预期`，用 `testify/assert` 做断言，集成测试用 `//go:build integration` 构建标签分离。

**脚本检查**：检测 `fmt.Println/Printf` 调用（应使用日志库），检测 `_ = err` 错误忽略。

**推荐目录结构**：
```
cmd/                  — 程序入口
internal/handler/     — HTTP 处理器
internal/service/     — 业务逻辑
internal/repository/  — 数据访问
internal/config/      — 配置
internal/errors/      — 错误定义
pkg/                  — 可对外暴露的工具包
tests/                — 测试（含 integration 子目录）
```

---

### Java

**编码规范**：类 PascalCase、方法/变量 camelCase、常量 UPPER_SNAKE_CASE，公共方法必须有 Javadoc。禁止 `System.out.println`，业务异常必须继承统一基类（如 `BaseException`），便于全局异常处理器统一捕获。

**测试规范**：测试类命名 `XxxTest.java`，用 `@MockBean` 或 `Mockito.mock()` 隔离依赖，集成测试标记 `@SpringBootTest`。

**脚本检查**：检测 `System.out.println` 调用。

**推荐目录结构**：
```
src/main/java/{package}/controller/ — REST 控制器
src/main/java/{package}/service/    — 业务服务
src/main/java/{package}/repository/ — 数据访问
src/main/java/{package}/config/     — 配置类
src/main/java/{package}/exception/  — 统一异常
src/main/java/{package}/util/       — 工具类
src/test/java/{package}/            — 测试
```

---

## 日志库

### loguru（Python）

统一用 `logger.info() / logger.debug() / logger.warning() / logger.error()`，禁止 `print()`。日志初始化在应用入口配置，禁止在模块内重复配置。

### winston（Node.js）

禁止 `console.log/warn/error`，统一使用 `logger` 实例。logger 在 `src/logger.ts` 中统一创建和导出，其他模块 import 使用。

### zerolog（Go）

禁止 `fmt.Println/Printf`，统一使用 `log.Info().Msg()` 等 zerolog 链式方法。logger 实例通过 context 传递，禁止全局变量（便于测试替换）。

### slf4j / log4j（Java）

禁止 `System.out.println`，每个类声明 `private static final Logger log = LoggerFactory.getLogger(Xxx.class)`。

---

## 数据库

### MySQL / PostgreSQL

数据库凭证（host/user/password）禁止硬编码在代码中，必须从环境变量 `DB_HOST / DB_USER / DB_PASSWORD / DB_NAME` 读取。生产数据库禁止使用 root 账号（最小权限原则）。

**脚本检查**：检测代码中疑似硬编码的数据库连接串（如 `mysql://user:pass@`）。

### MongoDB

`MONGO_URI` 必须从环境变量读取，禁止硬编码连接串。

**脚本检查**：检测 `mongodb://` 后跟非变量引用的字符串。

---

## 缓存

### Redis

Redis 客户端必须通过统一工厂方法获取，禁止在业务代码中直接 `new Redis()`，这样便于测试替换和连接池管理。`REDIS_URL / REDIS_PASSWORD` 必须从环境变量读取。

**脚本检查**：检测 `redis://.*:.*@` 格式的硬编码连接串，以及 `REDIS_PASSWORD = "..."` 格式的硬编码密码。

---

## 消息队列

### RabbitMQ

AMQP 连接串（含 user/password/host）禁止硬编码，`RABBITMQ_URL` 必须从环境变量读取。

**脚本检查**：检测 `amqp://` 后跟非变量引用的字符串。

### Kafka

Kafka broker 地址和认证信息必须从环境变量读取，禁止硬编码 `bootstrap.servers`。

**脚本检查**：检测 `bootstrap.servers` 后跟 IP 地址或域名的硬编码配置。

---

## ORM / 数据访问

### SQLAlchemy / Peewee（Python）

禁止裸 SQL 字符串（`execute("SELECT ...")`），数据库操作统一通过 Repository 层，Service 层不直接调用 ORM。禁止在循环中执行数据库查询（N+1 问题会导致性能灾难）。

**脚本检查**：检测 `execute("SELECT` 和 `cursor.execute(` 等裸 SQL 模式。

### Prisma（TypeScript）

禁止直接使用 `$queryRaw` 执行裸 SQL（除非有充分理由并注释说明）。`PrismaClient` 全局单例，禁止在请求处理中 `new PrismaClient()`（否则每次请求都会创建新连接池）。

**脚本检查**：检测 `$queryRaw` 调用。

### GORM（Go）

禁止 `db.Raw()` 或 `db.Exec()` 裸 SQL，使用 GORM 链式方法。DB 实例通过依赖注入传递，禁止全局变量。

**脚本检查**：检测 `db.Raw(` 和 `db.Exec(` 调用。

---

## Web 框架

> 以下为推荐默认约定，属于项目工程规范而非 Harness 强制要求，团队可按实际情况调整。

### Express（TypeScript/Node.js）

路由处理函数必须有统一错误处理中间件，禁止在路由内直接 `res.send()` 裸字符串，统一返回 JSON 格式响应。

**脚本检查**：检测在路由文件中使用 `res.send(` 而非 `res.json(` 的情况。

### Gin（Go）

路由分组应通过 `gin.RouterGroup` 组织，中间件注册在分组级而非全局（避免不必要的拦截）。Handler 函数只做 HTTP 协议层逻辑，业务逻辑下沉到 service 层。

### FastAPI（Python）

路由函数使用 Pydantic 模型声明请求/响应类型，禁止直接返回 `dict`（绕过类型校验）。异步路由函数必须使用 `async def`。

### Spring Boot（Java/Kotlin）

Controller 只做请求映射和参数绑定，禁止在 Controller 中写业务逻辑。依赖注入统一使用构造函数注入，禁止字段注入（`@Autowired` 字段级）。

---

## 测试框架

> 以下为推荐默认约定，属于项目工程规范而非 Harness 强制要求，团队可按实际情况调整。

### Jest（TypeScript/JavaScript）

测试文件命名 `*.test.ts` 或 `*.spec.ts`，与被测模块同目录。外部依赖使用 `jest.mock()` 隔离，不发起真实网络请求。单元测试目标覆盖率：语句覆盖率 >= 80%。

### pytest（Python）

测试函数命名格式：`test_<被测方法>_<场景>_<预期结果>`。单元测试必须 Mock 所有外部依赖（LLM 调用、数据库、网络请求）。集成测试使用 `@pytest.mark.integration` 标记，默认运行时跳过。

---

## 配置管理

> 以下为推荐默认约定，属于项目工程规范而非 Harness 强制要求，团队可按实际情况调整。

### python-dotenv / viper / Spring Config / dotenv

统一从环境变量或配置文件读取，通过项目的统一配置模块暴露，禁止在业务代码中直接调用 `os.getenv()` 或 `process.env`。

**脚本检查（Python）**：检测业务代码（排除 `settings.py`、`config.py`、`*/config/*.py`）中直接调用 `os.getenv(` 的情况。

**脚本检查（TypeScript）**：检测业务代码（排除 `*/config/*.ts`）中直接访问 `process.env[` 的情况。

**脚本检查（Go）**：检测业务代码（排除 `*/config/*.go`）中直接调用 `viper.Get*(`、`os.Getenv(` 的情况。

---

## 基础设施

### Docker

Dockerfile 禁止将 `.env` 文件 `COPY` 进镜像（包含真实密钥）。禁止在 `ENV` 指令中设置真实密钥，密钥应在运行时通过 `--env-file` 或 K8s Secret 注入。容器不得以 root 用户运行（使用 `USER` 指令）。

**脚本检查**：检测 Dockerfile 中 `ENV` 设置含 KEY/SECRET/PASSWORD/TOKEN 关键字的变量。

### Kubernetes

禁止在代码中硬编码 K8s Namespace / ClusterIP / ServiceAccount Token。密钥必须使用 K8s Secret 并通过环境变量挂载。禁止硬编码 `kubectl` 命令的 `--context` 参数。

**脚本检查**：检测 `.svc.cluster.local` 形式的硬编码 Service 地址。

---

## 通用安全规则（所有项目）

无论使用何种技术栈，以下规则适用于所有项目：

- 禁止在代码中硬编码任何 API Key / Secret / Token
- `.env` 文件禁止提交 git，使用 `.env.example` 作为模板
- 敏感配置统一从环境变量读取，通过配置模块（`config/settings`）统一管理

**脚本检查**：
- 检测形如 `API_KEY = "abc123..."` 的长字符串赋值（疑似硬编码密钥）
- 检测 `.env` 文件中包含真实值的配置行（防止意外暂存）
