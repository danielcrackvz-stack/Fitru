-- Permisos y RLS. El dueño de la tabla (postgres) sigue pudiendo sembrar.
-- Un rol de aplicación solo ve sus filas. aplicar_pasaje es SECURITY DEFINER
-- con search_path fijo para que no se pueda secuestrar la función.

create or replace function kufi_usuario_actual()
returns text
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_usuario text;
begin
  v_usuario := nullif(current_setting('kufi.usuario_id', true), '');
  if v_usuario is not null then
    return v_usuario;
  end if;
  begin
    execute 'select auth.uid()::text' into v_usuario;
  exception
    when undefined_function or invalid_schema_name then
      v_usuario := null;
  end;
  return nullif(v_usuario, '');
end;
$$;

revoke all on function kufi_usuario_actual() from public;
grant execute on function kufi_usuario_actual() to public;

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
security definer
set search_path = public, pg_temp
as $$
declare
  v_existente text;
  v_dueno text;
  v_actor text;
begin
  if p_centavos is null or p_centavos <= 0 or p_centavos > 2000000 then
    raise exception 'monto_invalido';
  end if;
  if p_clave is null or length(p_clave) < 8 or p_pago_id is null then
    raise exception 'clave_invalida';
  end if;

  select usuario_id into v_dueno from cuentas where id = p_pasajero;
  if v_dueno is null then
    raise exception 'cuenta_inexistente';
  end if;

  v_actor := kufi_usuario_actual();
  if v_actor is not null and v_actor is distinct from v_dueno then
    raise exception 'no_autorizado';
  end if;
  if v_actor is null and current_user not in ('postgres', 'supabase_admin', 'service_role') then
    raise exception 'no_autorizado';
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

  if p_meta ? 'token_id' then
    insert into tokens_usados (token_id, pago_id)
    values (p_meta->>'token_id', p_pago_id)
    on conflict (token_id) do nothing;
  end if;

  return p_pago_id;
end;
$$;

revoke all on function aplicar_pasaje(text, text, text, bigint, text, jsonb) from public;
grant execute on function aplicar_pasaje(text, text, text, bigint, text, jsonb) to postgres;

alter table cuentas enable row level security;
alter table libro_mayor enable row level security;
alter table tokens_usados enable row level security;
alter table turnos enable row level security;
alter table tarifas enable row level security;
alter table rutas enable row level security;
alter table viajes enable row level security;
alter table shapes enable row level security;
alter table shape_puntos enable row level security;
alter table agencias enable row level security;

drop policy if exists cuentas_propias on cuentas;
create policy cuentas_propias on cuentas
  for select
  using (usuario_id = kufi_usuario_actual());

drop policy if exists libro_propio on libro_mayor;
create policy libro_propio on libro_mayor
  for select
  using (
    cuenta_id in (
      select id from cuentas where usuario_id = kufi_usuario_actual()
    )
  );

drop policy if exists turnos_propios on turnos;
create policy turnos_propios on turnos
  for select
  using (
    cuenta_chofer_id in (
      select id from cuentas where usuario_id = kufi_usuario_actual()
    )
  );

drop policy if exists catalogo_rutas on rutas;
create policy catalogo_rutas on rutas for select using (true);
drop policy if exists catalogo_viajes on viajes;
create policy catalogo_viajes on viajes for select using (true);
drop policy if exists catalogo_shapes on shapes;
create policy catalogo_shapes on shapes for select using (true);
drop policy if exists catalogo_puntos on shape_puntos;
create policy catalogo_puntos on shape_puntos for select using (true);
drop policy if exists catalogo_agencias on agencias;
create policy catalogo_agencias on agencias for select using (true);
drop policy if exists tarifas_lectura on tarifas;
create policy tarifas_lectura on tarifas for select using (true);

revoke insert, update, delete on libro_mayor from public;
revoke insert, update, delete on cuentas from public;
revoke insert, update, delete on tokens_usados from public;
