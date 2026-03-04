# Contributing to plan-an-go

Thanks for your interest in contributing. Here’s how to get started.

## Development setup

1. Clone the repo and go to the project root:
   ```bash
   git clone https://github.com/SkinnnyJay/plan-an-go.git
   cd plan-an-go
   ```

2. Copy `.env.sample` to `.env` and set at least `PLAN_AN_GO_CLI` (and any API keys if you don’t want interactive auth). See [docs/ENV-README.md](docs/ENV-README.md) for all env vars and for **output directory** (`--out-dir`) and **cleanup** (`--clean-after --force`) options.

3. Run the pipeline from the repo root (see [README.md](README.md)):
   ```bash
   npm run plan-an-go
   # or
   npm run plan-an-go-forever -- --no-slack
   ```

4. Try the example:
   ```bash
   npm run example:count
   ```

## How to contribute

- **Bug reports and feature ideas:** Open an [issue](https://github.com/SkinnnyJay/plan-an-go/issues). Include steps to reproduce for bugs and your environment (OS, CLI in use).

- **Code and docs:** Open a pull request. Keep changes focused; link any related issues.

- **Scripts:** The main entry is `scripts/plan-an-go`; CLI logic lives in `scripts/cli/` and setup in `scripts/system/`. Use Bash with `set -e` and keep scripts portable (macOS/Linux).

- **Lint and format:** Run `npm run check` (or `make check`) before opening a PR. This runs ShellCheck and shfmt. Install shellcheck and shfmt (e.g. `brew install shellcheck shfmt`).

## Adding yourself as a contributor

After your first merged contribution, add your name (and optional link) to [CONTRIBUTORS.md](CONTRIBUTORS.md) in alphabetical order.

## License

By contributing, you agree that your contributions will be licensed under the same license as the project: [MIT](LICENSE).
