-- Catálogo de trufis con forma GTFS y geometría PostGIS.
-- Los trufis de Santa Cruz no tienen número de línea: la gente los llama por zona
-- (nombre_comun). route_id (R001–R126) es un id interno, no oficial.

create table if not exists agencias (
  agencia_id text primary key,
  nombre text not null,
  url text,
  zona_horaria text not null default 'America/La_Paz'
);

create table if not exists rutas (
  route_id text primary key,
  agencia_id text references agencias (agencia_id),
  nombre_comun text not null,
  nombre_crudo text not null default '',
  nombre_revisar boolean not null default false,
  motivo_revisar text not null default '',
  zonas text not null default '',
  operador text not null default '',
  tipo_entidad text not null default '',
  federacion text not null default '',
  jurisdiccion text not null default '',
  color_panter text not null default '',
  banderin text not null default '',
  color_hex text not null default '#009048',
  color_hex_2 text not null default '',
  fecha_ruteo date
);

create table if not exists viajes (
  trip_id text primary key,
  route_id text not null references rutas (route_id),
  shape_id text not null,
  sentido text not null check (sentido in ('ida', 'vuelta')),
  zona_origen text not null default '',
  zona_destino text not null default '',
  km numeric(8, 2) not null default 0,
  minutos numeric(6, 1) not null default 0,
  geom_invertida_corregida boolean not null default false
);

-- Un registro por sentido, con la línea en EPSG:4326.
create table if not exists shapes (
  shape_id text primary key,
  route_id text not null references rutas (route_id),
  sentido text not null check (sentido in ('ida', 'vuelta')),
  geom geometry(LineString, 4326) not null
);

-- Secuencia GTFS clásica (lat/lon por vértice), además de la geometría.
create table if not exists shape_puntos (
  shape_id text not null references shapes (shape_id) on delete cascade,
  secuencia integer not null,
  lat double precision not null,
  lon double precision not null,
  primary key (shape_id, secuencia)
);

create index if not exists rutas_nombre_idx on rutas (nombre_comun);
create index if not exists rutas_jurisdiccion_idx on rutas (jurisdiccion);
create index if not exists shapes_geom_idx on shapes using gist (geom);
create index if not exists viajes_route_idx on viajes (route_id);
