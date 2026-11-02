-- Migration: Add App Version Control configuration for Force Update
-- This row in app_settings governs minimum and latest allowed version codes for Play Store updates.

INSERT INTO public.app_settings (setting_key, setting_value, description)
VALUES (
  'app_version_control',
  '{
    "min_version_code": 4,
    "latest_version_code": 4,
    "min_version_name": "1.0.3",
    "latest_version_name": "1.0.3",
    "force_update": true,
    "title": "Update Required",
    "message": "A newer version of TallyCare is available on Google Play. Please update the app to continue using it.",
    "release_notes": "• Performance improvements and bug fixes\n• Mobile profile photo and UI enhancements\n• Enforced version control",
    "play_store_url": "https://play.google.com/store/apps/details?id=com.aroundtally.tallycare"
  }'::jsonb,
  'Governs app version enforcement, minimum required build number, and Google Play Store link'
)
ON CONFLICT (setting_key) DO UPDATE
SET setting_value = EXCLUDED.setting_value,
    description = EXCLUDED.description;

-- Ensure public read access (for both anonymous and authenticated users)
-- so the app can verify its version code on launch even before user login
DROP POLICY IF EXISTS "Allow public read for app_version_control" ON public.app_settings;
CREATE POLICY "Allow public read for app_version_control" ON public.app_settings
  FOR SELECT TO public
  USING (setting_key = 'app_version_control');
