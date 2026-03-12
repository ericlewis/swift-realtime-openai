import Foundation

private struct AnyEncodableBox: Encodable {
	let value: any Encodable

	func encode(to encoder: any Encoder) throws {
		try value.encode(to: encoder)
	}
}

private func _jsonObject(from value: any Encodable) throws -> Any {
	let data = try JSONEncoder().encode(AnyEncodableBox(value: value))
	return try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
}

private func _jsonString(from value: Any) -> String? {
	switch value {
		case is NSNull:
			return "null"
		case let string as String:
			let escaped = string
				.replacingOccurrences(of: "\\", with: "\\\\")
				.replacingOccurrences(of: "\"", with: "\\\"")
				.replacingOccurrences(of: "\n", with: "\\n")
				.replacingOccurrences(of: "\r", with: "\\r")
				.replacingOccurrences(of: "\t", with: "\\t")
			return "\"\(escaped)\""
		case let bool as Bool:
			return bool ? "true" : "false"
		case let int as Int:
			return String(int)
		case let double as Double:
			return String(double)
		case let float as Float:
			return String(float)
		case let array as [Any]:
			let values = array.compactMap(_jsonString(from:))
			guard values.count == array.count else { return nil }
			return "[\(values.joined(separator: ","))]"
		case let dictionary as [String: Any]:
			let pairs = dictionary.keys.sorted().compactMap { key -> String? in
				guard let value = dictionary[key], let encoded = _jsonString(from: value) else { return nil }
				return "\"\(key)\":\(encoded)"
			}
			guard pairs.count == dictionary.count else { return nil }
			return "{\(pairs.joined(separator: ","))}"
		default:
			return nil
	}
}

private func _generatedContentObject(from value: any Encodable, includeNilValues: Bool) throws -> Any {
	if let string = value as? String { return string }
	if let bool = value as? Bool { return bool }
	if let int = value as? Int { return int }
	if let double = value as? Double { return double }
	if let float = value as? Float { return float }

	let mirror = Mirror(reflecting: value)

	switch mirror.displayStyle {
		case .optional:
			guard let child = mirror.children.first else { return NSNull() }
			guard let encodable = child.value as? any Encodable else { return NSNull() }
			return try _generatedContentObject(from: encodable, includeNilValues: includeNilValues)

		case .collection, .set:
			return try mirror.children.compactMap { child -> Any? in
				guard let encodable = child.value as? any Encodable else { return nil }
				return try _generatedContentObject(from: encodable, includeNilValues: includeNilValues)
			}

		case .dictionary:
			var object: [String: Any] = [:]

			for child in mirror.children {
				let entryMirror = Mirror(reflecting: child.value)
				let entryChildren = Array(entryMirror.children)
				guard entryChildren.count == 2,
				      let key = entryChildren[0].value as? String,
				      let value = entryChildren[1].value as? any Encodable
				else {
					continue
				}

				object[key] = try _generatedContentObject(from: value, includeNilValues: includeNilValues)
			}

			return object

		case .struct, .class:
			var object: [String: Any] = [:]

			for child in mirror.children {
				guard let label = child.label else { continue }

				let childMirror = Mirror(reflecting: child.value)
				if childMirror.displayStyle == .optional, childMirror.children.isEmpty {
					// `representNilExplicitlyInGeneratedContent` opts into preserving explicit
					// nulls instead of dropping missing optional fields from generated content.
					if includeNilValues {
						object[label] = NSNull()
					}
					continue
				}

				guard let encodable = child.value as? any Encodable else { continue }
				object[label] = try _generatedContentObject(from: encodable, includeNilValues: includeNilValues)
			}

			return object

		default:
			return try _jsonObject(from: value)
	}
}

private func _generatedContentText<T: Encodable>(_ value: T) -> String {
	do {
		let data = try JSONEncoder().encode(value)
		return String(data: data, encoding: .utf8) ?? String(describing: value)
	} catch {
		return String(describing: value)
	}
}

public extension ConvertibleToGeneratedContent where Self: PromptRepresentable {
	var instructionsRepresentation: Instructions {
		Instructions(promptRepresentation.text)
	}
}

public extension Generable {
	/// Renders generated content into a prompt-oriented textual form.
	///
	/// If a generated type opts into explicit nil representation, optional properties that are
	/// `nil` are preserved as JSON `null` values in the resulting text.
	var promptRepresentation: Prompt {
		if Self.representNilExplicitlyInGeneratedContent,
		   let object = try? _generatedContentObject(from: self, includeNilValues: true),
		   let text = _jsonString(from: object)
		{
			return Prompt(text)
		}

		return Prompt(_generatedContentText(self))
	}
}

extension String: ConvertibleFromGeneratedContent, ConvertibleToGeneratedContent {}
extension Bool: ConvertibleFromGeneratedContent, PromptRepresentable, ConvertibleToGeneratedContent {
	public var promptRepresentation: Prompt {
		Prompt(String(self))
	}
}
extension Int: ConvertibleFromGeneratedContent, PromptRepresentable, ConvertibleToGeneratedContent {
	public var promptRepresentation: Prompt {
		Prompt(String(self))
	}
}
extension Double: ConvertibleFromGeneratedContent, PromptRepresentable, ConvertibleToGeneratedContent {
	public var promptRepresentation: Prompt {
		Prompt(String(self))
	}
}
extension Float: ConvertibleFromGeneratedContent, PromptRepresentable, ConvertibleToGeneratedContent {
	public var promptRepresentation: Prompt {
		Prompt(String(self))
	}
}
extension Prompt: ConvertibleToGeneratedContent {}
extension Array: ConvertibleFromGeneratedContent where Element: ConvertibleFromGeneratedContent {}
extension Array: PromptRepresentable where Element: Encodable {
	public var promptRepresentation: Prompt {
		Prompt(_generatedContentText(self))
	}
}
extension Dictionary: ConvertibleFromGeneratedContent where Key == String, Value: ConvertibleFromGeneratedContent {}
extension Dictionary: PromptRepresentable where Key == String, Value: Encodable {
	public var promptRepresentation: Prompt {
		Prompt(_generatedContentText(self))
	}
}
