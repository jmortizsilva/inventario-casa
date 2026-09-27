// Los textos de las notificaciones (docs/textos-interfaz.md, «Notificaciones»). Se componen
// aquí y no en las apps: el servidor es quien sabe qué ha cambiado, y así valen para iOS y
// Android. El título es siempre el nombre del hogar.

// Con más de dos nombres se cuentan los demás: leído en voz alta, una lista larga no se acaba.
function nombrar(nombres: string[]): string {
  if (nombres.length <= 2) return nombres.join(' y ');
  const resto = nombres.length - 2;
  return `${nombres[0]}, ${nombres[1]} y ${resto} más`;
}

export function productosNuevos(quien: string, nombres: string[]): string {
  if (nombres.length === 1) return `${quien} ha añadido ${nombres[0]}`;
  const resto = nombres.length - 1;
  return `${quien} ha añadido ${nombres[0]} y ${resto} ${resto === 1 ? 'producto' : 'productos'} más`;
}

export function categoriasNuevas(quien: string, nombres: string[]): string {
  const base = `${quien} ha añadido la categoría ${nombres[0]}`;
  return nombres.length === 1 ? base : `${base} y ${nombres.length - 1} más`;
}

export const entranEnLista = (nombres: string[]) => `A la lista: ${nombrar(nombres)}`;
export const salenDeLista = (nombres: string[]) => `Fuera de la lista: ${nombrar(nombres)}`;

export const personaNueva = (nombre: string | null) =>
  nombre ? `${nombre} se ha unido al hogar` : 'Alguien se ha unido al hogar';
