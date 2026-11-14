-- Subscriptions (Free / Premium) and account deletion.
--
-- A circle is Premium when its owner has an active Premium subscription.
-- Subscription rows are written only by the `revenuecat-webhook` Edge
-- Function using the service role; clients can read their own row.
--
-- Free plan limits (enforced here, mirrored in the app):
--   * up to 5 members per circle
--   * up to 2 places per circle
--   * low-battery alerts are Premium only (SOS is always free)

create table public.subscriptions (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  entitlement text not null default 'premium',
  product_id text,
  store text,
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.subscriptions enable row level security;

create policy "Users can read their own subscription"
on public.subscriptions for select to authenticated
using (user_id = auth.uid());

revoke insert, update, delete on public.subscriptions from authenticated;
grant select on public.subscriptions to authenticated;

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
  );
$$;

create or replace function public.circle_is_premium(p_circle_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select public.is_premium(owner_id) from public.circles where id = p_circle_id),
    false
  );
$$;

-- Plan details for the caller's circle, used by the app.
create or replace function public.circle_plan(p_circle_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_premium boolean;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'You are not a member of this circle';
  end if;
  v_premium := public.circle_is_premium(p_circle_id);
  return jsonb_build_object(
    'circle_premium', v_premium,
    'user_premium', public.is_premium(auth.uid()),
    'member_limit', case when v_premium then null else 5 end,
    'place_limit', case when v_premium then null else 2 end
  );
end;
$$;

create or replace function public.enforce_member_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.circle_is_premium(new.circle_id)
     and (select count(*) from public.circle_members where circle_id = new.circle_id) >= 5 then
    raise exception 'This circle is full on the Free plan (5 members). The circle owner can upgrade to Premium for unlimited members.';
  end if;
  return new;
end;
$$;

create trigger circle_members_enforce_limit
before insert on public.circle_members
for each row execute function public.enforce_member_limit();

create or replace function public.enforce_place_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.circle_is_premium(new.circle_id)
     and (select count(*) from public.places where circle_id = new.circle_id) >= 2 then
    raise exception 'The Free plan includes 2 places. Upgrade to Premium for unlimited places.';
  end if;
  return new;
end;
$$;

create trigger places_enforce_limit
before insert on public.places
for each row execute function public.enforce_place_limit();

-- Low-battery alerts are a Premium feature; drop them silently on Free.
create or replace function public.filter_premium_alerts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.type = 'battery' and not public.circle_is_premium(new.circle_id) then
    return null;
  end if;
  return new;
end;
$$;

create trigger alerts_filter_premium
before insert on public.alerts
for each row execute function public.filter_premium_alerts();

-- Permanently delete the caller's account (required by the App Store and the
-- Privacy Policy). Leaves the circle first so ownership is handed over.
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'You need to be signed in to delete your account';
  end if;
  perform public.leave_circle();
  delete from auth.users where id = v_user_id;
end;
$$;

revoke all on function public.is_premium(uuid) from public;
revoke all on function public.circle_is_premium(uuid) from public;
revoke all on function public.circle_plan(uuid) from public;
revoke all on function public.delete_account() from public;
grant execute on function public.is_premium(uuid) to authenticated;
grant execute on function public.circle_is_premium(uuid) to authenticated;
grant execute on function public.circle_plan(uuid) to authenticated;
grant execute on function public.delete_account() to authenticated;
