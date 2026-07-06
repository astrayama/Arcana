-- Arcana — Supabase schema
-- Run this in the SQL editor of your Supabase project (or `supabase db push`).
-- If your existing web app already has equivalent tables, adapt the table/column
-- names in SupabaseRepository.swift instead of re-creating them.

create table if not exists public.pulls (
  id          uuid primary key,
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  card_id     text not null,
  orientation text not null check (orientation in ('upright', 'reversed')),
  note        text not null default '',
  date        timestamptz not null,
  insight     text,
  created_at  timestamptz not null default now()
);

create table if not exists public.spreads (
  id            uuid primary key,
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title         text not null,
  template_id   text not null,
  template_name text not null,
  cards         jsonb not null default '[]',
  note          text not null default '',
  date          timestamptz not null,
  insight       text,
  created_at    timestamptz not null default now()
);

create index if not exists pulls_user_date_idx on public.pulls (user_id, date desc);
create index if not exists spreads_user_date_idx on public.spreads (user_id, date desc);

-- Row-level security: each user sees only their own entries.
alter table public.pulls enable row level security;
alter table public.spreads enable row level security;

drop policy if exists "pulls are own" on public.pulls;
create policy "pulls are own" on public.pulls
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "spreads are own" on public.spreads;
create policy "spreads are own" on public.spreads
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
