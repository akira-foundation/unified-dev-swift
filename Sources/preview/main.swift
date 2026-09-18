import Core
import Foundation

let result = PreviewCommand.run(Array(CommandLine.arguments.dropFirst()))
FileHandle.standardOutput.write(Data(result.output.utf8))
FileHandle.standardError.write(Data(result.error.utf8))
exit(result.status)
