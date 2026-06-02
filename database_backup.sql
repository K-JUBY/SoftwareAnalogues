--
-- PostgreSQL database dump
--

\restrict E37S1ZSlyPM6kjkGg6T52BRfWbuTofSzgi3zqVVCOAYFbda6FCbTTiF6xpUcJOp

-- Dumped from database version 18.0
-- Dumped by pg_dump version 18.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: software_app; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA software_app;


ALTER SCHEMA software_app OWNER TO postgres;

--
-- Name: add_collection_item(bigint, bigint, text, integer); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.add_collection_item(p_collection_id bigint, p_software_id bigint, p_note text DEFAULT NULL::text, p_position integer DEFAULT NULL::integer) RETURNS bigint
    LANGUAGE plpgsql
    SET search_path TO 'software_app', 'public'
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


ALTER FUNCTION software_app.add_collection_item(p_collection_id bigint, p_software_id bigint, p_note text, p_position integer) OWNER TO postgres;

--
-- Name: add_review(bigint, text, smallint); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.add_review(p_software_id bigint, p_review_text text, p_rating smallint) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'software_app', 'public'
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


ALTER FUNCTION software_app.add_review(p_software_id bigint, p_review_text text, p_rating smallint) OWNER TO postgres;

--
-- Name: add_software(text, text, text, numeric, text, bigint, bigint, boolean); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.add_software(p_title text, p_description text, p_system_requirements text, p_size_mb numeric, p_website text, p_category_id bigint, p_developer_id bigint, p_is_free boolean) RETURNS bigint
    LANGUAGE plpgsql
    SET search_path TO 'software_app', 'public'
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


ALTER FUNCTION software_app.add_software(p_title text, p_description text, p_system_requirements text, p_size_mb numeric, p_website text, p_category_id bigint, p_developer_id bigint, p_is_free boolean) OWNER TO postgres;

--
-- Name: add_software_analog(bigint, bigint, text, smallint); Type: PROCEDURE; Schema: software_app; Owner: postgres
--

CREATE PROCEDURE software_app.add_software_analog(IN p_software_id bigint, IN p_analog_id bigint, IN p_reason text DEFAULT NULL::text, IN p_similarity_score smallint DEFAULT NULL::smallint)
    LANGUAGE plpgsql
    SET search_path TO 'software_app', 'public'
    AS $$
BEGIN
    INSERT INTO software_analogs(software_id, analog_id, reason, similarity_score)
    VALUES (p_software_id, p_analog_id, p_reason, p_similarity_score)
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER PROCEDURE software_app.add_software_analog(IN p_software_id bigint, IN p_analog_id bigint, IN p_reason text, IN p_similarity_score smallint) OWNER TO postgres;

--
-- Name: audit_row_change(); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.audit_row_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'software_app', 'public'
    AS $$
DECLARE
    v_app_user_id BIGINT;
    v_old JSONB;
    v_new JSONB;
    v_pk JSONB;
BEGIN
    v_app_user_id := nullif(current_setting('app.user_id', true), '')::BIGINT;

    IF TG_OP = 'INSERT' THEN
        v_new := to_jsonb(NEW);
        v_pk := jsonb_build_object(TG_ARGV[0], v_new -> TG_ARGV[0]);
        IF TG_TABLE_NAME = 'users' THEN
            v_new := v_new - 'password_hash';
        END IF;
        INSERT INTO audit_log(table_name, operation, row_pk, new_data, app_user_id)
        VALUES (TG_TABLE_NAME, 'I', v_pk, v_new, v_app_user_id);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        v_old := to_jsonb(OLD);
        v_new := to_jsonb(NEW);
        v_pk := jsonb_build_object(TG_ARGV[0], v_new -> TG_ARGV[0]);
        IF TG_TABLE_NAME = 'users' THEN
            v_old := v_old - 'password_hash';
            v_new := v_new - 'password_hash';
        END IF;
        INSERT INTO audit_log(table_name, operation, row_pk, old_data, new_data, app_user_id)
        VALUES (TG_TABLE_NAME, 'U', v_pk, v_old, v_new, v_app_user_id);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        v_old := to_jsonb(OLD);
        v_pk := jsonb_build_object(TG_ARGV[0], v_old -> TG_ARGV[0]);
        IF TG_TABLE_NAME = 'users' THEN
            v_old := v_old - 'password_hash';
        END IF;
        INSERT INTO audit_log(table_name, operation, row_pk, old_data, app_user_id)
        VALUES (TG_TABLE_NAME, 'D', v_pk, v_old, v_app_user_id);
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION software_app.audit_row_change() OWNER TO postgres;

--
-- Name: authenticate_user(text, text); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.authenticate_user(p_username text, p_password text) RETURNS TABLE(user_id bigint, username character varying, display_name character varying, is_active boolean, created_at timestamp with time zone, last_login_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'software_app', 'public'
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


ALTER FUNCTION software_app.authenticate_user(p_username text, p_password text) OWNER TO postgres;

--
-- Name: create_app_user(text, text, text); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.create_app_user(p_username text, p_password text, p_display_name text DEFAULT NULL::text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'software_app', 'public'
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


ALTER FUNCTION software_app.create_app_user(p_username text, p_password text, p_display_name text) OWNER TO postgres;

--
-- Name: create_collection(text, text); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.create_collection(p_title text, p_description text DEFAULT NULL::text) RETURNS bigint
    LANGUAGE plpgsql
    SET search_path TO 'software_app', 'public'
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


ALTER FUNCTION software_app.create_collection(p_title text, p_description text) OWNER TO postgres;

--
-- Name: current_app_user_id(); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.current_app_user_id() RETURNS bigint
    LANGUAGE sql STABLE
    AS $$
    SELECT nullif(current_setting('app.user_id', true), '')::BIGINT;
$$;


ALTER FUNCTION software_app.current_app_user_id() OWNER TO postgres;

--
-- Name: delete_collection(bigint); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.delete_collection(p_collection_id bigint) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'software_app', 'public'
    AS $$
BEGIN
    DELETE FROM collections
     WHERE collection_id = p_collection_id
       AND user_id = current_app_user_id();
END;
$$;


ALTER FUNCTION software_app.delete_collection(p_collection_id bigint) OWNER TO postgres;

--
-- Name: delete_software(bigint); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.delete_software(p_software_id bigint) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'software_app', 'public'
    AS $$
BEGIN
    DELETE FROM software WHERE software_id = p_software_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Software with id % not found', p_software_id;
    END IF;
END;
$$;


ALTER FUNCTION software_app.delete_software(p_software_id bigint) OWNER TO postgres;

--
-- Name: get_categories_with_locale(character varying); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.get_categories_with_locale(p_locale character varying DEFAULT 'ru'::character varying) RETURNS TABLE(category_id bigint, name character varying, description text)
    LANGUAGE sql STABLE
    AS $$
    SELECT c.category_id,
           COALESCE(ct.name, c.name) AS name,
           COALESCE(ct.description, c.description) AS description
      FROM software_app.categories c
      LEFT JOIN software_app.category_translations ct 
             ON ct.category_id = c.category_id 
            AND ct.locale = p_locale
     ORDER BY COALESCE(ct.name, c.name);
$$;


ALTER FUNCTION software_app.get_categories_with_locale(p_locale character varying) OWNER TO postgres;

--
-- Name: list_collection_items(bigint); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.list_collection_items(p_collection_id bigint) RETURNS TABLE(collection_item_id bigint, collection_id bigint, software_id bigint, title character varying, category_name character varying, developer_name character varying, is_free boolean, note text, item_position integer, added_at timestamp with time zone)
    LANGUAGE sql STABLE
    SET search_path TO 'software_app', 'public'
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


ALTER FUNCTION software_app.list_collection_items(p_collection_id bigint) OWNER TO postgres;

--
-- Name: list_collections(); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.list_collections() RETURNS TABLE(collection_id bigint, user_id bigint, title character varying, description text, item_count bigint, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE sql STABLE
    SET search_path TO 'software_app', 'public'
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


ALTER FUNCTION software_app.list_collections() OWNER TO postgres;

--
-- Name: list_reviews(bigint); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.list_reviews(p_software_id bigint) RETURNS TABLE(review_id bigint, software_id bigint, user_id bigint, author_name character varying, review_text text, rating smallint, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE sql STABLE
    SET search_path TO 'software_app', 'public'
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


ALTER FUNCTION software_app.list_reviews(p_software_id bigint) OWNER TO postgres;

--
-- Name: list_software_analogs(bigint); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.list_software_analogs(p_software_id bigint) RETURNS TABLE(software_analog_id bigint, software_id bigint, analog_id bigint, analog_title character varying, category_name character varying, developer_name character varying, is_free boolean, average_rating numeric, review_count bigint, reason text, similarity_score smallint, created_at timestamp with time zone)
    LANGUAGE sql STABLE
    SET search_path TO 'software_app', 'public'
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


ALTER FUNCTION software_app.list_software_analogs(p_software_id bigint) OWNER TO postgres;

--
-- Name: remove_collection_item(bigint, bigint); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.remove_collection_item(p_collection_id bigint, p_software_id bigint) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'software_app', 'public'
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


ALTER FUNCTION software_app.remove_collection_item(p_collection_id bigint, p_software_id bigint) OWNER TO postgres;

--
-- Name: remove_software_analog(bigint, bigint); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.remove_software_analog(p_software_id bigint, p_analog_id bigint) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'software_app', 'public'
    AS $$
BEGIN
    DELETE FROM software_analogs sa
     WHERE least(sa.software_id, sa.analog_id) = least(p_software_id, p_analog_id)
       AND greatest(sa.software_id, sa.analog_id) = greatest(p_software_id, p_analog_id);
END;
$$;


ALTER FUNCTION software_app.remove_software_analog(p_software_id bigint, p_analog_id bigint) OWNER TO postgres;

--
-- Name: search_software(text, bigint, bigint, boolean, character varying); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.search_software(p_query text DEFAULT NULL::text, p_category_id bigint DEFAULT NULL::bigint, p_developer_id bigint DEFAULT NULL::bigint, p_is_free boolean DEFAULT NULL::boolean, p_locale character varying DEFAULT 'ru'::character varying) RETURNS TABLE(software_id bigint, title character varying, description text, system_requirements text, size_mb numeric, website character varying, category_id bigint, category_name character varying, developer_id bigint, developer_name character varying, is_free boolean, average_rating numeric, review_count bigint, last_updated_at timestamp with time zone)
    LANGUAGE sql STABLE
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
      FROM software_app.software s
      LEFT JOIN software_app.categories c ON c.category_id = s.category_id
      LEFT JOIN software_app.category_translations ct 
             ON ct.category_id = c.category_id 
            AND ct.locale = p_locale
      LEFT JOIN software_app.developers d ON d.developer_id = s.developer_id
      LEFT JOIN software_app.reviews r ON r.software_id = s.software_id
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


ALTER FUNCTION software_app.search_software(p_query text, p_category_id bigint, p_developer_id bigint, p_is_free boolean, p_locale character varying) OWNER TO postgres;

--
-- Name: touch_updated_at(); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_TABLE_NAME = 'software' THEN
        NEW.last_updated_at = now();
    ELSE
        NEW.updated_at = now();
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION software_app.touch_updated_at() OWNER TO postgres;

--
-- Name: update_software(bigint, text, text, text, numeric, text, bigint, bigint, boolean); Type: FUNCTION; Schema: software_app; Owner: postgres
--

CREATE FUNCTION software_app.update_software(p_software_id bigint, p_title text, p_description text, p_system_requirements text, p_size_mb numeric, p_website text, p_category_id bigint, p_developer_id bigint, p_is_free boolean) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'software_app', 'public'
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


ALTER FUNCTION software_app.update_software(p_software_id bigint, p_title text, p_description text, p_system_requirements text, p_size_mb numeric, p_website text, p_category_id bigint, p_developer_id bigint, p_is_free boolean) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log; Type: TABLE; Schema: software_app; Owner: postgres
--

CREATE TABLE software_app.audit_log (
    audit_id bigint NOT NULL,
    table_name text NOT NULL,
    operation character(1) NOT NULL,
    row_pk jsonb NOT NULL,
    old_data jsonb,
    new_data jsonb,
    app_user_id bigint,
    db_user name DEFAULT SESSION_USER NOT NULL,
    client_addr inet DEFAULT inet_client_addr(),
    changed_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE software_app.audit_log OWNER TO postgres;

--
-- Name: audit_log_audit_id_seq; Type: SEQUENCE; Schema: software_app; Owner: postgres
--

ALTER TABLE software_app.audit_log ALTER COLUMN audit_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME software_app.audit_log_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: categories; Type: TABLE; Schema: software_app; Owner: postgres
--

CREATE TABLE software_app.categories (
    category_id bigint NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_categories_name_not_blank CHECK ((length(TRIM(BOTH FROM name)) > 0))
);


ALTER TABLE software_app.categories OWNER TO postgres;

--
-- Name: categories_category_id_seq; Type: SEQUENCE; Schema: software_app; Owner: postgres
--

ALTER TABLE software_app.categories ALTER COLUMN category_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME software_app.categories_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: category_translations; Type: TABLE; Schema: software_app; Owner: postgres
--

CREATE TABLE software_app.category_translations (
    category_translation_id bigint NOT NULL,
    category_id bigint NOT NULL,
    locale character varying(10) NOT NULL,
    name character varying(150) NOT NULL,
    description text
);


ALTER TABLE software_app.category_translations OWNER TO postgres;

--
-- Name: category_translations_category_translation_id_seq; Type: SEQUENCE; Schema: software_app; Owner: postgres
--

ALTER TABLE software_app.category_translations ALTER COLUMN category_translation_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME software_app.category_translations_category_translation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: collection_items; Type: TABLE; Schema: software_app; Owner: postgres
--

CREATE TABLE software_app.collection_items (
    collection_item_id bigint NOT NULL,
    collection_id bigint NOT NULL,
    software_id bigint NOT NULL,
    note text,
    "position" integer,
    added_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_collection_items_position_positive CHECK ((("position" IS NULL) OR ("position" > 0)))
);


ALTER TABLE software_app.collection_items OWNER TO postgres;

--
-- Name: collection_items_collection_item_id_seq; Type: SEQUENCE; Schema: software_app; Owner: postgres
--

ALTER TABLE software_app.collection_items ALTER COLUMN collection_item_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME software_app.collection_items_collection_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: collections; Type: TABLE; Schema: software_app; Owner: postgres
--

CREATE TABLE software_app.collections (
    collection_id bigint NOT NULL,
    user_id bigint NOT NULL,
    title character varying(150) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_collections_title_not_blank CHECK ((length(TRIM(BOTH FROM title)) > 0))
);


ALTER TABLE software_app.collections OWNER TO postgres;

--
-- Name: collections_collection_id_seq; Type: SEQUENCE; Schema: software_app; Owner: postgres
--

ALTER TABLE software_app.collections ALTER COLUMN collection_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME software_app.collections_collection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: developers; Type: TABLE; Schema: software_app; Owner: postgres
--

CREATE TABLE software_app.developers (
    developer_id bigint NOT NULL,
    name character varying(150) NOT NULL,
    website character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_developers_name_not_blank CHECK ((length(TRIM(BOTH FROM name)) > 0))
);


ALTER TABLE software_app.developers OWNER TO postgres;

--
-- Name: developers_developer_id_seq; Type: SEQUENCE; Schema: software_app; Owner: postgres
--

ALTER TABLE software_app.developers ALTER COLUMN developer_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME software_app.developers_developer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: reviews; Type: TABLE; Schema: software_app; Owner: postgres
--

CREATE TABLE software_app.reviews (
    review_id bigint NOT NULL,
    software_id bigint NOT NULL,
    user_id bigint,
    author_name character varying(100) DEFAULT 'Аноним'::character varying NOT NULL,
    review_text text NOT NULL,
    rating smallint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_reviews_author_not_blank CHECK ((length(TRIM(BOTH FROM author_name)) > 0)),
    CONSTRAINT ck_reviews_rating CHECK (((rating >= 1) AND (rating <= 5))),
    CONSTRAINT ck_reviews_text_not_blank CHECK ((length(TRIM(BOTH FROM review_text)) > 0))
);


ALTER TABLE software_app.reviews OWNER TO postgres;

--
-- Name: reviews_review_id_seq; Type: SEQUENCE; Schema: software_app; Owner: postgres
--

ALTER TABLE software_app.reviews ALTER COLUMN review_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME software_app.reviews_review_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: screenshots; Type: TABLE; Schema: software_app; Owner: postgres
--

CREATE TABLE software_app.screenshots (
    screenshot_id bigint NOT NULL,
    software_id bigint NOT NULL,
    image_data bytea NOT NULL,
    mime_type character varying(50) DEFAULT 'image/png'::character varying NOT NULL,
    caption character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_screenshots_mime_type CHECK (((mime_type)::text = ANY ((ARRAY['image/png'::character varying, 'image/jpeg'::character varying, 'image/webp'::character varying])::text[])))
);


ALTER TABLE software_app.screenshots OWNER TO postgres;

--
-- Name: screenshots_screenshot_id_seq; Type: SEQUENCE; Schema: software_app; Owner: postgres
--

ALTER TABLE software_app.screenshots ALTER COLUMN screenshot_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME software_app.screenshots_screenshot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: software; Type: TABLE; Schema: software_app; Owner: postgres
--

CREATE TABLE software_app.software (
    software_id bigint NOT NULL,
    title character varying(150) NOT NULL,
    description text,
    system_requirements text,
    size_mb numeric(10,2),
    website character varying(255),
    category_id bigint,
    developer_id bigint,
    is_free boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_software_size_nonnegative CHECK (((size_mb IS NULL) OR (size_mb >= (0)::numeric))),
    CONSTRAINT ck_software_title_not_blank CHECK ((length(TRIM(BOTH FROM title)) > 0)),
    CONSTRAINT ck_software_website_url CHECK (((website IS NULL) OR ((website)::text = ''::text) OR ((website)::text ~* '^https?://'::text)))
);


ALTER TABLE software_app.software OWNER TO postgres;

--
-- Name: software_analogs; Type: TABLE; Schema: software_app; Owner: postgres
--

CREATE TABLE software_app.software_analogs (
    software_analog_id bigint NOT NULL,
    software_id bigint NOT NULL,
    analog_id bigint NOT NULL,
    reason text,
    similarity_score smallint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_software_analogs_not_self CHECK ((software_id <> analog_id)),
    CONSTRAINT ck_software_analogs_similarity CHECK (((similarity_score IS NULL) OR ((similarity_score >= 0) AND (similarity_score <= 100))))
);


ALTER TABLE software_app.software_analogs OWNER TO postgres;

--
-- Name: software_analogs_software_analog_id_seq; Type: SEQUENCE; Schema: software_app; Owner: postgres
--

ALTER TABLE software_app.software_analogs ALTER COLUMN software_analog_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME software_app.software_analogs_software_analog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: software_software_id_seq; Type: SEQUENCE; Schema: software_app; Owner: postgres
--

ALTER TABLE software_app.software ALTER COLUMN software_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME software_app.software_software_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: users; Type: TABLE; Schema: software_app; Owner: postgres
--

CREATE TABLE software_app.users (
    user_id bigint NOT NULL,
    username character varying(100) NOT NULL,
    password_hash text NOT NULL,
    display_name character varying(150),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_login_at timestamp with time zone,
    CONSTRAINT ck_users_password_hash_not_blank CHECK ((length(password_hash) >= 20)),
    CONSTRAINT ck_users_username_not_blank CHECK ((length(TRIM(BOTH FROM username)) >= 3))
);


ALTER TABLE software_app.users OWNER TO postgres;

--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: software_app; Owner: postgres
--

ALTER TABLE software_app.users ALTER COLUMN user_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME software_app.users_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: software_app; Owner: postgres
--

INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (1, 'categories', 'I', '{"category_id": 1}', NULL, '{"name": "Офисные пакеты", "created_at": "2026-06-01T01:46:10.063217+03:00", "updated_at": "2026-06-01T01:46:10.063217+03:00", "category_id": 1, "description": "Программы для работы с документами"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (2, 'categories', 'I', '{"category_id": 2}', NULL, '{"name": "Графические редакторы", "created_at": "2026-06-01T01:46:10.063217+03:00", "updated_at": "2026-06-01T01:46:10.063217+03:00", "category_id": 2, "description": "Программы для обработки изображений"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (3, 'categories', 'I', '{"category_id": 3}', NULL, '{"name": "Браузеры", "created_at": "2026-06-01T01:46:10.063217+03:00", "updated_at": "2026-06-01T01:46:10.063217+03:00", "category_id": 3, "description": "Программы для просмотра веб-страниц"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (4, 'developers', 'I', '{"developer_id": 1}', NULL, '{"name": "Microsoft", "website": "https://www.microsoft.com", "created_at": "2026-06-01T01:46:10.063217+03:00", "updated_at": "2026-06-01T01:46:10.063217+03:00", "developer_id": 1}', NULL, 'postgres', '127.0.0.1', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (5, 'developers', 'I', '{"developer_id": 2}', NULL, '{"name": "The Document Foundation", "website": "https://www.documentfoundation.org", "created_at": "2026-06-01T01:46:10.063217+03:00", "updated_at": "2026-06-01T01:46:10.063217+03:00", "developer_id": 2}', NULL, 'postgres', '127.0.0.1', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (6, 'developers', 'I', '{"developer_id": 3}', NULL, '{"name": "Mozilla", "website": "https://www.mozilla.org", "created_at": "2026-06-01T01:46:10.063217+03:00", "updated_at": "2026-06-01T01:46:10.063217+03:00", "developer_id": 3}', NULL, 'postgres', '127.0.0.1', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (7, 'users', 'I', '{"user_id": 1}', NULL, '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": null}', NULL, 'postgres', '127.0.0.1', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (8, 'software', 'I', '{"software_id": 1}', NULL, '{"title": "LibreOffice", "is_free": true, "size_mb": 350.00, "website": "https://www.libreoffice.org", "created_at": "2026-06-01T01:46:10.063217+03:00", "category_id": 1, "description": "Свободный офисный пакет", "software_id": 1, "developer_id": 2, "last_updated_at": "2026-06-01T01:46:10.063217+03:00", "system_requirements": "Windows/Linux/macOS, 2 GB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (9, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": null}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T01:46:53.623586+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-01 01:46:53.623586+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (10, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T01:46:53.623586+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T02:12:53.179671+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-01 02:12:53.179671+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (11, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T02:12:53.179671+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T02:13:34.058059+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-01 02:13:34.058059+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (12, 'reviews', 'I', '{"review_id": 1}', NULL, '{"rating": 5, "user_id": 1, "review_id": 1, "created_at": "2026-06-01T02:13:34.075793+03:00", "updated_at": "2026-06-01T02:13:34.075793+03:00", "author_name": "Пользователь", "review_text": "Smoke review", "software_id": 1}', 1, 'software_app', '127.0.0.1', '2026-06-01 02:13:34.075793+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (13, 'collections', 'I', '{"collection_id": 1}', NULL, '{"title": "Smoke collection", "user_id": 1, "created_at": "2026-06-01T02:13:34.077531+03:00", "updated_at": "2026-06-01T02:13:34.077531+03:00", "description": "Temporary smoke collection", "collection_id": 1}', 1, 'software_app', '127.0.0.1', '2026-06-01 02:13:34.077531+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (14, 'collection_items', 'I', '{"collection_item_id": 1}', NULL, '{"note": "Smoke note", "added_at": "2026-06-01T02:13:34.078983+03:00", "position": null, "software_id": 1, "collection_id": 1, "collection_item_id": 1}', 1, 'software_app', '127.0.0.1', '2026-06-01 02:13:34.078983+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (15, 'collections', 'D', '{"collection_id": 1}', '{"title": "Smoke collection", "user_id": 1, "created_at": "2026-06-01T02:13:34.077531+03:00", "updated_at": "2026-06-01T02:13:34.077531+03:00", "description": "Temporary smoke collection", "collection_id": 1}', NULL, 1, 'software_app', '127.0.0.1', '2026-06-01 02:13:34.08079+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (16, 'collection_items', 'D', '{"collection_item_id": 1}', '{"note": "Smoke note", "added_at": "2026-06-01T02:13:34.078983+03:00", "position": null, "software_id": 1, "collection_id": 1, "collection_item_id": 1}', NULL, 1, 'software_app', '127.0.0.1', '2026-06-01 02:13:34.08079+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (17, 'reviews', 'D', '{"review_id": 1}', '{"rating": 5, "user_id": 1, "review_id": 1, "created_at": "2026-06-01T02:13:34.075793+03:00", "updated_at": "2026-06-01T02:13:34.075793+03:00", "author_name": "Пользователь", "review_text": "Smoke review", "software_id": 1}', NULL, NULL, 'postgres', '127.0.0.1', '2026-06-01 02:28:48.917899+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (49, 'categories', 'I', '{"category_id": 13}', NULL, '{"name": "Среды разработки", "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 13, "description": "Инструменты для разработки программного обеспечения"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (18, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T02:13:34.058059+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T02:35:09.186134+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-01 02:35:09.186134+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (19, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T02:35:09.186134+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T02:35:34.828117+03:00"}', 1, 'software_app', '127.0.0.1', '2026-06-01 02:35:34.828117+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (20, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T02:35:34.828117+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T02:40:23.761008+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-01 02:40:23.761008+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (50, 'categories', 'I', '{"category_id": 14}', NULL, '{"name": "Антивирусы", "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 14, "description": "Программы для защиты компьютера"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (51, 'categories', 'I', '{"category_id": 15}', NULL, '{"name": "Архиваторы", "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 15, "description": "Программы для работы с архивами"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (52, 'developers', 'I', '{"developer_id": 20}', NULL, '{"name": "Google", "website": "https://www.google.com", "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "developer_id": 20}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (53, 'developers', 'I', '{"developer_id": 21}', NULL, '{"name": "Adobe", "website": "https://www.adobe.com", "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "developer_id": 21}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (54, 'developers', 'I', '{"developer_id": 22}', NULL, '{"name": "The GIMP Team", "website": "https://www.gimp.org", "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "developer_id": 22}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (55, 'developers', 'I', '{"developer_id": 23}', NULL, '{"name": "KDE", "website": "https://kde.org", "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "developer_id": 23}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (56, 'developers', 'I', '{"developer_id": 24}', NULL, '{"name": "JetBrains", "website": "https://www.jetbrains.com", "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "developer_id": 24}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (57, 'developers', 'I', '{"developer_id": 25}', NULL, '{"name": "Eclipse Foundation", "website": "https://www.eclipse.org", "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "developer_id": 25}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (58, 'developers', 'I', '{"developer_id": 26}', NULL, '{"name": "Igor Pavlov", "website": "https://www.7-zip.org", "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "developer_id": 26}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (59, 'developers', 'I', '{"developer_id": 27}', NULL, '{"name": "RARLAB", "website": "https://www.rarlab.com", "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "developer_id": 27}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (60, 'developers', 'I', '{"developer_id": 28}', NULL, '{"name": "Kaspersky", "website": "https://www.kaspersky.ru", "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "developer_id": 28}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (61, 'developers', 'I', '{"developer_id": 29}', NULL, '{"name": "Avast", "website": "https://www.avast.com", "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "developer_id": 29}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (62, 'software', 'I', '{"software_id": 17}', NULL, '{"title": "Google Docs", "is_free": true, "size_mb": 0.00, "website": "https://docs.google.com", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 1, "description": "Веб-сервис для совместной работы с документами", "software_id": 17, "developer_id": 20, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Современный браузер, подключение к интернету"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (63, 'software', 'I', '{"software_id": 18}', NULL, '{"title": "Microsoft Office", "is_free": false, "size_mb": 4500.00, "website": "https://www.microsoft.com/microsoft-365", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 1, "description": "Коммерческий офисный пакет для документов, таблиц и презентаций", "software_id": 18, "developer_id": 1, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows/macOS, 4 GB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (64, 'software', 'I', '{"software_id": 19}', NULL, '{"title": "Krita", "is_free": true, "size_mb": 250.00, "website": "https://krita.org", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 2, "description": "Свободная программа для цифровой живописи и иллюстрации", "software_id": 19, "developer_id": 23, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows/Linux/macOS, 4 GB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (65, 'software', 'I', '{"software_id": 20}', NULL, '{"title": "GIMP", "is_free": true, "size_mb": 300.00, "website": "https://www.gimp.org", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 2, "description": "Свободный графический редактор растровой графики", "software_id": 20, "developer_id": 22, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows/Linux/macOS, 2 GB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (66, 'software', 'I', '{"software_id": 21}', NULL, '{"title": "Adobe Photoshop", "is_free": false, "size_mb": 3500.00, "website": "https://www.adobe.com/products/photoshop.html", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 2, "description": "Профессиональный графический редактор", "software_id": 21, "developer_id": 21, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows/macOS, 8 GB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (67, 'software', 'I', '{"software_id": 22}', NULL, '{"title": "Google Chrome", "is_free": true, "size_mb": 250.00, "website": "https://www.google.com/chrome", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 3, "description": "Популярный веб-браузер на базе Chromium", "software_id": 22, "developer_id": 20, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows/Linux/macOS, 2 GB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (68, 'software', 'I', '{"software_id": 23}', NULL, '{"title": "Mozilla Firefox", "is_free": true, "size_mb": 220.00, "website": "https://www.mozilla.org/firefox", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 3, "description": "Свободный веб-браузер с поддержкой расширений", "software_id": 23, "developer_id": 3, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows/Linux/macOS, 2 GB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (69, 'software', 'I', '{"software_id": 24}', NULL, '{"title": "Microsoft Edge", "is_free": true, "size_mb": 240.00, "website": "https://www.microsoft.com/edge", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 3, "description": "Браузер Microsoft на базе Chromium", "software_id": 24, "developer_id": 1, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows/macOS/Linux, 2 GB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (70, 'software', 'I', '{"software_id": 25}', NULL, '{"title": "Eclipse IDE", "is_free": true, "size_mb": 900.00, "website": "https://www.eclipse.org/ide", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 13, "description": "Расширяемая среда разработки", "software_id": 25, "developer_id": 25, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows/Linux/macOS, 4 GB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (71, 'software', 'I', '{"software_id": 26}', NULL, '{"title": "IntelliJ IDEA Community", "is_free": true, "size_mb": 1500.00, "website": "https://www.jetbrains.com/idea", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 13, "description": "Свободная IDE для Java и Kotlin", "software_id": 26, "developer_id": 24, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows/Linux/macOS, 8 GB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (72, 'software', 'I', '{"software_id": 27}', NULL, '{"title": "Visual Studio Code", "is_free": true, "size_mb": 350.00, "website": "https://code.visualstudio.com", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 13, "description": "Легкий редактор кода с расширениями", "software_id": 27, "developer_id": 1, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows/Linux/macOS, 2 GB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (73, 'software', 'I', '{"software_id": 28}', NULL, '{"title": "Avast Free Antivirus", "is_free": true, "size_mb": 1200.00, "website": "https://www.avast.com", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 14, "description": "Бесплатный антивирус для базовой защиты", "software_id": 28, "developer_id": 29, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows/macOS, 2 GB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (74, 'software', 'I', '{"software_id": 29}', NULL, '{"title": "Kaspersky Anti-Virus", "is_free": false, "size_mb": 1500.00, "website": "https://www.kaspersky.ru", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 14, "description": "Антивирусная защита для персональных компьютеров", "software_id": 29, "developer_id": 28, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows, 2 GB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (75, 'software', 'I', '{"software_id": 30}', NULL, '{"title": "WinRAR", "is_free": false, "size_mb": 10.00, "website": "https://www.rarlab.com", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 15, "description": "Коммерческий архиватор с поддержкой RAR и ZIP", "software_id": 30, "developer_id": 27, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows, 512 MB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (76, 'software', 'I', '{"software_id": 31}', NULL, '{"title": "7-Zip", "is_free": true, "size_mb": 20.00, "website": "https://www.7-zip.org", "created_at": "2026-06-01T02:47:03.95314+03:00", "category_id": 15, "description": "Свободный архиватор с высокой степенью сжатия", "software_id": 31, "developer_id": 26, "last_updated_at": "2026-06-01T02:47:03.95314+03:00", "system_requirements": "Windows/Linux, 512 MB RAM"}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (77, 'software_analogs', 'I', '{"software_analog_id": 1}', NULL, '{"reason": "Офисные документы и совместная работа", "analog_id": 17, "created_at": "2026-06-01T02:47:03.95314+03:00", "software_id": 1, "similarity_score": 78, "software_analog_id": 1}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (78, 'software_analogs', 'I', '{"software_analog_id": 2}', NULL, '{"reason": "Оба продукта используются для работы с документами, таблицами и презентациями", "analog_id": 18, "created_at": "2026-06-01T02:47:03.95314+03:00", "software_id": 1, "similarity_score": 90, "software_analog_id": 2}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (79, 'software_analogs', 'I', '{"software_analog_id": 3}', NULL, '{"reason": "Свободные графические редакторы", "analog_id": 19, "created_at": "2026-06-01T02:47:03.95314+03:00", "software_id": 20, "similarity_score": 70, "software_analog_id": 3}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (80, 'software_analogs', 'I', '{"software_analog_id": 4}', NULL, '{"reason": "Редактирование растровых изображений", "analog_id": 21, "created_at": "2026-06-01T02:47:03.95314+03:00", "software_id": 20, "similarity_score": 82, "software_analog_id": 4}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (81, 'software_analogs', 'I', '{"software_analog_id": 5}', NULL, '{"reason": "Веб-браузеры общего назначения", "analog_id": 22, "created_at": "2026-06-01T02:47:03.95314+03:00", "software_id": 23, "similarity_score": 88, "software_analog_id": 5}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (82, 'software_analogs', 'I', '{"software_analog_id": 6}', NULL, '{"reason": "Браузеры на базе Chromium", "analog_id": 24, "created_at": "2026-06-01T02:47:03.95314+03:00", "software_id": 22, "similarity_score": 92, "software_analog_id": 6}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (83, 'software_analogs', 'I', '{"software_analog_id": 7}', NULL, '{"reason": "Инструменты для разработки программного обеспечения", "analog_id": 26, "created_at": "2026-06-01T02:47:03.95314+03:00", "software_id": 27, "similarity_score": 68, "software_analog_id": 7}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (84, 'software_analogs', 'I', '{"software_analog_id": 8}', NULL, '{"reason": "Антивирусные решения для защиты компьютера", "analog_id": 28, "created_at": "2026-06-01T02:47:03.95314+03:00", "software_id": 29, "similarity_score": 75, "software_analog_id": 8}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (85, 'software_analogs', 'I', '{"software_analog_id": 9}', NULL, '{"reason": "Архиваторы для сжатия и распаковки файлов", "analog_id": 30, "created_at": "2026-06-01T02:47:03.95314+03:00", "software_id": 31, "similarity_score": 85, "software_analog_id": 9}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (86, 'reviews', 'I', '{"review_id": 2}', NULL, '{"rating": 5, "user_id": 1, "review_id": 2, "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "author_name": "Пользователь", "review_text": "Удобный свободный офисный пакет для учебы и дома.", "software_id": 1}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (87, 'reviews', 'I', '{"review_id": 3}', NULL, '{"rating": 4, "user_id": 1, "review_id": 3, "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "author_name": "Пользователь", "review_text": "Хорошая бесплатная альтернатива Photoshop для базовой обработки изображений.", "software_id": 20}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (88, 'reviews', 'I', '{"review_id": 4}', NULL, '{"rating": 5, "user_id": 1, "review_id": 4, "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "author_name": "Пользователь", "review_text": "Быстрый редактор кода, удобно расширяется плагинами.", "software_id": 27}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (89, 'reviews', 'I', '{"review_id": 5}', NULL, '{"rating": 5, "user_id": 1, "review_id": 5, "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "author_name": "Пользователь", "review_text": "Простой и надежный архиватор.", "software_id": 31}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (90, 'reviews', 'I', '{"review_id": 6}', NULL, '{"rating": 5, "user_id": 1, "review_id": 6, "created_at": "2026-06-01T02:47:03.95314+03:00", "updated_at": "2026-06-01T02:47:03.95314+03:00", "author_name": "Пользователь", "review_text": "Гибкий браузер с большим количеством расширений.", "software_id": 23}', NULL, 'postgres', '127.0.0.1', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (91, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T02:40:23.761008+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T02:50:25.117466+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-01 02:50:25.117466+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (92, 'collections', 'I', '{"collection_id": 2}', NULL, '{"title": "браузеры", "user_id": 1, "created_at": "2026-06-01T02:51:57.085096+03:00", "updated_at": "2026-06-01T02:51:57.085096+03:00", "description": null, "collection_id": 2}', 1, 'software_app', '127.0.0.1', '2026-06-01 02:51:57.085096+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (93, 'collection_items', 'I', '{"collection_item_id": 2}', NULL, '{"note": null, "added_at": "2026-06-01T02:52:33.990601+03:00", "position": null, "software_id": 24, "collection_id": 2, "collection_item_id": 2}', 1, 'software_app', '127.0.0.1', '2026-06-01 02:52:33.990601+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (94, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-01T02:50:25.117466+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T20:25:14.582888+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-04 20:25:14.582888+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (95, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T20:25:14.582888+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T20:28:07.822457+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-04 20:28:07.822457+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (96, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T20:28:07.822457+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T20:28:59.296992+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-04 20:28:59.296992+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (97, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T20:28:59.296992+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T20:35:31.845506+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-04 20:35:31.845506+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (98, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T20:35:31.845506+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T20:39:50.089113+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-04 20:39:50.089113+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (99, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T20:39:50.089113+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T20:41:48.261204+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-04 20:41:48.261204+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (100, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T20:41:48.261204+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T22:24:20.791843+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-04 22:24:20.791843+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (101, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T22:24:20.791843+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T22:25:23.434726+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-04 22:25:23.434726+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (102, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T22:25:23.434726+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T22:25:44.557502+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-04 22:25:44.557502+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (103, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T22:25:44.557502+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T22:27:31.982031+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-04 22:27:31.982031+03');
INSERT INTO software_app.audit_log (audit_id, table_name, operation, row_pk, old_data, new_data, app_user_id, db_user, client_addr, changed_at) OVERRIDING SYSTEM VALUE VALUES (104, 'users', 'U', '{"user_id": 1}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T22:27:31.982031+03:00"}', '{"user_id": 1, "username": "user", "is_active": true, "created_at": "2026-06-01T01:46:10.063217+03:00", "display_name": "Пользователь", "last_login_at": "2026-06-04T22:28:26.495476+03:00"}', NULL, 'software_app', '127.0.0.1', '2026-06-04 22:28:26.495476+03');


--
-- Data for Name: categories; Type: TABLE DATA; Schema: software_app; Owner: postgres
--

INSERT INTO software_app.categories (category_id, name, description, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (1, 'Офисные пакеты', 'Программы для работы с документами', '2026-06-01 01:46:10.063217+03', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.categories (category_id, name, description, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (2, 'Графические редакторы', 'Программы для обработки изображений', '2026-06-01 01:46:10.063217+03', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.categories (category_id, name, description, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (3, 'Браузеры', 'Программы для просмотра веб-страниц', '2026-06-01 01:46:10.063217+03', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.categories (category_id, name, description, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (13, 'Среды разработки', 'Инструменты для разработки программного обеспечения', '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.categories (category_id, name, description, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (14, 'Антивирусы', 'Программы для защиты компьютера', '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.categories (category_id, name, description, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (15, 'Архиваторы', 'Программы для работы с архивами', '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');


--
-- Data for Name: category_translations; Type: TABLE DATA; Schema: software_app; Owner: postgres
--

INSERT INTO software_app.category_translations (category_translation_id, category_id, locale, name, description) OVERRIDING SYSTEM VALUE VALUES (1, 1, 'en', 'Office Suites', 'Software for working with documents');
INSERT INTO software_app.category_translations (category_translation_id, category_id, locale, name, description) OVERRIDING SYSTEM VALUE VALUES (2, 2, 'en', 'Graphics Editors', 'Image processing software');
INSERT INTO software_app.category_translations (category_translation_id, category_id, locale, name, description) OVERRIDING SYSTEM VALUE VALUES (3, 3, 'en', 'Browsers', 'Web browsing software');
INSERT INTO software_app.category_translations (category_translation_id, category_id, locale, name, description) OVERRIDING SYSTEM VALUE VALUES (4, 13, 'en', 'Development Environments', 'Software development tools');
INSERT INTO software_app.category_translations (category_translation_id, category_id, locale, name, description) OVERRIDING SYSTEM VALUE VALUES (5, 14, 'en', 'Antiviruses', 'Computer security software');
INSERT INTO software_app.category_translations (category_translation_id, category_id, locale, name, description) OVERRIDING SYSTEM VALUE VALUES (6, 15, 'en', 'Archivers', 'Archive management software');


--
-- Data for Name: collection_items; Type: TABLE DATA; Schema: software_app; Owner: postgres
--

INSERT INTO software_app.collection_items (collection_item_id, collection_id, software_id, note, "position", added_at) OVERRIDING SYSTEM VALUE VALUES (2, 2, 24, NULL, NULL, '2026-06-01 02:52:33.990601+03');


--
-- Data for Name: collections; Type: TABLE DATA; Schema: software_app; Owner: postgres
--

INSERT INTO software_app.collections (collection_id, user_id, title, description, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (2, 1, 'браузеры', NULL, '2026-06-01 02:51:57.085096+03', '2026-06-01 02:51:57.085096+03');


--
-- Data for Name: developers; Type: TABLE DATA; Schema: software_app; Owner: postgres
--

INSERT INTO software_app.developers (developer_id, name, website, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (1, 'Microsoft', 'https://www.microsoft.com', '2026-06-01 01:46:10.063217+03', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.developers (developer_id, name, website, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (2, 'The Document Foundation', 'https://www.documentfoundation.org', '2026-06-01 01:46:10.063217+03', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.developers (developer_id, name, website, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (3, 'Mozilla', 'https://www.mozilla.org', '2026-06-01 01:46:10.063217+03', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.developers (developer_id, name, website, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (20, 'Google', 'https://www.google.com', '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.developers (developer_id, name, website, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (21, 'Adobe', 'https://www.adobe.com', '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.developers (developer_id, name, website, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (22, 'The GIMP Team', 'https://www.gimp.org', '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.developers (developer_id, name, website, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (23, 'KDE', 'https://kde.org', '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.developers (developer_id, name, website, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (24, 'JetBrains', 'https://www.jetbrains.com', '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.developers (developer_id, name, website, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (25, 'Eclipse Foundation', 'https://www.eclipse.org', '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.developers (developer_id, name, website, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (26, 'Igor Pavlov', 'https://www.7-zip.org', '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.developers (developer_id, name, website, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (27, 'RARLAB', 'https://www.rarlab.com', '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.developers (developer_id, name, website, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (28, 'Kaspersky', 'https://www.kaspersky.ru', '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.developers (developer_id, name, website, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (29, 'Avast', 'https://www.avast.com', '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');


--
-- Data for Name: reviews; Type: TABLE DATA; Schema: software_app; Owner: postgres
--

INSERT INTO software_app.reviews (review_id, software_id, user_id, author_name, review_text, rating, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (2, 1, 1, 'Пользователь', 'Удобный свободный офисный пакет для учебы и дома.', 5, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.reviews (review_id, software_id, user_id, author_name, review_text, rating, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (3, 20, 1, 'Пользователь', 'Хорошая бесплатная альтернатива Photoshop для базовой обработки изображений.', 4, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.reviews (review_id, software_id, user_id, author_name, review_text, rating, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (4, 27, 1, 'Пользователь', 'Быстрый редактор кода, удобно расширяется плагинами.', 5, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.reviews (review_id, software_id, user_id, author_name, review_text, rating, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (5, 31, 1, 'Пользователь', 'Простой и надежный архиватор.', 5, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.reviews (review_id, software_id, user_id, author_name, review_text, rating, created_at, updated_at) OVERRIDING SYSTEM VALUE VALUES (6, 23, 1, 'Пользователь', 'Гибкий браузер с большим количеством расширений.', 5, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');


--
-- Data for Name: screenshots; Type: TABLE DATA; Schema: software_app; Owner: postgres
--



--
-- Data for Name: software; Type: TABLE DATA; Schema: software_app; Owner: postgres
--

INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (1, 'LibreOffice', 'Свободный офисный пакет', 'Windows/Linux/macOS, 2 GB RAM', 350.00, 'https://www.libreoffice.org', 1, 2, true, '2026-06-01 01:46:10.063217+03', '2026-06-01 01:46:10.063217+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (17, 'Google Docs', 'Веб-сервис для совместной работы с документами', 'Современный браузер, подключение к интернету', 0.00, 'https://docs.google.com', 1, 20, true, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (18, 'Microsoft Office', 'Коммерческий офисный пакет для документов, таблиц и презентаций', 'Windows/macOS, 4 GB RAM', 4500.00, 'https://www.microsoft.com/microsoft-365', 1, 1, false, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (19, 'Krita', 'Свободная программа для цифровой живописи и иллюстрации', 'Windows/Linux/macOS, 4 GB RAM', 250.00, 'https://krita.org', 2, 23, true, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (20, 'GIMP', 'Свободный графический редактор растровой графики', 'Windows/Linux/macOS, 2 GB RAM', 300.00, 'https://www.gimp.org', 2, 22, true, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (21, 'Adobe Photoshop', 'Профессиональный графический редактор', 'Windows/macOS, 8 GB RAM', 3500.00, 'https://www.adobe.com/products/photoshop.html', 2, 21, false, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (22, 'Google Chrome', 'Популярный веб-браузер на базе Chromium', 'Windows/Linux/macOS, 2 GB RAM', 250.00, 'https://www.google.com/chrome', 3, 20, true, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (23, 'Mozilla Firefox', 'Свободный веб-браузер с поддержкой расширений', 'Windows/Linux/macOS, 2 GB RAM', 220.00, 'https://www.mozilla.org/firefox', 3, 3, true, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (24, 'Microsoft Edge', 'Браузер Microsoft на базе Chromium', 'Windows/macOS/Linux, 2 GB RAM', 240.00, 'https://www.microsoft.com/edge', 3, 1, true, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (25, 'Eclipse IDE', 'Расширяемая среда разработки', 'Windows/Linux/macOS, 4 GB RAM', 900.00, 'https://www.eclipse.org/ide', 13, 25, true, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (26, 'IntelliJ IDEA Community', 'Свободная IDE для Java и Kotlin', 'Windows/Linux/macOS, 8 GB RAM', 1500.00, 'https://www.jetbrains.com/idea', 13, 24, true, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (27, 'Visual Studio Code', 'Легкий редактор кода с расширениями', 'Windows/Linux/macOS, 2 GB RAM', 350.00, 'https://code.visualstudio.com', 13, 1, true, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (28, 'Avast Free Antivirus', 'Бесплатный антивирус для базовой защиты', 'Windows/macOS, 2 GB RAM', 1200.00, 'https://www.avast.com', 14, 29, true, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (29, 'Kaspersky Anti-Virus', 'Антивирусная защита для персональных компьютеров', 'Windows, 2 GB RAM', 1500.00, 'https://www.kaspersky.ru', 14, 28, false, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (30, 'WinRAR', 'Коммерческий архиватор с поддержкой RAR и ZIP', 'Windows, 512 MB RAM', 10.00, 'https://www.rarlab.com', 15, 27, false, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software (software_id, title, description, system_requirements, size_mb, website, category_id, developer_id, is_free, created_at, last_updated_at) OVERRIDING SYSTEM VALUE VALUES (31, '7-Zip', 'Свободный архиватор с высокой степенью сжатия', 'Windows/Linux, 512 MB RAM', 20.00, 'https://www.7-zip.org', 15, 26, true, '2026-06-01 02:47:03.95314+03', '2026-06-01 02:47:03.95314+03');


--
-- Data for Name: software_analogs; Type: TABLE DATA; Schema: software_app; Owner: postgres
--

INSERT INTO software_app.software_analogs (software_analog_id, software_id, analog_id, reason, similarity_score, created_at) OVERRIDING SYSTEM VALUE VALUES (1, 1, 17, 'Офисные документы и совместная работа', 78, '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software_analogs (software_analog_id, software_id, analog_id, reason, similarity_score, created_at) OVERRIDING SYSTEM VALUE VALUES (2, 1, 18, 'Оба продукта используются для работы с документами, таблицами и презентациями', 90, '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software_analogs (software_analog_id, software_id, analog_id, reason, similarity_score, created_at) OVERRIDING SYSTEM VALUE VALUES (3, 20, 19, 'Свободные графические редакторы', 70, '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software_analogs (software_analog_id, software_id, analog_id, reason, similarity_score, created_at) OVERRIDING SYSTEM VALUE VALUES (4, 20, 21, 'Редактирование растровых изображений', 82, '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software_analogs (software_analog_id, software_id, analog_id, reason, similarity_score, created_at) OVERRIDING SYSTEM VALUE VALUES (5, 23, 22, 'Веб-браузеры общего назначения', 88, '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software_analogs (software_analog_id, software_id, analog_id, reason, similarity_score, created_at) OVERRIDING SYSTEM VALUE VALUES (6, 22, 24, 'Браузеры на базе Chromium', 92, '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software_analogs (software_analog_id, software_id, analog_id, reason, similarity_score, created_at) OVERRIDING SYSTEM VALUE VALUES (7, 27, 26, 'Инструменты для разработки программного обеспечения', 68, '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software_analogs (software_analog_id, software_id, analog_id, reason, similarity_score, created_at) OVERRIDING SYSTEM VALUE VALUES (8, 29, 28, 'Антивирусные решения для защиты компьютера', 75, '2026-06-01 02:47:03.95314+03');
INSERT INTO software_app.software_analogs (software_analog_id, software_id, analog_id, reason, similarity_score, created_at) OVERRIDING SYSTEM VALUE VALUES (9, 31, 30, 'Архиваторы для сжатия и распаковки файлов', 85, '2026-06-01 02:47:03.95314+03');


--
-- Data for Name: users; Type: TABLE DATA; Schema: software_app; Owner: postgres
--

INSERT INTO software_app.users (user_id, username, password_hash, display_name, is_active, created_at, last_login_at) OVERRIDING SYSTEM VALUE VALUES (1, 'user', '$2a$06$Ba/2TY4MKYffmcLSJgBsCuyNuJTC/QgosSAHNySem9PHejfFet/ja', 'Пользователь', true, '2026-06-01 01:46:10.063217+03', '2026-06-04 22:28:26.495476+03');


--
-- Name: audit_log_audit_id_seq; Type: SEQUENCE SET; Schema: software_app; Owner: postgres
--

SELECT pg_catalog.setval('software_app.audit_log_audit_id_seq', 104, true);


--
-- Name: categories_category_id_seq; Type: SEQUENCE SET; Schema: software_app; Owner: postgres
--

SELECT pg_catalog.setval('software_app.categories_category_id_seq', 15, true);


--
-- Name: category_translations_category_translation_id_seq; Type: SEQUENCE SET; Schema: software_app; Owner: postgres
--

SELECT pg_catalog.setval('software_app.category_translations_category_translation_id_seq', 12, true);


--
-- Name: collection_items_collection_item_id_seq; Type: SEQUENCE SET; Schema: software_app; Owner: postgres
--

SELECT pg_catalog.setval('software_app.collection_items_collection_item_id_seq', 2, true);


--
-- Name: collections_collection_id_seq; Type: SEQUENCE SET; Schema: software_app; Owner: postgres
--

SELECT pg_catalog.setval('software_app.collections_collection_id_seq', 2, true);


--
-- Name: developers_developer_id_seq; Type: SEQUENCE SET; Schema: software_app; Owner: postgres
--

SELECT pg_catalog.setval('software_app.developers_developer_id_seq', 29, true);


--
-- Name: reviews_review_id_seq; Type: SEQUENCE SET; Schema: software_app; Owner: postgres
--

SELECT pg_catalog.setval('software_app.reviews_review_id_seq', 6, true);


--
-- Name: screenshots_screenshot_id_seq; Type: SEQUENCE SET; Schema: software_app; Owner: postgres
--

SELECT pg_catalog.setval('software_app.screenshots_screenshot_id_seq', 1, false);


--
-- Name: software_analogs_software_analog_id_seq; Type: SEQUENCE SET; Schema: software_app; Owner: postgres
--

SELECT pg_catalog.setval('software_app.software_analogs_software_analog_id_seq', 9, true);


--
-- Name: software_software_id_seq; Type: SEQUENCE SET; Schema: software_app; Owner: postgres
--

SELECT pg_catalog.setval('software_app.software_software_id_seq', 31, true);


--
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: software_app; Owner: postgres
--

SELECT pg_catalog.setval('software_app.users_user_id_seq', 1, true);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (audit_id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (category_id);


--
-- Name: category_translations category_translations_pkey; Type: CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.category_translations
    ADD CONSTRAINT category_translations_pkey PRIMARY KEY (category_translation_id);


--
-- Name: collection_items collection_items_collection_item_id_key; Type: CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.collection_items
    ADD CONSTRAINT collection_items_collection_item_id_key UNIQUE (collection_item_id);


--
-- Name: collection_items collection_items_pkey; Type: CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.collection_items
    ADD CONSTRAINT collection_items_pkey PRIMARY KEY (collection_id, software_id);


--
-- Name: collections collections_pkey; Type: CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.collections
    ADD CONSTRAINT collections_pkey PRIMARY KEY (collection_id);


--
-- Name: developers developers_pkey; Type: CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.developers
    ADD CONSTRAINT developers_pkey PRIMARY KEY (developer_id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (review_id);


--
-- Name: screenshots screenshots_pkey; Type: CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.screenshots
    ADD CONSTRAINT screenshots_pkey PRIMARY KEY (screenshot_id);


--
-- Name: software_analogs software_analogs_pkey; Type: CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.software_analogs
    ADD CONSTRAINT software_analogs_pkey PRIMARY KEY (software_analog_id);


--
-- Name: software software_pkey; Type: CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.software
    ADD CONSTRAINT software_pkey PRIMARY KEY (software_id);


--
-- Name: category_translations uk_category_translations_category_locale; Type: CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.category_translations
    ADD CONSTRAINT uk_category_translations_category_locale UNIQUE (category_id, locale);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: ix_category_translations_locale; Type: INDEX; Schema: software_app; Owner: postgres
--

CREATE INDEX ix_category_translations_locale ON software_app.category_translations USING btree (locale);


--
-- Name: ix_software_category_id; Type: INDEX; Schema: software_app; Owner: postgres
--

CREATE INDEX ix_software_category_id ON software_app.software USING btree (category_id);


--
-- Name: ix_software_developer_id; Type: INDEX; Schema: software_app; Owner: postgres
--

CREATE INDEX ix_software_developer_id ON software_app.software USING btree (developer_id);


--
-- Name: ix_software_title_lower; Type: INDEX; Schema: software_app; Owner: postgres
--

CREATE INDEX ix_software_title_lower ON software_app.software USING btree (lower((title)::text));


--
-- Name: ux_categories_name_lower; Type: INDEX; Schema: software_app; Owner: postgres
--

CREATE UNIQUE INDEX ux_categories_name_lower ON software_app.categories USING btree (lower((name)::text));


--
-- Name: ux_collections_user_title_lower; Type: INDEX; Schema: software_app; Owner: postgres
--

CREATE UNIQUE INDEX ux_collections_user_title_lower ON software_app.collections USING btree (user_id, lower((title)::text));


--
-- Name: ux_developers_name_lower; Type: INDEX; Schema: software_app; Owner: postgres
--

CREATE UNIQUE INDEX ux_developers_name_lower ON software_app.developers USING btree (lower((name)::text));


--
-- Name: ux_software_analogs_pair; Type: INDEX; Schema: software_app; Owner: postgres
--

CREATE UNIQUE INDEX ux_software_analogs_pair ON software_app.software_analogs USING btree (LEAST(software_id, analog_id), GREATEST(software_id, analog_id));


--
-- Name: ux_users_username_lower; Type: INDEX; Schema: software_app; Owner: postgres
--

CREATE UNIQUE INDEX ux_users_username_lower ON software_app.users USING btree (lower((username)::text));


--
-- Name: categories audit_categories; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER audit_categories AFTER INSERT OR DELETE OR UPDATE ON software_app.categories FOR EACH ROW EXECUTE FUNCTION software_app.audit_row_change('category_id');


--
-- Name: collection_items audit_collection_items; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER audit_collection_items AFTER INSERT OR DELETE OR UPDATE ON software_app.collection_items FOR EACH ROW EXECUTE FUNCTION software_app.audit_row_change('collection_item_id');


--
-- Name: collections audit_collections; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER audit_collections AFTER INSERT OR DELETE OR UPDATE ON software_app.collections FOR EACH ROW EXECUTE FUNCTION software_app.audit_row_change('collection_id');


--
-- Name: developers audit_developers; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER audit_developers AFTER INSERT OR DELETE OR UPDATE ON software_app.developers FOR EACH ROW EXECUTE FUNCTION software_app.audit_row_change('developer_id');


--
-- Name: reviews audit_reviews; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER audit_reviews AFTER INSERT OR DELETE OR UPDATE ON software_app.reviews FOR EACH ROW EXECUTE FUNCTION software_app.audit_row_change('review_id');


--
-- Name: screenshots audit_screenshots; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER audit_screenshots AFTER INSERT OR DELETE OR UPDATE ON software_app.screenshots FOR EACH ROW EXECUTE FUNCTION software_app.audit_row_change('screenshot_id');


--
-- Name: software audit_software; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER audit_software AFTER INSERT OR DELETE OR UPDATE ON software_app.software FOR EACH ROW EXECUTE FUNCTION software_app.audit_row_change('software_id');


--
-- Name: software_analogs audit_software_analogs; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER audit_software_analogs AFTER INSERT OR DELETE OR UPDATE ON software_app.software_analogs FOR EACH ROW EXECUTE FUNCTION software_app.audit_row_change('software_analog_id');


--
-- Name: users audit_users; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER audit_users AFTER INSERT OR DELETE OR UPDATE ON software_app.users FOR EACH ROW EXECUTE FUNCTION software_app.audit_row_change('user_id');


--
-- Name: categories touch_categories_updated_at; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER touch_categories_updated_at BEFORE UPDATE ON software_app.categories FOR EACH ROW EXECUTE FUNCTION software_app.touch_updated_at();


--
-- Name: collections touch_collections_updated_at; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER touch_collections_updated_at BEFORE UPDATE ON software_app.collections FOR EACH ROW EXECUTE FUNCTION software_app.touch_updated_at();


--
-- Name: developers touch_developers_updated_at; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER touch_developers_updated_at BEFORE UPDATE ON software_app.developers FOR EACH ROW EXECUTE FUNCTION software_app.touch_updated_at();


--
-- Name: reviews touch_reviews_updated_at; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER touch_reviews_updated_at BEFORE UPDATE ON software_app.reviews FOR EACH ROW EXECUTE FUNCTION software_app.touch_updated_at();


--
-- Name: software touch_software_updated_at; Type: TRIGGER; Schema: software_app; Owner: postgres
--

CREATE TRIGGER touch_software_updated_at BEFORE UPDATE ON software_app.software FOR EACH ROW EXECUTE FUNCTION software_app.touch_updated_at();


--
-- Name: category_translations category_translations_category_id_fkey; Type: FK CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.category_translations
    ADD CONSTRAINT category_translations_category_id_fkey FOREIGN KEY (category_id) REFERENCES software_app.categories(category_id) ON DELETE CASCADE;


--
-- Name: collection_items collection_items_collection_id_fkey; Type: FK CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.collection_items
    ADD CONSTRAINT collection_items_collection_id_fkey FOREIGN KEY (collection_id) REFERENCES software_app.collections(collection_id) ON DELETE CASCADE;


--
-- Name: collection_items collection_items_software_id_fkey; Type: FK CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.collection_items
    ADD CONSTRAINT collection_items_software_id_fkey FOREIGN KEY (software_id) REFERENCES software_app.software(software_id) ON DELETE CASCADE;


--
-- Name: collections collections_user_id_fkey; Type: FK CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.collections
    ADD CONSTRAINT collections_user_id_fkey FOREIGN KEY (user_id) REFERENCES software_app.users(user_id) ON DELETE CASCADE;


--
-- Name: reviews reviews_software_id_fkey; Type: FK CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.reviews
    ADD CONSTRAINT reviews_software_id_fkey FOREIGN KEY (software_id) REFERENCES software_app.software(software_id) ON DELETE CASCADE;


--
-- Name: reviews reviews_user_id_fkey; Type: FK CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.reviews
    ADD CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES software_app.users(user_id) ON DELETE SET NULL;


--
-- Name: screenshots screenshots_software_id_fkey; Type: FK CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.screenshots
    ADD CONSTRAINT screenshots_software_id_fkey FOREIGN KEY (software_id) REFERENCES software_app.software(software_id) ON DELETE CASCADE;


--
-- Name: software_analogs software_analogs_analog_id_fkey; Type: FK CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.software_analogs
    ADD CONSTRAINT software_analogs_analog_id_fkey FOREIGN KEY (analog_id) REFERENCES software_app.software(software_id) ON DELETE CASCADE;


--
-- Name: software_analogs software_analogs_software_id_fkey; Type: FK CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.software_analogs
    ADD CONSTRAINT software_analogs_software_id_fkey FOREIGN KEY (software_id) REFERENCES software_app.software(software_id) ON DELETE CASCADE;


--
-- Name: software software_category_id_fkey; Type: FK CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.software
    ADD CONSTRAINT software_category_id_fkey FOREIGN KEY (category_id) REFERENCES software_app.categories(category_id) ON DELETE RESTRICT;


--
-- Name: software software_developer_id_fkey; Type: FK CONSTRAINT; Schema: software_app; Owner: postgres
--

ALTER TABLE ONLY software_app.software
    ADD CONSTRAINT software_developer_id_fkey FOREIGN KEY (developer_id) REFERENCES software_app.developers(developer_id) ON DELETE SET NULL;


--
-- Name: SCHEMA software_app; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA software_app TO software_app;


--
-- Name: FUNCTION add_collection_item(p_collection_id bigint, p_software_id bigint, p_note text, p_position integer); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.add_collection_item(p_collection_id bigint, p_software_id bigint, p_note text, p_position integer) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.add_collection_item(p_collection_id bigint, p_software_id bigint, p_note text, p_position integer) TO software_app;


--
-- Name: FUNCTION add_review(p_software_id bigint, p_review_text text, p_rating smallint); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.add_review(p_software_id bigint, p_review_text text, p_rating smallint) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.add_review(p_software_id bigint, p_review_text text, p_rating smallint) TO software_app;


--
-- Name: FUNCTION add_software(p_title text, p_description text, p_system_requirements text, p_size_mb numeric, p_website text, p_category_id bigint, p_developer_id bigint, p_is_free boolean); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.add_software(p_title text, p_description text, p_system_requirements text, p_size_mb numeric, p_website text, p_category_id bigint, p_developer_id bigint, p_is_free boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.add_software(p_title text, p_description text, p_system_requirements text, p_size_mb numeric, p_website text, p_category_id bigint, p_developer_id bigint, p_is_free boolean) TO software_app;


--
-- Name: PROCEDURE add_software_analog(IN p_software_id bigint, IN p_analog_id bigint, IN p_reason text, IN p_similarity_score smallint); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON PROCEDURE software_app.add_software_analog(IN p_software_id bigint, IN p_analog_id bigint, IN p_reason text, IN p_similarity_score smallint) FROM PUBLIC;
GRANT ALL ON PROCEDURE software_app.add_software_analog(IN p_software_id bigint, IN p_analog_id bigint, IN p_reason text, IN p_similarity_score smallint) TO software_app;


--
-- Name: FUNCTION audit_row_change(); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.audit_row_change() FROM PUBLIC;


--
-- Name: FUNCTION authenticate_user(p_username text, p_password text); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.authenticate_user(p_username text, p_password text) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.authenticate_user(p_username text, p_password text) TO software_app;


--
-- Name: FUNCTION create_app_user(p_username text, p_password text, p_display_name text); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.create_app_user(p_username text, p_password text, p_display_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.create_app_user(p_username text, p_password text, p_display_name text) TO software_app;


--
-- Name: FUNCTION create_collection(p_title text, p_description text); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.create_collection(p_title text, p_description text) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.create_collection(p_title text, p_description text) TO software_app;


--
-- Name: FUNCTION current_app_user_id(); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.current_app_user_id() FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.current_app_user_id() TO software_app;


--
-- Name: FUNCTION delete_collection(p_collection_id bigint); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.delete_collection(p_collection_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.delete_collection(p_collection_id bigint) TO software_app;


--
-- Name: FUNCTION delete_software(p_software_id bigint); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.delete_software(p_software_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.delete_software(p_software_id bigint) TO software_app;


--
-- Name: FUNCTION list_collection_items(p_collection_id bigint); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.list_collection_items(p_collection_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.list_collection_items(p_collection_id bigint) TO software_app;


--
-- Name: FUNCTION list_collections(); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.list_collections() FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.list_collections() TO software_app;


--
-- Name: FUNCTION list_reviews(p_software_id bigint); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.list_reviews(p_software_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.list_reviews(p_software_id bigint) TO software_app;


--
-- Name: FUNCTION list_software_analogs(p_software_id bigint); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.list_software_analogs(p_software_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.list_software_analogs(p_software_id bigint) TO software_app;


--
-- Name: FUNCTION remove_collection_item(p_collection_id bigint, p_software_id bigint); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.remove_collection_item(p_collection_id bigint, p_software_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.remove_collection_item(p_collection_id bigint, p_software_id bigint) TO software_app;


--
-- Name: FUNCTION remove_software_analog(p_software_id bigint, p_analog_id bigint); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.remove_software_analog(p_software_id bigint, p_analog_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.remove_software_analog(p_software_id bigint, p_analog_id bigint) TO software_app;


--
-- Name: FUNCTION touch_updated_at(); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.touch_updated_at() FROM PUBLIC;


--
-- Name: FUNCTION update_software(p_software_id bigint, p_title text, p_description text, p_system_requirements text, p_size_mb numeric, p_website text, p_category_id bigint, p_developer_id bigint, p_is_free boolean); Type: ACL; Schema: software_app; Owner: postgres
--

REVOKE ALL ON FUNCTION software_app.update_software(p_software_id bigint, p_title text, p_description text, p_system_requirements text, p_size_mb numeric, p_website text, p_category_id bigint, p_developer_id bigint, p_is_free boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION software_app.update_software(p_software_id bigint, p_title text, p_description text, p_system_requirements text, p_size_mb numeric, p_website text, p_category_id bigint, p_developer_id bigint, p_is_free boolean) TO software_app;


--
-- Name: TABLE audit_log; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT ON TABLE software_app.audit_log TO software_app;


--
-- Name: SEQUENCE audit_log_audit_id_seq; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE software_app.audit_log_audit_id_seq TO software_app;


--
-- Name: TABLE categories; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE software_app.categories TO software_app;


--
-- Name: SEQUENCE categories_category_id_seq; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE software_app.categories_category_id_seq TO software_app;


--
-- Name: TABLE category_translations; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT ON TABLE software_app.category_translations TO software_app;


--
-- Name: SEQUENCE category_translations_category_translation_id_seq; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE software_app.category_translations_category_translation_id_seq TO software_app;


--
-- Name: TABLE collection_items; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE software_app.collection_items TO software_app;


--
-- Name: SEQUENCE collection_items_collection_item_id_seq; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE software_app.collection_items_collection_item_id_seq TO software_app;


--
-- Name: TABLE collections; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE software_app.collections TO software_app;


--
-- Name: SEQUENCE collections_collection_id_seq; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE software_app.collections_collection_id_seq TO software_app;


--
-- Name: TABLE developers; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE software_app.developers TO software_app;


--
-- Name: SEQUENCE developers_developer_id_seq; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE software_app.developers_developer_id_seq TO software_app;


--
-- Name: TABLE reviews; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE software_app.reviews TO software_app;


--
-- Name: SEQUENCE reviews_review_id_seq; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE software_app.reviews_review_id_seq TO software_app;


--
-- Name: TABLE screenshots; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE software_app.screenshots TO software_app;


--
-- Name: SEQUENCE screenshots_screenshot_id_seq; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE software_app.screenshots_screenshot_id_seq TO software_app;


--
-- Name: TABLE software; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE software_app.software TO software_app;


--
-- Name: TABLE software_analogs; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE software_app.software_analogs TO software_app;


--
-- Name: SEQUENCE software_analogs_software_analog_id_seq; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE software_app.software_analogs_software_analog_id_seq TO software_app;


--
-- Name: SEQUENCE software_software_id_seq; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE software_app.software_software_id_seq TO software_app;


--
-- Name: SEQUENCE users_user_id_seq; Type: ACL; Schema: software_app; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE software_app.users_user_id_seq TO software_app;


--
-- PostgreSQL database dump complete
--

\unrestrict E37S1ZSlyPM6kjkGg6T52BRfWbuTofSzgi3zqVVCOAYFbda6FCbTTiF6xpUcJOp

