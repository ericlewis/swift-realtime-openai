import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct RealtimeToolMacrosPlugin: CompilerPlugin {
	let providingMacros: [any Macro.Type] = [
		GenerableMacro.self,
		GuideMacro.self,
	]
}
