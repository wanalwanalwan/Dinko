-- Tracks every AI request per user for rate limiting
create table public.ai_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  created_at timestamptz not null default now()
);

-- Index for fast per-user sliding-window counts
create index idx_ai_requests_user_created on public.ai_requests(user_id, created_at desc);

alter table public.ai_requests enable row level security;

-- Users can insert their own tracking rows (needed for rate limit check to work with user JWT)
create policy "Users can insert own ai requests"
  on public.ai_requests for insert
  with check (auth.uid() = user_id);

-- Users can read their own request history (needed for count query)
create policy "Users can view own ai requests"
  on public.ai_requests for select
  using (auth.uid() = user_id);
