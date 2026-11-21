#!/usr/bin/env python3
"""Genera SQL de carga a partir de datos/rutas.geojson y datos/rutas_nombres.csv.

No abre una base de datos: escribe backend/semilla/rutas.sql para aplicarlo con psql.
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
GEOJSON = RAIZ / "datos" / "rutas.geojson"
CSV = RAIZ / "datos" / "rutas_nombres.csv"
SALIDA = Path(__file__).resolve().parent / "rutas.sql"


def sql(valor: object) -> str:
    if valor is None:
        return "NULL"
    if isinstance(valor, bool):
        return "true" if valor else "false"
    if isinstance(valor, (int, float)) and not isinstance(valor, bool):
        return str(valor)
    texto = str(valor).replace("'", "''")
    return f"'{texto}'"


def booleano(valor: object) -> bool:
    if isinstance(valor, bool):
        return valor
    return str(valor).strip().lower() == "true"


def main() -> None:
    features = json.loads(GEOJSON.read_text(encoding="utf-8"))["features"]
    with CSV.open(encoding="utf-8", newline="") as archivo:
        catalogo = {fila["route_id"]: fila for fila in csv.DictReader(archivo)}

    lineas: list[str] = [
        "-- Generado por backend/semilla/generar_semilla.py. No editar a mano.",
        "begin;",
        "",
    ]
    agencias: set[str] = set()
    rutas_vistas: set[str] = set()

    for feature in features:
        props = feature["properties"]
        fila = catalogo.get(props["route_id"], {})
        federacion = fila.get("federacion") or props.get("federacion") or "sin federación"
        if federacion not in agencias:
            agencias.add(federacion)
            lineas.append(
                "insert into agencias (agencia_id, nombre) values "
                f"({sql(federacion)}, {sql(federacion)}) on conflict (agencia_id) do nothing;"
            )

    lineas.append("")
    for feature in features:
        props = feature["properties"]
        ruta_id = props["route_id"]
        if ruta_id in rutas_vistas:
            continue
        rutas_vistas.add(ruta_id)
        fila = catalogo.get(ruta_id, {})
        federacion = fila.get("federacion") or props.get("federacion") or "sin federación"
        lineas.append(
            "insert into rutas (route_id, agencia_id, nombre_comun, nombre_crudo, "
            "nombre_revisar, motivo_revisar, zonas, operador, tipo_entidad, federacion, "
            "jurisdiccion, color_panter, banderin, color_hex, color_hex_2, fecha_ruteo) values ("
            + ", ".join(
                [
                    sql(ruta_id),
                    sql(federacion),
                    sql(fila.get("nombre_comun") or props.get("nombre_comun")),
                    sql(fila.get("nombre_crudo") or props.get("nombre_crudo") or ""),
                    sql(booleano(fila.get("nombre_revisar", props.get("nombre_revisar")))),
                    sql(fila.get("motivo_revisar") or ""),
                    sql(fila.get("zonas") or props.get("zonas") or ""),
                    sql(fila.get("operador") or props.get("operador") or ""),
                    sql(fila.get("tipo_entidad") or ""),
                    sql(federacion),
                    sql(fila.get("jurisdiccion") or props.get("jurisdiccion") or ""),
                    sql(fila.get("color_panter") or props.get("color_panter") or ""),
                    sql(fila.get("banderin") or props.get("banderin") or ""),
                    sql(fila.get("color_hex") or props.get("color_hex") or "#009048"),
                    sql(fila.get("color_hex_2") or props.get("color_hex_2") or ""),
                    sql(fila.get("fecha_ruteo") or None) if fila.get("fecha_ruteo") else "null",
                ]
            )
            + ") on conflict (route_id) do nothing;"
        )

    lineas.append("")
    puntos = 0
    for feature in features:
        props = feature["properties"]
        coords = feature["geometry"]["coordinates"]
        shape_id = props["shape_id"]
        wkt = "LINESTRING(" + ", ".join(f"{c[0]} {c[1]}" for c in coords) + ")"
        lineas.append(
            "insert into shapes (shape_id, route_id, sentido, geom) values ("
            f"{sql(shape_id)}, {sql(props['route_id'])}, {sql(props['sentido'])}, "
            f"ST_GeomFromText({sql(wkt)}, 4326)) on conflict (shape_id) do nothing;"
        )
        lineas.append(
            "insert into viajes (trip_id, route_id, shape_id, sentido, zona_origen, "
            "zona_destino, km, minutos, geom_invertida_corregida) values ("
            + ", ".join(
                [
                    sql(shape_id),
                    sql(props["route_id"]),
                    sql(shape_id),
                    sql(props["sentido"]),
                    sql(props.get("zona_origen") or ""),
                    sql(props.get("zona_destino") or ""),
                    sql(props.get("km") or 0),
                    sql(props.get("min") or 0),
                    sql(bool(props.get("geom_invertida_corregida"))),
                ]
            )
            + ") on conflict (trip_id) do nothing;"
        )
        for indice, coord in enumerate(coords, start=1):
            puntos += 1
            lineas.append(
                "insert into shape_puntos (shape_id, secuencia, lat, lon) values ("
                f"{sql(shape_id)}, {indice}, {coord[1]}, {coord[0]}) "
                "on conflict (shape_id, secuencia) do nothing;"
            )

    lineas.append("commit;")
    lineas.append("")
    SALIDA.write_text("\n".join(lineas), encoding="utf-8")
    print(f"Rutas: {len(rutas_vistas)}. Sentidos: {len(features)}. Vértices: {puntos}.")
    print(f"Escrito {SALIDA} ({SALIDA.stat().st_size} bytes).")


if __name__ == "__main__":
    main()
