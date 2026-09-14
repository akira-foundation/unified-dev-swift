# Crash reporting

`CrashReportingService` installs an uncaught exception handler with `NSSetUncaughtExceptionHandler`.
It catches uncaught Objective-C exceptions, which is what an AppKit app dies of most often. A
signal that kills the process outright (a Swift runtime trap, a segfault) leaves nothing here, and
macOS writes its own report for those under `~/Library/Logs/DiagnosticReports`.

The handler installs in release and master builds under the `io.akira.unifieddev` bundle
identifier, unless a debugger is attached or **Send crash reports** is off in General settings.
`CrashReporting.isEligible` decides this; local and unbundled builds do not install a handler at
all.

There is no crash reporting service behind this and no network call anywhere in it. When an
uncaught exception fires, `CrashReportingService` writes a plain text report, build details, the
bundle identifier, the exception name and reason, and the call stack, to a file under
`CrashReports` inside the app's Application Support directory (`CrashLogWriter.directory()`). The
file is named by `CrashLogName.forReport`, `crash-<UTC timestamp>.log`, with a numeric suffix added
if a report with that name already exists.

Nothing leaves the machine. A report that leaves it is a decision the owner of the machine makes,
by attaching the file themselves; the whole of that decision is visible in Settings, and the
directory can be revealed from there through `CrashReportingService.directory`.

## Verify the integration

```shell
./Tools/build.sh
```

Raise an uncaught Objective-C exception in a release or master build with **Send crash reports**
on, and confirm a `crash-<timestamp>.log` file appears under `CrashReports` in the app's
Application Support directory, naming the build, the bundle identifier, the exception and its call
stack.
