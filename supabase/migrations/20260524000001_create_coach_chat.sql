-- Coach Chat: user_profiles, coach_assignments, conversations, coach_messages

-- 1. User profiles with role
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'player' CHECK (role IN ('player', 'coach', 'admin')),
    display_name TEXT NOT NULL DEFAULT '',
    coach_bio TEXT,
    coach_specialties TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
    ON user_profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Coaches can read assigned player profiles"
    ON user_profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM coach_assignments
            WHERE coach_id = auth.uid() AND player_id = user_profiles.id
        )
    );

CREATE POLICY "Players can read assigned coach profiles"
    ON user_profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM coach_assignments
            WHERE player_id = auth.uid() AND coach_id = user_profiles.id
        )
    );

-- 2. Coach assignments (admin-managed)
CREATE TABLE IF NOT EXISTS coach_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    coach_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(player_id, coach_id)
);

ALTER TABLE coach_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Players can see own assignments"
    ON coach_assignments FOR SELECT
    USING (auth.uid() = player_id);

CREATE POLICY "Coaches can see own assignments"
    ON coach_assignments FOR SELECT
    USING (auth.uid() = coach_id);

-- 3. Conversations
CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    coach_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    last_message_at TIMESTAMPTZ,
    last_message_preview TEXT,
    player_unread_count INT NOT NULL DEFAULT 0,
    coach_unread_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(player_id, coach_id)
);

ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Players can see own conversations"
    ON conversations FOR SELECT
    USING (auth.uid() = player_id);

CREATE POLICY "Coaches can see own conversations"
    ON conversations FOR SELECT
    USING (auth.uid() = coach_id);

CREATE POLICY "Players can update own conversations"
    ON conversations FOR UPDATE
    USING (auth.uid() = player_id);

CREATE POLICY "Coaches can update own conversations"
    ON conversations FOR UPDATE
    USING (auth.uid() = coach_id);

-- 4. Coach messages
CREATE TABLE IF NOT EXISTS coach_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at TIMESTAMPTZ
);

CREATE INDEX idx_coach_messages_conversation ON coach_messages(conversation_id, created_at DESC);
CREATE INDEX idx_coach_messages_sender ON coach_messages(sender_id);

ALTER TABLE coach_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Participants can read messages"
    ON coach_messages FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM conversations c
            WHERE c.id = coach_messages.conversation_id
            AND (c.player_id = auth.uid() OR c.coach_id = auth.uid())
        )
    );

CREATE POLICY "Participants can insert messages"
    ON coach_messages FOR INSERT
    WITH CHECK (
        auth.uid() = sender_id
        AND EXISTS (
            SELECT 1 FROM conversations c
            WHERE c.id = conversation_id
            AND (c.player_id = auth.uid() OR c.coach_id = auth.uid())
        )
    );

CREATE POLICY "Participants can update read_at"
    ON coach_messages FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM conversations c
            WHERE c.id = coach_messages.conversation_id
            AND (c.player_id = auth.uid() OR c.coach_id = auth.uid())
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM conversations c
            WHERE c.id = coach_messages.conversation_id
            AND (c.player_id = auth.uid() OR c.coach_id = auth.uid())
        )
    );

-- 5. Trigger: update conversation metadata on new message
CREATE OR REPLACE FUNCTION update_conversation_on_message()
RETURNS TRIGGER AS $$
DECLARE
    conv RECORD;
BEGIN
    SELECT * INTO conv FROM conversations WHERE id = NEW.conversation_id;

    UPDATE conversations SET
        last_message_at = NEW.created_at,
        last_message_preview = LEFT(NEW.content, 100),
        player_unread_count = CASE
            WHEN NEW.sender_id = conv.coach_id THEN player_unread_count + 1
            ELSE player_unread_count
        END,
        coach_unread_count = CASE
            WHEN NEW.sender_id = conv.player_id THEN coach_unread_count + 1
            ELSE coach_unread_count
        END
    WHERE id = NEW.conversation_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_update_conversation_on_message
    AFTER INSERT ON coach_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_conversation_on_message();

-- 6. Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE coach_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
