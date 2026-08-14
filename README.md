# overleaf-codex-workflow

**中文 | [English](#english)**

一个轻量、保守、安全优先的 **Codex Agent Skill**，用于一次配置后管理完整的 **Overleaf ↔ Git ↔ Codex** 论文工作流。

它不负责“替你写论文”，而是负责论文仓库生命周期：拉取 Overleaf 最新版本、生成 Codex 项目指令、让 Codex 在本地修改 LaTeX，并且只有在你明确要求后才经过检查、确认、提交并推送回 Overleaf。

```text
Overleaf
   │
   │  pull（仅 fast-forward）
   ▼
本地 Git 仓库  ←→  Codex 在这里修改 LaTeX
   │
   │  push 预检 → 人工确认 → commit + push
   ▼
Overleaf
```

## 中文

### 功能

- **一次配置** Overleaf 项目，之后重复使用。
- 支持输入 Overleaf 项目 URL、Git URL 或 project ID。
- 自动 clone 到本地，并将远端统一命名为 `overleaf`。
- 自动创建项目级 Codex 指令：通常是 `AGENTS.md`。
- 如果论文仓库已经跟踪 `AGENTS.md`，自动改用本地 `AGENTS.override.md`，避免污染已有文件。
- `AGENTS.md` / `AGENTS.override.md`、`.agents/`、`.codex/` 默认通过 `.git/info/exclude` 保持为**本地文件**，不会上传到 Overleaf。
- 安全 `pull`：要求工作区干净，仅允许 fast-forward，不自动 stash / merge / rebase / reset。
- `status`：fetch 后报告 synchronized / local ahead / Overleaf ahead / diverged，并展示未提交改动。
- **两阶段 push**：第一次只 stage、检查并展示变更；第二次必须显式确认才会 commit + push。
- 如果 review 之后 staged diff、HEAD 或 Overleaf 远端发生变化，之前的 push 确认自动失效。
- 永不 force-push，永不自动改写历史。
- 不把 Overleaf token 写入仓库、`AGENTS.md` 或 Git remote URL；认证交给 Git credential helper。
- 除 Agent Skill 外，也提供 `overleaf-codex` CLI，可脱离 Codex 单独使用。

### 适用场景

你希望长期保持这种工作方式：

```text
第一次：配置一次 Overleaf
          ↓
以后：pull → Codex 修改 → status → push 预检 → 你确认 → 上传
```

例如：

```text
$overleaf-codex-workflow pull

把 Introduction 第二段改得更清楚。
不要修改 citation、实验数字、figure 和 contribution claim。

$overleaf-codex-workflow status
$overleaf-codex-workflow push
```

查看预检结果后，你明确确认：

```text
$overleaf-codex-workflow push --confirm "Revise introduction motivation"
```

只有这一步才真正执行 commit + push。

### 环境要求

- Git
- Bash（Linux、macOS、WSL 或 Git Bash）
- Codex CLI / IDE extension（使用 Skill 时需要）
- 一个已启用 Git integration 的 Overleaf 项目/方案
- Overleaf Git authentication token

Overleaf Git integration 的同步目标使用 `master`。本工具始终把本地 `HEAD` 安全地推送到 `overleaf/master`。

### 安装

下载或 clone 本仓库后：

```bash
./install.sh
```

默认安装到 Codex 用户级 Skill 目录：

```text
~/.agents/skills/overleaf-codex-workflow/
```

并创建命令：

```text
~/.local/bin/overleaf-codex
```

如果 `~/.local/bin` 不在 `PATH`，请将其加入 `PATH`，或者直接通过 Codex Skill 使用。

#### 安装到某个仓库

也可以把 Skill 安装为 repo-local skill：

```bash
./install.sh --repo /path/to/repository
```

### 第一次配置 Overleaf 项目

在 Codex 中：

```text
$overleaf-codex-workflow setup https://www.overleaf.com/project/<PROJECT_ID> ~/papers/my-paper
```

或者直接在终端运行：

```bash
overleaf-codex setup https://www.overleaf.com/project/<PROJECT_ID> ~/papers/my-paper
```

你也可以直接传入 Overleaf 提供的 Git URL 或 project ID。

第一次进行网络 Git 操作时，Git 可能要求认证：

```text
username: git
password: <你的 Overleaf Git authentication token>
```

**不要把 token 放进 URL，也不要把 token 粘贴给 Codex / ChatGPT。** 如果希望记住凭据，请在本机配置可信的 Git credential helper。

配置完成后：

```bash
cd ~/papers/my-paper
codex
```

项目根目录此时已经拥有本地 Codex 指令文件。

### 日常工作流

#### 1. 修改前先拉取

```text
$overleaf-codex-workflow pull
```

`pull` 会要求工作区干净，并使用 fast-forward-only 更新。遇到脏工作区或 divergent history 时会停止，不会自动处理。

#### 2. 让 Codex 正常修改论文

例如：

```text
重写 Introduction 第二段，让 motivation 更清楚。
保持现有 citation，不修改实验数字、figure、label 和 contribution claim。
```

默认生成的 `AGENTS.md` 会持续提醒 Codex遵守论文仓库的安全规则。

#### 3. 查看同步状态

```text
$overleaf-codex-workflow status
```

也可以使用 CLI：

```bash
overleaf-codex status
```

#### 4. 发起 push 预检

```text
$overleaf-codex-workflow push
```

第一次 `push` **不会 commit，也不会 push**。它只会：

1. fetch Overleaf；
2. 检查是否 remote-ahead / diverged；
3. stage 本地修改；
4. 运行 `git diff --cached --check`；
5. 展示 diffstat 和变更文件；
6. 保存一个安全快照。

#### 5. 人工确认后才真正上传

确认变更正确以后：

```text
$overleaf-codex-workflow push --confirm "Update manuscript"
```

确认阶段会再次 fetch。如果下列任意状态在 review 后发生变化，push 会被拒绝：

- staged diff；
- 本地 `HEAD`；
- Overleaf remote；
- Git 历史关系。

### CLI 命令

```bash
overleaf-codex setup <url|git-url|project-id> [directory]
overleaf-codex pull
overleaf-codex status
overleaf-codex push
overleaf-codex push --confirm ["commit message"]
overleaf-codex init-agents
overleaf-codex doctor
```

### 为什么默认这么保守？

论文通常是多人协作。静默执行 merge / rebase / stash / reset，可能覆盖自己或合作者刚刚完成的修改。

因此这个项目明确**不会自动**：

- stash 本地修改；
- merge divergent histories；
- rebase；
- reset / discard 文件；
- 自动解决冲突；
- force-push。

遇到复杂状态时，它的原则是：**停止、展示状态、让人决定下一步。**

### `AGENTS.md` 行为

setup 会写入带有以下 marker 的管理块：

```text
<!-- overleaf-codex-workflow:start -->
...
<!-- overleaf-codex-workflow:end -->
```

规则如下：

- 如果没有 `AGENTS.md`：创建本地 `AGENTS.md`。
- 如果已有未跟踪/本地 `AGENTS.md`：保留原内容，只追加 workflow block。
- 如果 `AGENTS.md` 已经被论文仓库跟踪：不修改它，改为创建本地 `AGENTS.override.md`。
- 如果 `AGENTS.md` 和 `AGENTS.override.md` 都已经被跟踪：直接停止，避免静默改变项目级 Codex 指令。

本地指令通过 `.git/info/exclude` 排除，而不是修改论文仓库的 `.gitignore`。

### Token 与凭据安全

本 Skill 不读取、不保存 Overleaf token。认证完全委托给 Git。

推荐流程：

1. 在 Overleaf Account Settings 中创建 Git authentication token；
2. 在你自己的终端执行一次 Git 网络操作；
3. username 输入 `git`；
4. password 输入 token；
5. 如需持久化，使用可信的系统/Git credential helper。

setup 会拒绝形如 `https://user:password@host/...` 的 URL，降低 token 被写入历史或日志的风险。

### 测试

测试不需要真实 Overleaf 账号，会使用本地 bare Git repository 模拟 Overleaf remote：

```bash
bash tests/test.sh
```

GitHub Actions 也会自动执行 Bash syntax check 和安全测试。

### 项目结构

```text
overleaf-codex-workflow/
├── README.md                 # 中文 + English
├── VERSION
├── LICENSE
├── SECURITY.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── install.sh
├── uninstall.sh
├── .github/
│   └── workflows/
│       └── test.yml
├── tests/
│   └── test.sh
└── skill/
    └── overleaf-codex-workflow/
        ├── SKILL.md
        ├── agents/
        │   └── openai.yaml
        ├── assets/
        │   └── AGENTS.block.md
        └── scripts/
            └── overleaf_workflow.sh
```

### 设计依据

本项目按以下官方文档的当前行为设计：

- OpenAI Codex Agent Skills: https://developers.openai.com/codex/build-skills
- OpenAI Codex `AGENTS.md`: https://developers.openai.com/codex/agent-configuration/agents-md
- Overleaf Git integration: https://docs.overleaf.com/integrations-and-add-ons/git-integration-and-github-synchronization/git
- Overleaf Git authentication tokens: https://docs.overleaf.com/integrations-and-add-ons/git-integration-and-github-synchronization/git/git-integration-authentication-tokens
- Overleaf advanced Git operations: https://docs.overleaf.com/integrations-and-add-ons/git-integration-and-github-synchronization/git-integration/advanced-git-operations

### License

MIT

---

<a id="english"></a>

# English

A small, conservative, safety-first **Codex Agent Skill** for a one-time-configured **Overleaf ↔ Git ↔ Codex** manuscript workflow.

It does **not** try to write your paper for you. It manages the repository lifecycle around the manuscript: pull the newest Overleaf state, initialize Codex project guidance, let Codex edit LaTeX locally, and only commit/push after an explicit user request and review gate.

```text
Overleaf
   │
   │  pull (fast-forward only)
   ▼
local Git repository  ←→  Codex edits LaTeX here
   │
   │  push preflight → human confirmation → commit + push
   ▼
Overleaf
```

## Features

- One-time Overleaf project setup.
- Accepts an Overleaf project URL, Git URL, or project ID.
- Clones the project and renames the remote to `overleaf`.
- Automatically creates project-level Codex guidance, normally `AGENTS.md`.
- If the manuscript already tracks `AGENTS.md`, creates a local `AGENTS.override.md` instead of modifying the tracked file.
- Keeps `AGENTS.md` / `AGENTS.override.md`, `.agents/`, and `.codex/` local-only through `.git/info/exclude`, so Codex configuration is not uploaded to Overleaf.
- Safe `pull`: requires a clean tree, fast-forward only, with no automatic stash / merge / rebase / reset.
- Useful `status`: fetches Overleaf and reports synchronized / local ahead / Overleaf ahead / diverged state plus uncommitted changes.
- **Two-stage push**: the first command only stages, checks, and displays changes; a second explicit confirmation is required before commit + push.
- Invalidates the previous push approval if the staged diff, local HEAD, or Overleaf remote changes after review.
- Never force-pushes or silently rewrites history.
- Never stores an Overleaf token in the repository, `AGENTS.md`, or Git remote URL; authentication is delegated to Git credential helpers.
- Works as both a Codex skill and a small standalone `overleaf-codex` CLI.

## Intended workflow

Configure once, then repeat:

```text
first time: configure Overleaf once
                 ↓
later: pull → Codex edit → status → push preflight → approve → upload
```

Example:

```text
$overleaf-codex-workflow pull

Rewrite the second paragraph of the Introduction to make the motivation clearer.
Do not change citations, numerical results, figures, or contribution claims.

$overleaf-codex-workflow status
$overleaf-codex-workflow push
```

After reviewing the preflight output, explicitly confirm:

```text
$overleaf-codex-workflow push --confirm "Revise introduction motivation"
```

Only the confirmation step can create a commit and push it to Overleaf.

## Requirements

- Git
- Bash (Linux, macOS, WSL, or Git Bash)
- Codex CLI / IDE extension for skill use
- An Overleaf project/plan with Git integration enabled
- An Overleaf Git authentication token

Overleaf Git integration synchronizes through `master`. This workflow always pushes local `HEAD` to `overleaf/master` without force.

## Install

Clone or download this repository, then run:

```bash
./install.sh
```

The skill is installed to the current Codex user-level skill location:

```text
~/.agents/skills/overleaf-codex-workflow/
```

By default it also creates:

```text
~/.local/bin/overleaf-codex
```

If `~/.local/bin` is not on your `PATH`, add it or invoke the skill directly from Codex.

### Repository-local installation

You can also install it as a repo-local skill:

```bash
./install.sh --repo /path/to/repository
```

## First-time Overleaf setup

From Codex:

```text
$overleaf-codex-workflow setup https://www.overleaf.com/project/<PROJECT_ID> ~/papers/my-paper
```

Or from a terminal:

```bash
overleaf-codex setup https://www.overleaf.com/project/<PROJECT_ID> ~/papers/my-paper
```

You may also pass the Git URL shown by Overleaf or a project ID.

On the first network Git operation, Git may ask for credentials:

```text
username: git
password: <your Overleaf Git authentication token>
```

**Never embed the token in the URL or paste it into an AI prompt.** Configure a trusted Git/OS credential helper locally if you want Git to remember it.

After setup:

```bash
cd ~/papers/my-paper
codex
```

The repository now has local Codex project guidance.

## Daily workflow

### 1. Pull before editing

```text
$overleaf-codex-workflow pull
```

Pull requires a clean working tree and updates only with fast-forward semantics. Dirty trees and divergent history cause the workflow to stop instead of guessing.

### 2. Ask Codex to edit normally

For example:

```text
Rewrite the second paragraph of the Introduction to make the motivation clearer.
Preserve existing citations, experiment numbers, figures, labels, and contribution claims.
```

The generated `AGENTS.md` guidance keeps the repository safety rules active in future Codex sessions.

### 3. Inspect synchronization state

```text
$overleaf-codex-workflow status
```

Or use the CLI:

```bash
overleaf-codex status
```

### 4. Start a push preflight

```text
$overleaf-codex-workflow push
```

The first `push` command **does not commit and does not push**. It only:

1. fetches Overleaf;
2. rejects remote-ahead or diverged history;
3. stages local changes;
4. runs `git diff --cached --check`;
5. prints the diffstat and changed files;
6. records a safety snapshot.

### 5. Upload only after human confirmation

After reviewing the changes:

```text
$overleaf-codex-workflow push --confirm "Update manuscript"
```

The confirmation step fetches Overleaf again. It aborts if any reviewed state has changed, including:

- staged diff;
- local `HEAD`;
- Overleaf remote;
- Git ancestry relationship.

## CLI commands

```bash
overleaf-codex setup <url|git-url|project-id> [directory]
overleaf-codex pull
overleaf-codex status
overleaf-codex push
overleaf-codex push --confirm ["commit message"]
overleaf-codex init-agents
overleaf-codex doctor
```

## Why so conservative?

Academic manuscripts are often edited collaboratively. Silent merge / rebase / stash / reset behavior can overwrite or obscure changes made by you or your collaborators.

Therefore the workflow deliberately does **not** automatically:

- stash local edits;
- merge divergent histories;
- rebase;
- reset or discard files;
- resolve conflicts;
- force-push.

When synchronization becomes non-trivial, the rule is: **stop, show the state, let the human decide.**

## `AGENTS.md` behavior

Setup adds a managed block delimited by:

```text
<!-- overleaf-codex-workflow:start -->
...
<!-- overleaf-codex-workflow:end -->
```

Rules:

- No `AGENTS.md`: create a local `AGENTS.md`.
- Existing untracked/local `AGENTS.md`: preserve it and append the workflow block.
- Tracked `AGENTS.md`: leave it untouched and create a local `AGENTS.override.md` instead.
- Both `AGENTS.md` and `AGENTS.override.md` tracked: stop instead of silently modifying tracked Codex guidance.

Local guidance is excluded through `.git/info/exclude`, not by modifying the manuscript's tracked `.gitignore`.

## Authentication and secrets

The skill does not read or store your Overleaf token. Authentication is delegated to Git.

Recommended flow:

1. Generate a Git authentication token in Overleaf Account Settings.
2. Run a Git network operation in your own terminal.
3. Enter username `git`.
4. Enter the token as the password.
5. Use a trusted OS/Git credential helper if you want persistence.

Setup rejects URLs in the form `https://user:password@host/...` to reduce accidental secret leakage into shell history, logs, or repository configuration.

## Test

No real Overleaf account is needed. The test suite creates a local bare Git repository as a fake Overleaf remote:

```bash
bash tests/test.sh
```

GitHub Actions also runs Bash syntax checks and the safety test suite.

## Project structure

```text
overleaf-codex-workflow/
├── README.md                 # 中文 + English
├── VERSION
├── LICENSE
├── SECURITY.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── install.sh
├── uninstall.sh
├── .github/
│   └── workflows/
│       └── test.yml
├── tests/
│   └── test.sh
└── skill/
    └── overleaf-codex-workflow/
        ├── SKILL.md
        ├── agents/
        │   └── openai.yaml
        ├── assets/
        │   └── AGENTS.block.md
        └── scripts/
            └── overleaf_workflow.sh
```

## Design references

The workflow is aligned with the current public behavior documented by:

- OpenAI Codex Agent Skills: https://developers.openai.com/codex/build-skills
- OpenAI Codex `AGENTS.md`: https://developers.openai.com/codex/agent-configuration/agents-md
- Overleaf Git integration: https://docs.overleaf.com/integrations-and-add-ons/git-integration-and-github-synchronization/git
- Overleaf Git authentication tokens: https://docs.overleaf.com/integrations-and-add-ons/git-integration-and-github-synchronization/git/git-integration-authentication-tokens
- Overleaf advanced Git operations: https://docs.overleaf.com/integrations-and-add-ons/git-integration-and-github-synchronization/git-integration/advanced-git-operations

## License

MIT
