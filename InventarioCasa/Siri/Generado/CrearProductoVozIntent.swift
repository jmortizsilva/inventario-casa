//
// CrearProductoVozIntent.swift
//
// This file was automatically generated and should not be edited.
//

#if canImport(Intents)

import Intents

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(CrearProductoVozIntent)
internal class CrearProductoVozIntent: INIntent {

    @NSManaged internal var nombre: String?
    @NSManaged internal var categoria: String?
    @NSManaged internal var unidades: NSNumber?

}

/*!
 @abstract Protocol to declare support for handling a CrearProductoVozIntent. By implementing this protocol, a class can provide logic for resolving, confirming and handling the intent.
 @discussion The minimum requirement for an implementing class is that it should be able to handle the intent. The confirmation method is optional. The handling method is always called last, after confirming the intent.
 */
@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(CrearProductoVozIntentHandling)
internal protocol CrearProductoVozIntentHandling: NSObjectProtocol {

    @available(*, renamed: "handle(intent:)")
    @objc(handleCrearProductoVoz:completion:)
    func handle(intent: CrearProductoVozIntent, completion: @escaping (CrearProductoVozIntentResponse) -> Swift.Void)
    
    /*!
     @abstract Handling method - Execute the task represented by the CrearProductoVozIntent that's passed in
     @discussion Called to actually execute the intent. The app must return a response for this intent.

     @param  intent The input intent
     @param  completion The response handling block takes a CrearProductoVozIntentResponse containing the details of the result of having executed the intent

     @see  CrearProductoVozIntentResponse
     */
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(handleCrearProductoVoz:completion:)
    func handle(intent: CrearProductoVozIntent) async -> CrearProductoVozIntentResponse

    /*!
     @abstract Resolution methods - Determine if this intent is ready for the next step (confirmation)
     @discussion Called to make sure the app extension is capable of handling this intent in its current form. This method is for validating if the intent needs any further fleshing out.

     @param  intent The input intent
     @param  completion The response block contains an INIntentResolutionResult for the parameter being resolved

     @see INIntentResolutionResult
     */
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @available(*, renamed: "resolveNombre(for:)")
    @objc(resolveNombreForCrearProductoVoz:withCompletion:)
    func resolveNombre(for intent: CrearProductoVozIntent, with completion: @escaping (CrearProductoVozNombreResolutionResult) -> Swift.Void)

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(resolveNombreForCrearProductoVoz:withCompletion:)
    func resolveNombre(for intent: CrearProductoVozIntent) async -> CrearProductoVozNombreResolutionResult

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @available(*, renamed: "resolveCategoria(for:)")
    @objc(resolveCategoriaForCrearProductoVoz:withCompletion:)
    func resolveCategoria(for intent: CrearProductoVozIntent, with completion: @escaping (CrearProductoVozCategoriaResolutionResult) -> Swift.Void)

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(resolveCategoriaForCrearProductoVoz:withCompletion:)
    func resolveCategoria(for intent: CrearProductoVozIntent) async -> CrearProductoVozCategoriaResolutionResult

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @available(*, renamed: "resolveUnidades(for:)")
    @objc(resolveUnidadesForCrearProductoVoz:withCompletion:)
    func resolveUnidades(for intent: CrearProductoVozIntent, with completion: @escaping (CrearProductoVozUnidadesResolutionResult) -> Swift.Void)

    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(resolveUnidadesForCrearProductoVoz:withCompletion:)
    func resolveUnidades(for intent: CrearProductoVozIntent) async -> CrearProductoVozUnidadesResolutionResult

    @available(*, renamed: "confirm(intent:)")
    @objc(confirmCrearProductoVoz:completion:)
    optional func confirm(intent: CrearProductoVozIntent, completion: @escaping (CrearProductoVozIntentResponse) -> Swift.Void)

    /*!
     @abstract Confirmation method - Validate that this intent is ready for the next step (i.e. handling)
     @discussion Called prior to asking the app to handle the intent. The app should return a response object that contains additional information about the intent, which may be relevant for the system to show the user prior to handling. If unimplemented, the system will assume the intent is valid, and will assume there is no additional information relevant to this intent.

     @param  intent The input intent
     @param  completion The response block contains a CrearProductoVozIntentResponse containing additional details about the intent that may be relevant for the system to show the user prior to handling.

     @see CrearProductoVozIntentResponse
     */
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(confirmCrearProductoVoz:completion:)
    optional func confirm(intent: CrearProductoVozIntent) async -> CrearProductoVozIntentResponse

}

/*!
 @abstract Constants indicating the state of the response.
 */
@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc internal enum CrearProductoVozIntentResponseCode: Int {
    case unspecified = 0
    case ready
    case continueInApp
    case inProgress
    case success
    case failure
    case failureRequiringAppLaunch
}

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(CrearProductoVozIntentResponse)
internal class CrearProductoVozIntentResponse: INIntentResponse {

    @NSManaged internal var texto: String?

    /*!
     @abstract The response code indicating your success or failure in confirming or handling the intent.
     */
    @objc internal fileprivate(set) var code: CrearProductoVozIntentResponseCode = .unspecified

    /*!
     @abstract Initializes the response object with the specified code and user activity object.
     @discussion The app extension has the option of capturing its private state as an NSUserActivity and returning it as the 'currentActivity'. If the app is launched, an NSUserActivity will be passed in with the private state. The NSUserActivity may also be used to query the app's UI extension (if provided) for a view controller representing the current intent handling state. In the case of app launch, the NSUserActivity will have its activityType set to the name of the intent. This intent object will also be available in the NSUserActivity.interaction property.

     @param  code The response code indicating your success or failure in confirming or handling the intent.
     @param  userActivity The user activity object to use when launching your app. Provide an object if you want to add information that is specific to your app. If you specify nil, the system automatically creates a user activity object for you, sets its type to the class name of the intent being handled, and fills it with an INInteraction object containing the intent and your response.
     */
    @objc(initWithCode:userActivity:)
    internal convenience init(code: CrearProductoVozIntentResponseCode, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }

    /*!
     @abstract Initializes and returns the response object with the success code.
     */
    @objc(successIntentResponseWithTexto:)
    internal static func success(texto: String) -> CrearProductoVozIntentResponse {
        let intentResponse = CrearProductoVozIntentResponse(code: .success, userActivity: nil)
        intentResponse.texto = texto
        return intentResponse
    }

    /*!
     @abstract Initializes and returns the response object with the failure code.
     */
    @objc(failureIntentResponseWithTexto:)
    internal static func failure(texto: String) -> CrearProductoVozIntentResponse {
        let intentResponse = CrearProductoVozIntentResponse(code: .failure, userActivity: nil)
        intentResponse.texto = texto
        return intentResponse
    }

}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc internal enum CrearProductoVozNombreUnsupportedReason: Int {
    case noEntendido = 1
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc(CrearProductoVozNombreResolutionResult)
internal class CrearProductoVozNombreResolutionResult: INStringResolutionResult {
    @objc(unsupportedForReason:)
    internal class func unsupported(forReason reason: CrearProductoVozNombreUnsupportedReason) -> Self {
        return __unsupported(withReason: reason.rawValue)
    }
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc internal enum CrearProductoVozCategoriaUnsupportedReason: Int {
    case noEncontrada = 1
    case varias
    case repetido
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc(CrearProductoVozCategoriaResolutionResult)
internal class CrearProductoVozCategoriaResolutionResult: INStringResolutionResult {
    @objc(unsupportedForReason:)
    internal class func unsupported(forReason reason: CrearProductoVozCategoriaUnsupportedReason) -> Self {
        return __unsupported(withReason: reason.rawValue)
    }
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc internal enum CrearProductoVozUnidadesUnsupportedReason: Int {
    case negativeNumbersNotSupported = 1
    case greaterThanMaximumValue
    case lessThanMinimumValue
}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
@objc(CrearProductoVozUnidadesResolutionResult)
internal class CrearProductoVozUnidadesResolutionResult: INIntegerResolutionResult {
    @objc(unsupportedForReason:)
    internal class func unsupported(forReason reason: CrearProductoVozUnidadesUnsupportedReason) -> Self {
        return __unsupported(withReason: reason.rawValue)
    }
}

#endif
