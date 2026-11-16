-- Increase storage limit for chat_attachments bucket to 5 GB (5368709120 bytes)
-- to support large file transfers (e.g. 3 GB+ datasets/archives) via TUS chunked resumable uploads.

UPDATE storage.buckets
SET file_size_limit = 5368709120
WHERE id = 'chat_attachments';

