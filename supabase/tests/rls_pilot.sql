begin;

create extension if not exists pgtap with schema extensions;
select plan(18);

select has_table('public', 'stores', 'stores table exists');
select has_table('public', 'shelves', 'shelves table exists');
select has_table('public', 'store_members', 'store_members table exists');
select has_table('public', 'shelf_members', 'shelf_members table exists');
select has_table('public', 'action_tasks', 'action_tasks table exists');
select has_table('public', 'task_events', 'task_events table exists');
select has_table('public', 'task_photos', 'task_photos table exists');
select has_function(
  'public',
  'can_access_shelf',
  array['uuid', 'uuid'],
  'fine-grained shelf authorization function exists'
);

select is(
  (
    select public
    from storage.buckets
    where id = 'task-proofs'
  ),
  false,
  'task-proofs bucket is private'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'rls-chef-a@shelfguide.test',
    crypt('test-password', gen_salt('bf')),
    now(),
    '{"role":"chef"}',
    '{"full_name":"Chef A"}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'rls-chef-b@shelfguide.test',
    crypt('test-password', gen_salt('bf')),
    now(),
    '{"role":"chef"}',
    '{"full_name":"Chef B"}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'rls-manager@shelfguide.test',
    crypt('test-password', gen_salt('bf')),
    now(),
    '{"role":"manager"}',
    '{"full_name":"Manager"}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'rls-hq@shelfguide.test',
    crypt('test-password', gen_salt('bf')),
    now(),
    '{"role":"hq"}',
    '{"full_name":"HQ"}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000005',
    'authenticated',
    'authenticated',
    'rls-invalid@shelfguide.test',
    crypt('test-password', gen_salt('bf')),
    now(),
    '{"role":"chef"}',
    '{"full_name":"Invalid"}',
    now(),
    now()
  );

update public.profiles
set role = case id
  when '10000000-0000-0000-0000-000000000003' then 'manager'::public.app_role
  when '10000000-0000-0000-0000-000000000004' then 'hq'::public.app_role
  else 'chef'::public.app_role
end
where id::text like '10000000-0000-0000-0000-00000000000%';

delete from public.profiles
where id = '10000000-0000-0000-0000-000000000005';

insert into public.stores (id, code, name, store_format)
values (
  '20000000-0000-0000-0000-000000000001',
  'RLS-TEST',
  'RLS Test Store',
  'Super'
);

insert into public.shelves (id, store_id, code, name, category)
values (
  '30000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  'RLS-SHELF',
  'RLS Shelf',
  'Test'
);

insert into public.store_members (store_id, user_id, member_role)
values
  (
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'chef'
  ),
  (
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000002',
    'chef'
  ),
  (
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000003',
    'manager'
  );

insert into public.shelf_members (shelf_id, user_id)
values (
  '30000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001'
);

insert into public.action_tasks (
  id,
  analysis_id,
  store_id,
  shelf_id,
  title,
  status,
  priority,
  assigned_to,
  created_by
)
values (
  '40000000-0000-0000-0000-000000000001',
  'rls-analysis-1',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'RLS task',
  'open',
  'high',
  '10000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000003'
);

select is(
  (
    select count(*)
    from public.task_events
    where task_id = '40000000-0000-0000-0000-000000000001'
      and event_type = 'created'
  ),
  1::bigint,
  'task creation writes an audit event'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select is(
  (select count(*) from public.action_tasks),
  1::bigint,
  'assigned chef can read the task in an authorized shelf'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);

select is(
  (select count(*) from public.action_tasks),
  0::bigint,
  'chef without shelf authorization cannot read the task'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);

select is(
  (select count(*) from public.action_tasks),
  1::bigint,
  'manager can read all tasks in the managed store'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);

select is(
  (select count(*) from public.action_tasks),
  1::bigint,
  'hq can read network tasks'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000005', true);

select is(
  (select count(*) from public.action_tasks),
  0::bigint,
  'user without a valid profile cannot read tasks'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

update public.action_tasks
set status = 'in_progress'
where id = '40000000-0000-0000-0000-000000000001';

select is(
  (
    select status::text
    from public.action_tasks
    where id = '40000000-0000-0000-0000-000000000001'
  ),
  'in_progress',
  'assigned chef can claim the task'
);

reset role;
select is(
  (
    select count(*)
    from public.task_events
    where task_id = '40000000-0000-0000-0000-000000000001'
      and event_type = 'status_changed'
      and to_status = 'in_progress'
  ),
  1::bigint,
  'status transition writes an audit event'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);

update public.action_tasks
set title = 'Unauthorized change'
where id = '40000000-0000-0000-0000-000000000001';

reset role;
select is(
  (
    select title
    from public.action_tasks
    where id = '40000000-0000-0000-0000-000000000001'
  ),
  'RLS task',
  'chef outside the shelf cannot modify the task'
);

select * from finish();
rollback;
