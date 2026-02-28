-- Session logs: stores every session note and AI pipeline output for auditability
create table public.session_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  raw_note text not null,
  extracted_json jsonb,
  applied_deltas jsonb,
  drill_recommendations jsonb,
  user_confirmed boolean not null default false,
  created_at timestamptz not null default now()
);

-- Index for querying a user's sessions chronologically
create index idx_session_logs_user_created on public.session_logs(user_id, created_at desc);

-- Enable RLS
alter table public.session_logs enable row level security;

-- Users can only read their own session logs
create policy "Users can view own session logs"
  on public.session_logs for select
  using (auth.uid() = user_id);

-- Users can insert their own session logs
create policy "Users can insert own session logs"
  on public.session_logs for insert
  with check (auth.uid() = user_id);

-- Users can update their own session logs (e.g. confirming suggestions)
create policy "Users can update own session logs"
  on public.session_logs for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
