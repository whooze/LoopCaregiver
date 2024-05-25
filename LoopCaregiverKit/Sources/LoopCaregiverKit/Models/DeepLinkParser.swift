//
//  DeepLinkParser.swift
//  LoopCaregiver
//
//  Created by Bill Gestrich on 10/17/23.
//

import Foundation

public class DeepLinkParser {
    public init() {
    }

    public func parseDeepLink(url: URL) throws -> DeepLinkAction {
        guard let action = url.host(percentEncoded: false) else {
            throw DeepLinkError.unsupportedURL(unsupportedURL: url)
        }

        let pathComponents = url.pathComponents.filter({ $0 != "/" })

            let queryParameters = convertQueryParametersToDictionary(from: url)

            if action == CreateLooperDeepLink.actionName {
                let deepLink = try CreateLooperDeepLink(pathParts: pathComponents, queryParameters: queryParameters)
                return .addLooper(deepLink: deepLink)
            } else if action == SelectLooperDeepLink.actionName {
                let deepLink = try SelectLooperDeepLink(pathParts: pathComponents, queryParameters: queryParameters)
                return .selectLooper(deepLink: deepLink)
            } else if action == RequestWatchConfigurationDeepLink.actionName {
                let deepLink = try RequestWatchConfigurationDeepLink(pathParts: pathComponents, queryParameters: queryParameters)
                return .requestWatchConfigurationDeepLink(deepLink: deepLink)
            } else {
                throw DeepLinkError.unknownAction(actionName: action)
            }
        }

    private func convertQueryParametersToDictionary(from url: URL) -> [String: String] {
        var queryDict = [String: String]()

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let queryItems = components.queryItems {
                for item in queryItems {
                    queryDict[item.name] = item.value ?? ""
                }
            }
        }

        return queryDict
    }

    enum DeepLinkError: LocalizedError {
        case unsupportedURL(unsupportedURL: URL)
        case unknownAction(actionName: String)

        var errorDescription: String? {
            switch self {
            case .unsupportedURL(let url):
                return "Unsupported URL: \(url)"
            case .unknownAction(let actionName):
                return "Unknown Action: \(actionName)"
            }
        }
    }
}

public enum DeepLinkAction {
    case selectLooper(deepLink: SelectLooperDeepLink)
    case addLooper(deepLink: CreateLooperDeepLink)
    case requestWatchConfigurationDeepLink(deepLink: RequestWatchConfigurationDeepLink)
}

public protocol DeepLink {
    var host: String { get }
    static var actionName: String { get }
    
    func toURL() throws -> URL
}

public extension DeepLink {
    var host: String {
        return "caregiver"
    }
}

public struct SelectLooperDeepLink: DeepLink {
    public let looperUUID: String

    public init(looperUUID: String) {
        self.looperUUID = looperUUID
    }

    public init(pathParts: [String], queryParameters: [String: String]) throws {
        guard let uuid = pathParts.first, !uuid.isEmpty else {
            throw SelectLooperDeepLink.SelectLooperDeepLinkError.widgetConfigurationRequired
        }
        self = SelectLooperDeepLink(looperUUID: uuid)
    }

    public func toURL() -> URL {
        return URL(string: "\(host)://\(Self.actionName)/\(looperUUID)")!
    }

    public static let actionName = "selectLooper"

    enum SelectLooperDeepLinkError: LocalizedError {
        case widgetConfigurationRequired

        var errorDescription: String? {
            switch self {
            case .widgetConfigurationRequired:
                return "This widget requires configuration."
            }
        }
    }
}

public struct CreateLooperDeepLink: DeepLink {
    public let name: String
    public let nsURL: URL
    public let secretKey: String
    public let otpURL: URL

    public static let actionName = "createLooper"

    public init(name: String, nsURL: URL, secretKey: String, otpURL: URL) {
        self.name = name
        self.nsURL = nsURL
        self.secretKey = secretKey
        self.otpURL = otpURL
    }

    public init(pathParts: [String], queryParameters: [String: String]) throws {
        guard let name = queryParameters["name"], !name.isEmpty else {
            throw CreateLooperDeepLinkError.missingName
        }

        guard let nightscoutURLString = queryParameters["nsURL"]?.removingPercentEncoding?.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
              let nightscoutURL = URL(string: nightscoutURLString)
        else {
            throw CreateLooperDeepLinkError.missingNSURL
        }

        guard let apiSecret = queryParameters["secretKey"]?.trimmingCharacters(in: .whitespacesAndNewlines), !apiSecret.isEmpty else {
            throw CreateLooperDeepLinkError.missingNSSecretKey
        }

        guard let otpURLString = queryParameters["otpURL"]?.removingPercentEncoding, !otpURLString.isEmpty,
        let otpURL = URL(string: otpURLString)
        else {
            throw CreateLooperDeepLinkError.missingOTPURL
        }

        self = CreateLooperDeepLink(name: name, nsURL: nightscoutURL, secretKey: apiSecret, otpURL: otpURL)
    }

    public func toURL() throws -> URL {
        guard let otpURL = otpURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            throw CreateLooperDeepLinkError.urlEncodingError(url: otpURL.absoluteString)
        }
        guard let nsURL = nsURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            throw CreateLooperDeepLinkError.urlEncodingError(url: nsURL.absoluteString)
        }
        // TODO: The date is appended to each deep link to ensure we have a unique message received by the watch each time.
        // See https://stackoverflow.com/a/47915741
        return URL(string: "\(host)://\(Self.actionName)?name=\(name)&secretKey=\(secretKey)&nsURL=\(nsURL)&otpURL=\(otpURL)&createdDate=\(Date())")!
    }

    enum CreateLooperDeepLinkError: LocalizedError, Equatable {
        case missingOTPURL
        case missingName
        case missingNSSecretKey
        case missingNSURL
        case urlEncodingError(url: String)

        var errorDescription: String? {
            switch self {
            case .missingName:
                return "Include the Loopers name in the URL"
            case .missingNSSecretKey:
                return "Include the NS secret key in the URL"
            case .missingNSURL:
                return "Include the NS URL in the URL"
            case .missingOTPURL:
                return "Include the OTP URL in the URL"
            case .urlEncodingError(let url):
                return "Could not URL encode the URL: \(url)"
            }
        }
    }
}

public struct RequestWatchConfigurationDeepLink: DeepLink {
    public init() {
    }

    public init(pathParts: [String], queryParameters: [String: String]) throws {
        self = RequestWatchConfigurationDeepLink()
    }

    public func toURL() -> URL {
        // TODO: The date is appended to each deep link to ensure we have a unique message received by the watch each time.
        return URL(string: "\(host)://\(Self.actionName)?createdDate=\(Date())")!
    }

    public static let actionName = "requestWatchConfiguration"
}
