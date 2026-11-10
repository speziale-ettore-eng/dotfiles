# Questions about another project

Bare repos live under `~/Work`, as `~/Work/<name>.git` or `~/Work/<group>/<name>.git`. Each linked worktree is a directory inside its bare repo. Match the project name in the question to that directory name (`harbor` is `~/Work/harbor.git`, `compiler` is `~/Work/acme/compiler.git`).

When a question needs the contents of a different one of these repos, spawn a separate agent and give it the question, the checkout path, the revision, and why that revision was chosen. Set its working directory to that checkout. Answer from what it reports.

Pick the revision in this order:

1. A branch or commit the user named for that repo.
2. The revision the current checkout pins for that repo. Resolve the pin to a commit in the other bare repo:
   - A submodule whose URL is that repo: the gitlink commit.
   - A `*_COMMIT` assignment, or a `git_override` / `archive_override` / archive URL, that records a commit of that repo.
   - A `bazel_dep` version for a module from that repo. `0.0.0-<40-hex>` is that commit. A dotted version is the tag `<module>-<version>` in the other repo when that tag exists, otherwise the 40-hex commit in that version's registry `source.json` (`url` or `strip_prefix`).
   When more than one pin matches, use the pin the current project applies to the thing being asked, and name the file and value.
3. When the current checkout records no pin, the other bare repo's default branch: `git --git-dir=<bare> symbolic-ref --short HEAD`.

Outside a `~/Work` worktree there is no current pin, so stop after the named ref and the default branch.

When a pin is recorded and does not resolve to a commit, say so and stop. An unresolved pin stays unresolved.

Use a checkout `git worktree list` already has at that commit, and leave that worktree on its current commit. Otherwise add a detached worktree, and reuse the directory when it is already that revision:

`git --git-dir=<bare> worktree add --detach ~/Tmp/<bare-repo-path-without-.git>/<rev> <rev>`

`<bare-repo-path-without-.git>` is the bare repo path with the `~/Work/` prefix and a trailing `.git` removed. Leave worktrees you did not create where they are.

Examples:

- From `~/Work/widget.git/BUG-1234`, a question about harbor, with widget pinning harbor at `a1b2c3d`, is answered from harbor at `a1b2c3d`.
- The same question with no pin is answered from harbor's default branch.
- "On harbor branch `release-9`" is answered from `release-9`.
- A detached look at `~/Work/acme/compiler.git` commit `a1b2c3d` goes to `~/Tmp/acme/compiler/a1b2c3d`.
