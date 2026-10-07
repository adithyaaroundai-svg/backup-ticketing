-- 1. Create trigger function to route new leads based on product
CREATE OR REPLACE FUNCTION public.route_lead_pipeline()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- If private pipeline, respect user's private pipeline choice
  IF COALESCE(NEW.pipeline_type, '') = 'private' THEN
    RETURN NEW;
  END IF;

  -- Only for newly created leads:
  -- If product is Mobile App, route to mobile-app-sales channel
  IF LOWER(TRIM(COALESCE(NEW.product, ''))) LIKE '%mobile app%' THEN
    NEW.pipeline_type := 'mobile-app-sales';
  ELSIF NEW.pipeline_type IS NULL OR NEW.pipeline_type = '' THEN
    NEW.pipeline_type := 'global';
  END IF;

  RETURN NEW;
END;
$$;

-- 2. Drop any previous update/insert triggers and attach trigger ONLY on INSERT
DROP TRIGGER IF EXISTS trg_route_lead_pipeline ON public.leads;

CREATE TRIGGER trg_route_lead_pipeline
  BEFORE INSERT ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.route_lead_pipeline();

-- 3. Restore all existing leads back to 'global' (Product Sales Channel)
UPDATE public.leads
SET pipeline_type = 'global'
WHERE id IN (
  '9f1531d2-115e-4540-a1d1-a8a4b283c03b',
  '1909df20-6f3c-498f-ad8f-3db5d8c5cd68',
  'ee9f3d92-c7af-43e6-9ebc-f0924111b758',
  '1311a3a3-2cf0-4fc2-bd1d-fca2a6b930e8',
  '83dd5f35-9e7f-409c-974f-8444ceae2755',
  '9a2e30e3-36c8-405e-a7ac-dd6d43859ea2',
  'dadb4e58-5e28-4833-815f-83b94a90f465',
  '2d6525bf-c947-4b25-98e3-7e09f6a39d3f',
  'f29df077-4a59-46d4-a2f6-23038f2c5139',
  '38cdedb8-dd9f-4855-a3d8-7d9effe23cb5',
  'c5792ee5-9736-49fb-80b8-53c8ed05690c',
  '782447bd-43fa-47e5-916b-e5c948f4d52e',
  'f99f199f-f757-4ed0-a4a6-495b0a310b95',
  'e0e901bc-ae9d-428e-826b-f26440f0ff41',
  '5dd77f66-5035-4e33-a311-3c6bd1a99bae',
  '9466f9f7-cab3-4891-ac8d-0aac558b8cc1',
  '8ee098ed-6aea-471f-bada-1244c6a4f42c',
  '06bab50d-3c35-4402-94ad-f34692b183b7',
  'cd8231ce-d3df-48ff-b6e7-584019d0d2c5'
);
