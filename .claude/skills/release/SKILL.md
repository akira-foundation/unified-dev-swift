---
name: unifieddev-release
description: Release Unified Dev by pushing a version tag, which generates the changelog and release notes and publishes signed artefacts on GitHub, or create signed local release artefacts. Use when asked to cut, ship, publish, or prepare a Unified Dev release.
---

# Release Unified Dev

Run app commands from this repository root. `.github/workflows/release.yml` is the pipeline and
`cliff.toml` decides how commits become the changelog. Use `gh` for GitHub.

## Publish a release

1. Establish the intended commit and version. Inspect repository status, existing tags and
   releases, and CI for that commit. Do not release uncommitted code or infer success from a
   different commit's green run.
2. Work out the version from the commits rather than choosing it: `git-cliff --bumped-version`.
   The workflow refuses a stable tag that disagrees with it. Tags use `v1.4.0`, or `v1.4.0-beta.1`
   for a prerelease, which skips that check and publishes as a GitHub prerelease.
3. Tag the commit on `main` and push the tag. Tagging and pushing publish, so only do it when
   asked to publish:

   ```sh
   git tag v<version> && git push origin v<version>
   ```

4. Watch the **Release** workflow for that tag with `gh run list`, `gh run view` and
   `gh run watch`. The `changelog` job regenerates `CHANGELOG.md`, commits it to `main` and creates
   the GitHub Release with the git-cliff notes. The `release` job builds, signs, notarises,
   attaches the DMG and ZIP, and posts to Discord when that secret is set. If it fails, inspect the
   failed job before retrying and prefer `gh run rerun <run-id> --failed`. Do not delete or move a
   published tag. `workflow_dispatch` with a tag rebuilds and re-attaches the artefacts without
   touching the changelog.
5. Verify the GitHub release notes and both assets, and that `CHANGELOG.md` on `main` carries the
   new version. Report the release URL and the workflow result.

## Package locally

`./Tools/release.sh [<ref>] [--tag <tag>] [--no-dmg]` (or `make release`) creates signed,
notarised artefacts in `dist/` from committed code. It needs a Developer ID signing identity and
notarisation credentials, and it publishes nothing. For an isolated app to test, use
`unifieddev-dev-build` instead.
