# Implementación independiente del mapa

El mapa de Subí se inspira en la idea de Trufi (rutas cerca, un viaje de A a B, búsqueda de lugares), no en su código.

[trufi-core](https://github.com/trufi-association/trufi-core) es GPL v3. Este repositorio no lo copia, no lo traduce, no lo adapta línea por línea y no lo declara como dependencia. No hay un clon ni assets de ese proyecto. Quien mantiene Fitru colabora con Trufi; el código de Subí se escribió aparte, con nombres, estructura y dibujo propios.

Lo que hay hoy:

- `IndiceCercania`: grilla en grados para listar tramos a 100, 300 y 500 m.
- `PlanificadorViajes`: directo o un transbordo, con tramos a pie. Ordena por tiempo y, si empatan, por menos caminata. Respeta ida y vuelta.
- `lugaresSantaCruz`: plazas, mercados, universidades y anillos para buscar sin red. Con red, la app consulta Nominatim y pone su propio User-Agent.
- `tools/exportar_gtfs.py`: GTFS de las 126 rutas. Las paradas salen cada 300 m y el texto dice que son sintéticas.

Cobertura que falta en el GeoJSON (no hay geometría, no se inventa): oeste y noroeste, entre ellos Pentaguazú, Monte Carmelo y Satélite Norte. Esos nombres pueden aparecer como lugares de búsqueda, no como líneas.
