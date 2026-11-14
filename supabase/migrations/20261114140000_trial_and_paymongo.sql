-- 7-day Premium trial for new accounts and PayMongo web purchases.
--
-- Trial rules:
--   * every new profile gets 7 days of Premium automatically
--   * the trial is shown in circle_plan() so the app can display the days left
--   * a paid subscription or internal-tester access takes precedence over the
--     trial display, but all three grant the same Premium features
--
-- PayMongo rules:
--   * the landing page creates a hosted Checkout Session for a 30-day or
--     365-day Premium pass
--   * the webhook calls record_paymongo_purchase() with the service role
--   * if the buyer has no Locmate account yet, the purchase stays pending and
--     is applied automatically when the matching profile is created

create table public.trials (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  ends_at timestamptz not null,
  created_at timestamptz not null default now()
);

alter table public.trials enable row level security;

create policy "Users can read their own trial"
on public.trials for select to authenticated
using (user_id = auth.uid());

revoke all on public.trials from public;
revoke all on public.trials from anon, authenticated;
grant select on public.trials to authenticated;
grant all on public.trials to service_role;

create table public.premium_purchases (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'paymongo',
  provider_payment_id text not null,
  checkout_session_id text,
  reference_number text,
  email text not null,
  plan text not null check (plan in ('monthly', 'annual')),
  days integer not null check (days between 1 and 3660),
  amount integer not null check (amount > 0),
  currency text not null default 'PHP',
  user_id uuid references public.profiles (id) on delete set null,
  granted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (provider, provider_payment_id)
);

create index premium_purchases_pending_email_idx
  on public.premium_purchases (lower(email))
  where granted_at is null;

alter table public.premium_purchases enable row level security;

revoke all on public.premium_purchases from public;
revoke all on public.premium_purchases from anon, authenticated;
grant all on public.premium_purchases to service_role;

-- Extend an existing subscription or start a new one. Only the service role
-- calls this, either from the webhook RPC or the new-profile trigger.
create or replace function public.grant_premium(
  p_user_id uuid,
  p_days integer,
  p_product_id text default null,
  p_store text default null
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expires timestamptz;
begin
  insert into public.subscriptions (
    user_id,
    entitlement,
    product_id,
    store,
    expires_at,
    updated_at
  )
  values (
    p_user_id,
    'premium',
    p_product_id,
    p_store,
    now() + make_interval(days => p_days),
    now()
  )
  on conflict (user_id) do update
    set entitlement = 'premium',
        product_id = coalesce(excluded.product_id, public.subscriptions.product_id),
        store = coalesce(excluded.store, public.subscriptions.store),
        expires_at = greatest(
          coalesce(public.subscriptions.expires_at, now()),
          now()
        ) + make_interval(days => p_days),
        updated_at = now()
  returning expires_at into v_expires;

  return v_expires;
end;
$$;

revoke all on function public.grant_premium(uuid, integer, text, text) from public;
revoke all on function public.grant_premium(uuid, integer, text, text) from anon;
revoke all on function public.grant_premium(uuid, integer, text, text) from authenticated;
grant execute on function public.grant_premium(uuid, integer, text, text) to service_role;

-- Every new profile starts a trial. Any PayMongo purchases made with the same
-- email before the account existed are applied at the same time.
create or replace function public.start_profile_trial()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text;
  v_purchase record;
begin
  insert into public.trials (user_id, ends_at)
  values (new.id, now() + interval '7 days')
  on conflict (user_id) do nothing;

  select email into v_email from auth.users where id = new.id;

  if v_email is not null then
    for v_purchase in
      select *
      from public.premium_purchases
      where granted_at is null
        and lower(email) = lower(v_email)
      order by created_at
    loop
      perform public.grant_premium(
        new.id,
        v_purchase.days,
        'locmate_premium_' || v_purchase.plan,
        'paymongo'
      );
      update public.premium_purchases
      set user_id = new.id,
          granted_at = now()
      where id = v_purchase.id;
    end loop;
  end if;

  return new;
end;
$$;

create trigger profiles_start_trial
after insert on public.profiles
for each row execute function public.start_profile_trial();

-- Called by the landing page webhook (service role only). Returns:
--   granted   - the account existed and Premium was applied
--   pending   - no account yet; it will be applied on sign-up
--   duplicate - this PayMongo payment was already processed
create or replace function public.record_paymongo_purchase(
  p_payment_id text,
  p_checkout_session_id text,
  p_reference_number text,
  p_email text,
  p_plan text,
  p_amount integer,
  p_currency text,
  p_days integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_purchase_id uuid;
  v_user_id uuid;
  v_expires timestamptz;
begin
  insert into public.premium_purchases (
    provider,
    provider_payment_id,
    checkout_session_id,
    reference_number,
    email,
    plan,
    days,
    amount,
    currency
  )
  values (
    'paymongo',
    p_payment_id,
    p_checkout_session_id,
    p_reference_number,
    lower(trim(p_email)),
    p_plan,
    p_days,
    p_amount,
    upper(trim(p_currency))
  )
  on conflict (provider, provider_payment_id) do nothing
  returning id into v_purchase_id;

  if v_purchase_id is null then
    return jsonb_build_object('status', 'duplicate');
  end if;

  select id into v_user_id
  from auth.users
  where lower(email) = lower(trim(p_email))
  limit 1;

  if v_user_id is null then
    return jsonb_build_object(
      'status', 'pending',
      'purchase_id', v_purchase_id
    );
  end if;

  v_expires := public.grant_premium(
    v_user_id,
    p_days,
    'locmate_premium_' || p_plan,
    'paymongo'
  );

  update public.premium_purchases
  set user_id = v_user_id,
      granted_at = now()
  where id = v_purchase_id;

  return jsonb_build_object(
    'status', 'granted',
    'purchase_id', v_purchase_id,
    'user_id', v_user_id,
    'expires_at', v_expires
  );
end;
$$;

revoke all on function public.record_paymongo_purchase(text, text, text, text, text, integer, text, integer) from public;
revoke all on function public.record_paymongo_purchase(text, text, text, text, text, integer, text, integer) from anon;
revoke all on function public.record_paymongo_purchase(text, text, text, text, text, integer, text, integer) from authenticated;
grant execute on function public.record_paymongo_purchase(text, text, text, text, text, integer, text, integer) to service_role;

-- Premium = active subscription OR internal tester OR active trial.
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
  ) or exists (
    select 1 from public.trials
    where user_id = p_user_id
      and ends_at > now()
  );
$$;

revoke execute on function public.is_premium(uuid) from authenticated;
grant execute on function public.is_premium(uuid) to service_role;

-- Add trial details for the app. `trial_active` is false once a paid
-- subscription or internal-tester access is present.
create or replace function public.circle_plan(p_circle_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_premium boolean;
  v_trial_ends_at timestamptz;
  v_paid boolean;
  v_internal boolean;
  v_trial boolean;
begin
  if not public.is_circle_member(p_circle_id) then
    raise exception 'You are not a member of this circle';
  end if;

  v_premium := public.circle_is_premium(p_circle_id);

  select ends_at into v_trial_ends_at
  from public.trials
  where user_id = auth.uid();

  select exists (
    select 1 from public.subscriptions
    where user_id = auth.uid()
      and entitlement = 'premium'
      and (expires_at is null or expires_at > now())
  ) into v_paid;

  select exists (
    select 1 from public.internal_testers
    where user_id = auth.uid()
  ) into v_internal;

  v_trial := coalesce(v_trial_ends_at > now(), false)
    and not coalesce(v_paid, false)
    and not coalesce(v_internal, false);

  return jsonb_build_object(
    'circle_premium', v_premium,
    'user_premium', public.is_premium(auth.uid()),
    'trial_active', v_trial,
    'trial_ends_at', v_trial_ends_at,
    'trial_days_left', case
      when v_trial then ceil(extract(epoch from (v_trial_ends_at - now())) / 86400)::int
      else 0
    end,
    'member_limit', case when v_premium then null else 5 end,
    'place_limit', case when v_premium then null else 2 end
  );
end;
$$;

revoke all on function public.circle_plan(uuid) from public;
grant execute on function public.circle_plan(uuid) to authenticated;
