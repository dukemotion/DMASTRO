-- ระบบนัดคิวดูดวง (BK381) — รันครั้งเดียวใน Supabase > SQL Editor
-- ปลอดภัยที่จะรันซ้ำ: ใช้ if not exists / create or replace

create table if not exists public.bookings (
  id          uuid primary key default gen_random_uuid(),
  token       text not null unique default replace(gen_random_uuid()::text, '-', ''),
  qno         bigserial,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  nick        text not null check (char_length(nick) between 1 and 60),
  phone       text not null check (char_length(phone) between 9 and 20),
  line_id     text check (line_id is null or char_length(line_id) <= 60),
  bd          int  not null check (bd between 1 and 31),
  bm          int  not null check (bm between 1 and 12),
  by_be       int  not null check (by_be between 2400 and 2700),
  bh          int  check (bh between 0 and 23),
  bmi         int  check (bmi between 0 and 59),
  no_time     boolean not null default false,
  prov        int  not null check (prov between 0 and 100),
  slot_date   date not null,
  slot_time   text not null check (slot_time in ('10:00','13:00','20:00')),
  slip        text check (slip is null or char_length(slip) <= 1500000),
  note        text check (note is null or char_length(note) <= 500),
  admin_note  text,
  status      text not null default 'slip_sent'
              check (status in ('slip_sent','confirmed','rejected','done','cancelled'))
);

-- ประเทศและเมืองเกิด (v357.8) — เพิ่มให้ตารางเดิมได้ด้วย
alter table public.bookings add column if not exists cc   text not null default 'TH';
alter table public.bookings add column if not exists city text;
alter table public.bookings add column if not exists region text;
alter table public.bookings add column if not exists lat  double precision;
alter table public.bookings add column if not exists lon  double precision;
alter table public.bookings add column if not exists tz   text;
alter table public.bookings drop constraint if exists bookings_place_chk;
alter table public.bookings add constraint bookings_place_chk check (
  char_length(cc) between 2 and 3 and (city is null or char_length(city) <= 120) and (region is null or char_length(region) <= 120)
  and (tz is null or char_length(tz) <= 64) and (lat is null or lat between -90 and 90) and (lon is null or lon between -180 and 180)
  and (cc = 'TH' or (city is not null and lat is not null and lon is not null and tz is not null)));

-- ช่วงเวลาเกิดโดยประมาณ ช่องทางโทรกลับ และเขตเวลาของลูกค้า (v357.9)
alter table public.bookings add column if not exists tperiod text;
alter table public.bookings add column if not exists contact_via text not null default 'phone';
alter table public.bookings add column if not exists ctz text;
alter table public.bookings drop constraint if exists bookings_call_chk;
alter table public.bookings add constraint bookings_call_chk check (
  (tperiod is null or tperiod in ('dawn','morning','late','afternoon','evening','night'))
  and contact_via in ('line','phone') and (ctz is null or char_length(ctz) <= 64));

-- หนึ่งช่วงเวลารับได้หนึ่งคิว (นับเฉพาะคิวที่ยังมีผล)
create unique index if not exists bookings_slot_active
  on public.bookings (slot_date, slot_time)
  where status in ('slip_sent','confirmed','done');
create index if not exists bookings_slot_idx on public.bookings (slot_date, slot_time);

-- สิทธิ์แอดมิน (ใช้ตาราง admins เดิมของระบบสมาชิก)
create or replace function public.bk_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;

alter table public.bookings enable row level security;
drop policy if exists bk_admin_all on public.bookings;
create policy bk_admin_all on public.bookings for all to authenticated
  using (public.bk_is_admin()) with check (public.bk_is_admin());
-- ลูกค้า (anon) ไม่มีสิทธิ์อ่านหรือเขียนตารางตรง ใช้ได้เฉพาะฟังก์ชันด้านล่าง

-- ช่วงเวลาที่ถูกจองแล้ว (ไม่เปิดเผยข้อมูลลูกค้า)
create or replace function public.bk_slots(d1 date, d2 date)
returns table (slot_date date, slot_time text)
language sql stable security definer set search_path = public as $$
  select b.slot_date, b.slot_time from public.bookings b
  where b.slot_date between d1 and d2 and b.status in ('slip_sent','confirmed','done');
$$;

-- สร้างคิว (ต้องแนบสลิป)
create or replace function public.bk_create(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  d date := (p->>'slot_date')::date;
  t text := p->>'slot_time';
  today date := (now() at time zone 'Asia/Bangkok')::date;
  r public.bookings;
begin
  if d is null or d < today + 1 or d > today + 30 then raise exception 'bad_date'; end if;
  if t is null or t not in ('10:00','13:00','20:00') then raise exception 'bad_time'; end if;
  if coalesce(p->>'slip','') not like 'data:image/%' or char_length(p->>'slip') > 1500000 then raise exception 'bad_slip'; end if;
  if char_length(coalesce(p->>'nick','')) not between 1 and 60
     or char_length(coalesce(p->>'phone','')) not between 9 and 20 then raise exception 'bad_input'; end if;
  if (select count(*) from public.bookings where phone = p->>'phone' and status = 'slip_sent') >= 3 then
    raise exception 'too_many';
  end if;
  insert into public.bookings (nick, phone, line_id, bd, bm, by_be, bh, bmi, no_time, prov, cc, city, region, lat, lon, tz, tperiod, contact_via, ctz, slot_date, slot_time, slip, note)
  values (left(p->>'nick', 60), left(p->>'phone', 20), nullif(left(coalesce(p->>'line_id',''), 60), ''),
          (p->>'bd')::int, (p->>'bm')::int, (p->>'by')::int,
          nullif(p->>'bh','')::int, nullif(p->>'bmi','')::int, coalesce((p->>'no_time')::boolean, false),
          coalesce(nullif(p->>'prov','')::int, 0), upper(coalesce(nullif(p->>'cc',''), 'TH')),
          nullif(left(coalesce(p->>'city',''), 120), ''), nullif(left(coalesce(p->>'region',''), 120), ''),
          nullif(p->>'lat','')::double precision, nullif(p->>'lon','')::double precision, nullif(left(coalesce(p->>'tz',''), 64), ''),
          nullif(p->>'tperiod',''), coalesce(nullif(p->>'contact_via',''), 'phone'), nullif(left(coalesce(p->>'ctz',''), 64), ''),
          d, t, p->>'slip', nullif(left(coalesce(p->>'note',''), 500), ''))
  returning * into r;
  return jsonb_build_object('token', r.token, 'qno', r.qno, 'created_at', r.created_at);
exception
  when unique_violation then
    raise exception 'slot_taken';
  when check_violation then
    raise exception 'bad_place';
end;
$$;

-- สถานะคิวสำหรับลูกค้า (ต้องมี token เท่านั้น ไม่ส่งสลิปและบันทึกแอดมินกลับไป)
create or replace function public.bk_status(tk text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'qno', b.qno, 'created_at', b.created_at, 'updated_at', b.updated_at, 'status', b.status,
    'nick', b.nick, 'bd', b.bd, 'bm', b.bm, 'by', b.by_be, 'bh', b.bh, 'bmi', b.bmi,
    'no_time', b.no_time, 'prov', b.prov, 'cc', b.cc, 'city', b.city, 'region', b.region,
    'lat', b.lat, 'lon', b.lon, 'tz', b.tz, 'tperiod', b.tperiod, 'contact_via', b.contact_via, 'ctz', b.ctz, 'slot_date', b.slot_date, 'slot_time', b.slot_time,
    'ahead', (select count(*) from public.bookings x
              where x.status in ('slip_sent','confirmed')
                and ((x.slot_date + x.slot_time::time) at time zone 'Asia/Bangkok') > now()
                and ((x.slot_date + x.slot_time::time) at time zone 'Asia/Bangkok')
                    < ((b.slot_date + b.slot_time::time) at time zone 'Asia/Bangkok')))
  from public.bookings b where b.token = tk and char_length(tk) >= 24;
$$;

revoke all on function public.bk_create(jsonb) from public;
revoke all on function public.bk_status(text) from public;
revoke all on function public.bk_slots(date, date) from public;
grant execute on function public.bk_create(jsonb) to anon, authenticated;
grant execute on function public.bk_status(text) to anon, authenticated;
grant execute on function public.bk_slots(date, date) to anon, authenticated;
grant execute on function public.bk_is_admin() to authenticated;
