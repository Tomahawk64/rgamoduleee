-- =============================================================================
-- MIGRATION 006 - Special Pooja image storage bucket and policies
-- Run after: 005_add_missing_columns.sql
-- =============================================================================

-- Create/ensure a public bucket used by admin image uploads.
-- Public read is required so image_url can be rendered directly by Image.network.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'special-pooja-images',
  'special-pooja-images',
  true,
  5242880, -- 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Public can read objects from this bucket.
DROP POLICY IF EXISTS "special_pooja_images_read_public" ON storage.objects;
CREATE POLICY "special_pooja_images_read_public"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'special-pooja-images');

-- Only admin users can upload/update/delete objects.
DROP POLICY IF EXISTS "special_pooja_images_admin_upload" ON storage.objects;
CREATE POLICY "special_pooja_images_admin_upload"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'special-pooja-images'
    AND public.get_my_role() = 'admin'
  );

DROP POLICY IF EXISTS "special_pooja_images_admin_update" ON storage.objects;
CREATE POLICY "special_pooja_images_admin_update"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'special-pooja-images'
    AND public.get_my_role() = 'admin'
  )
  WITH CHECK (
    bucket_id = 'special-pooja-images'
    AND public.get_my_role() = 'admin'
  );

DROP POLICY IF EXISTS "special_pooja_images_admin_delete" ON storage.objects;
CREATE POLICY "special_pooja_images_admin_delete"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'special-pooja-images'
    AND public.get_my_role() = 'admin'
  );
