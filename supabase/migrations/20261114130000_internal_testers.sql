-- Internal team access.
--
-- Blank CO PH Solutions staff need Premium for testing without a store
-- purchase. Internal testers are listed explicitly; everyone else needs a real
-- subscription (or a RevenueCat granted entitlement).
--
-- Access follows the normal subscription rule: a circle is Premium when its
-- owner is Premium. An internal tester therefore gets Premium in the circles
-- they create; circles owned by external users are unaffected.

create table public.internal_testers (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  note text,
  created_at timestamptz not null default now()
);

alter table public.internal_testers enable row level security;

create policy "Users can read their own internal tester row"
on public.internal_testers for select to authenticated
using (user_id = auth.uid());

revoke all on public.internal_testers from public;
revoke all on public.internal_testers from anon, authenticated;
grant select on public.internal_testers to authenticated;
grant all on public.internal_testers to service_role;

-- Premium = an active subscription OR an internal tester.
create or replace function public.is_premium(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.subscriptions
    where user_id = p_user_id
      and entitlement = 'premium'
      and (expires_at is null or expires_at > now())
  ) or exists (
    select 1 from public.internal_testers
    where user_id = p_user_id
  );
$$;

-- Clients only need circle_plan(). The lower-level helpers are called by
-- circle_plan and the limit triggers, which are all security definer.
revoke execute on function public.is_premium(uuid) from authenticated;
revoke execute on function public.circle_is_premium(uuid) from authenticated;
grant execute on function public.is_premium(uuid) to service_role;
grant execute on function public.circle_is_premium(uuid) to service_role;

-- Convenience helpers for the Supabase SQL editor / service role.
create or replace function public.add_internal_tester(
  p_email text,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
begin
  select id into v_user_id
  from auth.users
  where lower(email) = lower(trim(p_email))
  limit 1;

  if v_user_id is null then
    raise exception 'No account found for %', p_email;
  end if;

  insert into public.internal_testers (user_id, note)
  values (v_user_id, p_note)
  on conflict (user_id) do update set note = excluded.note;

  return v_user_id;
end;
$$;

revoke all on function public.add_internal_tester(text, text) from public;
revoke all on function public.add_internal_tester(text, text) from anon;
revoke all on function public.add_internal_tester(text, text) from authenticated;
grant execute on function public.add_internal_tester(text, text) to service_role;

create or replace function public.remove_internal_tester(p_email text)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
begin
  select id into v_user_id
  from auth.users
  where lower(email) = lower(trim(p_email))
  limit 1;

  if v_user_id is null then
    raise exception 'No account found for %', p_email;
  end if;

  delete from public.internal_testers where user_id = v_user_id;
  return v_user_id;
end;
$$;

revoke all on function public.remove_internal_tester(text) from public;
revoke all on function public.remove_internal_tester(text) from anon;
revoke all on function public.remove_internal_tester(text) from authenticated;
grant execute on function public.remove_internal_tester(text) to service_role;
