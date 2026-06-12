-- =========================================================
-- 08_onboard_tenant_v2.sql
-- Tenant Onboarding Script
-- =========================================================
-- INSTRUCTIONS:
--   1. Fill in all variables in the CONFIGURATION section
--   2. Review values carefully before running
--   3. Run as platform_admin
--   4. Script is idempotent - safe to re-run
--   5. After running, query the SET_PASSWORD token and
--      send the setup link manually to v_email:
--
--      SELECT u.email, ut.token, ut.expiry
--      FROM platform.user_tokens ut
--      JOIN platform.users u ON u.id = ut.user_id
--      JOIN platform.tenant t ON t.id = ut.tenant_id
--      WHERE t.code = '<v_code>'
--        AND ut.type = 'SET_PASSWORD'
--        AND ut.used = false;
-- =========================================================

DO $$
DECLARE

    -- =====================================================
    -- CONFIGURATION — fill these values before running
    -- =====================================================

    -- Tenant details
    v_code              VARCHAR := 'DevTenant';
    v_name              VARCHAR := 'Default dev tenant for development';
    v_contact_name      VARCHAR := 'Development Tenant';
    v_contact_number    VARCHAR := '00911234567890';
    v_contact_number_2  VARCHAR := '00911234567891';

    -- Subscription
    -- Product code must exist in platform.product (e.g. 'AUDIT')
    -- Date format: 'YYYY-MM-DD'
    v_product_code      VARCHAR := 'AUDIT';
    v_start_date        DATE    := '2026-04-01';
    v_end_date          DATE    := '2027-03-31'; -- set to NULL if open-ended

    -- Site
    -- state_code must exist in platform.state; country_code must exist in platform.country
    v_site_code         VARCHAR := 'HQ';
    v_site_name         VARCHAR := 'Head Office';
    v_address_line1     VARCHAR := '123 Main Street';
    v_address_line2     VARCHAR := NULL;
    v_city              VARCHAR := 'Pune';
    v_zip               VARCHAR := '411004';
    v_state_code        VARCHAR := 'MH';
    v_country_code      VARCHAR := 'IND';
    v_site_contact      VARCHAR := 'Johnrao Dhawale Not John Doe';
    v_site_phone        VARCHAR := '+91 9876543210';
    v_site_email        VARCHAR := 'hq@devtenant.com';

    -- Department
    v_dept_code         VARCHAR := 'QA';
    v_dept_name         VARCHAR := 'Quality Assurance';
    v_dept_contact      VARCHAR := 'Janabai Dhawale Not Jane Doe';
    v_dept_phone        VARCHAR := '+91 9876543211';
    v_dept_email        VARCHAR := 'qa@devtenant.com';

    -- Admin user
    -- language_code must exist in platform.language (e.g. 'ENG')
    v_email             VARCHAR := 'admin@devtenant.com';
    v_first_name        VARCHAR := 'Dev';
    v_last_name         VARCHAR := 'Admin';
    v_mobile            VARCHAR := '+91 9876543212';
    v_language_code     VARCHAR := 'ENG';

    -- =====================================================
    -- WORKING VARIABLES — do not edit below this line
    -- =====================================================
    v_system_user_id    UUID;
    v_tenant_id         UUID;
    v_product_id        UUID;
    v_language_id       UUID;
    v_site_id           UUID;
    v_dept_id           UUID;
    v_user_id           UUID;
    v_role_id           UUID;

BEGIN

    -- =====================================================
    -- 0. Validate inputs
    -- =====================================================
    SELECT id INTO v_system_user_id
    FROM platform.users WHERE email = 'admin@auditpro.in';
    IF v_system_user_id IS NULL THEN
        RAISE EXCEPTION 'System user not found. Ensure bootstrap scripts have been run.';
    END IF;

    SELECT id INTO v_product_id
    FROM platform.product WHERE code = v_product_code;
    IF v_product_id IS NULL THEN
        RAISE EXCEPTION 'Product % not found. Check platform.product table.', v_product_code;
    END IF;

    SELECT id INTO v_language_id
    FROM platform.language WHERE code = v_language_code;
    IF v_language_id IS NULL THEN
        RAISE EXCEPTION 'Language % not found. Check platform.language table.', v_language_code;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM platform.state s
        JOIN platform.country c ON c.id = s.country_id
        WHERE s.code = v_state_code AND c.code = v_country_code
          AND s.is_deleted = false
    ) THEN
        RAISE EXCEPTION 'State % for country % not found. Check platform.state table.',
            v_state_code, v_country_code;
    END IF;

    RAISE NOTICE 'All inputs validated successfully.';

    -- =====================================================
    -- 1. CREATE TENANT
    -- =====================================================
    SELECT id INTO v_tenant_id
    FROM platform.tenant WHERE code = v_code;

    IF v_tenant_id IS NULL THEN
        INSERT INTO platform.tenant (
            code, name, status,
            contact_name, contact_number, contact_number_2,
            created_by, last_updated_by
        ) VALUES (
            v_code, v_name, 'ACTIVE',
            v_contact_name, v_contact_number, v_contact_number_2,
            v_system_user_id, v_system_user_id
        )
        RETURNING id INTO v_tenant_id;
        RAISE NOTICE 'Tenant created: % (%)', v_name, v_tenant_id;
    ELSE
        RAISE NOTICE 'Tenant % already exists (%) — skipping.', v_code, v_tenant_id;
    END IF;

    -- =====================================================
    -- 2. CREATE SUBSCRIPTION
    -- =====================================================
    IF NOT EXISTS (
        SELECT 1 FROM platform.subscription
        WHERE tenant_id = v_tenant_id AND product_id = v_product_id
    ) THEN
        INSERT INTO platform.subscription (
            tenant_id, product_id,
            start_date, end_date, status,
            created_by, last_updated_by
        ) VALUES (
            v_tenant_id, v_product_id,
            v_start_date, v_end_date, 'ACTIVE',
            v_system_user_id, v_system_user_id
        );
        RAISE NOTICE 'Subscription created: % from % to %.',
            v_product_code, v_start_date, v_end_date;
    ELSE
        RAISE NOTICE 'Subscription for % already exists — skipping.', v_product_code;
    END IF;

    -- =====================================================
    -- 3. CREATE ROLES for this tenant
    -- =====================================================
    INSERT INTO platform.role (
        tenant_id, product_id, code, name, description,
        created_by, last_updated_by
    )
    SELECT
        v_tenant_id, v_product_id,
        v.code, v.name, v.description,
        v_system_user_id, v_system_user_id
    FROM (VALUES
        ('AUDIT_ADMIN',
         'Audit Administrator',
         'Full access to admin functions within audit application. Manages users, roles, sites, departments and permission assignments.'),
        ('QA_MANAGER',
         'QA Manager',
         'Creates and manages audit types, templates and schedules. Assigns auditors and auditees. Full view access to all audit data.'),
        ('APPROVER',
         'Approver',
         'Approves audit templates, schedules and CAPAs (second level). Can create and manage CAPAs. Access to all audit data within configured scope.'),
        ('AUDITOR',
         'Auditor',
         'Executes audits, fills responses, raises findings. First level approver of CAPA after closure.'),
        ('AUDITEE',
         'Auditee',
         'Views assigned audits. Creates, updates and deletes CAPAs. Submits CAPAs for closure. Views reports and approvals.'),
        ('VIEWER',
         'Viewer',
         'Read-only access to audit types, templates, schedules, executions, responses, CAPAs, comments and approvals.')
    ) AS v(code, name, description)
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Roles created for tenant %.', v_code;

    -- =====================================================
    -- 4. ROLE_PERMISSION mappings
    -- =====================================================

    -- ── AUDIT_ADMIN — only AUDIT SCHEMA ADMIN permissions ─
    INSERT INTO platform.role_permission (
        tenant_id, role_id, permission_id,
        created_by, last_updated_by
    )
    SELECT r.tenant_id, r.id, perm.id,
           v_system_user_id, v_system_user_id
    FROM platform.role r
    JOIN platform.permission perm ON perm.product_id = v_product_id
    WHERE r.tenant_id  = v_tenant_id
      AND r.code       = 'AUDIT_ADMIN'
      AND r.product_id = v_product_id
      AND (perm.resource, perm.action) IN (
        ('platform.language', 		 'VIEW'),
		('platform.country',         'VIEW'),
		('platform.state',           'VIEW'),
		
        ('platform.users',           'CREATE'),
        ('platform.users',           'VIEW'),
        ('platform.users',           'UPDATE'),
        ('platform.users',           'DELETE'),
        ('platform.users',           'DEACTIVATE'),
        
        ('platform.tenant_config',	 'VIEW'),
        ('platform.tenant_config',	 'UPDATE'),
        
        ('platform.role',            'CREATE'),
        ('platform.role',            'VIEW'),
        ('platform.role',            'UPDATE'),
        ('platform.role',            'DELETE'),
        ('platform.permission',      'VIEW'),
        ('platform.role_permission', 'CREATE'),
        ('platform.role_permission', 'VIEW'),
        ('platform.role_permission', 'DELETE'),
        ('platform.user_role',       'CREATE'),
        ('platform.user_role',       'VIEW'),
        ('platform.user_role',       'DELETE'),
        ('platform.site',            'CREATE'),
        ('platform.site',            'VIEW'),
        ('platform.site',            'UPDATE'),
        ('platform.site',            'DELETE'),
        ('platform.department',      'CREATE'),
        ('platform.department',      'VIEW'),
        ('platform.department',      'UPDATE'),
        ('platform.department',      'DELETE')
    )
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Permissions assigned to AUDIT_ADMIN.';

    -- ── QA_MANAGER ──────────────────────────────────────
    INSERT INTO platform.role_permission (
        tenant_id, role_id, permission_id,
        created_by, last_updated_by
    )
    SELECT r.tenant_id, r.id, perm.id,
           v_system_user_id, v_system_user_id
    FROM platform.role r
    JOIN platform.permission perm ON perm.product_id = v_product_id
    WHERE r.tenant_id  = v_tenant_id
      AND r.code       = 'QA_MANAGER'
      AND r.product_id = v_product_id
      AND (perm.resource, perm.action) IN (

        ('platform.language', 		 'VIEW'),
		('platform.country',         'VIEW'),
		('platform.state',           'VIEW'),

        ('platform.users',           	'VIEW'),
        
        ('audit.audit_type',           'CREATE'),
        ('audit.audit_type',           'VIEW'),
        ('audit.audit_type',           'UPDATE'),
        ('audit.audit_type',           'DELETE'),
        ('audit.audit_template',       'CREATE'),
        ('audit.audit_template',       'VIEW'),
        ('audit.audit_template',       'UPDATE'),
        ('audit.audit_template',       'DELETE'),   -- fix #3
        -- APPROVE_L2 removed from QA_MANAGER (fix #3)
        ('audit.template_version',     'CREATE'),
        ('audit.template_version',     'VIEW'),
        ('audit.template_version',     'UPDATE'),
        ('audit.template_version',     'DELETE'),
        ('audit.template_section',     'CREATE'),
        ('audit.template_section',     'VIEW'),
        ('audit.template_section',     'UPDATE'),
        ('audit.template_section',     'DELETE'),
        ('audit.template_item',        'CREATE'),
        ('audit.template_item',        'VIEW'),
        ('audit.template_item',        'UPDATE'),
        ('audit.template_item',        'DELETE'),
        ('audit.audit_schedule',       'CREATE'),
        ('audit.audit_schedule',       'VIEW'),
        ('audit.audit_schedule',       'UPDATE'),
        ('audit.audit_schedule',       'DELETE'),   -- fix #3
        ('audit.audit_execution',      'VIEW'),
        ('audit.audit_execution',      'CANCEL'),
        ('audit.response',             'VIEW'),
        ('audit.capa',                 'VIEW'),
       	('audit.action_history',       'CREATE'),
    	('audit.action_history',       'VIEW'),
    	('audit.action_history',       'DELETE'),
    	('audit.attachment',       	   'CREATE'),
    	('audit.attachment',           'VIEW'),
    	('audit.attachment',           'DELETE'),
    	
    	('platform.tenant_config',	 'VIEW')
    )
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Permissions assigned to QA_MANAGER.';

    -- ── APPROVER ─────────────────────────────────────────
    INSERT INTO platform.role_permission (
        tenant_id, role_id, permission_id,
        created_by, last_updated_by
    )
    SELECT r.tenant_id, r.id, perm.id,
           v_system_user_id, v_system_user_id
    FROM platform.role r
    JOIN platform.permission perm ON perm.product_id = v_product_id
    WHERE r.tenant_id  = v_tenant_id
      AND r.code       = 'APPROVER'
      AND r.product_id = v_product_id
      AND (perm.resource, perm.action) IN (
        ('platform.language', 		 'VIEW'),
		('platform.country',         'VIEW'),
		('platform.state',           'VIEW'),
        ('platform.users',           	'VIEW'),

        ('audit.audit_type',           'VIEW'),
        ('audit.audit_template',       'VIEW'),
        ('audit.template_version',     'VIEW'),
        ('audit.template_version',     'APPROVE_L2'),
        ('audit.template_section',     'VIEW'),
        ('audit.template_item',        'VIEW'),
        ('audit.audit_schedule',       'VIEW'),
        ('audit.audit_schedule',       'APPROVE_L2'),
        ('audit.audit_execution',      'VIEW'),
        ('audit.audit_execution',      'APPROVE_L2'),
        ('audit.response',             'VIEW'),
        ('audit.capa',                 'CREATE'),      -- fix #4b
        ('audit.capa',                 'VIEW'),
        ('audit.capa',                 'UPDATE'),      -- fix #4b
        ('audit.capa',                 'REASSIGN'),
        ('audit.action_history',       'CREATE'),
    	('audit.action_history',       'VIEW'),
    	('audit.action_history',       'DELETE'),
    	('audit.attachment',       	   'CREATE'),
    	('audit.attachment',           'VIEW'),
    	('audit.attachment',           'DELETE'),
    	('audit.approval',           'VIEW'),
    	
    	('platform.tenant_config',	 'VIEW')
    	

    )
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Permissions assigned to APPROVER.';

    -- ── AUDITOR ─────────────────────────────────────────
    INSERT INTO platform.role_permission (
        tenant_id, role_id, permission_id,
        created_by, last_updated_by
    )
    SELECT r.tenant_id, r.id, perm.id,
           v_system_user_id, v_system_user_id
    FROM platform.role r
    JOIN platform.permission perm ON perm.product_id = v_product_id
    WHERE r.tenant_id  = v_tenant_id
      AND r.code       = 'AUDITOR'
      AND r.product_id = v_product_id
      AND (perm.resource, perm.action) IN (
        ('platform.language', 		 'VIEW'),
		('platform.country',         'VIEW'),
		('platform.state',           'VIEW'),
        ('platform.users',           	'VIEW'),

        ('audit.audit_type',           'VIEW'),
        ('audit.audit_template',       'VIEW'),
        ('audit.template_version',     'VIEW'),
        ('audit.template_section',     'VIEW'),
        ('audit.template_item',        'VIEW'),
        ('audit.audit_schedule',       'VIEW'),
        ('audit.audit_schedule',       'APPROVE_L1'),  -- CAPA review: auditor approves/rejects
        ('audit.audit_execution',      'CREATE'),
        ('audit.audit_execution',      'VIEW'),
        ('audit.audit_execution',      'UPDATE'),
        ('audit.response',             'CREATE'),
        ('audit.response',             'VIEW'),
        ('audit.response',             'UPDATE'),
        ('audit.capa',                 'VIEW'),
        ('audit.capa',                 'UPDATE'),
      	('audit.action_history',       'CREATE'),
    	('audit.action_history',       'VIEW'),
    	('audit.action_history',       'DELETE'),
    	('audit.attachment',       	   'CREATE'),
    	('audit.attachment',           'VIEW'),
    	('audit.attachment',           'DELETE'),
    	
    	('platform.tenant_config',	 'VIEW')

    )
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Permissions assigned to AUDITOR.';

    -- ── AUDITEE ─────────────────────────────────────────
    INSERT INTO platform.role_permission (
        tenant_id, role_id, permission_id,
        created_by, last_updated_by
    )
    SELECT r.tenant_id, r.id, perm.id,
           v_system_user_id, v_system_user_id
    FROM platform.role r
    JOIN platform.permission perm ON perm.product_id = v_product_id
    WHERE r.tenant_id  = v_tenant_id
      AND r.code       = 'AUDITEE'
      AND r.product_id = v_product_id
      AND (perm.resource, perm.action) IN (
        ('platform.language', 		 'VIEW'),
		('platform.country',         'VIEW'),
		('platform.state',           'VIEW'),
        ('platform.users',           	'VIEW'),

        ('audit.audit_type',           'VIEW'),
        ('audit.audit_template',       'VIEW'),
        ('audit.template_version',     'VIEW'),
        ('audit.template_section',     'VIEW'),
        ('audit.template_item',        'VIEW'),
        ('audit.audit_schedule',       'VIEW'),
        ('audit.audit_schedule',       'SUBMIT'),      -- submit all CAPAs for review
        ('audit.audit_execution',      'VIEW'),
        ('audit.response',             'VIEW'),
        ('audit.capa',                 'CREATE'),
        ('audit.capa',                 'VIEW'),
        ('audit.capa',                 'UPDATE'),
        ('audit.capa',                 'DELETE'),
        ('audit.capa',                 'SUBMIT'),      -- submit individual CAPA for closure
        ('audit.capa',                 'REASSIGN'),
      	('audit.action_history',       'CREATE'),
    	('audit.action_history',       'VIEW'),
    	('audit.action_history',       'DELETE'),
    	('audit.attachment',       	   'CREATE'),
    	('audit.attachment',           'VIEW'),
    	('audit.attachment',           'DELETE'),
    	
    	('platform.tenant_config',	 'VIEW')

    )
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Permissions assigned to AUDITEE.';

    -- ── VIEWER ──────────────────────────────────────────
    INSERT INTO platform.role_permission (
        tenant_id, role_id, permission_id,
        created_by, last_updated_by
    )
    SELECT r.tenant_id, r.id, perm.id,
           v_system_user_id, v_system_user_id
    FROM platform.role r
    JOIN platform.permission perm ON perm.product_id = v_product_id
    WHERE r.tenant_id  = v_tenant_id
      AND r.code       = 'VIEWER'
      AND r.product_id = v_product_id
      AND (perm.resource, perm.action) IN (
        ('platform.language', 		 'VIEW'),
		('platform.country',         'VIEW'),
		('platform.state',           'VIEW'),
        ('platform.users',           	'VIEW'),
        ('platform.tenant_config',	 'VIEW'),
      
        ('audit.audit_type',           'VIEW'),
        ('audit.audit_template',       'VIEW'),
        ('audit.template_version',     'VIEW'),
        ('audit.template_section',     'VIEW'),
        ('audit.template_item',        'VIEW'),
        ('audit.audit_schedule',       'VIEW'),
        ('audit.audit_execution',      'VIEW'),
        ('audit.response',             'VIEW'),
        ('audit.capa',                 'VIEW'),
        ('audit.action_history',       'VIEW'),
        ('audit.attachment',           'VIEW')
    )
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Permissions assigned to VIEWER.';

    -- =====================================================
    -- 5. CREATE SITE
    -- =====================================================
    SELECT id INTO v_site_id
    FROM platform.site
    WHERE tenant_id = v_tenant_id AND code = v_site_code;

    IF v_site_id IS NULL THEN
        INSERT INTO platform.site (
            tenant_id, code, name,
            address_line_1, address_line_2,
            city, zip, state_code, country_code,
            contact_person, phone, email,
            created_by, last_updated_by
        ) VALUES (
            v_tenant_id, v_site_code, v_site_name,
            v_address_line1, v_address_line2,
            v_city, v_zip, v_state_code, v_country_code,
            v_site_contact, v_site_phone, v_site_email,
            v_system_user_id, v_system_user_id
        )
        RETURNING id INTO v_site_id;
        RAISE NOTICE 'Site created: % (%)', v_site_name, v_site_id;
    ELSE
        RAISE NOTICE 'Site % already exists — skipping.', v_site_code;
    END IF;

    -- =====================================================
    -- 6. CREATE DEPARTMENT
    -- =====================================================
    SELECT id INTO v_dept_id
    FROM platform.department
    WHERE tenant_id = v_tenant_id
      AND site_id   = v_site_id
      AND code      = v_dept_code;

    IF v_dept_id IS NULL THEN
        INSERT INTO platform.department (
            tenant_id, site_id, code, name,
            contact_person, phone, email,
            created_by, last_updated_by
        ) VALUES (
            v_tenant_id, v_site_id, v_dept_code, v_dept_name,
            v_dept_contact, v_dept_phone, v_dept_email,
            v_system_user_id, v_system_user_id
        )
        RETURNING id INTO v_dept_id;
        RAISE NOTICE 'Department created: % (%)', v_dept_name, v_dept_id;
    ELSE
        RAISE NOTICE 'Department % already exists — skipping.', v_dept_code;
    END IF;

    -- =====================================================
    -- 7. CREATE ADMIN USER
    -- =====================================================
    SELECT id INTO v_user_id
    FROM platform.users
    WHERE tenant_id = v_tenant_id
      AND lower(email) = lower(v_email);

    IF v_user_id IS NULL THEN
        INSERT INTO platform.users (
            tenant_id, user_type,
            email, first_name, last_name, full_name, mobile,
            language_id, department_id,
            is_active, force_password_reset,
            password_hash,
            created_by, last_updated_by
        ) VALUES (
            v_tenant_id, 'TENANT',
            lower(v_email), v_first_name, v_last_name,
            v_first_name || ' ' || v_last_name, v_mobile,
            v_language_id, v_dept_id,
            true,
            true,   -- force password reset on first login
            NULL,   -- no password yet — user sets via token link
            v_system_user_id, v_system_user_id
        )
        RETURNING id INTO v_user_id;
        RAISE NOTICE 'Admin user created: % (%)', v_email, v_user_id;
    ELSE
        RAISE NOTICE 'User % already exists — skipping.', v_email;
    END IF;

    -- =====================================================
    -- 8. ASSIGN AUDIT_ADMIN ROLE TO USER
    -- =====================================================
    SELECT id INTO v_role_id
    FROM platform.role
    WHERE tenant_id  = v_tenant_id
      AND product_id = v_product_id
      AND code       = 'AUDIT_ADMIN';

    IF v_role_id IS NULL THEN
        RAISE EXCEPTION
            'AUDIT_ADMIN role not found for tenant %. Ensure step 3 completed.', v_code;
    END IF;

    INSERT INTO platform.user_role (
        tenant_id, user_id, role_id,
        created_by, last_updated_by
    ) VALUES (
        v_tenant_id, v_user_id, v_role_id,
        v_system_user_id, v_system_user_id
    )
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'AUDIT_ADMIN role assigned to user %.', v_email;

    -- =====================================================
    -- 9. CREATE SET_PASSWORD TOKEN FOR ADMIN USER
    -- =====================================================
    INSERT INTO platform.user_tokens (
        tenant_id, user_id,
        token, type, expiry,
        used,
        created_by, last_updated_by
    ) VALUES (
        v_tenant_id, v_user_id,
        gen_random_uuid(), 'SET_PASSWORD',
        now() + INTERVAL '72 hours',
        false,
        v_system_user_id, v_system_user_id
    )
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'SET_PASSWORD token created. Valid for 72 hours.';
    
    
    -- =====================================================
    -- 10. CREATE DEFAULT CONFIGURATION FOR TENANT
    -- =====================================================
       
	INSERT INTO platform.tenant_config
    (tenant_id, product_id, config_key, config_value, description,
     value_type, allowed_values, created_by, last_updated_by)
	VALUES

    (v_tenant_id,
     (SELECT id FROM platform.product WHERE code = 'AUDIT'),
     'checklist_requires_approval', 'true',
     'Whether audit schedule requires approval before execution',
     'BOOLEAN', 'true,false',
     v_system_user_id, v_system_user_id);
     
     RAISE NOTICE 'Default Configuration for Tenant created.';

    -- =====================================================
    -- SUMMARY
    -- =====================================================
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Tenant onboarding complete.';
    RAISE NOTICE 'Tenant  : % (%)', v_name, v_tenant_id;
    RAISE NOTICE 'Product : %',     v_product_code;
    RAISE NOTICE 'Site    : % (%)', v_site_name, v_site_id;
    RAISE NOTICE 'Dept    : % (%)', v_dept_name, v_dept_id;
    RAISE NOTICE 'Admin   : %', v_email;
    RAISE NOTICE '-------------------------------------------------';
    RAISE NOTICE 'NEXT STEP: Run the following query to get the';
    RAISE NOTICE 'SET_PASSWORD token and send setup link to %', v_email;
    RAISE NOTICE '';
    RAISE NOTICE 'SELECT u.email, ut.token, ut.expiry';
    RAISE NOTICE 'FROM platform.user_tokens ut';
    RAISE NOTICE 'JOIN platform.users u ON u.id = ut.user_id';
    RAISE NOTICE 'JOIN platform.tenant t ON t.id = ut.tenant_id';
    RAISE NOTICE 'WHERE t.code = ''%''', v_code;
    RAISE NOTICE '  AND ut.type = ''SET_PASSWORD''';
    RAISE NOTICE '  AND ut.used = false;';
    RAISE NOTICE '=================================================';

END $$;
