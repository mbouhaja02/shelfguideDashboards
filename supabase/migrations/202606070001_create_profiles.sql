begin;

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'app_role'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.app_role as enum ('chef', 'manager', 'hq');
  end if;
end
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null default 'chef',
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

revoke all on public.profiles from anon;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

grant select on public.profiles to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role text;
begin
  requested_role := new.raw_app_meta_data ->> 'role';

  insert into public.profiles (id, role, full_name)
  values (
    new.id,
    case
      when requested_role in ('chef', 'manager', 'hq')
        then requested_role::public.app_role
      else 'chef'::public.app_role
    end,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

insert into public.profiles (id, role, full_name)
select
  users.id,
  case
    when users.raw_app_meta_data ->> 'role' in ('chef', 'manager', 'hq')
      then (users.raw_app_meta_data ->> 'role')::public.app_role
    else 'chef'::public.app_role
  end,
  coalesce(users.raw_user_meta_data ->> 'full_name', users.raw_user_meta_data ->> 'name')
from auth.users
on conflict (id) do nothing;

create or replace function public.set_profiles_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute procedure public.set_profiles_updated_at();

commit;

-- Affectation des roles par un administrateur Supabase :
-- update public.profiles set role = 'manager' where id = '<uuid>';
-- update public.profiles set role = 'hq' where id = '<uuid>';
