-- ============================================================================
-- OPTIMIZE DIRECT MESSAGE CONVERSATIONS
-- ============================================================================
-- This migration:
-- 1. Adds indexes for fast DM lookups
-- 2. Creates an optimized RPC for conversation summaries
-- ============================================================================

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Fast lookup of sent messages ordered by latest
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_time
ON public.chat_messages (sender_id, created_at DESC);

-- Fast lookup of received messages ordered by latest
CREATE INDEX IF NOT EXISTS idx_chat_messages_receiver_time
ON public.chat_messages (receiver_id, created_at DESC);

-- Composite index for DM conversations
CREATE INDEX IF NOT EXISTS idx_chat_messages_dm
ON public.chat_messages (sender_id, receiver_id, created_at DESC);

-- Reverse composite index
CREATE INDEX IF NOT EXISTS idx_chat_messages_dm_reverse
ON public.chat_messages (receiver_id, sender_id, created_at DESC);

-- Read receipt lookup
CREATE INDEX IF NOT EXISTS idx_chat_read_receipts_user_msg
ON public.chat_read_receipts (user_id, message_id);

-- ============================================================================
-- RPC
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_dm_conversations(p_user_id TEXT)
RETURNS TABLE (
    partner_id TEXT,
    last_message_id UUID,
    last_message TEXT,
    last_message_time TIMESTAMPTZ,
    last_sender_id TEXT,
    unread_count BIGINT,
    sender_name TEXT,
    sender_avatar_url TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS
$$
BEGIN
    RETURN QUERY

    WITH user_messages AS (

        SELECT
            m.id AS message_id,
            m.content,
            m.created_at,
            m.sender_id,
            m.receiver_id,

            CASE
                WHEN m.sender_id = p_user_id
                    THEN m.receiver_id
                ELSE
                    m.sender_id
            END AS partner_id

        FROM public.chat_messages m

        WHERE
            m.receiver_id IS NOT NULL

            -- Ignore accidental self-DMs
            AND m.sender_id <> m.receiver_id

            AND (
                m.sender_id = p_user_id
                OR
                m.receiver_id = p_user_id
            )

    ),

    latest_messages AS (

        SELECT DISTINCT ON (partner_id)

            partner_id,
            message_id,
            content,
            created_at,
            sender_id AS last_sender_id

        FROM user_messages

        ORDER BY
            partner_id,
            created_at DESC

    ),

    unread_counts AS (

        SELECT

            um.partner_id,

            COUNT(*)::BIGINT AS unread_count

        FROM user_messages um

        LEFT JOIN public.chat_read_receipts rr

            ON rr.message_id = um.message_id
           AND rr.user_id = p_user_id

        WHERE

            um.sender_id <> p_user_id

            AND rr.message_id IS NULL

        GROUP BY
            um.partner_id

    )

    SELECT

        lm.partner_id,

        lm.message_id,

        lm.content,

        lm.created_at,

        lm.last_sender_id,

        COALESCE(uc.unread_count,0),

        COALESCE(a.full_name,a.username),

        a.avatar_url

    FROM latest_messages lm

    LEFT JOIN unread_counts uc

        ON uc.partner_id = lm.partner_id

    LEFT JOIN public.agents a

        ON a.id = lm.partner_id::uuid

    ORDER BY
        lm.created_at DESC;

END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================

GRANT EXECUTE
ON FUNCTION public.get_dm_conversations(TEXT)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.get_dm_conversations(TEXT)
TO anon;

-- ============================================================================
-- Refresh PostgREST schema cache
-- ============================================================================

NOTIFY pgrst, 'reload schema';
