-- ============================================================================
-- OPTIMIZE DIRECT MESSAGE CONVERSATIONS
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

-- ============================================================================
-- SECURE RPC FOR DM CONVERSATION LIST
-- ============================================================================

CREATE OR REPLACE FUNCTION get_dm_conversations(p_user_id TEXT)
RETURNS TABLE (
    partner_id TEXT,
    last_message_time TIMESTAMP WITH TIME ZONE,
    last_message_id UUID,
    last_message TEXT,
    last_sender_id TEXT,
    unread_count BIGINT,
    sender_name TEXT,
    sender_avatar_url TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    WITH UserMessages AS (
        -- Get all DM messages where the user is either sender or receiver
        SELECT 
            m.id,
            m.sender_id,
            m.receiver_id,
            m.content,
            m.created_at,
            m.sender_name AS original_sender_name,
            m.sender_avatar_url AS original_sender_avatar,
            CASE 
                WHEN m.sender_id = p_user_id THEN m.receiver_id 
                ELSE m.sender_id 
            END AS partner
        FROM public.chat_messages m
        WHERE m.receiver_id IS NOT NULL 
          AND (m.sender_id = p_user_id OR m.receiver_id = p_user_id)
          AND m.is_deleted = false
    ),
    LatestMessages AS (
        -- Get the most recent message per partner
        SELECT 
            um.partner,
            MAX(um.created_at) AS last_time
        FROM UserMessages um
        GROUP BY um.partner
    ),
    ConversationDetails AS (
        -- Join back to get the actual message details for that latest time
        SELECT 
            lm.partner,
            lm.last_time,
            um.id AS msg_id,
            um.content,
            um.sender_id AS msg_sender_id,
            um.original_sender_name,
            um.original_sender_avatar,
            ROW_NUMBER() OVER (PARTITION BY lm.partner ORDER BY um.created_at DESC) as rn
        FROM LatestMessages lm
        JOIN UserMessages um ON um.partner = lm.partner AND um.created_at = lm.last_time
    ),
    UnreadCounts AS (
        -- Count unread messages (where partner is sender and user has not read)
        SELECT 
            um.partner,
            COUNT(um.id) AS unread
        FROM UserMessages um
        LEFT JOIN public.chat_read_receipts r 
               ON r.message_id = um.id AND r.user_id = p_user_id
        WHERE um.sender_id = um.partner 
          AND r.message_id IS NULL
        GROUP BY um.partner
    )
    SELECT 
        cd.partner AS partner_id,
        cd.last_time AS last_message_time,
        cd.msg_id::uuid AS last_message_id,
        cd.content AS last_message,
        cd.msg_sender_id AS last_sender_id,
        COALESCE(uc.unread, 0) AS unread_count,
        -- Attempt to fetch the latest agent details from the agents table, fallback to the message's stored info
        COALESCE(a.full_name, a.username, cd.original_sender_name) AS sender_name,
        COALESCE(a.avatar_url, cd.original_sender_avatar) AS sender_avatar_url
    FROM ConversationDetails cd
    LEFT JOIN UnreadCounts uc ON uc.partner = cd.partner
    LEFT JOIN public.agents a ON a.id::text = cd.partner
    WHERE cd.rn = 1
    ORDER BY cd.last_time DESC;
END;
$$;
