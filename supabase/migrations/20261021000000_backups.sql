-- One backup row per account: the app's whole snapshot (profiles, measurements, plan) as JSON.
-- Row-level security means a signed-in user can only ever read or write their own row.

create table if not exists public.backups (
  user_id uuid primary key references auth.users (id) on delete cascade,
  data jsonb not null,
  schema_version integer not null default 1,
  updated_at timestamptz not null default now()
);

alter table public.backups enable row level security;

create policy "Read own backup" on public.backups
  for select using (auth.uid() = user_id);

create policy "Create own backup" on public.backups
  for insert with check (auth.uid() = user_id);

create policy "Update own backup" on public.backups
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Delete own backup" on public.backups
  for delete using (auth.uid() = user_id);

-- Backups are small; refuse anything absurd (about 5 MB of JSON).
alter table public.backups add constraint backups_size check (pg_column_size(data) < 5000000);
