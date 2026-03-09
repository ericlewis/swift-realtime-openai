public protocol Generable: Codable, Sendable {
	static var generationSchema: JSONSchema { get }
}

public struct GuideConstraint: Sendable {
	public static func count(_ count: Int) -> Self { Self() }
	public static func count(_ range: ClosedRange<Int>) -> Self { Self() }
	public static func length(_ count: Int) -> Self { Self() }
	public static func length(_ range: ClosedRange<Int>) -> Self { Self() }
	public static func minimumCount(_ count: Int) -> Self { Self() }
	public static func minimumLength(_ count: Int) -> Self { Self() }
	public static func maximumCount(_ count: Int) -> Self { Self() }
	public static func maximumLength(_ count: Int) -> Self { Self() }
	public static func minimum(_ value: Int) -> Self { Self() }
	public static func minimum(_ value: Double) -> Self { Self() }
	public static func minimum(_ value: Float) -> Self { Self() }
	public static func maximum(_ value: Int) -> Self { Self() }
	public static func maximum(_ value: Double) -> Self { Self() }
	public static func maximum(_ value: Float) -> Self { Self() }
	public static func range(_ range: ClosedRange<Int>) -> Self { Self() }
	public static func range(_ range: ClosedRange<Double>) -> Self { Self() }
	public static func range(_ range: ClosedRange<Float>) -> Self { Self() }
	public static func format(_ format: JSONSchema.StringFormat) -> Self { Self() }
	public static func pattern(_ value: String) -> Self { Self() }
}

@attached(member, names: named(generationSchema))
@attached(extension, conformances: Generable)
public macro Generable(description: String? = nil) = #externalMacro(
	module: "RealtimeToolMacrosImplementation",
	type: "GenerableMacro"
)

@attached(peer)
public macro Guide(description: String? = nil, _ constraints: GuideConstraint...) = #externalMacro(
	module: "RealtimeToolMacrosImplementation",
	type: "GuideMacro"
)
