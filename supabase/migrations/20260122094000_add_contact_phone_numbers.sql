-- Add support for storing multiple phone numbers per customer
alter table public.customers
  add column if not exists contact_phone_numbers text[];

-- Backfill the new column with any existing single phone number
update public.customers
set contact_phone_numbers = array[contact_phone]
where contact_phone is not null
  and (contact_phone_numbers is null or array_length(contact_phone_numbers, 1) = 0);

comment on column public.customers.contact_phone_numbers is
  'All phone numbers associated with the customer (supersedes contact_phone).';
