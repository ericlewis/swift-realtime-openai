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
		let description = extractDescription(from: node)
		let representNilExplicitly = extractRepresentNilSetting(from: node)
		var members: [String] = []

		if let structDecl = declaration.as(StructDeclSyntax.self) {
			let properties = try extractProperties(from: structDecl, in: context)
			members.append(generateStructSchema(properties: properties, description: description))
		} else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
			let cases = try extractEnumCases(from: enumDecl)
			members.append(generateEnumSchema(cases: cases, description: description))
		} else {
			throw GenerableMacroError.unsupportedDeclaration
		}

		if let representNilExplicitly {
			members.append(generateRepresentNilProperty(representNilExplicitly))
		}

		return members.map { DeclSyntax(stringLiteral: $0) }
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

	final class GuideInfo {
		var description: String?
		var minimum: String?
		var maximum: String?
		var minimumCount: Int?
		var maximumCount: Int?
		var minimumLength: Int?
		var maximumLength: Int?
		var pattern: String?
		var format: String?
		var constant: String?
		var anyOf: [String]?
		var elementGuide: GuideInfo?
		var invalidFormat = false

		var hasNumericConstraints: Bool {
			minimum != nil || maximum != nil
		}

		var hasCountConstraints: Bool {
			minimumCount != nil || maximumCount != nil
		}

		var hasStringConstraints: Bool {
			pattern != nil ||
				format != nil ||
				minimumLength != nil ||
				maximumLength != nil ||
				constant != nil ||
				anyOf != nil ||
				invalidFormat
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
		case elementConstraintsRequireArray

		var message: String {
			switch self {
				case .unsupportedFormat:
					"@Guide format only supports .ipv4, .ipv6, .uuid, .date, .time, .email, .duration, .hostname, and .dateTime."
				case .stringConstraintsRequireString:
					"@Guide pattern, format, length, constant, and anyOf constraints only apply to String properties."
				case .numericConstraintsRequireNumeric:
					"@Guide numeric constraints only apply to Int, Double, or Float properties."
				case .countConstraintsRequireArray:
					"@Guide count constraints only apply to Array properties."
				case .elementConstraintsRequireArray:
					"@Guide element constraints only apply to Array properties."
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
		".ipv4",
		".ipv6",
		".uuid",
		".date",
		".time",
		".email",
		".duration",
		".hostname",
		".dateTime",
		"GenerationSchema.StringFormat.ipv4",
		"GenerationSchema.StringFormat.ipv6",
		"GenerationSchema.StringFormat.uuid",
		"GenerationSchema.StringFormat.date",
		"GenerationSchema.StringFormat.time",
		"GenerationSchema.StringFormat.email",
		"GenerationSchema.StringFormat.duration",
		"GenerationSchema.StringFormat.hostname",
		"GenerationSchema.StringFormat.dateTime",
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

	static func extractRepresentNilSetting(from node: AttributeSyntax) -> Bool? {
		guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
			return nil
		}

		for argument in arguments where argument.label?.text == "representNilExplicitlyInGeneratedContent" {
			switch argument.expression.trimmedDescription {
				case "true":
					return true
				case "false":
					return false
				default:
					return nil
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

				applyGuideConstraint(from: argument.expression, to: &info)
			}
		}

		return info
	}

	static func applyGuideConstraint(from expression: ExprSyntax, to info: inout GuideInfo) {
		if let pattern = parseRegexLiteral(from: expression) {
			info.pattern = pattern
			return
		}

		let normalized = expression.trimmedDescription.replacingOccurrences(of: " ", with: "")

		if normalized.hasPrefix(".range("), normalized.hasSuffix(")") {
			let rangeText = String(normalized.dropFirst(".range(".count).dropLast())
			let parts = rangeText.components(separatedBy: "...")
			if parts.count == 2 {
				info.minimum = parts[0]
				info.maximum = parts[1]
			}
			return
		}

		if normalized.hasPrefix(".minimum("), normalized.hasSuffix(")") {
			info.minimum = String(normalized.dropFirst(".minimum(".count).dropLast())
			return
		}

		if normalized.hasPrefix(".maximum("), normalized.hasSuffix(")") {
			info.maximum = String(normalized.dropFirst(".maximum(".count).dropLast())
			return
		}

		if normalized.hasPrefix(".count("), normalized.hasSuffix(")") {
			let countText = String(normalized.dropFirst(".count(".count).dropLast())
			let parts = countText.components(separatedBy: "...")
			if parts.count == 2 {
				info.minimumCount = Int(parts[0])
				info.maximumCount = Int(parts[1])
			} else if let count = Int(countText) {
				info.minimumCount = count
				info.maximumCount = count
			}
			return
		}

		if normalized.hasPrefix(".minimumCount("), normalized.hasSuffix(")") {
			let value = String(normalized.dropFirst(".minimumCount(".count).dropLast())
			info.minimumCount = Int(value)
			return
		}

		if normalized.hasPrefix(".maximumCount("), normalized.hasSuffix(")") {
			let value = String(normalized.dropFirst(".maximumCount(".count).dropLast())
			info.maximumCount = Int(value)
			return
		}

		if normalized.hasPrefix(".length("), normalized.hasSuffix(")") {
			let lengthText = String(normalized.dropFirst(".length(".count).dropLast())
			let parts = lengthText.components(separatedBy: "...")
			if parts.count == 2 {
				info.minimumLength = Int(parts[0])
				info.maximumLength = Int(parts[1])
			} else if let count = Int(lengthText) {
				info.minimumLength = count
				info.maximumLength = count
			}
			return
		}

		if normalized.hasPrefix(".minimumLength("), normalized.hasSuffix(")") {
			let value = String(normalized.dropFirst(".minimumLength(".count).dropLast())
			info.minimumLength = Int(value)
			return
		}

		if normalized.hasPrefix(".maximumLength("), normalized.hasSuffix(")") {
			let value = String(normalized.dropFirst(".maximumLength(".count).dropLast())
			info.maximumLength = Int(value)
			return
		}

		if let pattern = parsePattern(from: expression) {
			info.pattern = pattern
			return
		}

		if let format = parseFormat(from: expression) {
			info.format = format
			return
		}

		if let constant = parseConstant(from: expression) {
			info.constant = constant
			return
		}

		if let values = parseAnyOf(from: expression) {
			info.anyOf = values
			return
		}

		if let nestedExpression = parseElementConstraint(from: expression) {
			var nestedGuide = GuideInfo()
			applyGuideConstraint(from: nestedExpression, to: &nestedGuide)
			info.elementGuide = nestedGuide
			return
		}

		if isFormatExpression(expression) {
			info.invalidFormat = true
		}
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
				guide: guide.elementGuide ?? .init(),
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
				guide: guide.elementGuide ?? .init(),
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
				if let constant = guide.constant {
					return (".enum(cases: [\(literal(constant))], description: \(literal(guide.description)))", false)
				}
				if let values = guide.anyOf {
					let cases = values.map(literal).joined(separator: ", ")
					return (".enum(cases: [\(cases)], description: \(literal(guide.description)))", false)
				}
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

		if guide.elementGuide != nil, kind != .array {
			context.diagnose(Diagnostic(node: node, message: GuideDiagnosticMessage.elementConstraintsRequireArray))
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
		static var generationSchema: GenerationSchema {
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
		let casesLiteral = cases.map(literal).joined(separator: ", ")
		return """
		static var generationSchema: GenerationSchema {
			.enum(cases: [\(casesLiteral)], description: \(literal(description)))
		}
		"""
	}

	static func generateRepresentNilProperty(_ value: Bool) -> String {
		"""
		static var representNilExplicitlyInGeneratedContent: Bool {
			\(value ? "true" : "false")
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

		return parseStringLiteral(firstArgument.expression) ?? parseRegexLiteral(from: firstArgument.expression)
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

	static func parseConstant(from expression: ExprSyntax) -> String? {
		guard let functionCall = expression.as(FunctionCallExprSyntax.self),
		      functionCall.calledExpression.trimmedDescription == ".constant",
		      let firstArgument = functionCall.arguments.first
		else {
			return nil
		}

		return parseStringLiteral(firstArgument.expression)
	}

	static func parseAnyOf(from expression: ExprSyntax) -> [String]? {
		guard let functionCall = expression.as(FunctionCallExprSyntax.self),
		      functionCall.calledExpression.trimmedDescription == ".anyOf",
		      let firstArgument = functionCall.arguments.first,
		      let array = firstArgument.expression.as(ArrayExprSyntax.self)
		else {
			return nil
		}

		let values = array.elements.compactMap { parseStringLiteral($0.expression) }
		return values.count == array.elements.count ? values : nil
	}

	static func parseElementConstraint(from expression: ExprSyntax) -> ExprSyntax? {
		guard let functionCall = expression.as(FunctionCallExprSyntax.self),
		      functionCall.calledExpression.trimmedDescription == ".element",
		      let firstArgument = functionCall.arguments.first
		else {
			return nil
		}

		return firstArgument.expression
	}

	static func parseRegexLiteral(from expression: ExprSyntax) -> String? {
		let text = expression.trimmedDescription

		if text.hasPrefix("/"), text.hasSuffix("/"), text.count >= 2 {
			return String(text.dropFirst().dropLast())
		}

		let hashCount = text.prefix { $0 == "#" }.count
		guard hashCount > 0 else { return nil }

		let prefix = String(repeating: "#", count: hashCount) + "/"
		let suffix = "/" + String(repeating: "#", count: hashCount)
		guard text.hasPrefix(prefix), text.hasSuffix(suffix) else { return nil }

		return String(text.dropFirst(prefix.count).dropLast(suffix.count))
	}
}
