-- =========================================================
-- First grand permissions to app_user because schemas are now created.
-- =========================================================
GRANT USAGE ON SCHEMA platform, audit, infra TO app_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA platform TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA audit TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA infra TO app_user;

-- Default permission on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA platform
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA audit
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA infra
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;

-- =========================================================
-- Helper functions and triggers
-- 1) current_tenant_id and current_user_id functions - should these be here or per schema?
-- 2) set_audit_metadata function - Updating updated_by, created_by etc fields 
-- 3) Audit Log - fn_audit_log() function and code to attach this to all table triggers 
-- 4) RLS Helper code to enable and enforce RLS for all tables. (need to filter out some tables)
-- =========================================================

-- Helper functions

CREATE OR REPLACE FUNCTION platform.current_user_id()
RETURNS uuid LANGUAGE sql STABLE AS $$
    SELECT NULLIF(current_setting('app.current_user_id', true), '')::uuid;
$$;

CREATE OR REPLACE FUNCTION platform.current_tenant_id()
RETURNS uuid LANGUAGE sql STABLE AS $$
    SELECT NULLIF(current_setting('app.current_tenant_id', true), '')::uuid;
$$;

CREATE OR REPLACE FUNCTION platform.platform_tenant_id()
RETURNS uuid LANGUAGE sql STABLE AS $$
    SELECT '00000000-0000-0000-0000-000000000001'::uuid;
$$;

CREATE OR REPLACE FUNCTION platform.system_user_id()
RETURNS uuid LANGUAGE sql STABLE AS $$
    SELECT '00000000-0000-0000-0000-000000000000'::uuid;
$$;
---------------------------------------------------------------------------------------------
-- set_audit_metadata() function definition and then code to attach it to all table triggers
---------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION platform.set_audit_metadata()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_user uuid;
BEGIN
    -- read user from session variable
    v_user := platform.current_user_id();
    -- v_user := COALESCE(platform.current_user_id(), '42d04615-df87-41e6-8242-5634dd9d208d'::uuid); 

    IF v_user IS NULL THEN
        v_user := platform.system_user_id();
    END IF;

    IF TG_OP = 'INSERT' THEN
        NEW.created_by := COALESCE(NEW.created_by, v_user);
        NEW.last_updated_by := COALESCE(NEW.last_updated_by, v_user);
        NEW.created_at := COALESCE(NEW.created_at, now());
        NEW.last_updated_at := COALESCE(NEW.last_updated_at, now());
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.last_updated_by := v_user;
        NEW.last_updated_at := now();
    END IF;

    RETURN NEW;
END;
$$;

-- Function to create triggers for all tables to update created_by/updated_by columns
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT tablename, schemaname
        FROM pg_tables
        WHERE schemaname in ('platform', 'audit')
          AND tablename NOT LIKE '%audit_log%'
          AND tablename NOT IN ('user_password_history')
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS trg_%I_audit_metadata ON %I.%I;',
            r.tablename, r.schemaname, r.tablename
        );

        EXECUTE format(
            'CREATE TRIGGER trg_%I_audit_metadata
             BEFORE INSERT OR UPDATE ON %I.%I
             FOR EACH ROW
             EXECUTE FUNCTION platform.set_audit_metadata();',
            r.tablename, r.schemaname, r.tablename
        );
    END LOOP;
END;
$$;



---------------------------------------------------------------------------------------------
-- fn_audit_log() function definition and then code to attach it to all table triggers
---------------------------------------------------------------------------------------------

-- Generic Audit Trigger Function

CREATE OR REPLACE FUNCTION platform.fn_audit_log()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_tenant uuid;
    v_user uuid;
    v_operation text;
    v_retention_class platform.retention_class;
BEGIN
    v_tenant := COALESCE(
	    platform.current_tenant_id(),
	    CASE WHEN TG_OP <> 'DELETE' 
	         THEN (to_jsonb(NEW) ->> 'tenant_id')::uuid   --- to_jsonb takes care of tables that don't have tenant_id 
	    END,
	    (to_jsonb(OLD) ->> 'tenant_id')::uuid,  --- to_jsonb takes care of tables that don't have tenant_id
	    platform.platform_tenant_id()
	);
	
    v_user := COALESCE(
	    platform.current_user_id(),
	    CASE WHEN TG_OP <> 'DELETE' 
	         THEN (to_jsonb(NEW) ->> 'last_updated_by')::uuid 
	    END,
	    (to_jsonb(OLD) ->> 'last_updated_by')::uuid,
	    platform.system_user_id()
	);

    v_operation := TG_OP; -- postgres sets only one of three values INSERT, UPDATE, DELETE

	SELECT retention_class INTO v_retention_class
	FROM platform.audit_retention_policy
	WHERE schema_name = TG_TABLE_SCHEMA
	AND table_name = TG_TABLE_NAME;

        v_retention_class := COALESCE(v_retention_class, 'STANDARD'); -- takes care of nulls

    --set non-standard values of operation if needed
        IF TG_OP = 'UPDATE' THEN

           -- detect soft delete
           IF OLD.is_deleted = false AND NEW.is_deleted = true THEN
               v_operation := 'SOFT_DELETE';

           -- detect restore
           ELSIF OLD.is_deleted = true AND NEW.is_deleted = false THEN
               v_operation := 'RESTORE';

 	   END IF;

	END IF;

    INSERT INTO platform.audit_log (
        tenant_id,
        schema_name,
        table_name,
        record_id,
        operation,
        old_data,
        new_data,
        changed_by,
        changed_at,
        retention_class
    )
    VALUES (
        v_tenant,
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,

        -- generic row identifier
        CASE
            WHEN TG_OP = 'DELETE' THEN OLD.id
            ELSE NEW.id
        END,

        -- TG_OP value is set by postgresql, values can be INSERT, UPDATE, DELETE
        v_operation,

        CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) END,
        CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) END,

        v_user,
        clock_timestamp(),
        v_retention_class
    );

    RETURN COALESCE(NEW, OLD);
END;
$$;

-- attach audit log trigger to all tables

DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT tablename, schemaname
        FROM pg_tables
        WHERE schemaname in ('platform', 'audit')
          AND tablename NOT LIKE 'audit_log%'
          AND tablename NOT IN ('user_password_history')
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS trg_%I_audit ON %I.%I;',
            r.tablename, r.schemaname, r.tablename
        );

        EXECUTE format(
            'CREATE TRIGGER trg_%I_audit
             AFTER INSERT OR UPDATE OR DELETE
             ON %I.%I
             FOR EACH ROW
             EXECUTE FUNCTION platform.fn_audit_log();',
            r.tablename, r.schemaname, r.tablename
        );
    END LOOP;
END;
$$;

---------------------------------------------------------------------------------------------
-- function and trigger to make audit_log table read only (prevent modifications to it)
-- cleanup script will drop partitions of audit log and not update/delete rows. So it is not impacted.
---------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION platform.prevent_audit_log_modification()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Audit log is immutable. % operations are not allowed on audit records.', TG_OP;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_audit_log_modification
ON platform.audit_log;

CREATE TRIGGER trg_prevent_audit_log_modification
BEFORE UPDATE OR DELETE
ON platform.audit_log
FOR EACH ROW
EXECUTE FUNCTION platform.prevent_audit_log_modification();

---------------------------------------------------------------------------------------------
-- enable and enforce RLS for all tables
---------------------------------------------------------------------------------------------

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT schemaname, tablename
        FROM pg_tables
        WHERE schemaname in ('platform', 'audit', 'infra')
	AND tablename NOT IN ('tenant', 'users', 'user_tokens', 'user_password_history', 'product',
							'audit_retention_policy', 'audit_log', 'country', 'state', 'language', 'permission')
        AND tablename NOT LIKE 'audit_log%'
    LOOP
        -- Enable RLS
        EXECUTE format(
            'ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY',
            r.schemaname,
            r.tablename
        );

        -- Force RLS
        EXECUTE format(
            'ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY',
            r.schemaname,
            r.tablename
        );

        -- Drop policy if exists (optional but recommended)
        EXECUTE format(
            'DROP POLICY IF EXISTS tenant_isolation_policy ON %I.%I',
            r.schemaname,
            r.tablename
        );

        -- Create policy
        EXECUTE format(
            $policy$
            CREATE POLICY tenant_isolation_policy
            ON %I.%I
            USING (
                tenant_id = platform.current_tenant_id()
            )
            WITH CHECK (
                tenant_id = platform.current_tenant_id()
            )
            $policy$,
            r.schemaname,
            r.tablename
        );
    END LOOP;
END $$;

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- In certain situations we need to bypass RLS. For example when user says forgot password,
-- he is not logged in. How can we query users table to get details of user by email?
-- So define a "SECURITY DEFINER" function that is owned by platform_admin which has bypass RLS privileges
-- and give execute privilege to app_user which is used by the backend. 
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------
-- SECURITY DEFINER functions are not needed for platform.users and platform.user_tokens
-- because RLS is intentionally disabled on those tables.
-- app_user can query and update them directly.
-- All auth flows (login, password reset, set password) use app_user with direct queries.
-- Session variables (app.current_user_id, app.current_tenant_id) are set by the Spring Boot
-- TenantFilter before any authenticated operation, ensuring audit triggers work correctly.
---------------------------------------------------------------------------------------------

