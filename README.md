# Overleaf Codex Workflow

[中文](#中文) · [English](#english)

## 中文

让 Codex 在本地修改 Overleaf 论文，经过审阅后同步回去。提供 Agent Skill 和独立 CLI，支持当前 `main` 与旧版 `master` 项目。

```text
Overleaf → pull → 本地编辑与验证 → push 预检 → 确认 → Overleaf
```

### 安装与配置

需要 Git、Bash，以及支持 Git integration 的 Overleaf 项目；使用 Skill 还需要可执行本地命令的 Codex 环境（桌面端、CLI 或 IDE）。

```bash
git clone https://github.com/abaichuan1017/overleaf-codex-workflow.git
cd overleaf-codex-workflow
./install.sh
```

默认安装到 `~/.agents/skills/overleaf-codex-workflow`，并创建 `~/.local/bin/overleaf-codex`。把 `~/.local/bin` 加入 `PATH`，然后重启 Codex 会话以加载 Skill。

```bash
overleaf-codex setup https://www.overleaf.com/project/PROJECT_ID ~/papers/my-paper
cd ~/papers/my-paper
```

也可以传入项目 ID 或 Overleaf 提供的 Git URL。Git 首次认证时，用户名填 `git`，密码填 Overleaf Git token；在本机 Git 提示框输入，凭据交给可信的 Git credential helper，**不要粘贴到聊天或 URL**。

### 日常使用

在论文目录运行：

```bash
overleaf-codex pull
# 让 Codex 按要求修改论文，并运行项目现有的编译/检查命令。
overleaf-codex status
overleaf-codex push                # 暂存全部非忽略改动，展示待上传内容；不会提交或上传
```

审阅 `git diff --cached` 以及预检列出的已有提交，确认后执行：

```bash
overleaf-codex push --confirm "Revise introduction"
```

在 Codex 中也可直接说：

```text
使用 $overleaf-codex-workflow 拉取最新论文。
把 Introduction 第二段写清楚，保持引用和实验数字不变，编译检查后给我看差异。
```

之后明确要求上传；Skill 会展示预检结果并等待对该版本的确认。已确认的同一版本无需重复批准。普通论文编辑请求不会触发上传。

### 保护与升级

- `pull` 只接受干净工作区和 fast-forward；不自动 stash、解决分歧或改写历史，不 force-push。
- 推送前复核远端、分支、HEAD、暂存内容和工作区；审阅后有变化会拒绝上传。
- 项目指令默认保存在本地，通过 `.git/info/exclude` 排除。若已有被跟踪的 `AGENTS.md`，先复制其中规则到本地 override；**已有被跟踪的文件不会因 exclude 而停止上传**。
- 重新运行安装会保留旧 Skill，备份路径会打印出来。更新项目指令用 `overleaf-codex init-agents`，重启会话生效。override 中复制的项目规则需随原文件变化手动核对。
- 仅为某个仓库安装：`./install.sh --repo /path/to/repository`，不改全局 CLI；卸载用 `./uninstall.sh --repo /path/to/repository`。用户级卸载用 `./uninstall.sh`，保留论文和安装备份。

这是文件与 Git 工作流，不绑定 GPT 型号、不调用模型 API，也不需要 OpenAI API key。新版优化聚焦精简上下文、按需读取说明和保留可验证的同步检查。

## English

Edit an Overleaf manuscript locally with Codex, then review and synchronize it. Includes an Agent Skill and standalone CLI; detects current `main` and legacy `master` projects.

Requires Git, Bash, an Overleaf project with Git integration, and a Codex environment with local command execution for Skill use.

```bash
git clone https://github.com/abaichuan1017/overleaf-codex-workflow.git
cd overleaf-codex-workflow
./install.sh
# Add ~/.local/bin to PATH and restart your Codex session.
overleaf-codex setup https://www.overleaf.com/project/PROJECT_ID ~/papers/my-paper
cd ~/papers/my-paper
overleaf-codex pull
# Edit and validate with the manuscript's existing build command.
overleaf-codex status
overleaf-codex push
# Review git diff --cached and any outgoing commits before confirming:
overleaf-codex push --confirm "Revise introduction"
```

You can invoke `$overleaf-codex-workflow` in Codex instead. An upload requires an explicit request and approval of the reviewed state; editing alone does not authorize it. Enter Overleaf credentials directly into Git's prompt (username `git`, password your Git token), using a trusted credential helper. Never put tokens in chat or URLs.

Pulls require a clean tree and fast-forward history. Uploads recheck the endpoint, branch, HEAD, staged content, and worktree. No automatic stashing, divergent merges, history rewriting, or force-push. Generated guidance stays local; tracked files remain tracked. A new override copies existing project rules because Codex reads an override instead of its sibling `AGENTS.md`; reconcile copied rules when the original changes.

Reinstall to upgrade; the previous Skill is backed up. Run `overleaf-codex init-agents` to refresh the managed instruction block and restart Codex. `./install.sh --repo /path/to/repository` installs locally without changing the global CLI. Uninstall with `./uninstall.sh` or `./uninstall.sh --repo /path/to/repository`; manuscripts and upgrade backups are preserved.

The workflow does not select a GPT model or call a model API. Its current Codex adaptation uses concise instructions, on-demand references, and deterministic Git checks.

## Commands / 命令

```text
setup <project-url|git-url|project-id> [directory]
pull
status
push
push --confirm [commit message]
init-agents
doctor
```

Detailed behavior / 详细行为：[workflow.md](skill/overleaf-codex-workflow/references/workflow.md)

## Tests / 测试

```bash
bash tests/run.sh
```

Tests use temporary local Git remotes and isolated installation directories. They cover setup, editing, review, upload, collaborator changes, both branch names, instruction preservation, linked worktrees, and install/upgrade/uninstall. CI runs on Linux and macOS. These checks do not establish live Overleaf authentication, remote compilation, or a specific GPT model's behavior.

## References / 依据

- [OpenAI: concise skills and project instructions](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra)
- [Codex Skills](https://learn.chatgpt.com/docs/build-skills) · [AGENTS.md precedence](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Overleaf Git integration and main/master compatibility](https://docs.overleaf.com/integrations-and-add-ons/git-integration-and-github-synchronization/git-integration)

[MIT License](LICENSE) · [Security](SECURITY.md) · [Contributing](CONTRIBUTING.md)
