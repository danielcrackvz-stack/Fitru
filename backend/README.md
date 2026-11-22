# Backend Kufi

El sistema de registro pensado para producción es **PostgreSQL con PostGIS**, el mismo motor que usa Supabase. Las migraciones están en `migraciones/` y no dependen del panel de Supabase.

La app Flutter no necesita esta base para la demo: el libro mayor corre en el teléfono con el mismo modelo (apuntes inmutables y clave de idempotencia). Cuando haya servidor, `aplicar_pasaje` hace ese cobro en una transacción.

## Aplicar

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migraciones/001_extensiones.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migraciones/002_gtfs_rutas.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migraciones/003_billetera.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migraciones/004_rls_seguridad.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/semilla/rutas.sql
```

`rutas.sql` sale de los archivos de `datos/`:

```bash
python3 backend/semilla/generar_semilla.py
```

Carga 126 rutas, 250 sentidos (ida/vuelta) y los vértices del GeoJSON. La geometría queda en `shapes.geom` (EPSG:4326) y también como `shape_puntos`, al estilo GTFS.

No hay credenciales en este directorio. La URL de la base va en `.env`, a partir de `.env.example`.
