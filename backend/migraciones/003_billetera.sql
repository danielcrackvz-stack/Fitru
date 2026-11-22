-- Billetera. El saldo no se guarda: es la suma del libro.
-- El libro es append-only. La clave de idempotencia impide el doble cobro.

create table if not exists cuentas (
  id text primary key,
  usuario_id text not null,
  rol text not null check (rol in ('pasajero', 'chofer', 'operador', 'sistema')),
  nombre text not null,
  telefono text,
  creado_en timestamptz not null default now()
);

create table if not exists libro_mayor (
  id text primary key,
  clave_idempotencia text not null unique,
  cuenta_id text not null references cuentas (id),
  tipo text not null check (tipo in ('recarga', 'pasaje', 'reverso')),
  centavos bigint not null check (centavos <> 0),
  creado_en timestamptz not null default now(),
  pago_id text not null,
  ruta_id text,
  nombre_ruta text,
  operador text,
  tipo_pasaje text,
  pasajeros integer not null default 1,
  medio text,
  sentido text,
  vehiculo_id text,
  sync text not null default 'sincronizado' check (sync in ('sincronizado', 'pendiente')),
  numero_operacion text,
  nota text
);

create index if not exists libro_cuenta_idx on libro_mayor (cuenta_id, creado_en desc);
create index if not exists libro_pago_idx on libro_mayor (pago_id);
create index if not exists libro_sync_idx on libro_mayor (sync) where sync = 'pendiente';

create or replace function kufi_libro_es_inmutable()
returns trigger
language plpgsql
as $$
begin
  raise exception 'libro_mayor es inmutable: no se puede %', tg_op;
end;
$$;

drop trigger if exists libro_mayor_no_update on libro_mayor;
create trigger libro_mayor_no_update
  before update or delete on libro_mayor
  for each row execute function kufi_libro_es_inmutable();

create or replace function saldo_cuenta(p_cuenta text)
returns bigint
language sql
stable
as $$
  select coalesce(sum(centavos), 0)::bigint
  from libro_mayor
  where cuenta_id = p_cuenta;
$$;

-- Cobra un pasaje en una sola transacción.
-- Si la clave ya existe, devuelve el pago original y no descuenta de nuevo.
create or replace function aplicar_pasaje(
  p_clave text,
  p_pasajero text,
  p_chofer text,
  p_centavos bigint,
  p_pago_id text,
  p_meta jsonb default '{}'::jsonb
)
returns text
language plpgsql
as $$
declare
  v_existente text;
begin
  if p_centavos <= 0 then
    raise exception 'monto_invalido';
  end if;

  select pago_id into v_existente
  from libro_mayor
  where clave_idempotencia = p_clave || ':debito';

  if v_existente is not null then
    return v_existente;
  end if;

  if saldo_cuenta(p_pasajero) < p_centavos then
    raise exception 'saldo_insuficiente';
  end if;

  insert into libro_mayor (
    id, clave_idempotencia, cuenta_id, tipo, centavos, pago_id,
    ruta_id, nombre_ruta, operador, tipo_pasaje, pasajeros, medio,
    sentido, vehiculo_id, numero_operacion, sync
  ) values (
    gen_random_uuid()::text,
    p_clave || ':debito',
    p_pasajero,
    'pasaje',
    -p_centavos,
    p_pago_id,
    p_meta->>'ruta_id',
    p_meta->>'nombre_ruta',
    p_meta->>'operador',
    p_meta->>'tipo_pasaje',
    coalesce((p_meta->>'pasajeros')::int, 1),
    p_meta->>'medio',
    p_meta->>'sentido',
    p_meta->>'vehiculo_id',
    p_meta->>'numero_operacion',
    coalesce(p_meta->>'sync', 'sincronizado')
  );

  insert into libro_mayor (
    id, clave_idempotencia, cuenta_id, tipo, centavos, pago_id,
    ruta_id, nombre_ruta, operador, tipo_pasaje, pasajeros, medio,
    sentido, vehiculo_id, numero_operacion, sync
  ) values (
    gen_random_uuid()::text,
    p_clave || ':credito',
    p_chofer,
    'pasaje',
    p_centavos,
    p_pago_id,
    p_meta->>'ruta_id',
    p_meta->>'nombre_ruta',
    p_meta->>'operador',
    p_meta->>'tipo_pasaje',
    coalesce((p_meta->>'pasajeros')::int, 1),
    p_meta->>'medio',
    p_meta->>'sentido',
    p_meta->>'vehiculo_id',
    p_meta->>'numero_operacion',
    coalesce(p_meta->>'sync', 'sincronizado')
  );

  return p_pago_id;
end;
$$;

create table if not exists tokens_usados (
  token_id text primary key,
  pago_id text not null,
  usado_en timestamptz not null default now()
);

create table if not exists turnos (
  id text primary key,
  cuenta_chofer_id text not null references cuentas (id),
  vehiculo_id text not null,
  route_id text not null references rutas (route_id),
  sentido text not null check (sentido in ('ida', 'vuelta')),
  iniciado_en timestamptz not null default now(),
  cerrado_en timestamptz,
  pausado boolean not null default false
);

create table if not exists tarifas (
  tipo text primary key,
  centavos integer not null check (centavos > 0),
  nota text not null default 'Por confirmar con la asociación.'
);

insert into tarifas (tipo, centavos) values
  ('adulto', 230),
  ('estudiante', 100),
  ('nino', 100),
  ('adulto_mayor', 150)
on conflict (tipo) do nothing;
