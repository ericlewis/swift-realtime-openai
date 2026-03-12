/// A type that can be decoded from generated content returned by a model or tool.
public protocol ConvertibleFromGeneratedContent: Decodable, Sendable {}

/// A type that can render itself as prompt and instructions content.
public protocol ConvertibleToGeneratedContent: InstructionsRepresentable, PromptRepresentable, Sendable {}

/// A schema-generating type used for tool arguments and generated content modeling.
public protocol Generable: Codable, ConvertibleFromGeneratedContent, ConvertibleToGeneratedContent {
	static var generationSchema: GenerationSchema { get }
	static var representNilExplicitlyInGeneratedContent: Bool { get }
}

public extension Generable {
	static var representNilExplicitlyInGeneratedContent: Bool {
		false
	}
}

/// A typed guide value used by the `@Guide` macro surface.
public struct GenerationGuide<Value>: Sendable {
	fileprivate init() {}
}

public typealias GuideConstraint = GenerationGuide<Never>

public extension GenerationGuide where Value == Never {
	static func count(_ count: Int) -> GuideConstraint { .init() }
	static func count(_ range: ClosedRange<Int>) -> GuideConstraint { .init() }
	static func length(_ count: Int) -> GuideConstraint { .init() }
	static func length(_ range: ClosedRange<Int>) -> GuideConstraint { .init() }
	static func minimumCount(_ count: Int) -> GuideConstraint { .init() }
	static func minimumLength(_ count: Int) -> GuideConstraint { .init() }
	static func maximumCount(_ count: Int) -> GuideConstraint { .init() }
	static func maximumLength(_ count: Int) -> GuideConstraint { .init() }
	static func minimum(_ value: Int) -> GuideConstraint { .init() }
	static func minimum(_ value: Double) -> GuideConstraint { .init() }
	static func minimum(_ value: Float) -> GuideConstraint { .init() }
	static func maximum(_ value: Int) -> GuideConstraint { .init() }
	static func maximum(_ value: Double) -> GuideConstraint { .init() }
	static func maximum(_ value: Float) -> GuideConstraint { .init() }
	static func range(_ range: ClosedRange<Int>) -> GuideConstraint { .init() }
	static func range(_ range: ClosedRange<Double>) -> GuideConstraint { .init() }
	static func range(_ range: ClosedRange<Float>) -> GuideConstraint { .init() }
	static func format(_ format: GenerationSchema.StringFormat) -> GuideConstraint { .init() }
	static func pattern(_ value: String) -> GuideConstraint { .init() }
	static func pattern<RegexOutput>(_ regex: Regex<RegexOutput>) -> GuideConstraint { .init() }
	static func constant(_ value: String) -> GuideConstraint { .init() }
	static func anyOf(_ values: [String]) -> GuideConstraint { .init() }
	static func element<Element>(_ guide: GenerationGuide<Element>) -> GuideConstraint { .init() }
}

@attached(member, names: named(generationSchema), named(representNilExplicitlyInGeneratedContent))
@attached(extension, conformances: Generable)
public macro Generable(description: String? = nil) = #externalMacro(
	module: "RealtimeToolMacrosImplementation",
	type: "GenerableMacro"
)

@attached(member, names: named(generationSchema), named(representNilExplicitlyInGeneratedContent))
@attached(extension, conformances: Generable)
public macro Generable(
	description: String? = nil,
	representNilExplicitlyInGeneratedContent: Bool
) = #externalMacro(
	module: "RealtimeToolMacrosImplementation",
	type: "GenerableMacro"
)

@attached(peer)
public macro Guide(description: String? = nil, _ constraints: GuideConstraint...) = #externalMacro(
	module: "RealtimeToolMacrosImplementation",
	type: "GuideMacro"
)

@attached(peer)
public macro Guide<RegexOutput>(description: String? = nil, _ regex: Regex<RegexOutput>) = #externalMacro(
	module: "RealtimeToolMacrosImplementation",
	type: "GuideMacro"
)
