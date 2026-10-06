-- askit: Fragen und Votes
CREATE TABLE IF NOT EXISTS questions (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  text           text NOT NULL CHECK (char_length(text) BETWEEN 3 AND 500),
  author_sub     text NOT NULL,
  author_name    text NOT NULL,
  attachment_key text,
  answered       boolean NOT NULL DEFAULT false,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS votes (
  question_id uuid NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  user_sub    text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (question_id, user_sub)
);

CREATE INDEX IF NOT EXISTS questions_created_at_idx ON questions (created_at DESC);
