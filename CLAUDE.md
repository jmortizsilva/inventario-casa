# Inventario Casa (iOS nativa)

- Swift 6 y SwiftUI, iOS 17 como mínimo. Persistencia local con SwiftData.
- El proyecto usa carpetas sincronizadas de Xcode: los ficheros que se añaden en `InventarioCasa/` entran solos en el target. No hace falta tocar `project.pbxproj`.
- Excepción: las pruebas de interfaz (XCUITest) están en `InventarioCasa/pruebas/`, dentro de la carpeta de la app. Cada fichero nuevo ahí hay que añadirlo a `membershipExceptions` en `project.pbxproj` para sacarlo del target de la app. Poner solo la carpeta (`pruebas`) no funciona, se comprobó con Xcode 27. Si se olvida, la app no compila: «unable to resolve module dependency: 'XCTest' (in target 'InventarioCasa')».
- Argumentos de arranque solo en depuración: `-datosDeEjemplo` (datos de ejemplo en memoria), `-almacenEnMemoria` (SwiftData vacío en memoria, para las pruebas de interfaz), `-servidorFalso` (servidor, Google y Apple sustituidos por `ConexionEnMemoria`; Google entra como Ana, Apple como alguien sin nombre, y el hogar de Luis admite el código `LUISCASA`), `-conBienvenida` (con `-almacenEnMemoria` la bienvenida no sale salvo que se pida con este), `-abrirEnlace <url>` (abre un enlace de invitación al arrancar: el simulador no verifica enlaces universales) `-cambioAjeno` (con `-servidorFalso`, Luis añade «Yogures» a los 20 segundos, para probar que llega sin cerrar la app) y `-sinPermisoNotificaciones` (con `-servidorFalso`, simula que iOS tiene denegadas las notificaciones; sin él, el permiso se da por concedido, porque la alerta del sistema que lo pide no la controlan las pruebas).
- Las preferencias (`UserDefaults`) de la app sobreviven entre arranques del simulador: una prueba que las cambia afecta a las siguientes. Por eso `-conBienvenida` ignora lo guardado.
- Nada de `.sheet` ni `.alert` sobre un `Group` dentro de una `List`: el `Group` reparte sus modificadores entre sus hijos, cada fila se queda con una copia y ninguna llega a presentar. Las presentaciones van sobre la lista entera (ver `PresentacionesCuenta`).
- Agitar para deshacer: iOS busca qué deshacer en el primer respondedor, y en una pantalla sin campo de texto no hay ninguno; el `UndoManager` del entorno de SwiftUI no se llega a usar. `ReceptorAgitar` (en `DeshacerEliminacion.swift`) es una vista invisible que se hace primer respondedor mientras hay algo que deshacer. La acción registrada captura el inventario y no la vista: iOS la llama fuera del ciclo de SwiftUI y ahí el entorno de una copia de la vista no vale. Para probarlo, con la app abierta en el simulador: `xcrun simctl spawn <UDID> notifyutil -p com.apple.UIKit.SimulatorShake` (con el UDID exacto: hay varios «iPhone 15»).
- Siri (App Intents, en `InventarioCasa/Siri`): iOS arranca la app en segundo plano para una acción sin crear ninguna vista. Por eso la cuenta y el inventario se crean en `Arranque`, una vez por proceso, y no en `VistaRaiz`; las acciones lo reciben con `@Dependency` (registrado en `InventarioCasaApp.init`). Las frases, los títulos y las preguntas son literales (Apple los lee al compilar); las respuestas están en `Textos.Siri`. En España la Siri nueva de iOS 27 no llega al iPhone (UE): solo funcionan las frases fijas de `Atajos`, con un único dato variable por frase y el nombre de la app dentro. XCUITest no puede hablar con Siri: las acciones se prueban en el iPhone.
- Presentar una hoja a pantalla completa en el mismo momento en que se crea la vista que la presenta a veces no muestra nada. Se hace desde su `.task` (ver la bienvenida en `VistaRaiz`).
- La sincronización está en tres sitios: la cola y las reglas en `InventarioNucleo/Sincronizacion`, la red y la sesión en `InventarioConexion`, y cuándo se sincroniza en `Cuenta`. `ConexionEnMemoria` imita las reglas del servidor para las pruebas: si cambian en `servidor/src/sincronizacion`, hay que cambiarlas allí también.
- XCUITest no puede lanzar acciones del rotor. Lo que hacen se prueba por el menú de pulsación larga, que llama al mismo código.
- XCUITest muestra los descendientes de un elemento aunque tenga `.accessibilityElement(children: .ignore)`: su árbol no es lo que recorre VoiceOver. Un botón dentro de una fila sale como otro elemento con la misma etiqueta y la consulta por etiqueta falla por ambigua; en las filas se usa un toque (`onTapGesture`) en lugar de un botón interior.
- En las pruebas: esperar a que una alerta exista antes de pulsarla (un toque durante la animación se pierde) y usar `waitForNonExistence` para comprobar que algo desaparece (`waitForExistence` da verdadero mientras dura la animación).
- Un `.frame` puesto por fuera de un botón no amplía la zona de toque: va dentro de la etiqueta, con `.contentShape`.
- Las pruebas de importación (`ImportarPruebasUI`) escriben sus archivos en «En mi iPhone» del simulador: es la carpeta `File Provider Storage` del grupo `group.com.apple.FileProvider.LocalStorage`, que se encuentra desde `SIMULATOR_SHARED_RESOURCES_DIRECTORY`. El selector muestra los archivos con su extensión.
- Formato de exportación: `Exportacion` en el núcleo, versión 1. Lo genera `scripts/exportar-firestore/convertir.js`; `pruebas/Recursos/exportacion-script.json` salió de ese script y fija que la app lo entiende. Si cambia el formato, se regenera.
- Un `Picker` con estilo menú dentro de un formulario con el teclado abierto: VoiceOver pasaba del menú al teclado que quedaba detrás. Si hay que elegir antes de escribir, el selector va primero y el teclado no se abre solo. Y nada de opción «Elegir» con valor nulo: sale en el menú como una opción más, marcada como elegida. El selector queda sin valor hasta elegir.
- Los `Stepper` del sistema exponen a VoiceOver sus dos botones por separado, y `.accessibilityLabel` sobre un `Stepper` no sustituye la etiqueta de su texto: la añade detrás. En los formularios, la fila entera (texto + `Stepper`) es un único elemento ajustable con `.accessibilityAdjustableAction` y etiqueta y valor propios (ver `FormularioProducto.selector`). En XCUITest esa fila es un `otherElements[etiqueta]` con el `Stepper` dentro.
- No hay rasgo de accesibilidad público para «abre un menú» (ni en UIKit ni en SwiftUI, comprobado en el SDK de iOS 27). VoiceOver dice «botón desplegable» solo en los selectores de un valor (Picker con estilo menú; clave `popup.button` del módulo de accesibilidad de UIKit, activada por una comprobación interna). Un menú de acciones, sea de SwiftUI o un UIButton de UIKit, se oye como «botón»: se probó en el iPhone. No se añade «menú» al nombre a mano: cada elemento da el rol que le da el sistema.
- La lógica que decide (regla de la lista de la compra, validaciones, textos que se anuncian) va en `Paquetes/InventarioNucleo`, sin importar SwiftUI ni SwiftData, y se prueba con Swift Testing.
- Las pruebas del paquete están en `Sources/InventarioNucleo/pruebas/`. El target principal las excluye en `Package.swift`.
- Más adelante habrá app de Android y servidor propio: los casos de prueba de la lógica compartida se escriben en JSON en `pruebas-compartidas/` (lista de la compra, cantidad), que leen las pruebas de iOS y del servidor, y leerá Kotlin.
- El modelo del núcleo son structs. `Inventario` (en el núcleo) decide y guarda a través del protocolo `Almacen`; `InventarioAlmacen` es la implementación con SwiftData, sin decisiones propias. `AlmacenEnMemoria` sirve para pruebas y vistas previas.
- El esquema de SwiftData está versionado (`EsquemaV1`). Un cambio de modelo añade `EsquemaV2` y una etapa en `PlanMigracion`; no se toca la versión anterior.
- Nombres: `.diacriticInsensitive` convierte la ñ en n («Año» = «ano»), por eso `Nombres.clave` quita tildes letra a letra. Para ordenar, `compare` con `.caseInsensitive` y `Locale("es_ES")` ya pone la ñ detrás de la n.
- Textos de interfaz y vocabulario (Añadir, Quitar, Eliminar…): `docs/textos-interfaz.md`. Todos viven en `Textos.swift` con pruebas; un cambio de texto toca los tres sitios a la vez.

## Verificación

```bash
cd Paquetes/InventarioNucleo && swift test
xcodebuild -project InventarioCasa.xcodeproj -scheme InventarioCasa \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' build
```

```bash
# Pruebas del paquete en el simulador (SwiftData del sistema de verdad)
cd Paquetes/InventarioNucleo && xcodebuild test -scheme InventarioNucleo-Package \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'
```

```bash
# Servidor (tipos, lint y pruebas)
cd servidor && npm run verificar
```

```bash
# Pruebas del script de exportación (sin conexión)
cd scripts/exportar-firestore && npm test
```

```bash
# Pruebas de interfaz (lentas: varios minutos)
xcodebuild test -project InventarioCasa.xcodeproj -scheme InventarioCasa \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'
```

Compilar para el simulador de iOS 17.5 comprueba que no se usa nada posterior a la versión mínima.
