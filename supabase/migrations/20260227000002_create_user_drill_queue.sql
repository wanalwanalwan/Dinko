-- User drill queue: AI-generated drills stored inline (no curated drill library)
create table public.user_drill_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text not null,
  target_skill text not null,
  target_subskill text,
  duration_minutes int not null,
  priority text not null default 'medium' check (priority in ('high', 'medium', 'low')),
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'completed', 'skipped')),
  rating smallint check (rating in (1, 5)),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

-- Index for querying a user's pending drills
create index idx_drill_queue_user_status on public.user_drill_queue(user_id, status);

-- Enable RLS
alter table public.user_drill_queue enable row level security;

-- Users can only read their own drills
create policy "Users can view own drills"
  on public.user_drill_queue for select
  using (auth.uid() = user_id);

-- Users can insert their own drills
create policy "Users can insert own drills"
  on public.user_drill_queue for insert
  with check (auth.uid() = user_id);

-- Users can update their own drills (mark complete, rate, skip)
create policy "Users can update own drills"
  on public.user_drill_queue for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Users can delete their own drills
create policy "Users can delete own drills"
  on public.user_drill_queue for delete
  using (auth.uid() = user_id);
