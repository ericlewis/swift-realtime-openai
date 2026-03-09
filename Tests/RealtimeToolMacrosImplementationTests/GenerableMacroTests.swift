import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import RealtimeToolMacrosImplementation

struct GenerableMacroTests {
	private let macros: [String: MacroSpec] = [
		"Generable": MacroSpec(type: GenerableMacro.self, conformances: ["Generable"]),
		"Guide": MacroSpec(type: GuideMacro.self),
	]

	@Test
	func patternConstraintDiagnosesNonStringProperty() {
		assertExpands(
			"""
			@Generable
			struct BadArguments {
				@Guide(description: "Nope", .pattern("^[a-z]+$"))
				let count: Int
			}
			""",
			expandedSource: """
			struct BadArguments {
				let count: Int

			    static var generationSchema: JSONSchema {
			    	.object(
			    		properties: [
			    			"count": .integer(minimum: nil, maximum: nil, description: "Nope")
			    		],
			    		required: ["count"],
			    		description: nil
			    	)
			    }
			}

			extension BadArguments: Generable {
			}
			""",
			diagnostics: [
				DiagnosticSpec(message: "@Guide pattern, format, and length constraints only apply to String properties.", line: 3, column: 2),
			]
		)
	}

	@Test
	func countConstraintDiagnosesNonArrayProperty() {
		assertExpands(
			"""
			@Generable
			struct BadArguments {
				@Guide(description: "Name", .count(2))
				let name: String
			}
			""",
			expandedSource: """
			struct BadArguments {
				let name: String

			    static var generationSchema: JSONSchema {
			    	.object(
			    		properties: [
			    			"name": .string(pattern: nil, format: nil, minLength: nil, maxLength: nil, description: "Name")
			    		],
			    		required: ["name"],
			    		description: nil
			    	)
			    }
			}

			extension BadArguments: Generable {
			}
			""",
			diagnostics: [
				DiagnosticSpec(message: "@Guide count constraints only apply to Array properties.", line: 3, column: 2),
			]
		)
	}

	@Test
	func formatConstraintDiagnosesUnsupportedFormat() {
		assertExpands(
			"""
			@Generable
			struct BadArguments {
				@Guide(description: "Email", .format(.postalCode))
				let email: String
			}
			""",
			expandedSource: """
			struct BadArguments {
				let email: String

			    static var generationSchema: JSONSchema {
			    	.object(
			    		properties: [
			    			"email": .string(pattern: nil, format: nil, minLength: nil, maxLength: nil, description: "Email")
			    		],
			    		required: ["email"],
			    		description: nil
			    	)
			    }
			}

			extension BadArguments: Generable {
			}
			""",
			diagnostics: [
				DiagnosticSpec(message: "@Guide format only supports .ipv4, .ipv6, .uuid, .date, .time, .email, .duration, .hostname, and .dateTime.", line: 3, column: 2),
			]
		)
	}

	private func assertExpands(
		_ source: String,
		expandedSource: String,
		diagnostics: [DiagnosticSpec]
	) {
		var failures: [String] = []

		assertMacroExpansion(
			source,
			expandedSource: expandedSource,
			diagnostics: diagnostics,
			macroSpecs: macros,
			failureHandler: { failures.append($0.message) }
		)

		if !failures.isEmpty {
			Issue.record(Comment(rawValue: failures.joined(separator: "\n\n")))
		}
	}
}
