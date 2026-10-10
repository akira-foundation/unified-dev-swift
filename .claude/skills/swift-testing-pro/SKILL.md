---
name: swift-testing-pro
description: Write and review the test targets using Swift Testing, including async behaviour, isolated fixtures and regression tests.
license: MIT
metadata:
  author: Paul Hudson
  version: "1.0-unifieddev.1"
  adapted-for: Unified Dev
---

# Swift Testing in Unified Dev

Use Swift Testing for new core tests and follow neighbouring suites in `Tests/CoreTests`.
The target imports `Core`, not the app.

There is a second target, `Tests/BrowserScriptTests`, for the JavaScript the browser tools inject
into a page: it links WebKit, drives an offscreen `WKWebView` through `BrowserPageFixture`, and
runs under `./Tools/test-browser-scripts.sh` rather than `test-core.sh`. Its suites are
`@MainActor`, its fixtures are HTML written in the test, and every answer it asserts goes through
the same `Core` function the app reads it with. Follow the neighbouring suites there instead when
the change is in those scripts.

Test presentation decisions in the core; use XCTest for UI automation if that is requested. Do not
migrate unrelated XCTest tests during a review.

Run `./Tools/test-core.sh <filter>` for the affected suites, or
`./Tools/test-browser-scripts.sh <filter>` when they are in the browser target. `make test` runs
the whole core suite and `make test-browser` the whole browser one; neither compiles the app, and
neither compiles the other, so use `make build` when the change needs it.
Follow `CLAUDE.md` for required lint and CI checks. Keep real agent calls and machine-dependent
checks opt-in, as documented by `Tools/test-core.sh`.

Keep assertions about observable behaviour. Lift mutating calls out of `#expect`: store their
result in a local, then assert on it. Use isolated temporary files, databases and defaults domains.

For reviews, report actual defects with file locations and effects. For test changes, edit the
files directly. Check installed toolchain/API availability rather than treating this guide as
more authoritative than compiler diagnostics or upstream documentation.

Load only the relevant references:

- [Core rules](references/core-rules.md): suites, assertions and parameterised cases.
- [Test design](references/writing-better-tests.md): dependencies, errors and useful regressions.
- [Async tests](references/async-tests.md): serialisation, completion and cancellation.
- [Newer APIs](references/new-features.md): version-dependent testing features.
- [XCTest migration](references/migrating-from-xctest.md): only for a requested migration.
