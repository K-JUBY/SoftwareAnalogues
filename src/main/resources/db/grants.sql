DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'software_app') THEN
        CREATE ROLE software_app LOGIN PASSWORD 'change_me';
    ELSE
        ALTER ROLE software_app LOGIN PASSWORD 'change_me';
    END IF;
END;
$$;

GRANT CONNECT ON DATABASE postgres TO software_app;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA software_app FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO software_app;
GRANT USAGE ON SCHEMA software_app TO software_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON
    software_app.categories,
    software_app.developers,
    software_app.software,
    software_app.software_analogs,
    software_app.reviews,
    software_app.collections,
    software_app.collection_items,
    software_app.screenshots
TO software_app;

GRANT SELECT ON software_app.audit_log TO software_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA software_app TO software_app;

REVOKE ALL ON software_app.users FROM software_app;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA software_app FROM PUBLIC;
REVOKE EXECUTE ON ALL PROCEDURES IN SCHEMA software_app FROM PUBLIC;
GRANT EXECUTE ON FUNCTION software_app.authenticate_user(TEXT, TEXT) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.create_app_user(TEXT, TEXT, TEXT) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.search_software(TEXT, BIGINT, BIGINT, BOOLEAN) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.add_software(TEXT, TEXT, TEXT, NUMERIC, TEXT, BIGINT, BIGINT, BOOLEAN) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.update_software(BIGINT, TEXT, TEXT, TEXT, NUMERIC, TEXT, BIGINT, BIGINT, BOOLEAN) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.delete_software(BIGINT) TO software_app;
GRANT EXECUTE ON PROCEDURE software_app.add_software_analog(BIGINT, BIGINT, TEXT, SMALLINT) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.list_reviews(BIGINT) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.add_review(BIGINT, TEXT, SMALLINT) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.list_software_analogs(BIGINT) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.remove_software_analog(BIGINT, BIGINT) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.current_app_user_id() TO software_app;
GRANT EXECUTE ON FUNCTION software_app.list_collections() TO software_app;
GRANT EXECUTE ON FUNCTION software_app.create_collection(TEXT, TEXT) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.delete_collection(BIGINT) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.list_collection_items(BIGINT) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.add_collection_item(BIGINT, BIGINT, TEXT, INTEGER) TO software_app;
GRANT EXECUTE ON FUNCTION software_app.remove_collection_item(BIGINT, BIGINT) TO software_app;
