import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct GenerableMacro: MemberMacro, ExtensionMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		conformingTo _: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		if let structDecl = declaration.as(StructDeclSyntax.self) {
			let properties = try extractProperties(from: structDecl, in: context)
			let description = extractDescription(from: node)
			return [DeclSyntax(stringLiteral: generateStructSchema(properties: properties, description: description))]
		}

		if let enumDecl = declaration.as(EnumDeclSyntax.self) {
			let cases = try extractEnumCases(from: enumDecl)
			let description = extractDescription(from: node)
			return [DeclSyntax(stringLiteral: generateEnumSchema(cases: cases, description: description))]
		}

		throw GenerableMacroError.unsupportedDeclaration
	}

	public static func expansion(
		of _: AttributeSyntax,
		attachedTo _: some DeclGroupSyntax,
		providingExtensionsOf type: some TypeSyntaxProtocol,
		conformingTo _: [TypeSyntax],
		in _: some MacroExpansionContext
	) throws -> [ExtensionDeclSyntax] {
		[
			try ExtensionDeclSyntax(
				"""
				extension \(type.trimmed): Generable {}
				"""
			)
		]
	}
}

private extension GenerableMacro {
	struct PropertyInfo {
		let name: String
		let schemaExpression: String
		let isOptional: Bool
	}

	struct GuideInfo {
		var description: String?
		var minimum: String?
		var maximum: String?
		var minimumCount: Int?
		var maximumCount: Int?
		var minimumLength: Int?
		var maximumLength: Int?
		var pattern: String?
		var format: String?
		var invalidFormat = false

		var hasNumericConstraints: Bool {
			minimum != nil || maximum != nil
		}

		var hasCountConstraints: Bool {
			minimumCount != nil || maximumCount != nil
		}

		var hasStringConstraints: Bool {
			pattern != nil || format != nil || minimumLength != nil || maximumLength != nil || invalidFormat
		}
	}

	enum PropertyKind {
		case string
		case boolean
		case integer
		case number
		case array
		case custom
	}

	enum GenerableMacroError: Error, CustomStringConvertible {
		case unsupportedDeclaration
		case unsupportedProperty(String)
		case unsupportedEnumCase(String)

		var description: String {
			switch self {
				case .unsupportedDeclaration:
					"@Generable only supports structs and enums."
				case let .unsupportedProperty(name):
					"@Generable could not synthesize a schema for property '\(name)'."
				case let .unsupportedEnumCase(name):
					"@Generable only supports enums without associated values. Unsupported case: '\(name)'."
			}
		}
	}

	enum GuideDiagnosticMessage: String, DiagnosticMessage {
		case unsupportedFormat
		case stringConstraintsRequireString
		case numericConstraintsRequireNumeric
		case countConstraintsRequireArray

		var message: String {
			switch self {
				case .unsupportedFormat:
					"@Guide format only supports .ipv4, .ipv6, .uuid, .date, .time, .email, .duration, .hostname, and .dateTime."
				case .stringConstraintsRequireString:
					"@Guide pattern, format, and length constraints only apply to String properties."
				case .numericConstraintsRequireNumeric:
					"@Guide numeric constraints only apply to Int, Double, or Float properties."
				case .countConstraintsRequireArray:
					"@Guide count constraints only apply to Array properties."
			}
		}

		var diagnosticID: MessageID {
			MessageID(domain: "RealtimeToolMacros", id: rawValue)
		}

		var severity: DiagnosticSeverity {
			.error
		}
	}

	static let supportedStringFormats: Set<String> = [
		".ipv4", ".ipv6", ".uuid", ".date", ".time", ".email", ".duration", ".hostname", ".dateTime",
		"JSONSchema.StringFormat.ipv4",
		"JSONSchema.StringFormat.ipv6",
		"JSONSchema.StringFormat.uuid",
		"JSONSchema.StringFormat.date",
		"JSONSchema.StringFormat.time",
		"JSONSchema.StringFormat.email",
		"JSONSchema.StringFormat.duration",
		"JSONSchema.StringFormat.hostname",
		"JSONSchema.StringFormat.dateTime",
	]

	static func extractDescription(from node: AttributeSyntax) -> String? {
		guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
			return nil
		}

		for argument in arguments {
			if argument.label?.text == "description",
			   let value = parseStringLiteral(argument.expression)
			{
				return value
			}

			if argument.label == nil,
			   let value = parseStringLiteral(argument.expression)
			{
				return value
			}
		}

		return nil
	}

	static func extractProperties(
		from structDecl: StructDeclSyntax,
		in context: some MacroExpansionContext
	) throws -> [PropertyInfo] {
		try structDecl.memberBlock.members.compactMap { member in
			guard let variable = member.decl.as(VariableDeclSyntax.self) else {
				return nil
			}

			guard let binding = variable.bindings.first,
			      let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
			      let typeAnnotation = binding.typeAnnotation
			else {
				return nil
			}

			let guide = extractGuideInfo(from: variable.attributes)
			let name = identifier.identifier.text
			let type = typeAnnotation.type.trimmedDescription
			let typeInfo = try schemaExpression(
				for: type,
				guide: guide,
				propertyName: name,
				diagnosticNode: Syntax(variable),
				in: context
			)
			return PropertyInfo(name: name, schemaExpression: typeInfo.schemaExpression, isOptional: typeInfo.isOptional)
		}
	}

	static func extractEnumCases(from enumDecl: EnumDeclSyntax) throws -> [String] {
		var cases: [String] = []

		for member in enumDecl.memberBlock.members {
			guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
				continue
			}

			for element in caseDecl.elements {
				if element.parameterClause != nil {
					throw GenerableMacroError.unsupportedEnumCase(element.name.text)
				}

				if let rawValue = element.rawValue {
					let rawText = rawValue.value.trimmedDescription
					if rawText.hasPrefix("\""), rawText.hasSuffix("\"") {
						cases.append(String(rawText.dropFirst().dropLast()))
						continue
					}
				}

				cases.append(element.name.text)
			}
		}

		return cases
	}

	static func extractGuideInfo(from attributes: AttributeListSyntax) -> GuideInfo {
		var info = GuideInfo()

		for attribute in attributes {
			guard let guide = attribute.as(AttributeSyntax.self),
			      guide.attributeName.trimmedDescription == "Guide",
			      let arguments = guide.arguments?.as(LabeledExprListSyntax.self)
			else {
				continue
			}

			for argument in arguments {
				if argument.label?.text == "description",
				   let value = parseStringLiteral(argument.expression)
				{
					info.description = value
					continue
				}

				guard argument.label == nil else { continue }

				if info.description == nil, let value = parseStringLiteral(argument.expression) {
					info.description = value
					continue
				}

				let expression = argument.expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
				if expression.hasPrefix(".range("), expression.hasSuffix(")") {
					let rangeText = String(expression.dropFirst(".range(".count).dropLast())
					let parts = rangeText.components(separatedBy: "...")
					if parts.count == 2 {
						info.minimum = parts[0]
						info.maximum = parts[1]
					}
					continue
				}

				if expression.hasPrefix(".minimum("), expression.hasSuffix(")") {
					info.minimum = String(expression.dropFirst(".minimum(".count).dropLast())
					continue
				}

				if expression.hasPrefix(".maximum("), expression.hasSuffix(")") {
					info.maximum = String(expression.dropFirst(".maximum(".count).dropLast())
					continue
				}

				if expression.hasPrefix(".count("), expression.hasSuffix(")") {
					let countText = String(expression.dropFirst(".count(".count).dropLast())
					let parts = countText.components(separatedBy: "...")
					if parts.count == 2 {
						info.minimumCount = Int(parts[0])
						info.maximumCount = Int(parts[1])
					} else if let count = Int(countText) {
						info.minimumCount = count
						info.maximumCount = count
					}
					continue
				}

				if expression.hasPrefix(".minimumCount("), expression.hasSuffix(")") {
					let value = String(expression.dropFirst(".minimumCount(".count).dropLast())
					info.minimumCount = Int(value)
					continue
				}

				if expression.hasPrefix(".maximumCount("), expression.hasSuffix(")") {
					let value = String(expression.dropFirst(".maximumCount(".count).dropLast())
					info.maximumCount = Int(value)
					continue
				}

				if expression.hasPrefix(".length("), expression.hasSuffix(")") {
					let lengthText = String(expression.dropFirst(".length(".count).dropLast())
					let parts = lengthText.components(separatedBy: "...")
					if parts.count == 2 {
						info.minimumLength = Int(parts[0])
						info.maximumLength = Int(parts[1])
					} else if let count = Int(lengthText) {
						info.minimumLength = count
						info.maximumLength = count
					}
					continue
				}

				if expression.hasPrefix(".minimumLength("), expression.hasSuffix(")") {
					let value = String(expression.dropFirst(".minimumLength(".count).dropLast())
					info.minimumLength = Int(value)
					continue
				}

				if expression.hasPrefix(".maximumLength("), expression.hasSuffix(")") {
					let value = String(expression.dropFirst(".maximumLength(".count).dropLast())
					info.maximumLength = Int(value)
					continue
				}

				if let pattern = parsePattern(from: argument.expression) {
					info.pattern = pattern
					continue
				}

				if let format = parseFormat(from: argument.expression) {
					info.format = format
					continue
				}

				if isFormatExpression(argument.expression) {
					info.invalidFormat = true
				}
			}
		}

		return info
	}

	static func schemaExpression(
		for type: String,
		guide: GuideInfo,
		propertyName: String,
		diagnosticNode: Syntax,
		in context: some MacroExpansionContext
	) throws -> (schemaExpression: String, isOptional: Bool) {
		let normalizedType = type.replacingOccurrences(of: " ", with: "")

		if normalizedType.hasSuffix("?") {
			let unwrapped = String(normalizedType.dropLast())
			let inner = try schemaExpression(
				for: unwrapped,
				guide: guide,
				propertyName: propertyName,
				diagnosticNode: diagnosticNode,
				in: context
			)
			return (inner.schemaExpression, true)
		}

		if normalizedType.hasPrefix("Optional<"), normalizedType.hasSuffix(">") {
			let unwrapped = String(normalizedType.dropFirst("Optional<".count).dropLast())
			let inner = try schemaExpression(
				for: unwrapped,
				guide: guide,
				propertyName: propertyName,
				diagnosticNode: diagnosticNode,
				in: context
			)
			return (inner.schemaExpression, true)
		}

		if normalizedType.hasPrefix("["), normalizedType.hasSuffix("]") {
			diagnoseGuide(guide, for: .array, at: diagnosticNode, in: context)
			let elementType = String(normalizedType.dropFirst().dropLast())
			let element = try schemaExpression(
				for: elementType,
				guide: .init(),
				propertyName: propertyName,
				diagnosticNode: diagnosticNode,
				in: context
			)
			return (
				".array(of: \(element.schemaExpression), minItems: \(sourceLiteral(guide.minimumCount)), maxItems: \(sourceLiteral(guide.maximumCount)), description: \(literal(guide.description)))",
				false
			)
		}

		if normalizedType.hasPrefix("Array<"), normalizedType.hasSuffix(">") {
			diagnoseGuide(guide, for: .array, at: diagnosticNode, in: context)
			let elementType = String(normalizedType.dropFirst("Array<".count).dropLast())
			let element = try schemaExpression(
				for: elementType,
				guide: .init(),
				propertyName: propertyName,
				diagnosticNode: diagnosticNode,
				in: context
			)
			return (
				".array(of: \(element.schemaExpression), minItems: \(sourceLiteral(guide.minimumCount)), maxItems: \(sourceLiteral(guide.maximumCount)), description: \(literal(guide.description)))",
				false
			)
		}

		let kind = propertyKind(for: normalizedType)
		diagnoseGuide(guide, for: kind, at: diagnosticNode, in: context)

		switch kind {
			case .string:
				return (
					".string(pattern: \(literal(guide.pattern)), format: \(sourceLiteral(guide.format)), minLength: \(sourceLiteral(guide.minimumLength)), maxLength: \(sourceLiteral(guide.maximumLength)), description: \(literal(guide.description)))",
					false
				)
			case .boolean:
				return (".boolean(description: \(literal(guide.description)))", false)
			case .integer:
				return (
					".integer(minimum: \(sourceLiteral(guide.minimum)), maximum: \(sourceLiteral(guide.maximum)), description: \(literal(guide.description)))",
					false
				)
			case .number:
				return (
					".number(minimum: \(sourceLiteral(guide.minimum)), maximum: \(sourceLiteral(guide.maximum)), description: \(literal(guide.description)))",
					false
				)
			case .array:
				throw GenerableMacroError.unsupportedProperty(propertyName)
			case .custom:
				return ("\(normalizedType).generationSchema.described(\(literal(guide.description)))", false)
		}
	}

	static func propertyKind(for normalizedType: String) -> PropertyKind {
		switch normalizedType {
			case "String":
				.string
			case "Bool":
				.boolean
			case "Int":
				.integer
			case "Double", "Float":
				.number
			default:
				.custom
		}
	}

	static func diagnoseGuide(
		_ guide: GuideInfo,
		for kind: PropertyKind,
		at node: Syntax,
		in context: some MacroExpansionContext
	) {
		if guide.invalidFormat {
			context.diagnose(Diagnostic(node: node, message: GuideDiagnosticMessage.unsupportedFormat))
		}

		if guide.hasCountConstraints, kind != .array {
			context.diagnose(Diagnostic(node: node, message: GuideDiagnosticMessage.countConstraintsRequireArray))
		}

		if guide.hasStringConstraints, kind != .string {
			context.diagnose(Diagnostic(node: node, message: GuideDiagnosticMessage.stringConstraintsRequireString))
		}

		if guide.hasNumericConstraints, kind != .integer, kind != .number {
			context.diagnose(Diagnostic(node: node, message: GuideDiagnosticMessage.numericConstraintsRequireNumeric))
		}
	}

	static func generateStructSchema(properties: [PropertyInfo], description: String?) -> String {
		let propertyLines = properties.map { property in
			"\"\(property.name)\": \(property.schemaExpression)"
		}.joined(separator: ",\n")

		let required = properties
			.filter { !$0.isOptional }
			.map { "\"\($0.name)\"" }
			.joined(separator: ", ")

		return """
		static var generationSchema: JSONSchema {
			.object(
				properties: [
					\(propertyLines)
				],
				required: [\(required)],
				description: \(literal(description))
			)
		}
		"""
	}

	static func generateEnumSchema(cases: [String], description: String?) -> String {
		let casesLiteral = cases.map { literal($0) }.joined(separator: ", ")
		return """
		static var generationSchema: JSONSchema {
			.enum(cases: [\(casesLiteral)], description: \(literal(description)))
		}
		"""
	}

	static func parseStringLiteral(_ expression: ExprSyntax) -> String? {
		guard let literal = expression.as(StringLiteralExprSyntax.self) else {
			return nil
		}

		return literal.segments.compactMap { segment in
			guard let stringSegment = segment.as(StringSegmentSyntax.self) else { return nil }
			return stringSegment.content.text
		}.joined()
	}

	static func literal(_ string: String?) -> String {
		guard let string else { return "nil" }
		let escaped = string
			.replacingOccurrences(of: "\\", with: "\\\\")
			.replacingOccurrences(of: "\"", with: "\\\"")
		return "\"\(escaped)\""
	}

	static func sourceLiteral(_ value: String?) -> String {
		value ?? "nil"
	}

	static func sourceLiteral(_ value: Int?) -> String {
		value.map(String.init) ?? "nil"
	}

	static func parsePattern(from expression: ExprSyntax) -> String? {
		guard let functionCall = expression.as(FunctionCallExprSyntax.self),
		      functionCall.calledExpression.trimmedDescription == ".pattern",
		      let firstArgument = functionCall.arguments.first
		else {
			return nil
		}

		return parseStringLiteral(firstArgument.expression)
	}

	static func parseFormat(from expression: ExprSyntax) -> String? {
		guard let functionCall = expression.as(FunctionCallExprSyntax.self),
		      functionCall.calledExpression.trimmedDescription == ".format",
		      let firstArgument = functionCall.arguments.first
		else {
			return nil
		}

		let rawFormat = firstArgument.expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
		guard supportedStringFormats.contains(rawFormat) else {
			return nil
		}

		return rawFormat
	}

	static func isFormatExpression(_ expression: ExprSyntax) -> Bool {
		guard let functionCall = expression.as(FunctionCallExprSyntax.self) else {
			return false
		}

		return functionCall.calledExpression.trimmedDescription == ".format"
	}
}
