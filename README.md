# ChartPilot

ChartPilot 是一个开源项目示例，帮助用户用自然语言探索 MySQL 业务数据。输入中文分析需求后，应用读取数据库结构，让 DeepSeek 生成只读查询，再根据查询到的真实数据生成 ECharts 配置，并在页面中渲染一张或多张图表。

> 项目仍在开发中。模型生成的查询和图表配置需要经过校验，但这不等于完整的生产级安全体系。公开部署前请阅读下方的安全说明。

## 功能

- 使用中文自然语言描述数据分析需求。
- 从 MySQL `information_schema` 读取表、列和外键结构。
- 根据数据库结构生成可直接使用的图表建议。
- 生成一条或多条只读 SQL 查询和对应的 ECharts 图表配置。
- 展示每张图表的查询结果数据及生成的 SQL。
- 使用完整 ECharts 包，支持其内置图表类型和 JSON 配置。
- 查询结果会限制行数；相同 SQL 会复用查询结果。
- 提供电商业务示例数据，便于本地试用。

## 技术栈

- [Nuxt 4](https://nuxt.com/)
- [Vue 3](https://vuejs.org/)
- [Vercel AI SDK](https://ai-sdk.dev/) 与 [DeepSeek Provider](https://ai-sdk.dev/providers/ai-sdk-providers/deepseek)
- [MySQL](https://www.mysql.com/) / [mysql2](https://github.com/sidorares/node-mysql2)
- [Apache ECharts](https://echarts.apache.org/)
- [Zod](https://zod.dev/) 和 [node-sql-parser](https://github.com/taozhi8833998/node-sql-parser)

## 环境要求

- Node.js：使用 Nuxt 支持的版本。当前项目建议 Node.js `^22.21.0`、`^24.11.0` 或更高兼容版本。
- pnpm：项目使用 pnpm，并通过 `pnpm-lock.yaml` 锁定依赖。
- MySQL：用于存放应用要分析的数据。
- API Key：服务端调用模型所需。

## 快速开始

### 1. 获取项目并安装依赖

```bash
git clone <repository-url>
cd chart-pilot
corepack pnpm install
```

### 2. 配置环境变量

复制示例文件并填写本地配置：

```bash
cp .env.example .env
```

编辑 `.env`：

```dotenv
NUXT_DEEPSEEK_API_KEY=your-deepseek-api-key

NUXT_DATABASE_DIALECT=mysql
NUXT_DATABASE_HOST=localhost
NUXT_DATABASE_PORT=3306
NUXT_DATABASE_USER=chart_pilot_readonly
NUXT_DATABASE_PASSWORD=your-database-password
NUXT_DATABASE_NAME=chart_pilot_ecommerce
```

`.env` 已加入 `.gitignore`，不要提交包含真实密钥或密码的环境文件。`.env.example` 只用于说明变量名，不放真实凭据。

| 变量 | 说明 | 默认值 |
| --- | --- | --- |
| `NUXT_API_KEY` | API Key | 无 |
| `NUXT_DATABASE_DIALECT` | 数据库类型；当前只支持 `mysql` | `mysql` |
| `NUXT_DATABASE_HOST` | MySQL 主机名 | `localhost` |
| `NUXT_DATABASE_PORT` | MySQL 端口 | `3306` |
| `NUXT_DATABASE_USER` | MySQL 用户名 | 无 |
| `NUXT_DATABASE_PASSWORD` | MySQL 密码 | 空 |
| `NUXT_DATABASE_NAME` | 要分析的数据库名 | 无 |

### 3. 初始化示例数据库（可选）

`sql/ecommerce.sql` 创建 `chart_pilot_ecommerce` 数据库，并建立及填充电商示例表。可以使用 MySQL CLI 执行：

```bash
mysql -u <mysql-admin-user> -p < sql/ecommerce.sql
```

该脚本包含 `CREATE DATABASE` 和 `USE`，应只在本地或测试数据库执行。不要把示例脚本中的数据库初始化操作直接用于已有生产数据库。

应用连接账号建议只拥有目标数据库的只读权限，以及读取 `information_schema` 所需的权限。项目的 SQL 校验和只读事务是纵深防御，不能替代数据库层最小权限配置。

### 4. 启动开发服务器

```bash
corepack pnpm dev
```

浏览器打开 <http://localhost:3000>。

### 5. 构建和预览

```bash
corepack pnpm build
corepack pnpm preview
```

## API

### `POST /api/chart`

根据自然语言需求生成图表。请求体：

```json
{
  "prompt": "统计今年每个月已支付订单的销售额，并用折线图展示趋势"
}
```

`prompt` 必须为 1 至 2000 个字符。成功时返回 `charts` 数组，每项包含标题、SQL、数据库实际返回的数据和 ECharts `option`：

```json
{
  "charts": [
    {
      "title": "月度销售额",
      "sql": "SELECT ... LIMIT 1000",
      "data": [
        {
          "month": "2026-01",
          "sales_amount": "1234.00"
        }
      ],
      "option": {
        "title": {
          "text": "月度销售额"
        },
        "series": []
      }
    }
  ]
}
```

应用最多生成 6 张图表；每条查询限制为最多 1000 行。图表类型由模型根据需求选择，不限定为固定的几类。

### `GET /api/chart/suggestions`

根据当前数据库结构生成 3 条图表建议。可用 `count` 请求 1 至 8 条：

```text
GET /api/chart/suggestions?count=5
```

每条建议包含标题、可直接提交的中文需求、推荐图表类型和理由。

## 工作流程

```mermaid
flowchart LR
    A[中文分析需求] --> B[读取 MySQL Schema]
    B --> C[DeepSeek 生成图表与 SQL 计划]
    C --> D[校验 SQL]
    D --> E[只读事务执行查询]
    E --> F[DeepSeek 根据真实结果生成 ECharts JSON]
    F --> G[前端渲染多张图表和数据]
```

## 安全与部署说明

- **API 尚未内置用户认证、授权或速率限制。** 不要将当前服务直接暴露给不可信的公网用户；接入适合项目的认证、授权和限流后再公开部署。
- 数据库账号应限制在指定数据库并使用只读权限。不能只依赖应用层 SQL 校验来保护数据。
- 服务端会检查模型生成的 SQL，拒绝非只读查询、未配置表/列、子查询、CTE、注释和多语句等不支持的结构，并通过只读事务执行查询。此规则有意限制 SQL 能力；复杂查询可能无法生成或会被拒绝。
- 模型返回的 ECharts `option` 是 JSON。项目不执行模型返回的 JavaScript 回调；纯 JSON 无法携带函数。应继续谨慎处理自定义配置和展示内容。
- 发送给模型的内容包括用户需求、数据库结构和查询结果。请确认这些信息符合所用模型服务的数据处理政策，不要连接包含未经授权敏感信息的数据源。
- `sql/ecommerce.sql` 是开发和演示用样例，不是生产数据库迁移方案。
- 密钥应保存在 `.env` 或部署平台的服务端环境变量中，切勿放入 `runtimeConfig.public`、前端代码或版本控制。

## 项目结构

```text
app/
  components/EChartCanvas.vue  ECharts 单图渲染组件
  pages/index.vue              自然语言输入与多图表结果页面
server/
  api/chart.post.ts            图表生成 API
  api/chart/suggestions.get.ts 图表建议 API
  utils/chart-generator.ts     SQL 校验、查询与图表生成流程
  utils/db.ts                  MySQL 连接、Schema 读取和只读查询
  utils/llm-connector.ts       DeepSeek 模型连接
sql/
  ecommerce.sql                电商示例数据库及数据
```

## 参与贡献

欢迎提交 Issue 和 Pull Request。建议在提交前：

1. 描述要解决的问题及复现步骤。
2. 保持改动聚焦，并说明对 API 或用户体验的影响。
3. 运行 `corepack pnpm build` 检查生产构建。
4. 不提交 `.env`、访问令牌、数据库转储或其他敏感数据。

## 许可证

当前仓库尚未包含许可证文件。发布或再分发前，项目维护者需要选择并添加适合的开源许可证；在许可证明确之前，请不要假定该项目已授予特定的使用、修改或分发权限。
