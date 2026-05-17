-- Таблица переводов для категорий
SET search_path TO software_app, public;

CREATE TABLE IF NOT EXISTS category_translations (
    category_translation_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id BIGINT NOT NULL REFERENCES categories(category_id) ON DELETE CASCADE,
    locale VARCHAR(10) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    CONSTRAINT uk_category_translations_category_locale UNIQUE (category_id, locale)
);

CREATE INDEX IF NOT EXISTS ix_category_translations_locale ON category_translations(locale);

-- Функция для получения категорий с переводами
CREATE OR REPLACE FUNCTION get_categories_with_locale(p_locale VARCHAR DEFAULT 'ru')
RETURNS TABLE (
    category_id BIGINT,
    name VARCHAR,
    description TEXT
)
LANGUAGE sql
STABLE
SET search_path = software_app, public
AS $$
    SELECT c.category_id,
           COALESCE(ct.name, c.name) AS name,
           COALESCE(ct.description, c.description) AS description
      FROM categories c
      LEFT JOIN category_translations ct 
             ON ct.category_id = c.category_id 
            AND ct.locale = p_locale
     ORDER BY COALESCE(ct.name, c.name);
$$;

-- Обновляем функцию search_software для поддержки локали
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
            OR s.title ILIKE '%' || p_query || '%'
            OR s.description ILIKE '%' || p_query || '%'
            OR s.system_requirements ILIKE '%' || p_query || '%')
       AND (p_category_id IS NULL OR s.category_id = p_category_id)
       AND (p_developer_id IS NULL OR s.developer_id = p_developer_id)
       AND (p_is_free IS NULL OR s.is_free = p_is_free)
     GROUP BY s.software_id, c.category_id, ct.name, c.name, d.developer_id, d.name
     ORDER BY s.title;
$$;
