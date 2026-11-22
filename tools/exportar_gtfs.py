#!/usr/bin/env python3
"""Exporta el GeoJSON de Subí a un GTFS mínimo.

Las paradas no existen en el archivo de origen. Se inventan cada ~300 m
sobre la polilínea y se marcan como sintéticas en stop_desc. Sirve para
probar un ruteador más adelante (por ejemplo OpenTripPlanner). No copia
código de ningún proyecto externo.

Uso:
    python3 tools/exportar_gtfs.py
    python3 tools/exportar_gtfs.py --salida /tmp/subi-gtfs
"""

from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
GEOJSON = RAIZ / "datos" / "rutas.geojson"
CSV_NOMBRES = RAIZ / "datos" / "rutas_nombres.csv"
PASO_METROS = 300


def haversine(lon1: float, lat1: float, lon2: float, lat2: float) -> float:
    radio = 6_371_000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlon / 2) ** 2
    return 2 * radio * math.asin(min(1.0, math.sqrt(a)))


def muestras(coords: list[list[float]]) -> list[tuple[float, float, float]]:
    """Devuelve (lat, lon, distancia_recorrida) cada PASO_METROS, más los extremos."""
    if not coords:
        return []
    puntos = [(coords[0][1], coords[0][0], 0.0)]
    acumulado = 0.0
    siguiente = float(PASO_METROS)
    for i in range(1, len(coords)):
        lon1, lat1 = coords[i - 1][0], coords[i - 1][1]
        lon2, lat2 = coords[i][0], coords[i][1]
        tramo = haversine(lon1, lat1, lon2, lat2)
        if tramo <= 0:
            continue
        while acumulado + tramo >= siguiente:
            falta = siguiente - acumulado
            t = falta / tramo
            lat = lat1 + (lat2 - lat1) * t
            lon = lon1 + (lon2 - lon1) * t
            puntos.append((lat, lon, siguiente))
            siguiente += PASO_METROS
        acumulado += tramo
    fin = (coords[-1][1], coords[-1][0], acumulado)
    if puntos[-1][0] != fin[0] or puntos[-1][1] != fin[1]:
        puntos.append(fin)
    return puntos


def escribir(ruta: Path, campos: list[str], filas: list[dict[str, object]]) -> None:
    with ruta.open("w", encoding="utf-8", newline="") as archivo:
        escritor = csv.DictWriter(archivo, fieldnames=campos)
        escritor.writeheader()
        escritor.writerows(filas)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--salida", default=str(RAIZ / "tools" / "gtfs_salida"))
    args = parser.parse_args()
    salida = Path(args.salida)
    salida.mkdir(parents=True, exist_ok=True)

    features = json.loads(GEOJSON.read_text(encoding="utf-8"))["features"]
    with CSV_NOMBRES.open(encoding="utf-8", newline="") as archivo:
        catalogo = {fila["route_id"]: fila for fila in csv.DictReader(archivo)}

    agencias: dict[str, dict[str, object]] = {}
    rutas: dict[str, dict[str, object]] = {}
    viajes: list[dict[str, object]] = []
    shapes: list[dict[str, object]] = []
    paradas: list[dict[str, object]] = []
    horarios: list[dict[str, object]] = []

    for feature in features:
        props = feature["properties"]
        fila = catalogo.get(props["route_id"], {})
        federacion = (fila.get("federacion") or props.get("federacion") or "Subí").strip()
        agencia = federacion or "Subí"
        agencias.setdefault(
            agencia,
            {
                "agency_id": agencia,
                "agency_name": agencia,
                "agency_url": "https://github.com/danielcrackvz-stack/Fitru",
                "agency_timezone": "America/La_Paz",
                "agency_lang": "es",
            },
        )
        route_id = props["route_id"]
        if route_id not in rutas:
            color = (fila.get("color_hex") or props.get("color_hex") or "#009048").replace("#", "")
            rutas[route_id] = {
                "route_id": route_id,
                "agency_id": agencia,
                "route_short_name": route_id,
                "route_long_name": fila.get("nombre_comun") or props.get("nombre_comun") or route_id,
                "route_type": 3,
                "route_color": color,
                "route_text_color": "FFFFFF",
            }
        shape_id = props["shape_id"]
        coords = feature["geometry"]["coordinates"]
        for seq, coord in enumerate(coords, start=1):
            shapes.append(
                {
                    "shape_id": shape_id,
                    "shape_pt_lat": f"{coord[1]:.6f}",
                    "shape_pt_lon": f"{coord[0]:.6f}",
                    "shape_pt_sequence": seq,
                }
            )
        viajes.append(
            {
                "route_id": route_id,
                "service_id": "diario",
                "trip_id": shape_id,
                "trip_headsign": props.get("zona_destino") or props.get("sentido") or "",
                "direction_id": 0 if props.get("sentido") == "ida" else 1,
                "shape_id": shape_id,
            }
        )
        for orden, (lat, lon, distancia) in enumerate(muestras(coords), start=1):
            stop_id = f"{shape_id}_{orden}"
            paradas.append(
                {
                    "stop_id": stop_id,
                    "stop_name": f"{props.get('nombre_comun') or route_id} {orden}",
                    "stop_lat": f"{lat:.6f}",
                    "stop_lon": f"{lon:.6f}",
                    "stop_desc": "Parada sintetica cada 300 m. No es un paradero real.",
                }
            )
            # Unos 20 km/h de recorrido. No es un horario real.
            segundos = int(distancia / 5.56)
            horas, resto = divmod(max(segundos, 0), 3600)
            minutos, segs = divmod(resto, 60)
            horarios.append(
                {
                    "trip_id": shape_id,
                    "arrival_time": f"{horas:02d}:{minutos:02d}:{segs:02d}",
                    "departure_time": f"{horas:02d}:{minutos:02d}:{segs:02d}",
                    "stop_id": stop_id,
                    "stop_sequence": orden,
                    "shape_dist_traveled": f"{distancia:.1f}",
                }
            )

    escribir(
        salida / "agency.txt",
        ["agency_id", "agency_name", "agency_url", "agency_timezone", "agency_lang"],
        list(agencias.values()),
    )
    escribir(
        salida / "routes.txt",
        ["route_id", "agency_id", "route_short_name", "route_long_name", "route_type", "route_color", "route_text_color"],
        list(rutas.values()),
    )
    escribir(
        salida / "trips.txt",
        ["route_id", "service_id", "trip_id", "trip_headsign", "direction_id", "shape_id"],
        viajes,
    )
    escribir(
        salida / "shapes.txt",
        ["shape_id", "shape_pt_lat", "shape_pt_lon", "shape_pt_sequence"],
        shapes,
    )
    escribir(
        salida / "stops.txt",
        ["stop_id", "stop_name", "stop_lat", "stop_lon", "stop_desc"],
        paradas,
    )
    escribir(
        salida / "stop_times.txt",
        ["trip_id", "arrival_time", "departure_time", "stop_id", "stop_sequence", "shape_dist_traveled"],
        horarios,
    )
    (salida / "calendar.txt").write_text(
        "service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\n"
        "diario,1,1,1,1,1,1,1,20260101,20271231\n",
        encoding="utf-8",
    )
    print(
        f"Agencias {len(agencias)}, rutas {len(rutas)}, viajes {len(viajes)}, "
        f"paradas sintéticas {len(paradas)}. Carpeta {salida}."
    )


if __name__ == "__main__":
    main()
