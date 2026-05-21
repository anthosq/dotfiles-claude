# dotfiles-claude

个人 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 配置：settings、hooks、skills 与 agents。

支持 **Windows**（Git Bash + Windows Terminal）和 **Linux / macOS**。

---

## 安装

### Windows

前置依赖：[Git for Windows](https://git-scm.com/download/win)（提供 `bash`）、[`jq`](https://jqlang.github.io/jq/)、[`uv`](https://docs.astral.sh/uv/)。

```powershell
git clone git@github.com:anthosq/dotfiles-claude.git
cd dotfiles-claude
powershell -ExecutionPolicy Bypass -File setup-windows.ps1
```

脚本会自动：检查前置依赖，将现有 `~/.claude` 完整备份至 `~/.claude-backups/<时间戳>/`，复制所有配置文件，并对关键 hooks 执行验证。安装完成后重启 Claude Code 即可生效。

**还原备份：**

```powershell
# 还原最新备份（交互确认）
powershell -ExecutionPolicy Bypass -File restore-windows.ps1

# 还原指定备份
powershell -ExecutionPolicy Bypass -File restore-windows.ps1 -BackupName 20260522-013330
```

### Linux / macOS

前置依赖：`bash`、`jq`、`uv`。

```bash
curl -fsSL https://raw.githubusercontent.com/anthosq/dotfiles-claude/main/setup.sh | bash
```

脚本幂等，可随时重跑以拉取更新。

---

## 生产工作流（SOP）

### 开始任务

在项目目录打开 Claude Code 会话。`inject-git-status` 和 `inject-time` hooks 会在每条消息中自动注入当前分支状态与时间戳。

对于**长时间或高计算量的任务**（构建、爬取、训练、大规模重构），先加载 babysit skill：

```
/babysit
```

然后描述任务。Babysit 会在受监督的后台运行器中执行，带有内存/CPU 上限和卡死检测。

### 让 hint hooks 引导你

Hooks 会自动识别模式并建议合适的工具：

- 消息中出现 URL → 提示加载 `/read-url` 或 `/jina-ai`
- 询问 Claude Code 功能 → 自动启动 `claude-code-guide` agent
- 任务涉及大量文件扫描 → 提示 fork 子 agent
- 检测到长时间任务 → 提示加载 `/babysit`

也可随时手动加载 skill：

```
/jina-ai       # 网页搜索、学术论文
/context7      # 编码前获取最新库文档
/review        # 大改动后进行代码审查
/memory-add    # 保存持久化事实或经验教训
```

### 任务中途：记忆与召回

`recall-reminder` hook 会定期提醒 Claude 在开始任务前查阅长期记忆页面。若任务中出现值得保留的事实、纠错或经验：

```
记住：在 Windows 上目录同步要用 robocopy 而不是 Copy-Item
```

Claude 会调用 `/memory-add` 将其追加到暂存记忆。

### 代码审查与审计

完成一批重要修改后，触发审查：

```
/review
```

这会启动一个专注的 agent，检查 bug、AI slop 模式和文档问题，并以交互方式提出修复建议。

**审计 stop hook** 在 Claude 完成涉及多次文件编辑的会话时自动触发。它运行一个无头的 `claude-opus-4-6` 实例，审查所有改动文件并在发现问题时上报——无需手动触发。

查看审计历史：

```bash
~/.claude/hooks/audit-edits.py stats
```

### 并行与多会话协作

使用 `claude-dm` skill 协调多个 Claude Code 会话（如每个子项目一个会话，或主控 session 调度多个工作 session）：

```
/claude-dm
```

### 收尾

长会话结束前，确认审计 hook 已触发（`Stop` 事件自动执行）。若会话中有架构决策或解决了棘手的 bug：

```
记住：<经验教训>
```

---

## 包含内容

### settings.json

- **`permissions.defaultMode: "bypassPermissions"`** — 无确认弹窗；安全性由 hooks 保障
- **`autoScrollEnabled: true`** — 输出流式自动滚动
- 审计 hook 环境变量（`AUDIT_BACKEND`、`AUDIT_CLAUDE_MODEL`）

### hooks/ — 40 个 hooks

Hooks 覆盖 `PreToolUse`、`PostToolUse`、`UserPromptSubmit`、`Stop`、`PostCompact` 五个事件。

**安全守卫**（`no-*.sh`）——软性拦截，附显式 bypass 逃生口：

| Hook | 拦截内容 |
|---|---|
| `no-dangerous-ops` | mkfs、dd、分区操作、写入 `/dev` `/sys` `/boot` |
| `no-destructive-git` | `git push --force`、`git clean -f`、删除分支 |
| `no-git-amend` | `git commit --amend` |
| `no-heredoc` | heredoc 写文件（改用 Write 工具） |
| `no-head-read` | `head`/`tail` 读文件（改用 Read 工具） |
| `no-head-tail-pipe` | 管道 `head`/`tail` 截断 |
| `no-devnull-redirect` | `2>/dev/null` 压制错误 |
| `no-sed-print` | `sed` 写文件 |
| `no-pip-npm` | `pip install` / `npm install`（改用 `uv`/`pnpm`） |
| `no-background-ampersand` | 裸 `&` 后台任务 |
| `no-cat-write` | `cat >` 写文件 |
| `no-multi-question` | 一次向用户提多个问题 |
| `no-schedule-wakeup-deadzone` | 在清醒时段设置定时唤醒 |
| `no-worktree-team` | 不安全的 worktree/team 操作 |

所有守卫均为软性提醒。`# BYPASS_*_CHECK` 标记允许 Claude 在确有需要时绕过特定守卫——防的是意外，不是刻意行为。

**上下文注入器**（每条消息均触发）：
- `inject-time.sh` — 当前时间
- `inject-git-status.sh` — 工作区状态
- `inject-system-load.sh` — CPU/内存负载

**提示 hooks**（模式匹配触发 skill 建议）：
- `hint-skill-babysit`、`hint-skill-jina-ai`、`hint-skill-read-url`
- `hint-agent-claude-code-guide`、`hint-fork-on-bloat`

**其他 hooks**：
- `recall-reminder` / `recall-reminder-reset` — 定期记忆召回提醒
- `prefer-uv-run`、`python-unbuffered` — 强制 Python 工具链规范
- `audit-edits.py` — 自动审计改动的 stop hook
- `cache-keepalive-hint`、`compact-bump`、`explore-model-sonnet` 等

### skills/ — 52 个 skill 包

| Skill | 用途 |
|---|---|
| `babysit` | 带资源上限的长时间后台任务监督运行 |
| `jina-ai` | 网页搜索、学术论文、PDF 提取、向量嵌入 |
| `read-url` | 从任意网页提取干净 Markdown |
| `context7` | 编码前获取第三方库的最新文档 |
| `chrome-cdp` | 通过用户真实 Chrome 会话进行有头浏览器自动化 |
| `agent-browser` | UI 测试和截图用的无头浏览器 |
| `canvas-design` | 生成 PNG/PDF 视觉设计产物 |
| `evolink-image` | AI 图像生成与编辑 |
| `frontend-design` | 构建有设计感的 Web UI，避免 AI slop |
| `claude-dm` | 多个 Claude Code 会话间的点对点消息传递 |
| `tmux` | 在 tmux 窗格中运行交互式 TUI/REPL |
| `memory-add` | 向长期记忆追加持久化事实或经验 |
| `review` | 检查 bug、AI slop 和文档的代码审查 |
| `pdf` | 读取、提取、合并、注释 PDF |
| `docx` / `pptx` | 创建和编辑 Word / PowerPoint 文档 |
| `openscad` | 生成并渲染 3D 模型 |
| `shader-dev` | GLSL 着色器——光线步进、SDF、粒子系统 |
| `zhihu-post` | 面向知乎的中文技术博客撰写 |
| `better-translate` | 自然人声的英→中翻译 |
| `skill-creator` | 创建、编辑和基准测试新 skill |
| `grep-app` | 在公开 GitHub 仓库中搜索代码 |
| `repo-cache` | 本地克隆并浏览远程 git 仓库 |
| `fresh-arch` | 从需求出发的架构设计 |

完整列表：`ls ~/.claude/skills/`

### agents/ — 5 个专用 agent

| Agent | 职责 |
|---|---|
| `audit-fresh-eye` | 以全新视角独立审计代码/文档 |
| `web-researcher` | 结合 Jina AI 和 WebSearch 的深度网络研究 |
| `claude-code-guide` | 解答 Claude Code 功能和 API 相关问题 |
| `code-review` | 专注代码质量的审查 |
| `doc-review` | 文档正确性与清晰度审查 |

### CLAUDE.md

注入每个会话的全局规则：偏好 CLI 工具（`rg`、`fd`、`eza`、`uv`、`pnpm`、`just`），编码纪律（先冒烟测试、先调查再下结论、不打补丁），输出风格（一句话结论，≤40 词），自动化程度等级（low / medium / high），以及长期记忆惯例。

---

## 审计 Hook

`Stop` hook 在涉及文件编辑的会话结束后自动触发，审查所有改动的正确性和 AI slop 模式。

审查者是运行 **claude-opus-4-6** 的无头 `claude` 实例。发现问题时会向主会话上报。

在 `settings.json` 中配置：

```json
"AUDIT_BACKEND": "claude",     // none | claude
"AUDIT_CLAUDE_MODEL": "claude-opus-4-6"
```

---

## 默认值说明

**`bypassPermissions`** — Claude 无需确认弹窗即可操作。安全层是上面的 hook 守卫。没有真正判断力支撑的确认弹窗只是注意力税；守卫拦截的才是真正要命的意外。

恢复标准确认弹窗：在 `settings.json` 中将 `"defaultMode"` 改为 `"default"`。

**记忆系统** — `memory/` 存放长期记忆页面、暂存缓冲区和常见陷阱条目。Claude 在每次任务前读取相关页面，通过 `/memory-add` 追加新内容。维护说明见 `memory/BUILD.md`。

**Windows 兼容性** — 所有 hooks 运行在 Git Bash（MSYS2）中。当 `grep -P` 不可用时，PCRE 模式通过 `hooks/lib/pcre-compat.sh` 的 perl shim 回退支持。`audit-edits.py` 使用跨平台的锁文件和临时目录策略。
