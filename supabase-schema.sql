-- 루트골프아카데미 · 연습장 청소 & 마감 체크 — Supabase 스키마/시드
-- 프로젝트: root-golf-kids (ref ynwftvlflobmewhztrsh)
-- 기존 students / lessons / settings 테이블은 절대 건드리지 않습니다.

-- 1) 테이블 --------------------------------------------------------------
create table if not exists public.cleaning_items (
  id text primary key,
  title text not null,
  category text check (category in ('매일','2개월','4개월','6개월')),
  interval_days int not null default 1 check (interval_days in (1,60,120,180)),
  options_json jsonb,
  sort_order int default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.cleaning_logs (
  id text primary key,
  item_id text not null references public.cleaning_items(id) on delete cascade,
  staff_name text not null,
  detail jsonb,
  memo text,
  done_at timestamptz not null default now()
);

create table if not exists public.cleaning_staff (
  id text primary key,
  name text not null,
  role text check (role in ('매니저','프로')),
  sort_order int default 0
);

create index if not exists cleaning_logs_item_done_idx on public.cleaning_logs (item_id, done_at desc);
create index if not exists cleaning_logs_done_idx on public.cleaning_logs (done_at desc);

-- 2) RLS (실험용: anon/authenticated 전체 허용) ---------------------------
alter table public.cleaning_items enable row level security;
alter table public.cleaning_logs enable row level security;
alter table public.cleaning_staff enable row level security;

drop policy if exists cleaning_items_all on public.cleaning_items;
create policy cleaning_items_all on public.cleaning_items for all to anon, authenticated using (true) with check (true);
drop policy if exists cleaning_logs_all on public.cleaning_logs;
create policy cleaning_logs_all on public.cleaning_logs for all to anon, authenticated using (true) with check (true);
drop policy if exists cleaning_staff_all on public.cleaning_staff;
create policy cleaning_staff_all on public.cleaning_staff for all to anon, authenticated using (true) with check (true);

grant select, insert, update, delete on public.cleaning_items to anon, authenticated;
grant select, insert, update, delete on public.cleaning_logs to anon, authenticated;
grant select, insert, update, delete on public.cleaning_staff to anon, authenticated;

-- 3) 실시간(realtime) publication 등록 ----------------------------------
do $$
declare t text;
begin
  foreach t in array array['cleaning_items','cleaning_logs','cleaning_staff'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- 4) 기본 체크리스트 시드 ----------------------------------------------
insert into public.cleaning_items (id, title, category, interval_days, options_json, sort_order) values
  ('floor',      '바닥청소',                          '매일',   1,   '{"zones":[{"label":"스크린쪽 바닥"},{"label":"타석쪽 바닥"},{"label":"대기실"},{"label":"광장"}],"methods":["청소기","물걸레질"]}', 1),
  ('coffee',     '커피머신 · 정수기 청소',            '매일',   1,   null, 2),
  ('trash',      '쓰레기통 비우기',                    '매일',   1,   null, 3),
  ('mat',        '타석 바닥매트 청소',                 '매일',   1,   null, 4),
  ('dust',       '기계 먼지 털기',                     '매일',   1,   null, 5),
  ('chabatang',  '채 닦는 곳 청소',                    '매일',   1,   null, 6),
  ('shutdown',   '노래 · 에어컨 · 히터 · 포스기 끄기',  '매일',   1,   '{"shutdown":true}', 7),
  ('fan',        '선풍기 청소',                        '2개월', 60,  null, 8),
  ('airpurifier','공기청정기 필터 청소',               '2개월', 60,  null, 9),
  ('projector',  '빔프로젝터 필터 청소',               '2개월', 60,  null, 10),
  ('computer',   '컴퓨터 청소',                        '4개월', 120, null, 11),
  ('teeup',      '티업기계 안 청소',                   '4개월', 120, null, 12),
  ('acfilter',   '에어컨 필터 청소',                   '6개월', 180, null, 13),
  ('yogibo',     '요기보 이불빨래',                    '6개월', 180, null, 14)
on conflict (id) do nothing;

insert into public.cleaning_staff (id, name, role, sort_order) values
  ('staff-lee',      '이재근 프로', '프로',   1),
  ('staff-manager',  '매니저',      '매니저', 2),
  ('staff-pro1',     '프로 1',      '프로',   3),
  ('staff-pro2',     '프로 2',      '프로',   4)
on conflict (id) do nothing;
