begin;

create extension if not exists pgcrypto with schema extensions;

do $$
begin
  if not exists (
    select 1 from pg_type
    where typname = 'task_status'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.task_status as enum (
      'open',
      'in_progress',
      'corrected',
      'verified',
      'rejected'
    );
  end if;

  if not exists (
    select 1 from pg_type
    where typname = 'task_priority'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.task_priority as enum ('low', 'medium', 'high');
  end if;

  if not exists (
    select 1 from pg_type
    where typname = 'task_event_type'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.task_event_type as enum (
      'created',
      'status_changed',
      'assigned',
      'photo_uploaded',
      'commented',
      'updated'
    );
  end if;
end
$$;

create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  store_format text not null default 'Super'
    check (store_format in ('Hyper', 'Super', 'Proximite', 'Express', 'Autre')),
  address text,
  city text not null default 'Casablanca',
  region text not null default 'Casablanca-Settat',
  country text not null default 'Maroc',
  latitude numeric(9, 6) check (latitude is null or latitude between -90 and 90),
  longitude numeric(9, 6) check (longitude is null or longitude between -180 and 180),
  timezone text not null default 'Africa/Casablanca',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shelves (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  code text not null,
  name text not null,
  category text not null default 'Autre',
  planogram_url text,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, code),
  unique (store_id, name)
);

create table if not exists public.store_members (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  member_role public.app_role not null,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, user_id),
  check (member_role in ('chef', 'manager'))
);

-- A store membership establishes the store perimeter. This second relation
-- narrows a chef account to one or more shelves inside that store.
create table if not exists public.shelf_members (
  id uuid primary key default gen_random_uuid(),
  shelf_id uuid not null references public.shelves(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (shelf_id, user_id)
);

create table if not exists public.action_tasks (
  id uuid primary key default gen_random_uuid(),
  -- shelfguide_analyses.id is not assumed to have a specific SQL type.
  -- The immutable textual identifier keeps the pilot migration compatible
  -- with existing bigint, uuid or text analysis tables.
  analysis_id text,
  store_id uuid not null references public.stores(id) on delete restrict,
  shelf_id uuid not null references public.shelves(id) on delete restrict,
  title text not null,
  description text,
  issue_type text,
  product_sku text,
  status public.task_status not null default 'open',
  priority public.task_priority not null default 'medium',
  assigned_to uuid references auth.users(id) on delete set null,
  created_by uuid not null references auth.users(id) on delete restrict,
  due_at timestamptz,
  corrected_at timestamptz,
  verified_at timestamptz,
  rejected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists action_tasks_analysis_id_unique
  on public.action_tasks (analysis_id)
  where analysis_id is not null;

create table if not exists public.task_events (
  id bigint generated always as identity primary key,
  task_id uuid not null references public.action_tasks(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  event_type public.task_event_type not null,
  from_status public.task_status,
  to_status public.task_status,
  from_assigned_to uuid references auth.users(id) on delete set null,
  to_assigned_to uuid references auth.users(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (jsonb_typeof(metadata) = 'object')
);

create table if not exists public.task_photos (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.action_tasks(id) on delete cascade,
  storage_path text not null unique,
  file_name text not null,
  mime_type text not null check (mime_type like 'image/%'),
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 10485760),
  uploaded_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.task_comments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.action_tasks(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete restrict,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists shelves_store_id_idx on public.shelves(store_id);
create index if not exists store_members_user_id_idx on public.store_members(user_id) where is_active;
create index if not exists shelf_members_user_id_idx on public.shelf_members(user_id) where is_active;
create index if not exists action_tasks_store_status_idx on public.action_tasks(store_id, status);
create index if not exists action_tasks_shelf_status_idx on public.action_tasks(shelf_id, status);
create index if not exists action_tasks_assigned_status_idx on public.action_tasks(assigned_to, status);
create index if not exists action_tasks_updated_at_idx on public.action_tasks(updated_at desc);
create index if not exists task_events_task_created_idx on public.task_events(task_id, created_at desc);
create index if not exists task_photos_task_created_idx on public.task_photos(task_id, created_at desc);
create index if not exists task_comments_task_created_idx on public.task_comments(task_id, created_at);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists stores_set_updated_at on public.stores;
create trigger stores_set_updated_at
  before update on public.stores
  for each row execute procedure public.set_updated_at();

drop trigger if exists shelves_set_updated_at on public.shelves;
create trigger shelves_set_updated_at
  before update on public.shelves
  for each row execute procedure public.set_updated_at();

drop trigger if exists store_members_set_updated_at on public.store_members;
create trigger store_members_set_updated_at
  before update on public.store_members
  for each row execute procedure public.set_updated_at();

drop trigger if exists task_comments_set_updated_at on public.task_comments;
create trigger task_comments_set_updated_at
  before update on public.task_comments
  for each row execute procedure public.set_updated_at();

create or replace function public.current_app_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select p.role
  from public.profiles p
  where p.id = (select auth.uid())
  limit 1
$$;

create or replace function public.has_valid_profile()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('chef', 'manager', 'hq')
  )
$$;

create or replace function public.is_hq()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() = 'hq'::public.app_role
$$;

create or replace function public.is_store_member(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.store_members sm
    where sm.store_id = p_store_id
      and sm.user_id = (select auth.uid())
      and sm.is_active
  )
$$;

create or replace function public.is_store_manager(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() = 'manager'::public.app_role
    and exists (
      select 1
      from public.store_members sm
      where sm.store_id = p_store_id
        and sm.user_id = (select auth.uid())
        and sm.member_role = 'manager'::public.app_role
        and sm.is_active
    )
$$;

create or replace function public.is_shelf_member(p_shelf_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.shelf_members shm
    where shm.shelf_id = p_shelf_id
      and shm.user_id = (select auth.uid())
      and shm.is_active
  )
$$;

create or replace function public.can_access_shelf(p_store_id uuid, p_shelf_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_valid_profile()
    and exists (
      select 1
      from public.shelves s
      where s.id = p_shelf_id
        and s.store_id = p_store_id
        and s.is_active
    )
    and (
      public.is_hq()
      or public.is_store_manager(p_store_id)
      or (
        public.current_app_role() = 'chef'::public.app_role
        and public.is_store_member(p_store_id)
        and public.is_shelf_member(p_shelf_id)
      )
    )
$$;

create or replace function public.can_view_task(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.action_tasks t
    where t.id = p_task_id
      and public.can_access_shelf(t.store_id, t.shelf_id)
  )
$$;

create or replace function public.can_manage_task(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.action_tasks t
    where t.id = p_task_id
      and public.has_valid_profile()
      and (
        public.is_store_manager(t.store_id)
        or (
          public.current_app_role() = 'chef'::public.app_role
          and public.is_store_member(t.store_id)
          and public.is_shelf_member(t.shelf_id)
          and (t.assigned_to is null or t.assigned_to = (select auth.uid()))
        )
      )
  )
$$;

create or replace function public.can_view_profile(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_valid_profile()
    and (
      p_user_id = (select auth.uid())
      or public.is_hq()
      or exists (
        select 1
        from public.store_members mine
        join public.store_members theirs on theirs.store_id = mine.store_id
        where mine.user_id = (select auth.uid())
          and mine.member_role = 'manager'::public.app_role
          and mine.is_active
          and theirs.user_id = p_user_id
          and theirs.is_active
      )
    )
$$;

revoke all on function public.current_app_role() from public;
revoke all on function public.has_valid_profile() from public;
revoke all on function public.is_hq() from public;
revoke all on function public.is_store_member(uuid) from public;
revoke all on function public.is_store_manager(uuid) from public;
revoke all on function public.is_shelf_member(uuid) from public;
revoke all on function public.can_access_shelf(uuid, uuid) from public;
revoke all on function public.can_view_task(uuid) from public;
revoke all on function public.can_manage_task(uuid) from public;
revoke all on function public.can_view_profile(uuid) from public;

grant execute on function public.current_app_role() to authenticated;
grant execute on function public.has_valid_profile() to authenticated;
grant execute on function public.is_hq() to authenticated;
grant execute on function public.is_store_member(uuid) to authenticated;
grant execute on function public.is_store_manager(uuid) to authenticated;
grant execute on function public.is_shelf_member(uuid) to authenticated;
grant execute on function public.can_access_shelf(uuid, uuid) to authenticated;
grant execute on function public.can_view_task(uuid) to authenticated;
grant execute on function public.can_manage_task(uuid) to authenticated;
grant execute on function public.can_view_profile(uuid) to authenticated;

create or replace function public.enforce_action_task_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  actor_role public.app_role;
  is_admin_context boolean := actor is null;
begin
  if tg_op = 'UPDATE' then
    if new.id <> old.id
      or new.store_id <> old.store_id
      or new.shelf_id <> old.shelf_id
      or new.analysis_id is distinct from old.analysis_id
      or new.created_by <> old.created_by
      or new.created_at <> old.created_at
    then
      raise exception 'Task identity and perimeter are immutable';
    end if;
  end if;

  if not exists (
    select 1 from public.shelves s
    where s.id = new.shelf_id and s.store_id = new.store_id and s.is_active
  ) then
    raise exception 'Shelf does not belong to the task store';
  end if;

  if new.assigned_to is not null and not exists (
    select 1 from public.store_members sm
    where sm.store_id = new.store_id
      and sm.user_id = new.assigned_to
      and sm.is_active
  ) then
    raise exception 'Assignee is not an active member of this store';
  end if;

  if new.assigned_to is not null
    and exists (
      select 1
      from public.profiles p
      where p.id = new.assigned_to
        and p.role = 'chef'::public.app_role
    )
    and not exists (
      select 1
      from public.shelf_members shm
      where shm.shelf_id = new.shelf_id
        and shm.user_id = new.assigned_to
        and shm.is_active
    )
  then
    raise exception 'Chef assignee is not authorized for this shelf';
  end if;

  if not is_admin_context then
    select p.role into actor_role
    from public.profiles p
    where p.id = actor;

    if actor_role is null then
      raise exception 'A valid ShelfGuide profile is required';
    end if;

    if actor_role = 'hq'::public.app_role then
      raise exception 'HQ access to operational tasks is read-only';
    end if;

    if tg_op = 'INSERT' then
      new.created_by := actor;

      if actor_role = 'manager'::public.app_role then
        if not public.is_store_manager(new.store_id) then
          raise exception 'Manager is outside this store';
        end if;
      elsif actor_role = 'chef'::public.app_role then
        if not public.is_store_member(new.store_id)
          or not public.is_shelf_member(new.shelf_id)
          or (new.assigned_to is not null and new.assigned_to <> actor)
        then
          raise exception 'Chef is outside this shelf perimeter';
        end if;
      end if;
    else
      if actor_role = 'manager'::public.app_role then
        if not public.is_store_manager(old.store_id) then
          raise exception 'Manager is outside this store';
        end if;
      elsif actor_role = 'chef'::public.app_role then
        if not public.is_store_member(old.store_id)
          or not public.is_shelf_member(old.shelf_id)
          or (old.assigned_to is not null and old.assigned_to <> actor)
        then
          raise exception 'Chef cannot modify this task';
        end if;

        if new.assigned_to is distinct from old.assigned_to
          and not (old.assigned_to is null and new.assigned_to = actor)
        then
          raise exception 'Chef can only claim an unassigned task';
        end if;

        if new.status is distinct from old.status and not (
          (old.status = 'open' and new.status = 'in_progress')
          or (old.status = 'in_progress' and new.status = 'corrected')
          or (old.status = 'corrected' and new.status = 'in_progress')
          or (old.status = 'rejected' and new.status = 'in_progress')
        ) then
          raise exception 'Invalid chef task status transition';
        end if;
      end if;

      if old.status = 'verified' and new.status is distinct from old.status then
        raise exception 'A verified task is immutable';
      end if;
    end if;
  elsif tg_op = 'INSERT' and new.created_by is null then
    raise exception 'created_by is required in administrative context';
  end if;

  if tg_op = 'INSERT' or new.status is distinct from old.status then
    if new.status = 'corrected' and new.corrected_at is null then
      new.corrected_at := now();
    elsif new.status = 'verified' and new.verified_at is null then
      new.verified_at := now();
    elsif new.status = 'rejected' then
      new.rejected_at := now();
      new.verified_at := null;
    elsif new.status = 'in_progress' then
      new.rejected_at := null;
      if tg_op = 'UPDATE' and old.status in ('corrected', 'rejected') then
        new.corrected_at := null;
      end if;
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists action_tasks_enforce_write on public.action_tasks;
create trigger action_tasks_enforce_write
  before insert or update on public.action_tasks
  for each row execute procedure public.enforce_action_task_write();

create or replace function public.audit_action_task_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := coalesce(auth.uid(), new.created_by);
begin
  if tg_op = 'INSERT' then
    insert into public.task_events (task_id, actor_id, event_type, to_status, metadata)
    values (new.id, actor, 'created', new.status, jsonb_build_object('priority', new.priority));

    if new.assigned_to is not null then
      insert into public.task_events (
        task_id, actor_id, event_type, to_assigned_to, metadata
      )
      values (
        new.id, actor, 'assigned', new.assigned_to,
        jsonb_build_object('source', 'task_creation')
      );
    end if;
  else
    if new.status is distinct from old.status then
      insert into public.task_events (
        task_id, actor_id, event_type, from_status, to_status
      )
      values (new.id, actor, 'status_changed', old.status, new.status);
    end if;

    if new.assigned_to is distinct from old.assigned_to then
      insert into public.task_events (
        task_id, actor_id, event_type, from_assigned_to, to_assigned_to
      )
      values (new.id, actor, 'assigned', old.assigned_to, new.assigned_to);
    end if;

    if new.status is not distinct from old.status
      and new.assigned_to is not distinct from old.assigned_to
      and (
        new.title is distinct from old.title
        or new.description is distinct from old.description
        or new.priority is distinct from old.priority
        or new.due_at is distinct from old.due_at
      )
    then
      insert into public.task_events (task_id, actor_id, event_type)
      values (new.id, actor, 'updated');
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists action_tasks_audit_change on public.action_tasks;
create trigger action_tasks_audit_change
  after insert or update on public.action_tasks
  for each row execute procedure public.audit_action_task_change();

create or replace function public.audit_task_photo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.task_events (task_id, actor_id, event_type, metadata)
  values (
    new.task_id,
    new.uploaded_by,
    'photo_uploaded',
    jsonb_build_object(
      'photo_id', new.id,
      'file_name', new.file_name,
      'storage_path', new.storage_path
    )
  );
  return new;
end;
$$;

drop trigger if exists task_photos_audit_insert on public.task_photos;
create trigger task_photos_audit_insert
  after insert on public.task_photos
  for each row execute procedure public.audit_task_photo();

create or replace function public.audit_task_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.task_events (task_id, actor_id, event_type, metadata)
  values (
    new.task_id,
    new.author_id,
    'commented',
    jsonb_build_object('comment_id', new.id)
  );
  return new;
end;
$$;

drop trigger if exists task_comments_audit_insert on public.task_comments;
create trigger task_comments_audit_insert
  after insert on public.task_comments
  for each row execute procedure public.audit_task_comment();

alter table public.stores enable row level security;
alter table public.shelves enable row level security;
alter table public.store_members enable row level security;
alter table public.shelf_members enable row level security;
alter table public.action_tasks enable row level security;
alter table public.task_events enable row level security;
alter table public.task_photos enable row level security;
alter table public.task_comments enable row level security;

revoke all on public.stores from anon;
revoke all on public.shelves from anon;
revoke all on public.store_members from anon;
revoke all on public.shelf_members from anon;
revoke all on public.action_tasks from anon;
revoke all on public.task_events from anon;
revoke all on public.task_photos from anon;
revoke all on public.task_comments from anon;

grant select on public.stores, public.shelves, public.store_members, public.shelf_members to authenticated;
grant select, insert, update on public.action_tasks to authenticated;
grant select on public.task_events to authenticated;
grant select, insert, delete on public.task_photos to authenticated;
grant select, insert, update, delete on public.task_comments to authenticated;
grant usage, select on sequence public.task_events_id_seq to authenticated;

drop policy if exists stores_select_perimeter on public.stores;
create policy stores_select_perimeter
on public.stores for select to authenticated
using (
  public.has_valid_profile()
  and (public.is_hq() or public.is_store_member(id))
);

drop policy if exists shelves_select_perimeter on public.shelves;
create policy shelves_select_perimeter
on public.shelves for select to authenticated
using (
  public.has_valid_profile()
  and (
    public.is_hq()
    or public.is_store_manager(store_id)
    or (
      public.current_app_role() = 'chef'::public.app_role
      and public.is_store_member(store_id)
      and public.is_shelf_member(id)
    )
  )
);

drop policy if exists store_members_select_perimeter on public.store_members;
create policy store_members_select_perimeter
on public.store_members for select to authenticated
using (
  public.has_valid_profile()
  and (
    public.is_hq()
    or user_id = (select auth.uid())
    or public.is_store_manager(store_id)
  )
);

drop policy if exists shelf_members_select_perimeter on public.shelf_members;
create policy shelf_members_select_perimeter
on public.shelf_members for select to authenticated
using (
  public.has_valid_profile()
  and (
    user_id = (select auth.uid())
    or public.is_hq()
    or exists (
      select 1
      from public.shelves s
      where s.id = shelf_id
        and public.is_store_manager(s.store_id)
    )
  )
);

drop policy if exists action_tasks_select_perimeter on public.action_tasks;
create policy action_tasks_select_perimeter
on public.action_tasks for select to authenticated
using (public.can_access_shelf(store_id, shelf_id));

drop policy if exists action_tasks_insert_perimeter on public.action_tasks;
create policy action_tasks_insert_perimeter
on public.action_tasks for insert to authenticated
with check (
  public.has_valid_profile()
  and created_by = (select auth.uid())
  and (
    public.is_store_manager(store_id)
    or (
      public.current_app_role() = 'chef'::public.app_role
      and public.is_store_member(store_id)
      and public.is_shelf_member(shelf_id)
      and (assigned_to is null or assigned_to = (select auth.uid()))
    )
  )
);

drop policy if exists action_tasks_update_perimeter on public.action_tasks;
create policy action_tasks_update_perimeter
on public.action_tasks for update to authenticated
using (public.can_manage_task(id))
with check (public.can_manage_task(id));

drop policy if exists task_events_select_perimeter on public.task_events;
create policy task_events_select_perimeter
on public.task_events for select to authenticated
using (public.can_view_task(task_id));

drop policy if exists task_photos_select_perimeter on public.task_photos;
create policy task_photos_select_perimeter
on public.task_photos for select to authenticated
using (public.can_view_task(task_id));

drop policy if exists task_photos_insert_perimeter on public.task_photos;
create policy task_photos_insert_perimeter
on public.task_photos for insert to authenticated
with check (
  uploaded_by = (select auth.uid())
  and public.can_manage_task(task_id)
);

drop policy if exists task_photos_delete_perimeter on public.task_photos;
create policy task_photos_delete_perimeter
on public.task_photos for delete to authenticated
using (
  uploaded_by = (select auth.uid())
  or exists (
    select 1
    from public.action_tasks t
    where t.id = task_id and public.is_store_manager(t.store_id)
  )
);

drop policy if exists task_comments_select_perimeter on public.task_comments;
create policy task_comments_select_perimeter
on public.task_comments for select to authenticated
using (public.can_view_task(task_id));

drop policy if exists task_comments_insert_perimeter on public.task_comments;
create policy task_comments_insert_perimeter
on public.task_comments for insert to authenticated
with check (
  author_id = (select auth.uid())
  and public.can_manage_task(task_id)
);

drop policy if exists task_comments_update_own on public.task_comments;
create policy task_comments_update_own
on public.task_comments for update to authenticated
using (author_id = (select auth.uid()))
with check (author_id = (select auth.uid()) and public.can_manage_task(task_id));

drop policy if exists task_comments_delete_own on public.task_comments;
create policy task_comments_delete_own
on public.task_comments for delete to authenticated
using (
  author_id = (select auth.uid())
  or exists (
    select 1
    from public.action_tasks t
    where t.id = task_id and public.is_store_manager(t.store_id)
  )
);

drop policy if exists profiles_select_store_colleagues on public.profiles;
create policy profiles_select_store_colleagues
on public.profiles for select to authenticated
using (public.can_view_profile(id));

-- Link legacy analyses to the new reference data without assuming their id type.
alter table public.shelfguide_analyses
  add column if not exists store_id uuid references public.stores(id) on delete set null,
  add column if not exists shelf_id uuid references public.shelves(id) on delete set null;

create index if not exists shelfguide_analyses_store_audit_idx
  on public.shelfguide_analyses(store_id, audit_date desc);
create index if not exists shelfguide_analyses_shelf_audit_idx
  on public.shelfguide_analyses(shelf_id, audit_date desc);

alter table public.shelfguide_analyses enable row level security;
revoke all on public.shelfguide_analyses from anon;
grant select on public.shelfguide_analyses to authenticated;

do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'shelfguide_analyses'
  loop
    execute format(
      'drop policy if exists %I on public.shelfguide_analyses',
      policy_record.policyname
    );
  end loop;
end
$$;

create policy shelfguide_analyses_select_perimeter
on public.shelfguide_analyses for select to authenticated
using (
  public.has_valid_profile()
  and store_id is not null
  and shelf_id is not null
  and public.can_access_shelf(store_id, shelf_id)
);

-- Private proof bucket. Objects use store_id/task_id/random-file.ext.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'task-proofs',
  'task-proofs',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.storage_task_id(p_name text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
declare
  candidate text := split_part(p_name, '/', 2);
begin
  if candidate ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    return candidate::uuid;
  end if;
  return null;
end;
$$;

create or replace function public.can_view_task_object(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.storage_task_id(p_name) is not null
    and public.can_view_task(public.storage_task_id(p_name))
$$;

create or replace function public.can_upload_task_object(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.action_tasks t
    where t.id = public.storage_task_id(p_name)
      and split_part(p_name, '/', 1) = t.store_id::text
      and public.can_manage_task(t.id)
  )
$$;

revoke all on function public.storage_task_id(text) from public;
revoke all on function public.can_view_task_object(text) from public;
revoke all on function public.can_upload_task_object(text) from public;
grant execute on function public.storage_task_id(text) to authenticated;
grant execute on function public.can_view_task_object(text) to authenticated;
grant execute on function public.can_upload_task_object(text) to authenticated;

drop policy if exists task_proofs_select_perimeter on storage.objects;
create policy task_proofs_select_perimeter
on storage.objects for select to authenticated
using (
  bucket_id = 'task-proofs'
  and public.can_view_task_object(name)
);

drop policy if exists task_proofs_insert_perimeter on storage.objects;
create policy task_proofs_insert_perimeter
on storage.objects for insert to authenticated
with check (
  bucket_id = 'task-proofs'
  and public.can_upload_task_object(name)
);

drop policy if exists task_proofs_delete_perimeter on storage.objects;
create policy task_proofs_delete_perimeter
on storage.objects for delete to authenticated
using (
  bucket_id = 'task-proofs'
  and public.can_upload_task_object(name)
);

-- Minimal Casablanca pilot reference.
insert into public.stores (
  code, name, store_format, address, city, region, country, latitude, longitude
)
values (
  'CASA-PILOT-001',
  'Magasin Pilote Casablanca',
  'Super',
  null,
  'Casablanca',
  'Casablanca-Settat',
  'Maroc',
  33.573100,
  -7.589800
)
on conflict (code) do update
set name = excluded.name,
    store_format = excluded.store_format,
    city = excluded.city,
    region = excluded.region,
    country = excluded.country,
    latitude = coalesce(public.stores.latitude, excluded.latitude),
    longitude = coalesce(public.stores.longitude, excluded.longitude);

with pilot as (
  select id from public.stores where code = 'CASA-PILOT-001'
)
insert into public.shelves (store_id, code, name, category, display_order)
select pilot.id, seed.code, seed.name, seed.category, seed.display_order
from pilot
cross join (
  values
    ('BOISSONS', 'Boissons', 'Boissons', 10),
    ('EPICERIE', 'Epicerie', 'Epicerie', 20),
    ('FRAIS', 'Frais', 'Frais', 30),
    ('BOULANGERIE', 'Boulangerie', 'Boulangerie', 40),
    ('HYGIENE', 'Hygiene', 'Hygiene', 50),
    ('ENTRETIEN', 'Entretien', 'Entretien', 60)
) as seed(code, name, category, display_order)
on conflict (store_id, code) do update
set name = excluded.name,
    category = excluded.category,
    display_order = excluded.display_order,
    is_active = true;

-- Attach demo/pilot users when they already exist. Real users can be attached
-- later with the documented administration SQL.
with pilot as (
  select id from public.stores where code = 'CASA-PILOT-001'
)
insert into public.store_members (store_id, user_id, member_role)
select
  pilot.id,
  u.id,
  p.role
from pilot
join auth.users u on lower(u.email) in (
  'chef.demo@shelfguide.ma',
  'manager.demo@shelfguide.ma'
)
join public.profiles p on p.id = u.id and p.role in ('chef', 'manager')
on conflict (store_id, user_id) do update
set member_role = excluded.member_role,
    is_active = true;

with pilot_chef as (
  select u.id as user_id
  from auth.users u
  join public.profiles p on p.id = u.id and p.role = 'chef'
  where lower(u.email) = 'chef.demo@shelfguide.ma'
), pilot_shelves as (
  select s.id
  from public.shelves s
  join public.stores st on st.id = s.store_id
  where st.code = 'CASA-PILOT-001'
)
insert into public.shelf_members (shelf_id, user_id)
select pilot_shelves.id, pilot_chef.user_id
from pilot_shelves cross join pilot_chef
on conflict (shelf_id, user_id) do update
set is_active = true;

-- Safe automatic backfill only when the legacy dataset contains one store.
do $$
declare
  distinct_stores integer;
  pilot_id uuid;
begin
  select count(distinct nullif(trim(store_name), ''))
  into distinct_stores
  from public.shelfguide_analyses;

  select id into pilot_id
  from public.stores
  where code = 'CASA-PILOT-001';

  if distinct_stores <= 1 then
    update public.shelfguide_analyses
    set store_id = pilot_id
    where store_id is null;
  end if;

  update public.shelfguide_analyses a
  set shelf_id = s.id
  from public.shelves s
  where a.store_id = s.store_id
    and a.shelf_id is null
    and lower(trim(a.shelf_name)) = lower(trim(s.name));
end
$$;

-- Realtime publication ignores tables already present in the publication.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'action_tasks'
  ) then
    alter publication supabase_realtime add table public.action_tasks;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'task_events'
  ) then
    alter publication supabase_realtime add table public.task_events;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'task_photos'
  ) then
    alter publication supabase_realtime add table public.task_photos;
  end if;
end
$$;

comment on table public.stores is 'ShelfGuide store reference and geographic perimeter.';
comment on table public.shelves is 'Shelf reference attached to one store.';
comment on table public.store_members is 'Active users authorized for a store.';
comment on table public.shelf_members is 'Fine-grained shelf authorization for chef users.';
comment on table public.action_tasks is 'Server-side operational workflow generated from an analysis or a manual issue.';
comment on column public.action_tasks.analysis_id is 'Text representation of shelfguide_analyses.id for legacy type compatibility.';
comment on table public.task_events is 'Immutable task audit journal populated by database triggers.';
comment on table public.task_photos is 'Metadata for private proof images stored in the task-proofs bucket.';
comment on table public.task_comments is 'Optional collaborative task comments.';

commit;
