#!/usr/bin/env python3
"""Genera las acciones de «Añadir a Siri» (SiriKit):

    scripts/siri/generar-acciones.py

Escribe tres cosas, que van juntas y no se editan a mano:
  - InventarioCasa/Siri/Base.lproj/Voz.intentdefinition, la definición;
  - InventarioCasa/Siri/es.lproj/Voz.strings, sus textos por identificador
    (App Store Connect rechaza con ITMS-90626 las acciones sin título
    localizado en el idioma de la app);
  - InventarioCasa/Siri/Generado/*.swift, las clases, con intentbuilderc.
    Con la definición dentro de Base.lproj, la carpeta sincronizada de Xcode
    la copia como recurso y no genera las clases al compilar.

Los identificadores salen de una semilla fija: cambiar el orden o añadir
textos los cambia, pero se regeneran los tres a la vez.
"""
import plistlib, random, string, subprocess, sys
from pathlib import Path
random.seed(7)
def rid(): return ''.join(random.choice(string.ascii_letters+string.digits) for _ in range(6))

def param(tag, nombre, titulo, tipo, pregunta, **extra):
    p = {
        'INIntentParameterName': nombre, 'INIntentParameterDisplayName': titulo,
        'INIntentParameterDisplayNameID': rid(), 'INIntentParameterTag': tag,
        'INIntentParameterDisplayPriority': tag, 'INIntentParameterType': tipo,
        'INIntentParameterSupportsMultipleValues': False,
        'INIntentParameterSupportsResolution': True,
        'INIntentParameterConfigurable': True,
        'INIntentParameterPromptDialogs': [
            {'INIntentParameterPromptDialogType': 'Configuration', 'INIntentParameterPromptDialogCustom': True},
            {'INIntentParameterPromptDialogType': 'Primary', 'INIntentParameterPromptDialogCustom': True,
             'INIntentParameterPromptDialogFormatString': pregunta, 'INIntentParameterPromptDialogFormatStringID': rid()},
        ],
    }
    p.update(extra)
    return p

def rechazos(*motivos):
    # Siri dice el texto al momento, con lo que se acaba de decir, y vuelve a
    # preguntar: sin esto, el «No encuentro…» llegaba al final de todo.
    return [{'INIntentParameterUnsupportedReasonCode': codigo,
             'INIntentParameterUnsupportedReasonFormatString': texto,
             'INIntentParameterUnsupportedReasonFormatStringID': rid()} for codigo, texto in motivos]

def eleccion(p, introduccion, seleccion):
    p['INIntentParameterCustomDisambiguation'] = True
    p['INIntentParameterPromptDialogs'] += [
        {'INIntentParameterPromptDialogType': 'DisambiguationIntroduction', 'INIntentParameterPromptDialogCustom': True,
         'INIntentParameterPromptDialogFormatString': introduccion, 'INIntentParameterPromptDialogFormatStringID': rid()},
        {'INIntentParameterPromptDialogType': 'DisambiguationSelection', 'INIntentParameterPromptDialogCustom': True,
         'INIntentParameterPromptDialogFormatString': seleccion, 'INIntentParameterPromptDialogFormatStringID': rid()},
    ]
    return p

def producto(pregunta, tag=1):
    # Texto y no una lista de productos: con lista, Siri la leía entera, con
    # las categorías, y preguntaba «¿Cuál?». Lo dicho se busca en la app; si
    # encaja con varios, Siri ofrece solo esos.
    p = texto(tag, 'producto', 'Producto', pregunta)
    p['INIntentParameterCustomDisambiguation'] = True
    p['INIntentParameterUnsupportedReasons'] = rechazos(('noEncontrado', 'No encuentro ${producto}.'))
    p['INIntentParameterPromptDialogs'] += [
        {'INIntentParameterPromptDialogType': 'DisambiguationIntroduction', 'INIntentParameterPromptDialogCustom': True,
         'INIntentParameterPromptDialogFormatString': 'Hay varios:', 'INIntentParameterPromptDialogFormatStringID': rid()},
        {'INIntentParameterPromptDialogType': 'DisambiguationSelection', 'INIntentParameterPromptDialogCustom': True,
         'INIntentParameterPromptDialogFormatString': '¿Cuál de ellos?', 'INIntentParameterPromptDialogFormatStringID': rid()},
    ]
    return p

def unidades(tag, pregunta, minimo, prioridad=None):
    return param(tag, 'unidades', 'Unidades', 'Integer', pregunta,
                 INIntentParameterDisplayPriority=prioridad or tag,
                 INIntentParameterMetadata={'INIntentParameterMetadataMinimumValue': minimo,
                                            'INIntentParameterMetadataMaximumValue': 999,
                                            'INIntentParameterMetadataSupportsNegativeNumbers': False})

def pregunta_cantidad(tag, prioridad):
    # La pregunta por las unidades depende del envase del producto («¿Cuántas
    # latas?», «¿Cuántos paquetes?») y la definición solo admite textos fijos.
    # Este parámetro, oculto, lo rellena la app al resolverlo (va después del
    # producto) y la pregunta de las unidades es «${pregunta}». Sin comprobar
    # todavía en el iPhone; si no lo lee, volver a «¿Qué cantidad?».
    return dict(texto(tag, 'pregunta', 'Pregunta', '¿Cuántas unidades?'),
                INIntentParameterConfigurable=False, INIntentParameterDisplayPriority=prioridad)

def texto(tag, nombre, titulo, pregunta):
    return param(tag, nombre, titulo, 'String', pregunta,
                 INIntentParameterMetadata={'INIntentParameterMetadataCapitalization': 'Sentences',
                                            'INIntentParameterMetadataDefaultValueID': rid()})

def intent(nombre, titulo, descripcion, categoria, params, combinacion, confirmar=False):
    codigos = [
        {'INIntentResponseCodeName': 'success', 'INIntentResponseCodeSuccess': True,
         'INIntentResponseCodeConciseFormatString': '${texto}', 'INIntentResponseCodeConciseFormatStringID': rid(),
         'INIntentResponseCodeFormatString': '${texto}', 'INIntentResponseCodeFormatStringID': rid()},
        {'INIntentResponseCodeName': 'failure',
         'INIntentResponseCodeConciseFormatString': '${texto}', 'INIntentResponseCodeConciseFormatStringID': rid(),
         'INIntentResponseCodeFormatString': '${texto}', 'INIntentResponseCodeFormatStringID': rid()},
    ]
    # Las combinaciones son lo que se puede configurar: sin los parámetros ocultos.
    combinables = ','.join(p['INIntentParameterName'] for p in params if p['INIntentParameterConfigurable'])
    return {
        'INIntentName': nombre, 'INIntentTitle': titulo, 'INIntentTitleID': rid(),
        'INIntentDescription': descripcion, 'INIntentDescriptionID': rid(),
        'INIntentCategory': categoria, 'INIntentVerb': {'generic': 'Do', 'create': 'Create', 'information': 'View'}[categoria],
        'INIntentType': 'Custom',
        'INIntentConfigurable': True, 'INIntentEligibleForWidgets': False,
        'INIntentIneligibleForSuggestions': False,
        'INIntentUserConfirmationRequired': confirmar,
        'INIntentLastParameterTag': max(p['INIntentParameterTag'] for p in params), 'INIntentParameters': params,
        'INIntentParameterCombinations': {
            combinables: {
                'INIntentParameterCombinationIsPrimary': True,
                'INIntentParameterCombinationSupportsBackgroundExecution': True,
                'INIntentParameterCombinationTitle': combinacion, 'INIntentParameterCombinationTitleID': rid(),
            }
        },
        'INIntentManagedParameterCombinations': {
            combinables: {
                'INIntentParameterCombinationSupportsBackgroundExecution': True,
                'INIntentParameterCombinationTitle': combinacion, 'INIntentParameterCombinationTitleID': rid(),
                'INIntentParameterCombinationUpdatesLinked': True,
            }
        },
        'INIntentResponse': {
            'INIntentResponseCodes': codigos,
            'INIntentResponseLastParameterTag': 1,
            'INIntentResponseParameters': [{
                'INIntentResponseParameterName': 'texto', 'INIntentResponseParameterDisplayName': 'Texto',
                'INIntentResponseParameterDisplayNameID': rid(), 'INIntentResponseParameterDisplayPriority': 1,
                'INIntentResponseParameterTag': 1, 'INIntentResponseParameterType': 'String',
            }],
        },
    }

def prop(tag, nombre, titulo, tipo, multiple=False):
    return {'INTypePropertyName': nombre, 'INTypePropertyDisplayName': titulo, 'INTypePropertyDisplayNameID': rid(),
            'INTypePropertyTag': tag, 'INTypePropertyDisplayPriority': tag, 'INTypePropertyDefault': True,
            'INTypePropertyType': tipo, 'INTypePropertySupportsMultipleValues': multiple}

definicion = {
    'INIntentDefinitionModelVersion': '1.2',
    'INIntentDefinitionNamespace': 'INVENTARIO',
    'INIntentDefinitionSystemVersion': '27A0',
    'INIntentDefinitionToolsBuildVersion': '27A0',
    'INIntentDefinitionToolsVersion': '27.0',
    'INEnums': [],
    'INTypes': [],
    'INIntents': [
        intent('CrearProductoVoz', 'Crear producto', 'Crea un producto en el hogar abierto', 'create',
               # Siri a veces toma una respuesta por una orden y la deja vacía
               # («despensa», «fregona»): la segunda vez se avisa o se ofrecen
               # las categorías, en lugar de repetir la pregunta sin fin.
               [dict(texto(1, 'nombre', 'Nombre', '¿Qué producto?'),
                     INIntentParameterUnsupportedReasons=rechazos(
                         ('noEntendido', 'No te he entendido. Dilo de otra forma.'))),
                dict(eleccion(texto(2, 'categoria', 'Categoría', '¿En qué categoría lo guardo?'),
                              'Estas son tus categorías:', '¿En cuál lo guardo?'),
                     INIntentParameterUnsupportedReasons=rechazos(
                         ('noEncontrada', 'No encuentro la categoría ${categoria}.'),
                         ('varias', 'Hay varias categorías así. Dilo con el nombre entero.'),
                         ('repetido', 'Ya hay un producto con ese nombre en ${categoria}.'))),
                unidades(3, '¿Cuántas unidades?', 0)],
               'Crear ${nombre} en ${categoria}'),
        intent('AnadirUnidadesVoz', 'Añadir unidades', 'Suma unidades a un producto', 'generic',
               [producto('¿Qué has comprado?'), pregunta_cantidad(3, 2), unidades(2, '${pregunta}', 1, prioridad=3)],
               'Añadir ${unidades} a ${producto}'),
        intent('QuitarUnidadesVoz', 'Quitar unidades', 'Resta unidades a un producto', 'generic',
               [producto('¿Qué producto?'), pregunta_cantidad(3, 2), unidades(2, '${pregunta}', 1, prioridad=3)],
               'Quitar ${unidades} a ${producto}'),
        intent('CambiarCantidadVoz', 'Cambiar la cantidad', 'Pone las unidades de un producto', 'generic',
               [producto('¿De qué producto?'), pregunta_cantidad(3, 2), unidades(2, '${pregunta}', 0, prioridad=3)],
               'Poner ${producto} a ${unidades}'),
        intent('ConsultarProductoVoz', 'Consultar un producto', 'Dice cuántas unidades quedan', 'information',
               [producto('¿De qué producto?')], 'Consultar ${producto}'),
        intent('EliminarProductoVoz', 'Eliminar producto', 'Elimina un producto', 'generic',
               [producto('¿Qué producto quieres eliminar?')], 'Eliminar ${producto}', confirmar=True),
    ],
}

raiz = Path(__file__).resolve().parents[2] / 'InventarioCasa' / 'Siri'
definicion_ruta = raiz / 'Base.lproj' / 'Voz.intentdefinition'
textos_ruta = raiz / 'es.lproj' / 'Voz.strings'
generado = raiz / 'Generado'

# Cada texto con su identificador, para es.lproj/Voz.strings: App Store
# Connect rechaza (ITMS-90626) las acciones sin título localizado en el idioma
# de la app, aunque el texto ya esté en la definición.
textos = {}
def recoger(nodo):
    if isinstance(nodo, dict):
        for clave, valor in nodo.items():
            if clave.endswith('ID') and isinstance(valor, str) and isinstance(nodo.get(clave[:-2]), str) and nodo[clave[:-2]]:
                textos[valor] = nodo[clave[:-2]]
            recoger(valor)
    elif isinstance(nodo, list):
        for valor in nodo: recoger(valor)
recoger(definicion)
with open(definicion_ruta, 'wb') as f:
    plistlib.dump(definicion, f)
def escapar(t): return t.replace('\\', '\\\\').replace('"', '\\"')
with open(textos_ruta, 'w', encoding='utf-8') as f:
    for ident, texto in sorted(textos.items()):
        f.write(f'"{ident}" = "{escapar(texto)}";\n')

for viejo in generado.glob('*.swift'):
    viejo.unlink()
generado.mkdir(exist_ok=True)
subprocess.run(['xcrun', 'intentbuilderc', 'generate', '-input', str(definicion_ruta), '-output', str(generado),
                '-language', 'Swift', '-swiftVersion', '6', '-visibility', 'project'], check=True)
print('Generadas:', ', '.join(sorted(f.name for f in generado.glob('*.swift'))))
