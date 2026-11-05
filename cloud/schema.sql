-- Walking Star Academy · ฐานข้อมูลสมาชิก (Supabase)
-- profiles: สมาชิก 1 แถวต่อบัญชี · events: บันทึกการใช้งาน · admins: ผู้ดูแล

create table if not exists public.profiles(
  id uuid primary key references auth.users on delete cascade,
  username text unique,
  display_name text,
  email text,
  created_at timestamptz default now(),
  last_seen timestamptz,
  device text,
  plan text default 'free',
  plan_exp timestamptz,
  grants jsonb not null default '{}'::jsonb,
  note text
);
create table if not exists public.events(
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users on delete cascade,
  ts timestamptz not null default now(),
  kind text not null,
  key text,
  meta jsonb
);
create index if not exists events_user_ts on public.events(user_id, ts desc);
create index if not exists events_ts on public.events(ts desc);
create table if not exists public.admins(user_id uuid primary key references auth.users on delete cascade);

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.admins where user_id = auth.uid()) $$;

-- สร้างโปรไฟล์อัตโนมัติเมื่อสมัคร
create or replace function public.on_signup() returns trigger
language plpgsql security definer set search_path = public as
$$ begin
  insert into public.profiles(id, username, display_name, email)
  values (new.id, new.raw_user_meta_data->>'username', new.raw_user_meta_data->>'name', new.raw_user_meta_data->>'contact')
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.on_signup();

-- สมาชิกอัปเดตเวลาใช้งานล่าสุดของตัวเอง
create or replace function public.touch(dev text) returns void
language sql security definer set search_path = public as
$$ update public.profiles set last_seen = now(), device = left(dev, 160) where id = auth.uid() $$;

-- ใช้สิทธิ์แบบนับครั้ง: ลดจำนวนครั้งที่เหลือ 1 แล้วคืนค่าที่เหลือ
create or replace function public.use_grant(k text) returns int
language plpgsql security definer set search_path = public as
$$ declare g jsonb; n int; begin
  select grants->k into g from public.profiles where id = auth.uid();
  if g is null or g->>'left' is null then return null; end if;
  n := greatest((g->>'left')::int - 1, 0);
  update public.profiles set grants = jsonb_set(grants, array[k, 'left'], to_jsonb(n)) where id = auth.uid();
  return n;
end $$;

alter table public.profiles enable row level security;
alter table public.events enable row level security;
alter table public.admins enable row level security;

drop policy if exists p_sel on public.profiles;
create policy p_sel on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
drop policy if exists p_upd on public.profiles;
create policy p_upd on public.profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists p_del on public.profiles;
create policy p_del on public.profiles for delete to authenticated using (public.is_admin());
drop policy if exists e_ins on public.events;
create policy e_ins on public.events for insert to authenticated with check (user_id = auth.uid());
drop policy if exists e_sel on public.events;
create policy e_sel on public.events for select to authenticated using (public.is_admin());
drop policy if exists a_sel on public.admins;
create policy a_sel on public.admins for select to authenticated using (user_id = auth.uid());

grant usage on schema public to anon, authenticated;
grant select, update, delete on public.profiles to authenticated;
grant select, insert on public.events to authenticated;
grant select on public.admins to authenticated;
grant execute on function public.is_admin(), public.touch(text), public.use_grant(text) to authenticated;
revoke execute on function public.touch(text), public.use_grant(text) from anon;

-- แอดมินคนแรก: อีเมลเจ้าของที่ยืนยันแล้ว และยังไม่มีแอดมินในระบบ
create or replace function public.claim_admin() returns boolean
language plpgsql security definer set search_path = public as
$$ begin
  if exists(select 1 from public.admins) then return exists(select 1 from public.admins where user_id = auth.uid()); end if;
  if exists(select 1 from auth.users where id = auth.uid() and lower(email) = 'dukemotion@gmail.com' and email_confirmed_at is not null) then
    insert into public.admins(user_id) values (auth.uid()); return true; end if;
  return false;
end $$;
revoke execute on function public.claim_admin() from anon, public;
grant execute on function public.claim_admin() to authenticated;
