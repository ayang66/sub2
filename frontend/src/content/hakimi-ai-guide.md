# Codex 与 Claude Code 接入哈基米中转站

本文介绍如何在 Codex、Claude Code 和 CC Switch 中使用哈基米中转站。开始前，请先在控制台的 **API 密钥** 页面创建自己的 `sk-` 密钥。

## 快速信息

| 项目 | 内容 |
|---|---|
| OpenAI 兼容基址 | `{{OPENAI_BASE_URL}}` |
| Claude Code 基址 | `{{ANTHROPIC_BASE_URL}}` |
| Codex 推荐模型 | `gpt-5.5` |
| Claude 推荐模型 | `claude-opus-4-7` / `claude-sonnet-4-6` |
| 认证方式 | 哈基米中转站 API Key |

> 安装或配置遇到问题，可添加客服微信 `15137315710`，新客可领取五元额度。

## 一、推荐使用方式

- **Codex 桌面客户端**：适合日常开发、代码审查和多任务处理。
- **Cursor / VS Code 安装 Codex 扩展**：适合在编辑器中直接调用 Codex。
- **Codex CLI**：适合在终端中工作。
- **CC Switch**：适合管理 Codex、Claude Code、Gemini CLI 等工具的配置。

Codex 桌面客户端、CLI、Cursor 和 VS Code 扩展通常共用同一套本地配置文件。

## 二、Codex 配置文件位置

Codex 的用户配置目录通常是 `.codex`：

| 环境 | 配置目录 |
|---|---|
| Windows 原生 | `C:\Users\你的用户名\.codex` |
| macOS | `/Users/你的用户名/.codex` |
| Linux | `/home/你的用户名/.codex` |
| WSL | `/home/你的Linux用户名/.codex` |

Windows 的 WSL 与 Windows 原生配置目录不是同一个。可在资源管理器中通过下面的路径打开 WSL 配置目录：

```text
\\wsl$\Ubuntu\home\你的Linux用户名\.codex
```

如果 `.codex` 不存在，可以手动创建。然后在目录中创建或编辑 `auth.json` 和 `config.toml`。

## 三、配置 Codex

### 1. auth.json

把 `sk-xxx` 替换为你在哈基米中转站创建的 API Key。

```json
{
  "OPENAI_API_KEY": "sk-xxx"
}
```

JSON 文件不能写注释、不能使用中文引号，也不要把 API Key 提交到代码仓库。

### 2. config.toml

下面是可直接使用的完整配置：

```toml
cli_auth_credentials_store = "file"

disable_response_storage = true
model = "gpt-5.5"
model_provider = "hakimi"
model_reasoning_effort = "xhigh"
personality = "friendly"

[model_providers.hakimi]
name = "hakimi"
base_url = "{{OPENAI_BASE_URL}}"
requires_openai_auth = true
wire_api = "responses"
```

保存后重启 Codex、Cursor 或 VS Code。如果提示 `disable_response_storage` 是未知配置项，可以删除该行，不影响接口接入。

## 四、推理等级

`model_reasoning_effort` 用于控制推理强度：

```toml
model_reasoning_effort = "xhigh"
model_reasoning_effort = "high"
model_reasoning_effort = "medium"
model_reasoning_effort = "low"
model_reasoning_effort = "minimal"
```

- 日常开发：推荐 `medium` 或 `high`。
- 复杂 Bug、架构分析和长任务：推荐 `xhigh`。
- 简单问答和轻量修改：推荐 `low` 或 `minimal`。

`xhigh` 是否生效取决于当前模型和上游服务是否支持。

## 五、Windows 一键安装

在侧栏打开 **AI 工具安装**，可以直接下载：

- Codex Windows x64 桌面安装器
- Claude Code 中文安装工具
- CC Switch Windows MSI

Codex 安装器支持自定义安装目录，并可写入模型供应商、接口基址、API Key 和模型名称。

## 六、Claude Code 一键安装与配置

Windows 10 或更高版本可以使用 `lxistired/claude-code-cn-installer`：

1. 下载并解压项目 ZIP。
2. 右键 `一键安装.bat`，选择“以管理员身份运行”。
3. 安装脚本询问智谱模型时选择“暂时跳过”。
4. 安装完成后运行 `配置API.bat`。
5. 选择菜单 4“自定义 Anthropic 兼容 API”。
6. Base URL 填写 `{{ANTHROPIC_BASE_URL}}`，API Key 填写自己的 `sk-` 密钥。

也可以手动创建或编辑 `.claude/settings.json`：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "{{ANTHROPIC_BASE_URL}}",
    "ANTHROPIC_API_KEY": "sk-xxx",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4-6",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-sonnet-4-6"
  }
}
```

Claude Code 使用 Anthropic Messages 协议，请注意：

- Base URL 不要添加 `/v1`，客户端会自动请求 `/v1/messages`。
- API Key 所属分组必须能够访问所填写的 Claude 模型。
- 模型名称应以本站模型广场当前显示的名称为准。

## 七、安装 Codex CLI

### 官方安装脚本

macOS / Linux：

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

Windows PowerShell：

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
```

### npm 安装

建议使用 Node.js 18+，推荐 Node.js 22 LTS：

```bash
npm install -g @openai/codex
codex --version
```

Linux 遇到权限问题时可使用：

```bash
sudo npm install -g @openai/codex
```

## 八、启动 Codex

进入项目目录并启动：

```bash
cd /你的项目路径
codex
```

首次启动后可输入：

```text
请帮我写一个 Node.js 的 hello world 示例
```

如果能够正常返回，且本站使用记录中出现对应调用，说明配置成功。

## 九、常见命令

| 命令 | 描述 |
|---|---|
| `/model` | 切换模型和推理级别 |
| `/permissions` | 调整权限模式 |
| `/init` | 生成 `AGENTS.md` 项目指令 |
| `/status` | 查看会话配置、模型和上下文使用情况 |
| `/diff` | 查看当前项目改动 |
| `/review` | 审查当前改动 |
| `/clear` | 清空当前会话 |
| `/new` | 开启新会话 |
| `/compact` | 压缩长对话上下文 |
| `/mcp` | 查看 MCP 工具状态 |
| `/quit` | 退出 Codex CLI |

## 十、常见问题

### 配置后不生效

确认编辑的是当前运行环境对应的 `.codex`。Windows 原生与 WSL 的配置目录不同，修改后需要重启客户端或编辑器。

### 提示模型不存在

检查模型名称是否在本站模型广场中可用，并确认 API Key 所属分组有权限访问。

### 提示 401 或认证失败

检查 `auth.json` 中的 API Key 是否正确，JSON 是否有效，以及 Key 是否被禁用或过期。

### 请求失败或连接失败

Codex 的 `base_url` 应为：

```text
{{OPENAI_BASE_URL}}
```

Claude Code 的 `ANTHROPIC_BASE_URL` 应为：

```text
{{ANTHROPIC_BASE_URL}}
```

## 十一、官方参考

- [Codex 官方文档](https://developers.openai.com/codex)
- [Codex 快速开始](https://developers.openai.com/codex/quickstart)
- [Codex 配置参考](https://developers.openai.com/codex/config-reference)
- [CC Switch 官网](https://ccswitch.io)
- [CC Switch GitHub Releases](https://github.com/farion1231/cc-switch/releases)
- [Claude Code 中文安装工具](https://github.com/lxistired/claude-code-cn-installer)
