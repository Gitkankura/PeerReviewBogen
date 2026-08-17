-- Run AFTER creating the administrator in Supabase Dashboard:
-- Authentication -> Users -> Add user
-- Replace the email below with the exact administrator email.

insert into public.admin_users (user_id)
select id
from auth.users
where lower(email) = lower('sbraun@dsvaldivia.cl')
on conflict (user_id) do nothing;

-- Verification: should return the user you just authorized.
select u.id, u.email, a.created_at as admin_since
from public.admin_users a
join auth.users u on u.id = a.user_id
order by a.created_at;
