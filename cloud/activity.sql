-- Walking Star Academy · v213 ตารางติดตามความเคลื่อนไหว (activity)
-- บันทึกทุกการใช้งาน: สมาชิกออนไลน์ บัญชีในเครื่อง เจ้าของ GOD MODE และ Guest
-- ใครก็เขียนได้ (anon + authenticated) แต่อ่านได้เฉพาะแอดมิน (public.is_admin() จาก schema.sql)
-- วิธีใช้: Supabase → SQL Editor → วางทั้งไฟล์ → Run (ต้องรัน schema.sql มาก่อนแล้ว)

create table if not exists public.activity(
  id bigint generated always as identity primary key,
  ts timestamptz not null default now(),
  client_ts timestamptz,
  uid uuid default auth.uid(),
  actor text not null,          -- ชื่อผู้ใช้ในแอป (duke, guest1117, ชื่อสมาชิก, _anon)
  actor_name text,
  role text,                    -- owner · guest · member · anon
  via text,                     -- login · register · god · guest · cloud · resume
  device_id text,
  device text,
  kind text not null,           -- session · open_app · view · chart · save_chart · search · lang · logout
  key text,
  meta jsonb,
  constraint activity_sizes check (
    length(actor) <= 80 and coalesce(length(actor_name),0) <= 120 and coalesce(length(device),0) <= 160
    and coalesce(length(device_id),0) <= 64 and length(kind) <= 40 and coalesce(length(key),0) <= 200
    and coalesce(pg_column_size(meta),0) <= 4096)
);
create index if not exists activity_ts on public.activity(ts desc);
create index if not exists activity_actor_ts on public.activity(actor, ts desc);
create index if not exists activity_kind_ts on public.activity(kind, ts desc);

alter table public.activity enable row level security;
drop policy if exists act_ins on public.activity;
create policy act_ins on public.activity for insert to anon, authenticated
  with check (uid is null or uid = auth.uid());
drop policy if exists act_sel on public.activity;
create policy act_sel on public.activity for select to authenticated using (public.is_admin());
drop policy if exists act_del on public.activity;
create policy act_del on public.activity for delete to authenticated using (public.is_admin());

grant insert on public.activity to anon, authenticated;
grant select, delete on public.activity to authenticated;
