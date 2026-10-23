# Release

Under autopilot nothing here runs: it parks with no release (why: the number and the tag push are the user's call).

## On the branch

1. Tooling: the project's own release tooling wins: a release script, changesets, semantic-release, or a release section in CONTRIBUTING or the README. Follow it, say which, and fill only its gaps; the confirm, the wait and the ask still hold.
2. Bump: `git describe --tags --abbrev=0` prints the last tag (none: this is the first release); `git log --oneline <tag>..HEAD` lists the changes since it. Choose by semver: a breaking change is major, a new feature minor, fixes only patch; below 1.0.0 a breaking change bumps minor. State the bump with the change that sets it; the user confirms the number before anything is written.
3. Changelog, for humans: one dated entry under the version, in the changelog's format; with none, `CHANGELOG.md` with Keep a Changelog's Added, Changed, Fixed, Removed. User-visible effects, breaking changes first, each with its migration step; never a commit-log dump.
4. Commit: the version in every manifest that carries one, plus the changelog entry, as one release commit by commit's steps 2 to 6, its subject naming the version.
5. Wait: the release stops here, under any option. Never tag a branch commit: a squash or rebase merge replaces it, leaving the tag off `<base>`. Report that the tag waits for the merge, with the commands of After the merge filled in but for `<sha>`.

## After the merge

For a request to tag a merged release, in place of finish-branch steps 2 to 11.

1. Base: `git fetch origin <base>`, `<baseref>` being `origin/<base>`; with no remote, local `<base>`.
2. Find the release commit by its subject, since a squash changes the SHA: `git log -1 -F --grep='<subject>' --format='%H %s' <baseref>`. Each manifest's version there (`git show <sha>:<manifest>`) must be `<x.y.z>`. None found, or a mismatch: stop and report.
3. Tag: `git tag -a v<x.y.z> <sha> -m "<x.y.z>: <one line>"`, never a lightweight tag; the line holds no `"`, `$` or backtick. The SHA means no checkout: kern never switches the main checkout's branch. The tag is the version's source of truth. Never move or reuse a pushed tag; a bad release gets the next patch.
4. Push: pushing the tag publishes it, so it is asked like any push: `git push origin v<x.y.z>` as its own call, never `--tags`. From any checkout G1 asks for it under `push.policy: auto` too: that prompt is the ask. Declined, the tag stays local: report it. A rejected tag push means the remote has that tag: stop and report; never force it.
