//
// ConsultarProductoVozIntent.swift
//
// This file was automatically generated and should not be edited.
//

#if canImport(Intents)

import Intents

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(ConsultarProductoVozIntent)
internal class ConsultarProductoVozIntent: INIntent {

    @NSManaged internal var producto: String?

}

/*!
 @abstract Protocol to declare support for handling a ConsultarProductoVozIntent. By implementing this protocol, a class can provide logic for resolving, confirming and handling the intent.
 @discussion The minimum requirement for an implementing class is that it should be able to handle the intent. The confirmation method is optional. The handling method is always called last, after confirming the intent.
 */
@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(ConsultarProductoVozIntentHandling)
internal protocol ConsultarProductoVozIntentHandling: NSObjectProtocol {

    @available(*, renamed: "handle(intent:)")
    @objc(handleConsultarProductoVoz:completion:)
    func handle(intent: ConsultarProductoVozIntent, completion: @escaping (ConsultarProductoVozIntentResponse) -> Swift.Void)
    
    /*!
     @abstract Handling method - Execute the task represented by the ConsultarProductoVozIntent that's passed in
     @discussion Called to actually execute the intent. The app must return a response for this intent.

     @param  intent The input intent
     @param  completion The response handling block takes a ConsultarProductoVozIntentResponse containing the details of the result of having executed the intent

     @see  ConsultarProductoVozIntentResponse
     */
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(handleConsultarProductoVoz:completion:)
    func handle(intent: ConsultarProductoVozIntent) async -> ConsultarProductoVozIntentResponse

    /*!
     @abstract Resolution methods - Determine if this intent is ready for the next step (confirmation)
     @discussion Called to make sure the app extension is capable of handling this intent in its current form. This method is for validating if the intent needs any further fleshing out.

     @param  intent The input intent
     @param  completion The response block contains an INIntentResolutionResult for the parameter being resolved

     @see INIntentResolutionResult
     */
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @available(*, renamed: "resolveProducto(for:)")
    @objc(resolveProductoForConsultarProductoVoz:withCompletion:)
    func resolveProducto(for intent: ConsultarProductoVozIntent, with completion: @escaping (ConsultarProductoVozProductoResolutionResult) -> Swift.Void)

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(resolveProductoForConsultarProductoVoz:withCompletion:)
    func resolveProducto(for intent: ConsultarProductoVozIntent) async -> ConsultarProductoVozProductoResolutionResult

    @available(*, renamed: "confirm(intent:)")
    @objc(confirmConsultarProductoVoz:completion:)
    optional func confirm(intent: ConsultarProductoVozIntent, completion: @escaping (ConsultarProductoVozIntentResponse) -> Swift.Void)

    /*!
     @abstract Confirmation method - Validate that this intent is ready for the next step (i.e. handling)
     @discussion Called prior to asking the app to handle the intent. The app should return a response object that contains additional information about the intent, which may be relevant for the system to show the user prior to handling. If unimplemented, the system will assume the intent is valid, and will assume there is no additional information relevant to this intent.

     @param  intent The input intent
     @param  completion The response block contains a ConsultarProductoVozIntentResponse containing additional details about the intent that may be relevant for the system to show the user prior to handling.

     @see ConsultarProductoVozIntentResponse
     */
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(confirmConsultarProductoVoz:completion:)
    optional func confirm(intent: ConsultarProductoVozIntent) async -> ConsultarProductoVozIntentResponse

}

/*!
 @abstract Constants indicating the state of the response.
 */
@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc internal enum ConsultarProductoVozIntentResponseCode: Int {
    case unspecified = 0
    case ready
    case continueInApp
    case inProgress
    case success
    case failure
    case failureRequiringAppLaunch
}

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(ConsultarProductoVozIntentResponse)
internal class ConsultarProductoVozIntentResponse: INIntentResponse {

    @NSManaged internal var texto: String?

    /*!
     @abstract The response code indicating your success or failure in confirming or handling the intent.
     */
    @objc internal fileprivate(set) var code: ConsultarProductoVozIntentResponseCode = .unspecified

    /*!
     @abstract Initializes the response object with the specified code and user activity object.
     @discussion The app extension has the option of capturing its private state as an NSUserActivity and returning it as the 'currentActivity'. If the app is launched, an NSUserActivity will be passed in with the private state. The NSUserActivity may also be used to query the app's UI extension (if provided) for a view controller representing the current intent handling state. In the case of app launch, the NSUserActivity will have its activityType set to the name of the intent. This intent object will also be available in the NSUserActivity.interaction property.

     @param  code The response code indicating your success or failure in confirming or handling the intent.
     @param  userActivity The user activity object to use when launching your app. Provide an object if you want to add information that is specific to your app. If you specify nil, the system automatically creates a user activity object for you, sets its type to the class name of the intent being handled, and fills it with an INInteraction object containing the intent and your response.
     */
    @objc(initWithCode:userActivity:)
    internal convenience init(code: ConsultarProductoVozIntentResponseCode, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }

    /*!
     @abstract Initializes and returns the response object with the success code.
     */
    @objc(successIntentResponseWithTexto:)
    internal static func success(texto: String) -> ConsultarProductoVozIntentResponse {
        let intentResponse = ConsultarProductoVozIntentResponse(code: .success, userActivity: nil)
        intentResponse.texto = texto
        return intentResponse
    }

    /*!
     @abstract Initializes and returns the response object with the failure code.
     */
    @objc(failureIntentResponseWithTexto:)
    internal static func failure(texto: String) -> ConsultarProductoVozIntentResponse {
        let intentResponse = ConsultarProductoVozIntentResponse(code: .failure, userActivity: nil)
        intentResponse.texto = texto
        return intentResponse
    }

}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc internal enum ConsultarProductoVozProductoUnsupportedReason: Int {
    case noEncontrado = 1
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc(ConsultarProductoVozProductoResolutionResult)
internal class ConsultarProductoVozProductoResolutionResult: INStringResolutionResult {
    @objc(unsupportedForReason:)
    internal class func unsupported(forReason reason: ConsultarProductoVozProductoUnsupportedReason) -> Self {
        return __unsupported(withReason: reason.rawValue)
    }
}

#endif
