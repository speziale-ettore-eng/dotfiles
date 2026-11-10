# Investigation dumps

When the checkout is a linked worktree of a bare repo under `~/Work`, write investigation dumps to:

`~/Tmp/<bare-repo-path-without-.git>/<worktree-name>/`

- Bare repo path: `git rev-parse --git-common-dir`, resolved absolute. Drop the `~/Work/` prefix and a trailing `.git`.
- Worktree name: the basename of `git rev-parse --show-toplevel`.

Examples:

- `~/Work/widget.git/BUG-1234` → `~/Tmp/widget/BUG-1234`
- `~/Work/acme/compiler.git/main` → `~/Tmp/acme/compiler/main`

Create the directory if it is missing. Do not ask for the dump path.
