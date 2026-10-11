# Releasing Unified Dev

What a release takes, written from what was measured on 11 October 2026 proving the pipeline end
to end against a real Developer ID, rather than from what ought to be true.

A release is a macOS app a stranger downloads and opens. That means four things have to be true
of the bundle, and all four are checked rather than assumed: it is signed with a Developer ID,
the hardened runtime is on, Apple has notarised it, and the ticket is stapled to it. Without all
four, macOS refuses to open it without the person going several clicks into System Settings,
Privacy and Security.

There is one copy of that sequence, in `Tools/release/package-app.sh`. `Tools/release.sh` calls
it and so does `.github/workflows/release.yml`, on purpose: a local release and a CI release
signing differently is the kind of difference nobody notices until a user cannot open the app.

## The certificate

A **Developer ID Application** certificate, issued to team `ZF76N8225L`, valid until
**1 February 2027**. It needs a paid Apple Developer membership. Xcode, Settings, Accounts, pick
the team, Manage Certificates, plus, Developer ID Application.

An **Apple Development** certificate is not this one. That one signs for the machine it was made
on, and Apple will not notarise anything signed with it. `Tools/release/package-app.sh` refuses
it outright rather than letting you find out after the build.

To see what this Mac holds:

```bash
security find-identity -v -p codesigning
```

### When it expires

Issue another one. **Do not revoke the old one.** Every release already published was signed with
a trusted timestamp, so it keeps opening after the certificate behind it expires; that is what
the `--timestamp` flag in `package-app.sh` buys. Revoking is what breaks apps already in people's
hands, because revocation is not bounded by time the way expiry is. An expired certificate simply
stops signing anything new, which is all you want.

## The signing identity, and why it is a fingerprint

`UD_CODESIGN_IDENTITY` locally and the `APPLE_SIGNING_IDENTITY` secret in CI both hold the
certificate's **SHA-1 fingerprint**, not its name.

A name that carries a character outside ASCII reaches `codesign` mangled. Measured, with a real
certificate:

```
==> signing with the hardened runtime
    Contents/MacOS/sleep-helper
Developer ID Application: Kidiatoliny Gon√ßalves (ZF76N8225L): no identity found
```

The `ç` arrives as `√ß`, `codesign` looks for a certificate that does not exist, and the build
stops with an error that reads like a missing certificate rather than a mangled string. In CI it
would do that after a seven minute build. The same run signs correctly when the fingerprint is
used instead. That defect is [#239](https://github.com/akira-foundation/unified-dev-swift/issues/239);
until it is fixed, the fingerprint is the value that works for everyone, whatever their name is.

Read it from the line `security find-identity` prints: the forty hex characters before the quoted
name.

```bash
security find-identity -v -p codesigning | grep 'Developer ID Application'
```

```
  2) 1234...CDEF "Developer ID Application: Your Name (ZF76N8225L)"
     ^ this
```

## The notarisation credential

`Tools/release/package-app.sh` takes one of three, tried in this order. None of them is ever
printed.

| Shape | Variables | Where it is used |
| --- | --- | --- |
| App Store Connect API key | `UD_NOTARY_KEY` (path to the `.p8`), `UD_NOTARY_KEY_ID`, `UD_NOTARY_ISSUER` | nothing stores it on the machine and it can be revoked on its own |
| Apple ID and app specific password | `UD_NOTARY_APPLE_ID`, `UD_NOTARY_PASSWORD`, `UD_NOTARY_TEAM_ID` | this is what CI uses |
| Stored keychain profile | `UD_NOTARY_PROFILE`, defaulting to `unifieddev` | this is the local shape |

The local one is stored once, with an app specific password made at appleid.apple.com:

```bash
xcrun notarytool store-credentials unifieddev --apple-id you@example.com --team-id ZF76N8225L --password <app-specific>
```

Neither setting up the certificate nor storing the credential can be scripted here, because both
are bound to an Apple ID and both need a person at the keyboard. That is why they are written
down instead.

## What CI needs

Every one of these is checked at the top of the `release` job, so a missing one costs a second
rather than a build.

| Secret | What it holds |
| --- | --- |
| `APPLE_CERTIFICATE` | base64 of the exported `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | the password it was exported with |
| `APPLE_SIGNING_IDENTITY` | the certificate's SHA-1 fingerprint, for the reason above |
| `APPLE_ID` | the Apple ID that notarises |
| `APPLE_PASSWORD` | an app specific password for it |
| `APPLE_TEAM_ID` | `ZF76N8225L` |

Two more are optional. `RELEASE_TOKEN` lets the changelog commit push to a protected branch, and
`DISCORD` is the webhook the release is announced on.

`Tools/release/keychain.sh` makes a keychain that exists only for the length of the job, imports
the `.p12` into it with the partition list set so `codesign` is not left waiting for a
confirmation dialog nobody will ever see, and deletes it in a step that runs even when the build
failed. It refuses to run outside CI, because importing a certificate and rearranging the
keychain search list on somebody's own machine is not a thing a release script should do by
accident.

## Proving it locally

This is the command that proved the pipeline, and it is the one to run before trusting a change
to any of it. It publishes nothing.

```bash
UD_CODESIGN_IDENTITY=<fingerprint> UD_NOTARY_PROFILE=<profile> ./Tools/release.sh --tag v1.0.0 --no-dmg
```

It builds a detached worktree at that commit, so nothing uncommitted and nothing from a
concurrent build can reach something being sent to another person, stamps the version from the
tag, signs every nested piece before the bundle itself with the hardened runtime on, verifies,
zips with `ditto`, sends it to Apple, waits, staples the ticket onto the app, zips again and
leaves the result in `dist/`.

What a good run ends with:

```
accepted
source=Notarized Developer ID
```

`--no-dmg` skips the disk image, which doubles the notarisation wait. Leave it off when the image
itself is what you are checking.

### What it checks that is easy to get wrong

- The notarisation **status**, not the exit code. `notarytool` exits 0 for a submission it
  accepted, waited on, and was told was Invalid, so the JSON decides.
- The ticket is stapled to the app and the app is zipped **again** afterwards. Without that, the
  receiver has to be online the first time they open it.
- The disk image carries a notarisation ticket of its own, and stapling the app inside it does
  not put one there. Gatekeeper assesses the file that was downloaded.
- The image is assessed with `--type open` rather than `--type execute`, because a disk image is
  a document being opened. Assessing the app inside instead passes happily on an image that was
  never notarised.

## The asset name is a contract

The workflow publishes `unified_dev_<version>_aarch64.zip`, and that is exactly the name the
updater in an installed copy looks for. It is built once in `SoftwareUpdate.assetName(for:)` and
once in the `Sign, notarise and staple` step of `.github/workflows/release.yml`.

**If one of the two changes, the other changes in the same pull request.** A release whose zip is
named anything else is a release every installed copy reports as having no download for this Mac,
and it will say so for as long as it stays the latest release.

The disk image, `unified_dev_<version>_aarch64.dmg`, is the artefact a person downloads from the
website, with the artwork and the drag to Applications window. The zip holds the same signed and
stapled bundle, and is what the updater takes.

## Publishing

Pushing a `v*` tag is what publishes. The version is not chosen, it is derived:

```bash
git-cliff --bumped-version
```

The workflow refuses a stable tag that disagrees with the commits since the last release. A tag
carrying a prerelease part, `v1.0.0-rc.1`, skips that check and publishes as a GitHub prerelease,
which installed copies never offer.

Tags are cut on the release branch `release/X.Y.Z`, on `main`, or on a maintenance line `N.x`.
Never on `develop` or a work branch; the workflow refuses a tag it cannot find on one of those.

```bash
git tag v1.0.0 && git push origin v1.0.0
```

Then watch it, with `gh run watch`. The `changelog` job regenerates `CHANGELOG.md` from
`cliff.toml`, commits it back to the line the tag was cut on, and creates the GitHub Release with
that tag's own notes. The `release` job builds on a macOS 26 runner, signs, notarises, staples,
and attaches both the zip and the disk image.

Do not delete or move a published tag. To rebuild the artefacts for a tag that already exists,
run the workflow by hand with `workflow_dispatch` and that tag; it re-attaches them without
touching the changelog.

## When it goes wrong

- **`no identity found`, with the name looking odd in the error.** The fingerprint, not the name.
  See above.
- **Notarisation comes back `Invalid`.** The script prints Apple's submission log, which is the
  only thing that says which file was objected to. Without it the failure is a single word.
- **The build fails before anything is signed.** `Tools/release.sh` captures the compile into
  `/tmp/unifieddev-release-build.log` and prints it, because `swift build` reports errors on
  stdout and the old bare redirect threw away the only account of a failed release build.
- **`spctl` says anything other than accepted.** Do not publish it. Something in the four steps
  did not happen, and the zip reaching people unnotarised is worse than a release that did not
  happen, because the second one is obvious.
