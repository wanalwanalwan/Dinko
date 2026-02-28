-- User roadmap: weekly focus themes and milestone goals
create table public.user_roadmap (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('weekly_focus', 'milestone')),
  title text not null,
  description text not null,
  target_skill text,
  target_value int,
  status text not null default 'active' check (status in ('active', 'completed', 'replaced')),
  starts_at date not null default current_date,
  ends_at date,
  created_at timestamptz not null default now()
);

-- Index for querying a user's active roadmap items
create index idx_roadmap_user_status on public.user_roadmap(user_id, status);

-- Index for finding active weekly focus (common query)
create index idx_roadmap_user_type_status on public.user_roadmap(user_id, type, status);

-- Enable RLS
alter table public.user_roadmap enable row level security;

-- Users can only read their own roadmap
create policy "Users can view own roadmap"
  on public.user_roadmap for select
  using (auth.uid() = user_id);

-- Users can insert their own roadmap entries
create policy "Users can insert own roadmap"
  on public.user_roadmap for insert
  with check (auth.uid() = user_id);

-- Users can update their own roadmap entries (mark complete, replace)
create policy "Users can update own roadmap"
  on public.user_roadmap for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Users can delete their own roadmap entries
create policy "Users can delete own roadmap"
  on public.user_roadmap for delete
  using (auth.uid() = user_id);
