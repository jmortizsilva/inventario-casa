//
// QuitarUnidadesVozIntent.swift
//
// This file was automatically generated and should not be edited.
//

#if canImport(Intents)

import Intents

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(QuitarUnidadesVozIntent)
internal class QuitarUnidadesVozIntent: INIntent {

    @NSManaged internal var producto: String?
    @NSManaged internal var pregunta: String?
    @NSManaged internal var unidades: NSNumber?

}

/*!
 @abstract Protocol to declare support for handling a QuitarUnidadesVozIntent. By implementing this protocol, a class can provide logic for resolving, confirming and handling the intent.
 @discussion The minimum requirement for an implementing class is that it should be able to handle the intent. The confirmation method is optional. The handling method is always called last, after confirming the intent.
 */
@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(QuitarUnidadesVozIntentHandling)
internal protocol QuitarUnidadesVozIntentHandling: NSObjectProtocol {

    @available(*, renamed: "handle(intent:)")
    @objc(handleQuitarUnidadesVoz:completion:)
    func handle(intent: QuitarUnidadesVozIntent, completion: @escaping (QuitarUnidadesVozIntentResponse) -> Swift.Void)
    
    /*!
     @abstract Handling method - Execute the task represented by the QuitarUnidadesVozIntent that's passed in
     @discussion Called to actually execute the intent. The app must return a response for this intent.

     @param  intent The input intent
     @param  completion The response handling block takes a QuitarUnidadesVozIntentResponse containing the details of the result of having executed the intent

     @see  QuitarUnidadesVozIntentResponse
     */
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(handleQuitarUnidadesVoz:completion:)
    func handle(intent: QuitarUnidadesVozIntent) async -> QuitarUnidadesVozIntentResponse

    /*!
     @abstract Resolution methods - Determine if this intent is ready for the next step (confirmation)
     @discussion Called to make sure the app extension is capable of handling this intent in its current form. This method is for validating if the intent needs any further fleshing out.

     @param  intent The input intent
     @param  completion The response block contains an INIntentResolutionResult for the parameter being resolved

     @see INIntentResolutionResult
     */
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @available(*, renamed: "resolveProducto(for:)")
    @objc(resolveProductoForQuitarUnidadesVoz:withCompletion:)
    func resolveProducto(for intent: QuitarUnidadesVozIntent, with completion: @escaping (QuitarUnidadesVozProductoResolutionResult) -> Swift.Void)

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(resolveProductoForQuitarUnidadesVoz:withCompletion:)
    func resolveProducto(for intent: QuitarUnidadesVozIntent) async -> QuitarUnidadesVozProductoResolutionResult

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @available(*, renamed: "resolvePregunta(for:)")
    @objc(resolvePreguntaForQuitarUnidadesVoz:withCompletion:)
    func resolvePregunta(for intent: QuitarUnidadesVozIntent, with completion: @escaping (INStringResolutionResult) -> Swift.Void)

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(resolvePreguntaForQuitarUnidadesVoz:withCompletion:)
    func resolvePregunta(for intent: QuitarUnidadesVozIntent) async -> INStringResolutionResult

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @available(*, renamed: "resolveUnidades(for:)")
    @objc(resolveUnidadesForQuitarUnidadesVoz:withCompletion:)
    func resolveUnidades(for intent: QuitarUnidadesVozIntent, with completion: @escaping (QuitarUnidadesVozUnidadesResolutionResult) -> Swift.Void)

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(resolveUnidadesForQuitarUnidadesVoz:withCompletion:)
    func resolveUnidades(for intent: QuitarUnidadesVozIntent) async -> QuitarUnidadesVozUnidadesResolutionResult

    @available(*, renamed: "confirm(intent:)")
    @objc(confirmQuitarUnidadesVoz:completion:)
    optional func confirm(intent: QuitarUnidadesVozIntent, completion: @escaping (QuitarUnidadesVozIntentResponse) -> Swift.Void)

    /*!
     @abstract Confirmation method - Validate that this intent is ready for the next step (i.e. handling)
     @discussion Called prior to asking the app to handle the intent. The app should return a response object that contains additional information about the intent, which may be relevant for the system to show the user prior to handling. If unimplemented, the system will assume the intent is valid, and will assume there is no additional information relevant to this intent.

     @param  intent The input intent
     @param  completion The response block contains a QuitarUnidadesVozIntentResponse containing additional details about the intent that may be relevant for the system to show the user prior to handling.

     @see QuitarUnidadesVozIntentResponse
     */
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(confirmQuitarUnidadesVoz:completion:)
    optional func confirm(intent: QuitarUnidadesVozIntent) async -> QuitarUnidadesVozIntentResponse

}

/*!
 @abstract Constants indicating the state of the response.
 */
@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc internal enum QuitarUnidadesVozIntentResponseCode: Int {
    case unspecified = 0
    case ready
    case continueInApp
    case inProgress
    case success
    case failure
    case failureRequiringAppLaunch
}

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(QuitarUnidadesVozIntentResponse)
internal class QuitarUnidadesVozIntentResponse: INIntentResponse {

    @NSManaged internal var texto: String?

    /*!
     @abstract The response code indicating your success or failure in confirming or handling the intent.
     */
    @objc internal fileprivate(set) var code: QuitarUnidadesVozIntentResponseCode = .unspecified

    /*!
     @abstract Initializes the response object with the specified code and user activity object.
     @discussion The app extension has the option of capturing its private state as an NSUserActivity and returning it as the 'currentActivity'. If the app is launched, an NSUserActivity will be passed in with the private state. The NSUserActivity may also be used to query the app's UI extension (if provided) for a view controller representing the current intent handling state. In the case of app launch, the NSUserActivity will have its activityType set to the name of the intent. This intent object will also be available in the NSUserActivity.interaction property.

     @param  code The response code indicating your success or failure in confirming or handling the intent.
     @param  userActivity The user activity object to use when launching your app. Provide an object if you want to add information that is specific to your app. If you specify nil, the system automatically creates a user activity object for you, sets its type to the class name of the intent being handled, and fills it with an INInteraction object containing the intent and your response.
     */
    @objc(initWithCode:userActivity:)
    internal convenience init(code: QuitarUnidadesVozIntentResponseCode, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }

    /*!
     @abstract Initializes and returns the response object with the success code.
     */
    @objc(successIntentResponseWithTexto:)
    internal static func success(texto: String) -> QuitarUnidadesVozIntentResponse {
        let intentResponse = QuitarUnidadesVozIntentResponse(code: .success, userActivity: nil)
        intentResponse.texto = texto
        return intentResponse
    }

    /*!
     @abstract Initializes and returns the response object with the failure code.
     */
    @objc(failureIntentResponseWithTexto:)
    internal static func failure(texto: String) -> QuitarUnidadesVozIntentResponse {
        let intentResponse = QuitarUnidadesVozIntentResponse(code: .failure, userActivity: nil)
        intentResponse.texto = texto
        return intentResponse
    }

}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc internal enum QuitarUnidadesVozProductoUnsupportedReason: Int {
    case noEncontrado = 1
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc(QuitarUnidadesVozProductoResolutionResult)
internal class QuitarUnidadesVozProductoResolutionResult: INStringResolutionResult {
    @objc(unsupportedForReason:)
    internal class func unsupported(forReason reason: QuitarUnidadesVozProductoUnsupportedReason) -> Self {
        return __unsupported(withReason: reason.rawValue)
    }
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc internal enum QuitarUnidadesVozUnidadesUnsupportedReason: Int {
    case negativeNumbersNotSupported = 1
    case greaterThanMaximumValue
    case lessThanMinimumValue
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc(QuitarUnidadesVozUnidadesResolutionResult)
internal class QuitarUnidadesVozUnidadesResolutionResult: INIntegerResolutionResult {
    @objc(unsupportedForReason:)
    internal class func unsupported(forReason reason: QuitarUnidadesVozUnidadesUnsupportedReason) -> Self {
        return __unsupported(withReason: reason.rawValue)
    }
}

#endif
