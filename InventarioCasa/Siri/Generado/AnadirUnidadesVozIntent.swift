//
// AnadirUnidadesVozIntent.swift
//
// This file was automatically generated and should not be edited.
//

#if canImport(Intents)

import Intents

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(AnadirUnidadesVozIntent)
internal class AnadirUnidadesVozIntent: INIntent {

    @NSManaged internal var producto: String?
    @NSManaged internal var pregunta: String?
    @NSManaged internal var unidades: NSNumber?

}

/*!
 @abstract Protocol to declare support for handling a AnadirUnidadesVozIntent. By implementing this protocol, a class can provide logic for resolving, confirming and handling the intent.
 @discussion The minimum requirement for an implementing class is that it should be able to handle the intent. The confirmation method is optional. The handling method is always called last, after confirming the intent.
 */
@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(AnadirUnidadesVozIntentHandling)
internal protocol AnadirUnidadesVozIntentHandling: NSObjectProtocol {

    @available(*, renamed: "handle(intent:)")
    @objc(handleAnadirUnidadesVoz:completion:)
    func handle(intent: AnadirUnidadesVozIntent, completion: @escaping (AnadirUnidadesVozIntentResponse) -> Swift.Void)
    
    /*!
     @abstract Handling method - Execute the task represented by the AnadirUnidadesVozIntent that's passed in
     @discussion Called to actually execute the intent. The app must return a response for this intent.

     @param  intent The input intent
     @param  completion The response handling block takes a AnadirUnidadesVozIntentResponse containing the details of the result of having executed the intent

     @see  AnadirUnidadesVozIntentResponse
     */
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(handleAnadirUnidadesVoz:completion:)
    func handle(intent: AnadirUnidadesVozIntent) async -> AnadirUnidadesVozIntentResponse

    /*!
     @abstract Resolution methods - Determine if this intent is ready for the next step (confirmation)
     @discussion Called to make sure the app extension is capable of handling this intent in its current form. This method is for validating if the intent needs any further fleshing out.

     @param  intent The input intent
     @param  completion The response block contains an INIntentResolutionResult for the parameter being resolved

     @see INIntentResolutionResult
     */
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @available(*, renamed: "resolveProducto(for:)")
    @objc(resolveProductoForAnadirUnidadesVoz:withCompletion:)
    func resolveProducto(for intent: AnadirUnidadesVozIntent, with completion: @escaping (AnadirUnidadesVozProductoResolutionResult) -> Swift.Void)

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(resolveProductoForAnadirUnidadesVoz:withCompletion:)
    func resolveProducto(for intent: AnadirUnidadesVozIntent) async -> AnadirUnidadesVozProductoResolutionResult

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @available(*, renamed: "resolvePregunta(for:)")
    @objc(resolvePreguntaForAnadirUnidadesVoz:withCompletion:)
    func resolvePregunta(for intent: AnadirUnidadesVozIntent, with completion: @escaping (INStringResolutionResult) -> Swift.Void)

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(resolvePreguntaForAnadirUnidadesVoz:withCompletion:)
    func resolvePregunta(for intent: AnadirUnidadesVozIntent) async -> INStringResolutionResult

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @available(*, renamed: "resolveUnidades(for:)")
    @objc(resolveUnidadesForAnadirUnidadesVoz:withCompletion:)
    func resolveUnidades(for intent: AnadirUnidadesVozIntent, with completion: @escaping (AnadirUnidadesVozUnidadesResolutionResult) -> Swift.Void)

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(resolveUnidadesForAnadirUnidadesVoz:withCompletion:)
    func resolveUnidades(for intent: AnadirUnidadesVozIntent) async -> AnadirUnidadesVozUnidadesResolutionResult

    @available(*, renamed: "confirm(intent:)")
    @objc(confirmAnadirUnidadesVoz:completion:)
    optional func confirm(intent: AnadirUnidadesVozIntent, completion: @escaping (AnadirUnidadesVozIntentResponse) -> Swift.Void)

    /*!
     @abstract Confirmation method - Validate that this intent is ready for the next step (i.e. handling)
     @discussion Called prior to asking the app to handle the intent. The app should return a response object that contains additional information about the intent, which may be relevant for the system to show the user prior to handling. If unimplemented, the system will assume the intent is valid, and will assume there is no additional information relevant to this intent.

     @param  intent The input intent
     @param  completion The response block contains a AnadirUnidadesVozIntentResponse containing additional details about the intent that may be relevant for the system to show the user prior to handling.

     @see AnadirUnidadesVozIntentResponse
     */
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(confirmAnadirUnidadesVoz:completion:)
    optional func confirm(intent: AnadirUnidadesVozIntent) async -> AnadirUnidadesVozIntentResponse

}

/*!
 @abstract Constants indicating the state of the response.
 */
@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc internal enum AnadirUnidadesVozIntentResponseCode: Int {
    case unspecified = 0
    case ready
    case continueInApp
    case inProgress
    case success
    case failure
    case failureRequiringAppLaunch
}

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(AnadirUnidadesVozIntentResponse)
internal class AnadirUnidadesVozIntentResponse: INIntentResponse {

    @NSManaged internal var texto: String?

    /*!
     @abstract The response code indicating your success or failure in confirming or handling the intent.
     */
    @objc internal fileprivate(set) var code: AnadirUnidadesVozIntentResponseCode = .unspecified

    /*!
     @abstract Initializes the response object with the specified code and user activity object.
     @discussion The app extension has the option of capturing its private state as an NSUserActivity and returning it as the 'currentActivity'. If the app is launched, an NSUserActivity will be passed in with the private state. The NSUserActivity may also be used to query the app's UI extension (if provided) for a view controller representing the current intent handling state. In the case of app launch, the NSUserActivity will have its activityType set to the name of the intent. This intent object will also be available in the NSUserActivity.interaction property.

     @param  code The response code indicating your success or failure in confirming or handling the intent.
     @param  userActivity The user activity object to use when launching your app. Provide an object if you want to add information that is specific to your app. If you specify nil, the system automatically creates a user activity object for you, sets its type to the class name of the intent being handled, and fills it with an INInteraction object containing the intent and your response.
     */
    @objc(initWithCode:userActivity:)
    internal convenience init(code: AnadirUnidadesVozIntentResponseCode, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }

    /*!
     @abstract Initializes and returns the response object with the success code.
     */
    @objc(successIntentResponseWithTexto:)
    internal static func success(texto: String) -> AnadirUnidadesVozIntentResponse {
        let intentResponse = AnadirUnidadesVozIntentResponse(code: .success, userActivity: nil)
        intentResponse.texto = texto
        return intentResponse
    }

    /*!
     @abstract Initializes and returns the response object with the failure code.
     */
    @objc(failureIntentResponseWithTexto:)
    internal static func failure(texto: String) -> AnadirUnidadesVozIntentResponse {
        let intentResponse = AnadirUnidadesVozIntentResponse(code: .failure, userActivity: nil)
        intentResponse.texto = texto
        return intentResponse
    }

}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc internal enum AnadirUnidadesVozProductoUnsupportedReason: Int {
    case noEncontrado = 1
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc(AnadirUnidadesVozProductoResolutionResult)
internal class AnadirUnidadesVozProductoResolutionResult: INStringResolutionResult {
    @objc(unsupportedForReason:)
    internal class func unsupported(forReason reason: AnadirUnidadesVozProductoUnsupportedReason) -> Self {
        return __unsupported(withReason: reason.rawValue)
    }
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc internal enum AnadirUnidadesVozUnidadesUnsupportedReason: Int {
    case negativeNumbersNotSupported = 1
    case greaterThanMaximumValue
    case lessThanMinimumValue
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc(AnadirUnidadesVozUnidadesResolutionResult)
internal class AnadirUnidadesVozUnidadesResolutionResult: INIntegerResolutionResult {
    @objc(unsupportedForReason:)
    internal class func unsupported(forReason reason: AnadirUnidadesVozUnidadesUnsupportedReason) -> Self {
        return __unsupported(withReason: reason.rawValue)
    }
}

#endif
