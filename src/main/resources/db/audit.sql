SET search_path TO software_app, public;

CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER
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

CREATE OR REPLACE FUNCTION audit_row_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = software_app, public
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

DROP TRIGGER IF EXISTS touch_categories_updated_at ON categories;
CREATE TRIGGER touch_categories_updated_at BEFORE UPDATE ON categories
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS touch_developers_updated_at ON developers;
CREATE TRIGGER touch_developers_updated_at BEFORE UPDATE ON developers
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS touch_software_updated_at ON software;
CREATE TRIGGER touch_software_updated_at BEFORE UPDATE ON software
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS touch_reviews_updated_at ON reviews;
CREATE TRIGGER touch_reviews_updated_at BEFORE UPDATE ON reviews
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS touch_collections_updated_at ON collections;
CREATE TRIGGER touch_collections_updated_at BEFORE UPDATE ON collections
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS audit_users ON users;
CREATE TRIGGER audit_users AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW EXECUTE FUNCTION audit_row_change('user_id');

DROP TRIGGER IF EXISTS audit_categories ON categories;
CREATE TRIGGER audit_categories AFTER INSERT OR UPDATE OR DELETE ON categories
FOR EACH ROW EXECUTE FUNCTION audit_row_change('category_id');

DROP TRIGGER IF EXISTS audit_developers ON developers;
CREATE TRIGGER audit_developers AFTER INSERT OR UPDATE OR DELETE ON developers
FOR EACH ROW EXECUTE FUNCTION audit_row_change('developer_id');

DROP TRIGGER IF EXISTS audit_software ON software;
CREATE TRIGGER audit_software AFTER INSERT OR UPDATE OR DELETE ON software
FOR EACH ROW EXECUTE FUNCTION audit_row_change('software_id');

DROP TRIGGER IF EXISTS audit_software_analogs ON software_analogs;
CREATE TRIGGER audit_software_analogs AFTER INSERT OR UPDATE OR DELETE ON software_analogs
FOR EACH ROW EXECUTE FUNCTION audit_row_change('software_analog_id');

DROP TRIGGER IF EXISTS audit_reviews ON reviews;
CREATE TRIGGER audit_reviews AFTER INSERT OR UPDATE OR DELETE ON reviews
FOR EACH ROW EXECUTE FUNCTION audit_row_change('review_id');

DROP TRIGGER IF EXISTS audit_collections ON collections;
CREATE TRIGGER audit_collections AFTER INSERT OR UPDATE OR DELETE ON collections
FOR EACH ROW EXECUTE FUNCTION audit_row_change('collection_id');

DROP TRIGGER IF EXISTS audit_collection_items ON collection_items;
CREATE TRIGGER audit_collection_items AFTER INSERT OR UPDATE OR DELETE ON collection_items
FOR EACH ROW EXECUTE FUNCTION audit_row_change('collection_item_id');

DROP TRIGGER IF EXISTS audit_screenshots ON screenshots;
CREATE TRIGGER audit_screenshots AFTER INSERT OR UPDATE OR DELETE ON screenshots
FOR EACH ROW EXECUTE FUNCTION audit_row_change('screenshot_id');
