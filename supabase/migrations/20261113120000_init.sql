-- Locmate schema: profiles, circles, live locations, places, chat and alerts.
-- All data is scoped to a circle and protected with row level security.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 60),
  color_index smallint not null default 0 check (color_index between 0 and 4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.circles (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 60),
  invite_code text not null unique,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.circle_members (
  circle_id uuid not null references public.circles (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id),
  unique (user_id)
);

create table public.locations (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  circle_id uuid not null references public.circles (id) on delete cascade,
  latitude double precision,
  longitude double precision,
  accuracy double precision,
  heading double precision,
  speed double precision,
  battery smallint check (battery between 0 and 100),
  is_sharing boolean not null default true,
  updated_at timestamptz not null default now(),
  constraint locations_coordinates_check check (
    (latitude is null and longitude is null)
    or (
      latitude between -90 and 90
      and longitude between -180 and 180
    )
  )
);

create table public.places (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  address text not null default '',
  icon text not null default 'other',
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  radius_meters integer not null default 180 check (radius_meters between 50 and 2000),
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

create table public.alerts (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  type text not null check (type in ('arrival', 'departure', 'sos', 'battery', 'speed', 'info')),
  title text not null check (char_length(title) between 1 and 160),
  body text not null default '' check (char_length(body) <= 400),
  created_at timestamptz not null default now()
);

create index messages_circle_created_idx
  on public.messages (circle_id, created_at desc);
create index alerts_circle_created_idx
  on public.alerts (circle_id, created_at desc);
create index places_circle_created_idx
  on public.places (circle_id, created_at);
create index locations_circle_idx on public.locations (circle_id);
create index circle_members_circle_idx on public.circle_members (circle_id);

-- Keep updated_at fresh on profile changes.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

-- Every auth user gets a profile.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  v_name := nullif(trim(new.raw_user_meta_data ->> 'display_name'), '');
  if v_name is null and new.email is not null then
    v_name := split_part(new.email, '@', 1);
  end if;

  insert into public.profiles (id, display_name, color_index)
  values (
    new.id,
    left(coalesce(v_name, 'Locmate user'), 60),
    floor(random() * 5)::smallint
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Six character invite codes from an unambiguous alphabet.
create or replace function public.generate_invite_code()
returns text
language plpgsql
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text := '';
  i integer;
begin
  for i in 1..6 loop
    v_code := v_code || substr(
      v_alphabet,
      1 + floor(random() * length(v_alphabet))::integer,
      1
    );
  end loop;
  return v_code;
end;
$$;

alter table public.circles
  alter column invite_code set default public.generate_invite_code();

-- RLS helpers. Security definer avoids recursive policy lookups.
create or replace function public.is_circle_member(p_circle_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.circle_members
    where circle_id = p_circle_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.shares_circle_with(p_user_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.circle_members mine
    join public.circle_members theirs using (circle_id)
    where mine.user_id = auth.uid()
      and theirs.user_id = p_user_id
  );
$$;

create or replace function public.is_circle_owner(p_circle_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.circles
    where id = p_circle_id
      and owner_id = auth.uid()
  );
$$;

alter table public.profiles enable row level security;
alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.locations enable row level security;
alter table public.places enable row level security;
alter table public.messages enable row level security;
alter table public.alerts enable row level security;

create policy "Profiles are visible to circle members"
on public.profiles for select
to authenticated
using (id = auth.uid() or public.shares_circle_with(id));

create policy "Users can insert their own profile"
on public.profiles for insert
to authenticated
with check (id = auth.uid());

create policy "Users can update their own profile"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "Circles are visible to their members"
on public.circles for select
to authenticated
using (public.is_circle_member(id));

create policy "Authenticated users can create circles"
on public.circles for insert
to authenticated
with check (owner_id = auth.uid());

create policy "Owners can update their circle"
on public.circles for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "Owners can delete their circle"
on public.circles for delete
to authenticated
using (owner_id = auth.uid());

create policy "Members are visible to their circle"
on public.circle_members for select
to authenticated
using (public.is_circle_member(circle_id));

create policy "Locations are visible to circle members"
on public.locations for select
to authenticated
using (user_id = auth.uid() or public.shares_circle_with(user_id));

create policy "Users can insert their own location"
on public.locations for insert
to authenticated
with check (user_id = auth.uid() and public.is_circle_member(circle_id));

create policy "Users can update their own location"
on public.locations for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid() and public.is_circle_member(circle_id));

create policy "Circles can manage their places"
on public.places for all
to authenticated
using (public.is_circle_member(circle_id))
with check (public.is_circle_member(circle_id) and created_by = auth.uid());

create policy "Circles can read their messages"
on public.messages for select
to authenticated
using (public.is_circle_member(circle_id));

create policy "Members can send messages"
on public.messages for insert
to authenticated
with check (sender_id = auth.uid() and public.is_circle_member(circle_id));

create policy "Senders can delete their messages"
on public.messages for delete
to authenticated
using (sender_id = auth.uid());

create policy "Circles can read their alerts"
on public.alerts for select
to authenticated
using (public.is_circle_member(circle_id));

create policy "Members can create their own alerts"
on public.alerts for insert
to authenticated
with check (member_id = auth.uid() and public.is_circle_member(circle_id));

-- Circle lifecycle helpers keep membership consistent.
create or replace function public.create_circle(p_name text)
returns public.circles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_name text := trim(coalesce(p_name, ''));
  v_circle public.circles;
begin
  if v_user_id is null then
    raise exception 'You need to be signed in to create a circle';
  end if;
  if v_name = '' then
    raise exception 'Give your circle a name';
  end if;
  if exists (
    select 1 from public.circle_members where user_id = v_user_id
  ) then
    raise exception 'You are already in a circle';
  end if;

  insert into public.circles (name, owner_id)
  values (left(v_name, 60), v_user_id)
  returning * into v_circle;

  insert into public.circle_members (circle_id, user_id)
  values (v_circle.id, v_user_id);

  insert into public.locations (user_id, circle_id, is_sharing)
  values (v_user_id, v_circle.id, true)
  on conflict (user_id) do update
    set circle_id = excluded.circle_id;

  return v_circle;
end;
$$;

create or replace function public.join_circle(p_invite_code text)
returns public.circles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_circle public.circles;
begin
  if v_user_id is null then
    raise exception 'You need to be signed in to join a circle';
  end if;
  if exists (
    select 1 from public.circle_members where user_id = v_user_id
  ) then
    raise exception 'You are already in a circle';
  end if;

  select * into v_circle
  from public.circles
  where invite_code = upper(trim(coalesce(p_invite_code, '')));

  if v_circle.id is null then
    raise exception 'No circle found with that invite code';
  end if;

  insert into public.circle_members (circle_id, user_id)
  values (v_circle.id, v_user_id);

  insert into public.locations (user_id, circle_id, is_sharing)
  values (v_user_id, v_circle.id, true)
  on conflict (user_id) do update
    set circle_id = excluded.circle_id;

  return v_circle;
end;
$$;

create or replace function public.leave_circle()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_circle_id uuid;
  v_next_owner uuid;
begin
  if v_user_id is null then
    raise exception 'You need to be signed in to leave a circle';
  end if;

  select circle_id into v_circle_id
  from public.circle_members
  where user_id = v_user_id;

  if v_circle_id is null then
    return;
  end if;

  delete from public.locations where user_id = v_user_id;
  delete from public.circle_members where user_id = v_user_id;

  if exists (
    select 1 from public.circles
    where id = v_circle_id and owner_id = v_user_id
  ) then
    select user_id into v_next_owner
    from public.circle_members
    where circle_id = v_circle_id
    order by joined_at
    limit 1;

    if v_next_owner is null then
      delete from public.circles where id = v_circle_id;
    else
      update public.circles
      set owner_id = v_next_owner
      where id = v_circle_id;
    end if;
  end if;
end;
$$;

revoke all on function public.create_circle(text) from public;
revoke all on function public.join_circle(text) from public;
revoke all on function public.leave_circle() from public;
grant execute on function public.create_circle(text) to authenticated;
grant execute on function public.join_circle(text) to authenticated;
grant execute on function public.leave_circle() to authenticated;

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- Realtime streams for circle data.
alter table public.locations replica identity full;
alter table public.places replica identity full;
alter table public.messages replica identity full;
alter table public.alerts replica identity full;

alter publication supabase_realtime add table public.locations;
alter publication supabase_realtime add table public.places;
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.alerts;
