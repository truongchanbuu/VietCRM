# Salesforce AI tooling

Seven skills from Salesforce's [sf-skills repository](https://github.com/forcedotcom/sf-skills) are installed under `.agents/skills`, pinned to commit `4bbae5c421e51b40e4169afa72c4496372a602a7`:

- platform-apex-generate
- platform-apex-test-generate
- platform-apex-test-run
- platform-metadata-retrieve
- platform-metadata-deploy
- dx-code-analyzer-run
- dx-code-analyzer-configure

Their files remain upstream copies. `LICENSE.salesforce.txt` retains the upstream Apache license. The lock information is in `config/salesforce-ai-tools.json`. Codex discovers these skills in the current session from `.agents/skills`; no Claude-specific conversion is needed. They can also be read directly in this workspace. Update the pinned revision deliberately and review upstream changes.

## DX MCP transition configuration

`.codex/config.toml` configures the [official DX MCP](https://github.com/forcedotcom/mcp) with `@salesforce/mcp@0.30.15`, explicit org allowlist `dev`, and metadata/testing/code-analysis toolsets. It uses local Salesforce CLI authentication; no token is stored in this repo. A trusted project and a new client session may be needed to load the configuration. See [Codex MCP configuration](https://developers.openai.com/codex/mcp).

Salesforce announced [end of life on November 2, 2026](https://github.com/forcedotcom/mcp/issues/46) and recommends skills instead. This MCP setup is a pinned transition option, not a maintained long-term dependency of the core or CI. All quality and deployment commands work through the CLI without MCP.

The Salesforce connector discovered in the application plugin directory was disabled by the workspace administrator. It was not installed or enabled. That connector is separate from this local developer MCP configuration.

## Connection verification

The local MCP configuration is present, but startup/handshake attempts timed out during dependency installation. A successful MCP connection has not been verified. Installed skills are available independently of MCP; Salesforce CLI remains the verified execution path for metadata operations and checks.
