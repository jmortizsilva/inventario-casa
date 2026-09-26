// Genera el icono de la aplicación: una despensa con dos baldas de tarros, en
// el PNG de 1024 que pide la App Store.
//
//    swift scripts/generar-icono.swift
//
// Se dibuja por código y no se guarda un .png hecho a mano, como en Guardar
// Enlaces: así el icono se cambia tocando unos números, y en una revisión se ve
// qué cambia de verdad.
//
// - Sin esquinas redondeadas ni margen: iOS recorta el icono con su propia
//   máscara, y si se redondea aquí se redondea dos veces.
// - Sin transparencia: la App Store rechaza un icono con canal alfa.
// - Pocas piezas y grandes: a 60 puntos, los detalles finos (etiquetas en los
//   tarros, vetas en la madera) se quedan en una mancha.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let lado = 1024
let fondo = CGColor(red: 46 / 255, green: 107 / 255, blue: 87 / 255, alpha: 1)
let crema = CGColor(red: 244 / 255, green: 239 / 255, blue: 227 / 255, alpha: 1)
let ambar = CGColor(red: 224 / 255, green: 163 / 255, blue: 74 / 255, alpha: 1)

let destino = URL(
    fileURLWithPath: CommandLine.arguments.count > 1
        ? CommandLine.arguments[1]
        : "InventarioCasa/Assets.xcassets/AppIcon.appiconset/icono.png")

guard
    let contexto = CGContext(
        data: nil,
        width: lado,
        height: lado,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )
else {
    fatalError("no se pudo crear el lienzo")
}

let g = CGFloat(lado)
contexto.setFillColor(fondo)
contexto.fill(CGRect(x: 0, y: 0, width: g, height: g))

// Las medidas van en fracciones del lado y contadas desde arriba, que es como
// se piensa un dibujo. CoreGraphics tiene el origen abajo: `rectangulo` lo da
// la vuelta.
func rectangulo(x: CGFloat, arriba: CGFloat, ancho: CGFloat, alto: CGFloat) -> CGRect {
    CGRect(x: x * g, y: g - (arriba + alto) * g, width: ancho * g, height: alto * g)
}

func relleno(_ rect: CGRect, radio: CGFloat, color: CGColor) {
    contexto.setFillColor(color)
    contexto.addPath(CGPath(roundedRect: rect, cornerWidth: radio * g, cornerHeight: radio * g, transform: nil))
    contexto.fillPath()
}

let anchoBalda: CGFloat = 0.66
let grosorBalda: CGFloat = 0.03
let anchoTarro: CGFloat = 0.17
let hueco: CGFloat = 0.045
let altoTapa: CGFloat = 0.045
let margenTapa: CGFloat = 0.015
let primerTarro = (1 - (3 * anchoTarro + 2 * hueco)) / 2

// Cada balda con la altura de sus tres tarros. Alturas distintas para que se
// lean como tarros y no como una valla.
let baldas: [(altura: CGFloat, tarros: [CGFloat])] = [
    (0.48, [0.20, 0.25, 0.18]),
    (0.80, [0.22, 0.16, 0.19]),
]

for balda in baldas {
    relleno(
        rectangulo(x: (1 - anchoBalda) / 2, arriba: balda.altura, ancho: anchoBalda, alto: grosorBalda),
        radio: grosorBalda / 2,
        color: crema)

    for (i, alto) in balda.tarros.enumerated() {
        let x = primerTarro + CGFloat(i) * (anchoTarro + hueco)
        let arribaTarro = balda.altura - alto
        relleno(
            rectangulo(x: x, arriba: arribaTarro, ancho: anchoTarro, alto: alto),
            radio: 0.03,
            color: crema)
        relleno(
            rectangulo(
                x: x + margenTapa, arriba: arribaTarro - altoTapa + 0.01,
                ancho: anchoTarro - 2 * margenTapa, alto: altoTapa),
            radio: 0.012,
            color: ambar)
    }
}

guard
    let imagen = contexto.makeImage(),
    let salida = CGImageDestinationCreateWithURL(
        destino as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    )
else {
    fatalError("no se pudo escribir \(destino.path)")
}

CGImageDestinationAddImage(salida, imagen, nil)
guard CGImageDestinationFinalize(salida) else {
    fatalError("no se pudo cerrar \(destino.path)")
}

print("icono escrito en \(destino.path) (\(lado)x\(lado))")
