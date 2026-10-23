# Release

Under autopilot none of this runs; it parks (why: the number and the tag push are the user's call).

## On the branch

1. Tooling: the project's own release tooling wins: a release script, changesets, semantic-release, or a release section in CONTRIBUTING or the README. Follow it, say which, and fill only its gaps; the confirm, the wait and the ask still hold.
2. Bump: `git describe --tags --abbrev=0 <baseref>` gives the last tag, `git log --oneline <tag>..HEAD` the changes. No tag: a first release of every commit, numbered as the manifest says, else 0.1.0 or 1.0.0, the user's pick. By semver, a breaking change is major, a new feature minor, fixes only patch; below 1.0.0 a breaking change bumps minor; unsure whether it breaks: it does. State the bump with the change that sets it; the user confirms the number before anything is written.
3. Changelog, for humans: one dated entry under the version, in the changelog's format; an Unreleased section becomes it. Else `CHANGELOG.md` with Keep a Changelog's Added, Changed, Deprecated, Removed, Fixed, Security. User-visible effects, breaking changes first, each with its migration step; never a commit-log dump.
4. Commit: the version in every manifest that carries one (a placeholder the tag sets stays), plus the changelog entry, as one release commit by commit's steps 2 to 6, its subject naming the version.
5. Wait: the release stops here, under any option. Never tag a branch commit: a squash or rebase merge replaces it. Report that the tag waits for the merge, with After the merge's commands filled in but for `<sha>`.

## After the merge

For a request to tag a merged release, in place of finish-branch steps 2 to 11. Tooling or CI that tags wins: say so and stop.

1. Base: `git fetch origin <base>`, `<baseref>` being `origin/<base>`; with no remote, local `<base>`.
2. Find the release commit by its subject, since a squash changes the SHA: the first line of `git log --reverse -F --grep='<subject>' --format=%H <baseref>`, each `'` in the subject as `'\''`. Each version file (manifests, else the changelog) must hold `<x.y.z>` at `<sha>` and not at `<sha>^`. None found, or a mismatch: stop and report. Name what the tag leaves out: `git log --oneline <sha>..<baseref>`.
3. Tag: `git tag -a v<x.y.z> <sha> -m "<x.y.z>: <one line>"`, never a lightweight tag; the line holds no `"`, `$` or backtick. The SHA needs no checkout: kern never switches the main checkout's branch. The tag is the version's source of truth. Never move or reuse a pushed tag; a bad release gets the next patch.
4. Push: pushing the tag publishes it, so it is asked like any push: `git push origin v<x.y.z>` as its own call, never `--tags`. G1 asks for it even under `push.policy: auto`: that prompt is the ask. Declined, or with no remote, the tag stays local: report it. Rejected: the remote has that tag; stop and report, never force it.
