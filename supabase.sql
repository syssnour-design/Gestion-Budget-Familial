-- =====================================================================
-- BudgetFoyer : schéma Supabase pour le partage du budget familial
-- À exécuter une seule fois dans Supabase > SQL Editor > New query > Run
-- (le script peut être relancé sans risque)
-- =====================================================================

-- Foyers
create table if not exists public.households (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  invite_code  text not null unique default upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
  created_by   uuid not null references auth.users(id) on delete cascade default auth.uid(),
  created_at   timestamptz not null default now()
);

-- Membres d'un foyer
create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  display_name text not null default '',
  role         text not null default 'membre' check (role in ('admin','membre')),
  joined_at    timestamptz not null default now(),
  primary key (household_id, user_id)
);

-- Données du budget : paramètres, rubriques, opérations, objectifs, montants prévus.
-- Chaque élément est une ligne, ce qui permet à plusieurs téléphones de saisir en même temps.
create table if not exists public.items (
  household_id uuid not null references public.households(id) on delete cascade,
  kind         text not null check (kind in ('meta','cat','tx','goal','budget')),
  id           text not null,
  data         jsonb not null default '{}'::jsonb,
  deleted      boolean not null default false,   -- suppression logique, propagée aux autres téléphones
  origin       text,                             -- identifiant de session de l'appareil émetteur
  updated_by   uuid default auth.uid(),
  updated_at   timestamptz not null default now(),
  primary key (household_id, kind, id)
);
create index if not exists items_household_updated on public.items (household_id, updated_at);

-- Horodatage fixé par le serveur (sert à la resynchronisation après une coupure)
create or replace function public.touch_item() returns trigger
language plpgsql as $$
begin
  new.updated_at := clock_timestamp();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  return new;
end $$;
drop trigger if exists items_touch on public.items;
create trigger items_touch before insert or update on public.items
for each row execute function public.touch_item();

-- Fonctions d'appartenance (security definer pour éviter la récursion des règles)
create or replace function public.is_member(h uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from household_members where household_id = h and user_id = auth.uid());
$$;
create or replace function public.is_admin(h uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from household_members where household_id = h and user_id = auth.uid() and role = 'admin');
$$;

-- Sécurité : chaque utilisateur ne voit que les foyers dont il est membre
alter table public.households        enable row level security;
alter table public.household_members enable row level security;
alter table public.items             enable row level security;

drop policy if exists hh_select   on public.households;
drop policy if exists hh_update   on public.households;
drop policy if exists hm_select   on public.household_members;
drop policy if exists hm_delete   on public.household_members;
drop policy if exists items_all   on public.items;

create policy hh_select on public.households        for select using (public.is_member(id));
create policy hh_update on public.households        for update using (public.is_admin(id)) with check (public.is_admin(id));
create policy hm_select on public.household_members for select using (public.is_member(household_id));
create policy hm_delete on public.household_members for delete using (user_id = auth.uid() or public.is_admin(household_id));
create policy items_all on public.items             for all    using (public.is_member(household_id)) with check (public.is_member(household_id));

-- Créer un foyer (le créateur devient administrateur)
create or replace function public.create_household(p_name text, p_display text)
returns public.households
language plpgsql security definer set search_path = public as $$
declare h households;
begin
  if auth.uid() is null then raise exception 'Non authentifié'; end if;
  insert into households (name, created_by)
    values (coalesce(nullif(trim(p_name), ''), 'Mon foyer'), auth.uid())
    returning * into h;
  insert into household_members (household_id, user_id, display_name, role)
    values (h.id, auth.uid(), coalesce(p_display, ''), 'admin');
  return h;
end $$;

-- Rejoindre un foyer avec son code d'invitation
create or replace function public.join_household(p_code text, p_display text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare hid uuid;
begin
  if auth.uid() is null then raise exception 'Non authentifié'; end if;
  select id into hid from households where invite_code = upper(trim(p_code));
  if hid is null then raise exception 'Code d''invitation inconnu'; end if;
  insert into household_members (household_id, user_id, display_name)
    values (hid, auth.uid(), coalesce(p_display, ''))
    on conflict (household_id, user_id) do nothing;
  return hid;
end $$;

-- Changer le code d'invitation (administrateur uniquement)
create or replace function public.regenerate_invite(p_household uuid)
returns text
language plpgsql security definer set search_path = public as $$
declare c text;
begin
  if not public.is_admin(p_household) then raise exception 'Réservé à l''administrateur du foyer'; end if;
  update households set invite_code = upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))
    where id = p_household returning invite_code into c;
  return c;
end $$;

revoke execute on function public.create_household(text,text)  from anon, public;
revoke execute on function public.join_household(text,text)    from anon, public;
revoke execute on function public.regenerate_invite(uuid)      from anon, public;
grant  execute on function public.create_household(text,text)  to authenticated;
grant  execute on function public.join_household(text,text)    to authenticated;
grant  execute on function public.regenerate_invite(uuid)      to authenticated;

-- Temps réel : diffuser les changements de la table items aux téléphones connectés
do $$
begin
  alter publication supabase_realtime add table public.items;
exception when duplicate_object then null;
end $$;
