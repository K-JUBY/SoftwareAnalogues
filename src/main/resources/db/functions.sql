SET search_path TO software_app, public;

CREATE OR REPLACE FUNCTION authenticate_user(p_username TEXT, p_password TEXT)
RETURNS TABLE (
    user_id BIGINT,
    username VARCHAR,
    display_name VARCHAR,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = software_app, public
AS $$
BEGIN
    RETURN QUERY
    UPDATE users u
       SET last_login_at = now()
     WHERE lower(u.username) = lower(trim(p_username))
       AND u.is_active = TRUE
       AND u.password_hash = crypt(p_password, u.password_hash)
    RETURNING u.user_id, u.username, u.display_name, u.is_active, u.created_at, u.last_login_at;
END;
$$;

CREATE OR REPLACE FUNCTION create_app_user(
    p_username TEXT,
    p_password TEXT,
    p_display_name TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = software_app, public
AS $$
DECLARE
    v_user_id BIGINT;
BEGIN
    IF length(trim(p_username)) < 3 THEN
        RAISE EXCEPTION 'Username must contain at least 3 characters';
    END IF;

    IF length(p_password) < 6 THEN
        RAISE EXCEPTION 'Password must contain at least 6 characters';
    END IF;

    INSERT INTO users(username, password_hash, display_name)
    VALUES (trim(p_username), crypt(p_password, gen_salt('bf')), nullif(trim(p_display_name), ''))
    RETURNING users.user_id INTO v_user_id;

    RETURN v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION search_software(
    p_query TEXT DEFAULT NULL,
    p_category_id BIGINT DEFAULT NULL,
    p_developer_id BIGINT DEFAULT NULL,
    p_is_free BOOLEAN DEFAULT NULL,
    p_locale VARCHAR DEFAULT 'ru'
)
RETURNS TABLE (
    software_id BIGINT,
    title VARCHAR,
    description TEXT,
    system_requirements TEXT,
    size_mb NUMERIC,
    website VARCHAR,
    category_id BIGINT,
    category_name VARCHAR,
    developer_id BIGINT,
    developer_name VARCHAR,
    is_free BOOLEAN,
    average_rating NUMERIC,
    review_count BIGINT,
    last_updated_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SET search_path = software_app, public
AS $$
    SELECT s.software_id,
           s.title,
           s.description,
           s.system_requirements,
           s.size_mb,
           s.website,
           c.category_id,
           COALESCE(ct.name, c.name) AS category_name,
           d.developer_id,
           d.name AS developer_name,
           s.is_free,
           COALESCE(round(avg(r.rating)::numeric, 2), 0) AS average_rating,
           count(r.review_id) AS review_count,
           s.last_updated_at
      FROM software s
      LEFT JOIN categories c ON c.category_id = s.category_id
      LEFT JOIN category_translations ct 
             ON ct.category_id = c.category_id 
            AND ct.locale = p_locale
      LEFT JOIN developers d ON d.developer_id = s.developer_id
      LEFT JOIN reviews r ON r.software_id = s.software_id
     WHERE (p_query IS NULL OR p_query = ''
            OR (length(trim(p_query)) >= 3 AND (
                s.title ILIKE '%' || p_query || '%'
                OR s.description ILIKE '%' || p_query || '%'
                OR s.system_requirements ILIKE '%' || p_query || '%'
            ))
            OR (length(trim(p_query)) < 3 AND (
                s.title ILIKE p_query || '%'
                OR s.title ILIKE '% ' || p_query || '%'
            ))
           )
       AND (p_category_id IS NULL OR s.category_id = p_category_id)
       AND (p_developer_id IS NULL OR s.developer_id = p_developer_id)
       AND (p_is_free IS NULL OR s.is_free = p_is_free)
     GROUP BY s.software_id, c.category_id, ct.name, c.name, d.developer_id, d.name
     ORDER BY s.title;
$$;

CREATE OR REPLACE FUNCTION add_software(
    p_title TEXT,
    p_description TEXT,
    p_system_requirements TEXT,
    p_size_mb NUMERIC,
    p_website TEXT,
    p_category_id BIGINT,
    p_developer_id BIGINT,
    p_is_free BOOLEAN
)
RETURNS BIGINT
LANGUAGE plpgsql
SET search_path = software_app, public
AS $$
DECLARE
    v_software_id BIGINT;
BEGIN
    INSERT INTO software(title, description, system_requirements, size_mb, website, category_id, developer_id, is_free)
    VALUES (
        trim(p_title),
        nullif(trim(p_description), ''),
        nullif(trim(p_system_requirements), ''),
        p_size_mb,
        nullif(trim(p_website), ''),
        p_category_id,
        p_developer_id,
        p_is_free
    )
    RETURNING software_id INTO v_software_id;

    RETURN v_software_id;
END;
$$;

CREATE OR REPLACE FUNCTION update_software(
    p_software_id BIGINT,
    p_title TEXT,
    p_description TEXT,
    p_system_requirements TEXT,
    p_size_mb NUMERIC,
    p_website TEXT,
    p_category_id BIGINT,
    p_developer_id BIGINT,
    p_is_free BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = software_app, public
AS $$
BEGIN
    UPDATE software
       SET title = trim(p_title),
           description = nullif(trim(p_description), ''),
           system_requirements = nullif(trim(p_system_requirements), ''),
           size_mb = p_size_mb,
           website = nullif(trim(p_website), ''),
           category_id = p_category_id,
           developer_id = p_developer_id,
           is_free = p_is_free
     WHERE software_id = p_software_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Software with id % not found', p_software_id;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION delete_software(p_software_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = software_app, public
AS $$
BEGIN
    DELETE FROM software WHERE software_id = p_software_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Software with id % not found', p_software_id;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE add_software_analog(
    p_software_id BIGINT,
    p_analog_id BIGINT,
    p_reason TEXT DEFAULT NULL,
    p_similarity_score SMALLINT DEFAULT NULL
)
LANGUAGE plpgsql
SET search_path = software_app, public
AS $$
BEGIN
    INSERT INTO software_analogs(software_id, analog_id, reason, similarity_score)
    VALUES (p_software_id, p_analog_id, p_reason, p_similarity_score)
    ON CONFLICT DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION list_reviews(p_software_id BIGINT)
RETURNS TABLE (
    review_id BIGINT,
    software_id BIGINT,
    user_id BIGINT,
    author_name VARCHAR,
    review_text TEXT,
    rating SMALLINT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SET search_path = software_app, public
AS $$
    SELECT review_id,
           software_id,
           user_id,
           author_name,
           review_text,
           rating,
           created_at,
           updated_at
      FROM reviews
     WHERE software_id = p_software_id
     ORDER BY created_at DESC;
$$;

CREATE OR REPLACE FUNCTION add_review(
    p_software_id BIGINT,
    p_review_text TEXT,
    p_rating SMALLINT
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = software_app, public
AS $$
DECLARE
    v_user_id BIGINT;
    v_author_name VARCHAR;
    v_review_id BIGINT;
BEGIN
    v_user_id := nullif(current_setting('app.user_id', true), '')::BIGINT;

    SELECT COALESCE(nullif(display_name, ''), username)
      INTO v_author_name
      FROM users
     WHERE users.user_id = v_user_id;

    INSERT INTO reviews(software_id, user_id, author_name, review_text, rating)
    VALUES (p_software_id, v_user_id, COALESCE(v_author_name, 'Аноним'), trim(p_review_text), p_rating)
    RETURNING review_id INTO v_review_id;

    RETURN v_review_id;
END;
$$;

CREATE OR REPLACE FUNCTION list_software_analogs(p_software_id BIGINT)
RETURNS TABLE (
    software_analog_id BIGINT,
    software_id BIGINT,
    analog_id BIGINT,
    analog_title VARCHAR,
    category_name VARCHAR,
    developer_name VARCHAR,
    is_free BOOLEAN,
    average_rating NUMERIC,
    review_count BIGINT,
    reason TEXT,
    similarity_score SMALLINT,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SET search_path = software_app, public
AS $$
    SELECT sa.software_analog_id,
           p_software_id AS software_id,
           analog.software_id AS analog_id,
           analog.title AS analog_title,
           c.name AS category_name,
           d.name AS developer_name,
           analog.is_free,
           COALESCE(round(avg(r.rating)::numeric, 2), 0) AS average_rating,
           count(r.review_id) AS review_count,
           sa.reason,
           sa.similarity_score,
           sa.created_at
      FROM software_analogs sa
      JOIN software analog ON analog.software_id = CASE
           WHEN sa.software_id = p_software_id THEN sa.analog_id
           ELSE sa.software_id
      END
      LEFT JOIN categories c ON c.category_id = analog.category_id
      LEFT JOIN developers d ON d.developer_id = analog.developer_id
      LEFT JOIN reviews r ON r.software_id = analog.software_id
     WHERE sa.software_id = p_software_id OR sa.analog_id = p_software_id
     GROUP BY sa.software_analog_id, analog.software_id, analog.title, c.name, d.name, analog.is_free,
              sa.reason, sa.similarity_score, sa.created_at
     ORDER BY analog.title;
$$;

CREATE OR REPLACE FUNCTION remove_software_analog(p_software_id BIGINT, p_analog_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = software_app, public
AS $$
BEGIN
    DELETE FROM software_analogs sa
     WHERE least(sa.software_id, sa.analog_id) = least(p_software_id, p_analog_id)
       AND greatest(sa.software_id, sa.analog_id) = greatest(p_software_id, p_analog_id);
END;
$$;

CREATE OR REPLACE FUNCTION current_app_user_id()
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
    SELECT nullif(current_setting('app.user_id', true), '')::BIGINT;
$$;

CREATE OR REPLACE FUNCTION list_collections()
RETURNS TABLE (
    collection_id BIGINT,
    user_id BIGINT,
    title VARCHAR,
    description TEXT,
    item_count BIGINT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SET search_path = software_app, public
AS $$
    SELECT c.collection_id,
           c.user_id,
           c.title,
           c.description,
           count(ci.collection_item_id) AS item_count,
           c.created_at,
           c.updated_at
      FROM collections c
      LEFT JOIN collection_items ci ON ci.collection_id = c.collection_id
     WHERE c.user_id = current_app_user_id()
     GROUP BY c.collection_id, c.user_id, c.title, c.description, c.created_at, c.updated_at
     ORDER BY c.title;
$$;

CREATE OR REPLACE FUNCTION create_collection(p_title TEXT, p_description TEXT DEFAULT NULL)
RETURNS BIGINT
LANGUAGE plpgsql
SET search_path = software_app, public
AS $$
DECLARE
    v_collection_id BIGINT;
BEGIN
    INSERT INTO collections(user_id, title, description)
    VALUES (current_app_user_id(), trim(p_title), nullif(trim(p_description), ''))
    RETURNING collection_id INTO v_collection_id;

    RETURN v_collection_id;
END;
$$;

CREATE OR REPLACE FUNCTION delete_collection(p_collection_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = software_app, public
AS $$
BEGIN
    DELETE FROM collections
     WHERE collection_id = p_collection_id
       AND user_id = current_app_user_id();
END;
$$;

CREATE OR REPLACE FUNCTION list_collection_items(p_collection_id BIGINT)
RETURNS TABLE (
    collection_item_id BIGINT,
    collection_id BIGINT,
    software_id BIGINT,
    title VARCHAR,
    category_name VARCHAR,
    developer_name VARCHAR,
    is_free BOOLEAN,
    note TEXT,
    item_position INTEGER,
    added_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SET search_path = software_app, public
AS $$
    SELECT ci.collection_item_id,
           ci.collection_id,
           s.software_id,
           s.title,
           c.name AS category_name,
           d.name AS developer_name,
           s.is_free,
           ci.note,
           ci.position AS item_position,
           ci.added_at
      FROM collection_items ci
      JOIN collections col ON col.collection_id = ci.collection_id
      JOIN software s ON s.software_id = ci.software_id
      LEFT JOIN categories c ON c.category_id = s.category_id
      LEFT JOIN developers d ON d.developer_id = s.developer_id
     WHERE ci.collection_id = p_collection_id
       AND col.user_id = current_app_user_id()
     ORDER BY ci.position NULLS LAST, s.title;
$$;

CREATE OR REPLACE FUNCTION add_collection_item(
    p_collection_id BIGINT,
    p_software_id BIGINT,
    p_note TEXT DEFAULT NULL,
    p_position INTEGER DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SET search_path = software_app, public
AS $$
DECLARE
    v_collection_item_id BIGINT;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM collections
         WHERE collection_id = p_collection_id
           AND user_id = current_app_user_id()
    ) THEN
        RAISE EXCEPTION 'Collection not found';
    END IF;

    INSERT INTO collection_items(collection_id, software_id, note, position)
    VALUES (p_collection_id, p_software_id, nullif(trim(p_note), ''), p_position)
    ON CONFLICT (collection_id, software_id)
    DO UPDATE SET note = EXCLUDED.note,
                  position = EXCLUDED.position
    RETURNING collection_item_id INTO v_collection_item_id;

    RETURN v_collection_item_id;
END;
$$;

CREATE OR REPLACE FUNCTION remove_collection_item(p_collection_id BIGINT, p_software_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = software_app, public
AS $$
BEGIN
    DELETE FROM collection_items ci
     USING collections c
     WHERE c.collection_id = ci.collection_id
       AND c.user_id = current_app_user_id()
       AND ci.collection_id = p_collection_id
       AND ci.software_id = p_software_id;
END;
$$;
