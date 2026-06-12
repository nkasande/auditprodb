
-- =========================================================
-- 01_platform_schema.sql
-- Platform Schema + Audit Log + RLS Helpers
-- =========================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE SCHEMA IF NOT EXISTS platform AUTHORIZATION platform_owner;

-- Identity users
-- user is postgresql key word. So name of user table has to be users (not user)

CREATE TABLE IF NOT EXISTS platform.language (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
    
    code VARCHAR(3) NOT NULL,     -- ISO 3166-1 alpha-3 (IND, USA, FRA)
    name VARCHAR(100) NOT NULL,

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid,
    deleted_at timestamptz,
    deleted_by uuid,
    CONSTRAINT chk_delete_metadata
    CHECK (
    	(is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
    	OR
    	(is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_language_code ON platform.language (code) WHERE is_deleted = false;
CREATE UNIQUE INDEX IF NOT EXISTS ux_language_name ON platform.language (name) WHERE is_deleted = false;

CREATE TABLE IF NOT EXISTS platform.users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID, -- cannot refer to tenant_id (FK) yet to avoid circular dependency.

    user_type 	    VARCHAR(20) NOT NULL DEFAULT 'TENANT', CHECK (user_type IN ('PLATFORM', 'TENANT')),
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    password_hash   VARCHAR(255),

    language_id     UUID,
    email           VARCHAR(100) NOT NULL,
    full_name       VARCHAR(100) NOT NULL,
    mobile          VARCHAR(20) NOT NULL,
    is_active       boolean NOT NULL DEFAULT true,
    force_password_reset 	boolean  NOT NULL DEFAULT true, -- new user should be forced to reset password
    failed_login_attempts 	INTEGER NOT NULL DEFAULT 0 CHECK (failed_login_attempts >= 0),
    lock_time 				timestamptz NULL,
    mobility_fcm_token 		VARCHAR(256),
    mobility_device_type 	VARCHAR(100),
    token_version           INT NOT NULL DEFAULT 0,

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid,
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
    	(is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
    	OR
    	(is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    )
);

-- email must be globally unique among active (non-deleted) users only
CREATE UNIQUE INDEX IF NOT EXISTS ux_users_email ON platform.users (lower(email)) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_users_tenant ON platform.users (tenant_id);

-- Tenant table

CREATE TABLE IF NOT EXISTS platform.tenant (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(20) NOT NULL,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    contact_name VARCHAR(100) NOT NULL,
    contact_number VARCHAR(20) NOT NULL,
    contact_number_2 VARCHAR(20),

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
    	(is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
    	OR
    	(is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    ),

    CONSTRAINT tenant_status_chk
        CHECK (status IN ('ACTIVE','SUSPENDED','INACTIVE'))
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_tenant_code ON platform.tenant (code) WHERE is_deleted = false;

-- =========================================================
-- Bootstrap user and tenant tables and language
-- =========================================================
-- ORDER MATTERS:
--   Language is inserted first (created_by is still nullable at this point).
--   System user is inserted second WITH language_id already set.
--   This guarantees language_id is never NULL on any row when we later run
--   "ALTER COLUMN language_id SET NOT NULL", regardless of whether the
--   SQL tool keeps the whole block in one transaction or auto-commits each DDL.
-- =========================================================

BEGIN;

-- 1 Insert English language WITH created_by already set to the system user UUID.
--   The FK constraint on language.created_by does not exist yet (added in step 7),
--   so referencing a user that doesn't exist yet is fine at this point.
--   Both IDs are hardcoded to break the circular dependency without any UPDATEs.
INSERT INTO platform.language (id, code, name, created_by)
VALUES ('00000000-0000-0000-0000-000000000002', 'ENG', 'English',
        '00000000-0000-0000-0000-000000000000')
ON CONFLICT DO NOTHING;

-- 2 Create SYSTEM user WITH language_id already set.
--   The FK constraint on users.language_id does not exist yet (added in step 8),
--   so referencing a language that was just inserted is fine.
INSERT INTO platform.users
    (id, email, user_type, first_name, last_name, password_hash, full_name,
     is_active, mobile, language_id)
VALUES
    ('00000000-0000-0000-0000-000000000000',
     'admin@auditpro.in', 'PLATFORM', 'System', 'User',
     '$2a$10$x6YCBlfkN7yRn0ipyn5TTe/xsoxk4.SKDcUVnKfYkU.6X6xj4p4DW',
     'System User', true, '7875440634',
     '00000000-0000-0000-0000-000000000002')
ON CONFLICT DO NOTHING;

-- 3 Create SYSTEM tenant using the SYSTEM user
INSERT INTO platform.tenant (id, code, name, contact_name, contact_number, created_by, last_updated_by)
SELECT
    '00000000-0000-0000-0000-000000000001',
    'SYSTEM',
    'Default root tenant used to bootstrap system',
    'Nilesh Kasande',
    '+91 7875440634',
    u.id,
    u.id
FROM platform.users u
WHERE u.email = 'admin@auditpro.in'
ON CONFLICT DO NOTHING;

-- 4 Assign SYSTEM tenant to SYSTEM user (self-referencing created_by / updated_by)
UPDATE platform.users u
SET
    tenant_id        = t.id,
    created_by       = u.id,
    last_updated_by  = u.id
FROM platform.tenant t
WHERE
    u.email  = 'admin@auditpro.in'
    AND t.code = 'SYSTEM';

-- 5 Add FK constraints on users now that both tenant and user rows exist
--   DO blocks let us skip gracefully if constraints already exist (idempotent re-runs).
DO $$ BEGIN
    ALTER TABLE platform.users
        ADD CONSTRAINT fk_user_tenant
            FOREIGN KEY (tenant_id) REFERENCES platform.tenant(id) ON DELETE CASCADE,
        ADD CONSTRAINT fk_created_by
            FOREIGN KEY (created_by) REFERENCES platform.users(id) ON DELETE SET NULL,
        ADD CONSTRAINT fk_updated_by
            FOREIGN KEY (last_updated_by) REFERENCES platform.users(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 6 Tighten language table: make created_by NOT NULL, add FK constraints
DO $$ BEGIN
    ALTER TABLE platform.language
        ALTER COLUMN created_by SET NOT NULL,
        ADD CONSTRAINT fk_language_created_by
            FOREIGN KEY (created_by)      REFERENCES platform.users(id),
        ADD CONSTRAINT fk_language_last_updated_by
            FOREIGN KEY (last_updated_by) REFERENCES platform.users(id),
        ADD CONSTRAINT fk_language_deleted_by
            FOREIGN KEY (deleted_by)      REFERENCES platform.users(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 7 Add language FK on users and enforce NOT NULL.
--   Every existing row already has language_id set (step 2), so this always succeeds.
DO $$ BEGIN
    ALTER TABLE platform.users
        ADD CONSTRAINT fk_user_language
            FOREIGN KEY (language_id) REFERENCES platform.language(id) ON DELETE RESTRICT,
        ALTER COLUMN language_id SET NOT NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMIT;

-- =========================================================
--Bootstrap user and tenant tables and language ends
-- =========================================================

-- product table

CREATE TABLE IF NOT EXISTS platform.product (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code        VARCHAR(20) NOT NULL,
    name        VARCHAR(100) NOT NULL,
    description VARCHAR(255),

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
    	(is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
    	OR
    	(is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_product_code ON platform.product (code) WHERE is_deleted = false;

-- subscription table

CREATE TABLE IF NOT EXISTS platform.subscription (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES platform.tenant(id) ON DELETE CASCADE,

    product_id      UUID NOT NULL REFERENCES platform.product(id),
    start_date      DATE NOT NULL,
    end_date        DATE,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
    	(is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
    	OR
    	(is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    ),

    CONSTRAINT subscription_status_chk
        CHECK (status IN ('ACTIVE','EXPIRED','SUSPENDED'))
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_subscription_tenant_product
ON platform.subscription (tenant_id, product_id) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_subscription_tenant ON platform.subscription (tenant_id);


CREATE TABLE IF NOT EXISTS platform.tenant_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES platform.tenant(id),
    
    product_id UUID NOT NULL REFERENCES platform.product(id),

    config_key   VARCHAR(100) NOT NULL,
    config_value VARCHAR(255) NOT NULL,
    description  VARCHAR(255),
    
    value_type     VARCHAR(20) NOT NULL DEFAULT 'STRING',
    allowed_values VARCHAR(255),

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
        (is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
        OR
        (is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_tenant_config_key
ON platform.tenant_config (tenant_id, product_id, config_key) WHERE is_deleted = false;

CREATE TABLE platform.user_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),
    
    user_id 	UUID NOT NULL REFERENCES platform.users(id),
    token 		UUID NOT NULL,
    type 		varchar(20) NOT NULL, -- SET_PASSWORD / RESET_PASSWORD
    expiry 		timestamptz NOT NULL,
    used 		boolean DEFAULT false NOT NULL,

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
    	(is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
    	OR
    	(is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_user_tokens_token ON platform.user_tokens(token);
CREATE UNIQUE INDEX ux_user_active_token ON platform.user_tokens(user_id, type) WHERE used = false;

CREATE TABLE IF NOT EXISTS platform.user_password_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),
    
    user_id UUID NOT NULL REFERENCES platform.users(id),
    password_hash VARCHAR(255) NOT NULL,
    
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pwd_history_user ON platform.user_password_history(user_id);


-- country table
CREATE TABLE  IF NOT EXISTS platform.country (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
    
    code VARCHAR(3) NOT NULL,     -- ISO 3166-1 alpha-3 (IND, USA, FRA)
    name VARCHAR(100) NOT NULL,

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
    	(is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
    	OR
    	(is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_country_code ON platform.country (code) WHERE is_deleted = false;
CREATE UNIQUE INDEX IF NOT EXISTS ux_country_name ON platform.country (name) WHERE is_deleted = false;

CREATE TABLE IF NOT EXISTS platform.state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
    
    code VARCHAR(10) NOT NULL,     -- ISO 3166-1 alpha-3 (IND, USA, FRA)
    name VARCHAR(100) NOT NULL,
    
    country_id UUID NOT NULL,
    CONSTRAINT fk_state_country_id FOREIGN KEY (country_id) REFERENCES platform.country(id),	

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
    	(is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
    	OR
    	(is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    ),
    
    UNIQUE (id, country_id)   -- retained: supports composite FK references
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_state_code_country ON platform.state (code, country_id) WHERE is_deleted = false;


------------------------------------------------------------------------------------------
----------------------------AUTHORISATION RELATED TABLES----------------------------------
------------------------------------------------------------------------------------------

-- Roles per tenant (RBAC foundation)
CREATE TABLE IF NOT EXISTS platform.role (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),
    
    product_id 	UUID NOT NULL REFERENCES platform.product(id),

    
    code 		VARCHAR(50) NOT NULL,
    name 		VARCHAR(100) NOT NULL,
    description VARCHAR(255),

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
        (is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
        OR
        (is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_role_code
ON platform.role (tenant_id, product_id, code) WHERE is_deleted = false;

-- Permissions - resource + action based (ABAC-ready)
CREATE TABLE IF NOT EXISTS platform.permission (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id 	UUID NOT NULL REFERENCES platform.product(id),


    resource 	VARCHAR(100) NOT NULL,  -- e.g. 'AUDIT_TEMPLATE', 'CAPA', 'RESPONSE'
    action 		VARCHAR(50) NOT NULL,     -- e.g. 'CREATE', 'READ', 'UPDATE', 'DELETE', 'APPROVE'
    description VARCHAR(255),
    
    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
        (is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
        OR
        (is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_permission_resource_action
ON platform.permission (product_id, resource, action) WHERE is_deleted = false;

-- Role to permission mapping
CREATE TABLE IF NOT EXISTS platform.role_permission (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),
    
    role_id 		UUID NOT NULL REFERENCES platform.role(id),
    permission_id 	UUID NOT NULL REFERENCES platform.permission(id),
    
    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
        (is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
        OR
        (is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_role_permission_active
ON platform.role_permission (tenant_id, role_id, permission_id) WHERE is_deleted = false;

-- User to role mapping
CREATE TABLE IF NOT EXISTS platform.user_role (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),

    user_id 	UUID NOT NULL REFERENCES platform.users(id),
    role_id 	UUID NOT NULL REFERENCES platform.role(id),

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
        (is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
        OR
        (is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_user_role_active
ON platform.user_role (tenant_id, user_id, role_id) WHERE is_deleted = false;


--Following table will remain empty for audit, but will be used for MES
-- For audit, service layer does simple role/permission checks. 
-- For MES, populate conditions and the authorization engine evaluates them

--This table makes authorisation mechanism ABAC ready.
CREATE TABLE IF NOT EXISTS platform.permission_condition (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),
    product_id 	UUID NOT NULL REFERENCES platform.product(id),
    role_permission_id UUID NOT NULL REFERENCES platform.role_permission(id),

    attribute_key 		VARCHAR(100) NOT NULL,  -- field name on the resource e.g. 'site_id', 'department_id', 'status'
    operator 			VARCHAR(20) NOT NULL,   -- e.g. 'EQUALS', 'IN', 'NOT_EQUALS'
    attribute_value 	VARCHAR(255) NOT NULL,	-- actual value to compare against e.g. specific site UUID

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
        (is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
        OR
        (is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    ),
    
    CONSTRAINT chk_operator
        CHECK (operator IN ('EQUALS', 'NOT_EQUALS', 'IN'))    
);
------------------------------------------------------------------------------------------
--------------------------AUTHORISATION RELATED TABLES END--------------------------------
------------------------------------------------------------------------------------------

-- site table.

CREATE TABLE IF NOT EXISTS platform.site (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),

    code	VARCHAR(20) NOT NULL, -- TODO should code have only upto 6 chars? 	
    name        VARCHAR(100) NOT NULL,
    address_line_1 VARCHAR(100) NOT NULL,
    address_line_2 VARCHAR(100),
    city VARCHAR(100),
    zip VARCHAR(20) NOT NULL,
    
    state_code VARCHAR(10),
    country_code VARCHAR(3),
      
    contact_person VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(100),	

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
    	(is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
    	OR
    	(is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_site_code ON platform.site (tenant_id, code) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_site_tenant ON platform.site (tenant_id);

-- department table. Shouldn't this be in platform? applicable for MES too?

CREATE TABLE IF NOT EXISTS platform.department (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),

    site_id     UUID NOT NULL REFERENCES platform.site(id),
    code	VARCHAR(20) NOT NULL, -- TODO should code have only upto 6 chars?
    name        VARCHAR(100) NOT NULL,
    contact_person VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(100),	
    
    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
    	(is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
    	OR
    	(is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_department_code
ON platform.department (tenant_id, site_id, code) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_department_tenant ON platform.department (tenant_id);

--now that we have department table created, add department column to users table
ALTER TABLE platform.users
ADD COLUMN department_id UUID
    REFERENCES platform.department(id);

-- audit log retention class enumeration

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'retention_class'
        AND n.nspname = 'platform'
    ) THEN
        CREATE TYPE platform.retention_class AS ENUM (
            'STANDARD',
            'LEGAL_HOLD',
            'PERMANENT'
        );
    END IF;
END $$;


-- audit retention policy table
CREATE TABLE IF NOT EXISTS platform.audit_retention_policy (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),    
    schema_name text NOT NULL,
    table_name  text NOT NULL,
    retention_class platform.retention_class NOT NULL DEFAULT 'STANDARD',

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    CONSTRAINT chk_delete_metadata
    CHECK (
    	(is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
    	OR
    	(is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_audit_retention_policy
ON platform.audit_retention_policy (schema_name, table_name) WHERE is_deleted = false;

-- Audit Log (Partitioned)

CREATE TABLE IF NOT EXISTS platform.audit_log (
    id uuid DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,

    schema_name text NOT NULL,
    table_name text NOT NULL,
    retention_class platform.retention_class NOT NULL DEFAULT 'STANDARD',	
    record_id uuid,
    operation text NOT NULL,
    old_data jsonb,
    new_data jsonb,

    changed_by uuid,
    changed_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_auditlog_operation
    CHECK (operation IN (
        'INSERT',
        'UPDATE',
        'DELETE',
        'SOFT_DELETE',
        'RESTORE'
    )),

    PRIMARY KEY (changed_at, id)     -- partition key has to be there in the primary key. So changed_at is added
) PARTITION BY RANGE (changed_at);

CREATE INDEX IF NOT EXISTS idx_audit_log_table_record
    ON platform.audit_log (table_name, record_id);

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-- Pre-create 12 monthly partitions
-- if this script is executed in March 2026, first partition created by below code will be
-- 	CREATE TABLE IF NOT EXISTS platform.audit_log_2026_03
-- 	PARTITION OF platform.audit_log
--	FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
-- create index statements at the end will create indexes on all partitions
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
DO $$
DECLARE
    start_date date := date_trunc('month', now());
    i int;
BEGIN
    FOR i IN 0..11 LOOP
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS platform.audit_log_%s PARTITION OF platform.audit_log
             FOR VALUES FROM (%L) TO (%L);',
            to_char(start_date + (i || ' month')::interval, 'YYYY_MM'),
            start_date + (i || ' month')::interval,
            start_date + ((i+1) || ' month')::interval
        );
    END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS idx_audit_log_tenant ON platform.audit_log (tenant_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_at ON platform.audit_log (changed_at);
