CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS software_app;
SET search_path TO software_app, public;

CREATE TABLE IF NOT EXISTS users (
    user_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    password_hash TEXT NOT NULL,
    display_name VARCHAR(150),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_login_at TIMESTAMPTZ,
    CONSTRAINT ck_users_username_not_blank CHECK (length(trim(username)) >= 3),
    CONSTRAINT ck_users_password_hash_not_blank CHECK (length(password_hash) >= 20)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_users_username_lower ON users (lower(username));

CREATE TABLE IF NOT EXISTS categories (
    category_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_categories_name_not_blank CHECK (length(trim(name)) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_categories_name_lower ON categories (lower(name));

CREATE TABLE IF NOT EXISTS developers (
    developer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    website VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_developers_name_not_blank CHECK (length(trim(name)) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_developers_name_lower ON developers (lower(name));

CREATE TABLE IF NOT EXISTS software (
    software_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    system_requirements TEXT,
    size_mb NUMERIC(10, 2),
    website VARCHAR(255),
    category_id BIGINT REFERENCES categories(category_id) ON DELETE RESTRICT,
    developer_id BIGINT REFERENCES developers(developer_id) ON DELETE SET NULL,
    is_free BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_software_title_not_blank CHECK (length(trim(title)) > 0),
    CONSTRAINT ck_software_size_nonnegative CHECK (size_mb IS NULL OR size_mb >= 0),
    CONSTRAINT ck_software_website_url CHECK (website IS NULL OR website = '' OR website ~* '^https?://')
);

CREATE INDEX IF NOT EXISTS ix_software_category_id ON software(category_id);
CREATE INDEX IF NOT EXISTS ix_software_developer_id ON software(developer_id);
CREATE INDEX IF NOT EXISTS ix_software_title_lower ON software(lower(title));

CREATE TABLE IF NOT EXISTS software_analogs (
    software_analog_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    software_id BIGINT NOT NULL REFERENCES software(software_id) ON DELETE CASCADE,
    analog_id BIGINT NOT NULL REFERENCES software(software_id) ON DELETE CASCADE,
    reason TEXT,
    similarity_score SMALLINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_software_analogs_not_self CHECK (software_id <> analog_id),
    CONSTRAINT ck_software_analogs_similarity CHECK (similarity_score IS NULL OR similarity_score BETWEEN 0 AND 100)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_software_analogs_pair
ON software_analogs (least(software_id, analog_id), greatest(software_id, analog_id));

CREATE TABLE IF NOT EXISTS reviews (
    review_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    software_id BIGINT NOT NULL REFERENCES software(software_id) ON DELETE CASCADE,
    user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    author_name VARCHAR(100) NOT NULL DEFAULT 'Аноним',
    review_text TEXT NOT NULL,
    rating SMALLINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_reviews_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT ck_reviews_text_not_blank CHECK (length(trim(review_text)) > 0),
    CONSTRAINT ck_reviews_author_not_blank CHECK (length(trim(author_name)) > 0)
);

CREATE TABLE IF NOT EXISTS collections (
    collection_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_collections_title_not_blank CHECK (length(trim(title)) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_collections_user_title_lower ON collections(user_id, lower(title));

CREATE TABLE IF NOT EXISTS collection_items (
    collection_item_id BIGINT GENERATED ALWAYS AS IDENTITY UNIQUE,
    collection_id BIGINT NOT NULL REFERENCES collections(collection_id) ON DELETE CASCADE,
    software_id BIGINT NOT NULL REFERENCES software(software_id) ON DELETE CASCADE,
    note TEXT,
    position INTEGER,
    added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (collection_id, software_id),
    CONSTRAINT ck_collection_items_position_positive CHECK (position IS NULL OR position > 0)
);

CREATE TABLE IF NOT EXISTS screenshots (
    screenshot_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    software_id BIGINT NOT NULL REFERENCES software(software_id) ON DELETE CASCADE,
    image_data BYTEA NOT NULL,
    mime_type VARCHAR(50) NOT NULL DEFAULT 'image/png',
    caption VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_screenshots_mime_type CHECK (mime_type IN ('image/png', 'image/jpeg', 'image/webp'))
);

CREATE TABLE IF NOT EXISTS audit_log (
    audit_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name TEXT NOT NULL,
    operation CHAR(1) NOT NULL,
    row_pk JSONB NOT NULL,
    old_data JSONB,
    new_data JSONB,
    app_user_id BIGINT,
    db_user NAME NOT NULL DEFAULT session_user,
    client_addr INET DEFAULT inet_client_addr(),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
