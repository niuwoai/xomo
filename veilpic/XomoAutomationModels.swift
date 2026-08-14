//
//  XomoAutomationModels.swift
//  veilpic
//

import Foundation

enum XomoJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: XomoJSONValue])
    case array([XomoJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: XomoJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([XomoJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var doubleValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    var objectValue: [String: XomoJSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var arrayValue: [XomoJSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }
}

struct XomoAutomationToolDefinition: Codable, Equatable, Sendable {
    let name: String
    let description: String
    let inputSchema: XomoJSONValue
}

struct XomoAutomationEndpoint: Codable, Sendable {
    let host: String
    let port: UInt16
    let token: String
    let pid: Int32
    let version: String
}

struct XomoAutomationWireRequest: Codable, Sendable {
    let token: String
    let operation: String
    let name: String?
    let arguments: [String: XomoJSONValue]?
}

struct XomoAutomationWireResponse: Codable, Sendable {
    let ok: Bool
    let result: XomoJSONValue?
    let error: String?

    static func success(_ result: XomoJSONValue) -> Self {
        Self(ok: true, result: result, error: nil)
    }

    static func failure(_ error: String) -> Self {
        Self(ok: false, result: nil, error: error)
    }
}

enum XomoAutomationSchema {
    static func object(
        properties: [String: XomoJSONValue] = [:],
        required: [String] = []
    ) -> XomoJSONValue {
        var schema: [String: XomoJSONValue] = [
            "type": .string("object"),
            "properties": .object(properties),
            "additionalProperties": .bool(false)
        ]
        if !required.isEmpty {
            schema["required"] = .array(required.map(XomoJSONValue.string))
        }
        return .object(schema)
    }

    static func string(description: String, values: [String] = []) -> XomoJSONValue {
        var schema: [String: XomoJSONValue] = [
            "type": .string("string"),
            "description": .string(description)
        ]
        if !values.isEmpty {
            schema["enum"] = .array(values.map(XomoJSONValue.string))
        }
        return .object(schema)
    }

    static func number(
        description: String,
        minimum: Double? = nil,
        maximum: Double? = nil
    ) -> XomoJSONValue {
        var schema: [String: XomoJSONValue] = [
            "type": .string("number"),
            "description": .string(description)
        ]
        if let minimum {
            schema["minimum"] = .number(minimum)
        }
        if let maximum {
            schema["maximum"] = .number(maximum)
        }
        return .object(schema)
    }

    static func integer(
        description: String,
        minimum: Int? = nil,
        maximum: Int? = nil
    ) -> XomoJSONValue {
        var schema: [String: XomoJSONValue] = [
            "type": .string("integer"),
            "description": .string(description)
        ]
        if let minimum {
            schema["minimum"] = .number(Double(minimum))
        }
        if let maximum {
            schema["maximum"] = .number(Double(maximum))
        }
        return .object(schema)
    }

    static func boolean(description: String) -> XomoJSONValue {
        .object(["type": .string("boolean"), "description": .string(description)])
    }
}
