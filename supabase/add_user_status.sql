-- Add status column to profiles for ban/unban feature
alter table public.profiles add column if not exists status text not null default 'active';

-- Policy so admin can update status
create policy "Admin can update profiles"
on public.profiles for update
to authenticated
using (true)
with check (true);
