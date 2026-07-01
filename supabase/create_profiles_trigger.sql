-- Trigger to auto-create profile on user signup

-- Function that copies new user into public.profiles
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, nama, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.email, 'User'),
    'user'
  );
  return new;
end;
$$;

-- Trigger on auth.users
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Insert existing auth users who don't have a profile yet
insert into public.profiles (id, nama, role)
select
  au.id,
  coalesce(au.raw_user_meta_data ->> 'full_name', au.email, 'User'),
  'user'
from auth.users au
left join public.profiles p on p.id = au.id
where p.id is null;
