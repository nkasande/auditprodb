-- =========================================================
-- 07_seed_roles_permissions.sql
-- Seed data for products, permissions, roles, role_permission
-- Execute AFTER all schema scripts (01 through 06)
-- =========================================================

-- =========================================================
-- 0. Add PLATFORM product (for platform-level permissions)
-- =========================================================
INSERT INTO platform.product (code, name, description, created_by)
VALUES ('PLATFORM', 'Platform', 'Platform administration product for managing tenants and subscriptions.',
        '00000000-0000-0000-0000-000000000000')
ON CONFLICT DO NOTHING;

-- =========================================================
-- 1. PERMISSIONS — platform product
-- =========================================================
INSERT INTO platform.permission (product_id, resource, action, description, created_by)
SELECT p.id, v.resource, v.action, v.description,
       '00000000-0000-0000-0000-000000000000'
FROM platform.product p,
(VALUES
    ('platform.tenant',                 'CREATE',   'Create a new tenant'),
    ('platform.tenant',                 'VIEW',     'View tenant details'),
    ('platform.tenant',                 'UPDATE',   'Update tenant details'),
    ('platform.tenant',                 'DELETE',   'Delete a tenant'),
    ('platform.tenant_config',          'CREATE',   'Create a new tenant level configuration'),
    ('platform.tenant_config',          'VIEW',     'View all tenant level configuration details'),
    ('platform.tenant_config',          'UPDATE',   'Update tenant level configuration'),
    ('platform.tenant_config',          'DELETE',   'Delete a tenan level configuration'),
    ('platform.subscription',           'CREATE',   'Create a subscription'),
    ('platform.subscription',           'VIEW',     'View subscription details'),
    ('platform.subscription',           'UPDATE',   'Update a subscription'),
    ('platform.subscription',           'DELETE',   'Delete a subscription'),
    ('platform.product',                'CREATE',   'Create a product'),
    ('platform.product',                'VIEW',     'View product details'),
    ('platform.product',                'UPDATE',   'Update product details'),
    ('platform.product',                'DELETE',   'Delete a product'),
    ('platform.language',               'CREATE',   'Create a new language'),
    ('platform.language',               'VIEW',     'View languages'),
    ('platform.language',               'UPDATE',   'Update a language'),
    ('platform.language',               'DELETE',   'Delete a language'),
    ('platform.country',                'CREATE',   'Add a country'),
    ('platform.country',                'VIEW',     'View countries'),
    ('platform.country',                'UPDATE',   'Update a country'),
    ('platform.country',                'DELETE',   'Delete a country'),
    ('platform.state',                  'CREATE',   'Add a state'),
    ('platform.state',                  'VIEW',     'View states'),
    ('platform.state',                  'UPDATE',   'Update a state'),
    ('platform.state',                  'DELETE',   'Delete a state'),
    ('platform.audit_retention_policy', 'CREATE',   'Create retention policy'),
    ('platform.audit_retention_policy', 'VIEW',     'View retention policies'),
    ('platform.audit_retention_policy', 'UPDATE',   'Update retention policy'),
    ('platform.audit_retention_policy', 'DELETE',   'Delete retention policy'),
    ('platform.audit_log',              'VIEW',     'View audit logs'),
    ('platform.permission',              'CREATE',  'Create permission'),
    ('platform.permission',              'VIEW',    'View all permissions'),
    ('platform.permission',              'UPDATE',  'Update permission'),
    ('platform.permission',              'DELETE',  'Delete permission')

) AS v(resource, action, description)
WHERE p.code = 'PLATFORM'
ON CONFLICT DO NOTHING;

-- =========================================================
-- 2. PERMISSIONS — audit product
-- =========================================================
INSERT INTO platform.permission (product_id, resource, action, description, created_by)
SELECT p.id, v.resource, v.action, v.description,
       '00000000-0000-0000-0000-000000000000'
FROM platform.product p,
(VALUES
    -- master data controlled by platform admin. Only view access for audit users
    ('platform.language',               'VIEW',     'View languages'),
	('platform.country',                'VIEW',     'View countries'),
	('platform.state',                  'VIEW',     'View states'),
	-- Users (managed by AUDIT_ADMIN under AUDIT product)
    ('platform.users',              'CREATE',       'Create a user'),
    ('platform.users',              'VIEW',         'View user details'),
    ('platform.users',              'UPDATE',       'Update user details'),
    ('platform.users',              'DELETE',       'Delete a user'),
    ('platform.users',              'DEACTIVATE',   'Reset user password'),
    -- AUDIT_ADMIN permissions for tenant config
	('platform.tenant_config', 		'VIEW',   		'View tenant configuration'),
	('platform.tenant_config', 		'UPDATE', 		'Update tenant configuration'),
    -- Roles & permissions
    ('platform.role',               'CREATE',       'Create a role'),
    ('platform.role',               'VIEW',         'View roles'),
    ('platform.role',               'UPDATE',       'Update a role'),
    ('platform.role',               'DELETE',       'Delete a role'),
    ('platform.permission',         'VIEW',         'View permissions'),
    ('platform.role_permission',    'CREATE',       'Assign permission to role'),
    ('platform.role_permission',    'VIEW',         'View role permissions'),
    ('platform.role_permission',    'DELETE',       'Remove permission from role'),
    ('platform.user_role',          'CREATE',       'Assign role to user'),
    ('platform.user_role',          'VIEW',         'View user roles'),
    ('platform.user_role',          'DELETE',       'Remove role from user'),
    -- Sites & departments
    ('platform.site',               'CREATE',       'Create a site'),
    ('platform.site',               'VIEW',         'View site details'),
    ('platform.site',               'UPDATE',       'Update a site'),
    ('platform.site',               'DELETE',       'Delete a site'),
    ('platform.department',         'CREATE',       'Create a department'),
    ('platform.department',         'VIEW',         'View department details'),
    ('platform.department',         'UPDATE',       'Update a department'),
    ('platform.department',         'DELETE',       'Delete a department'),
    -- Audit types
    ('audit.audit_type',            'CREATE',       'Create audit type'),
    ('audit.audit_type',            'VIEW',         'View audit types'),
    ('audit.audit_type',            'UPDATE',       'Update audit type'),
    ('audit.audit_type',            'DELETE',       'Delete audit type'),
    -- Audit templates
    ('audit.audit_template',        'CREATE',       'Create audit template'),
    ('audit.audit_template',        'VIEW',         'View audit templates'),
    ('audit.audit_template',        'UPDATE',       'Update audit template'),
    ('audit.audit_template',        'DELETE',       'Delete audit template'),
    -- Template versions
    ('audit.template_version',      'CREATE',       'Create template version'),
    ('audit.template_version',      'VIEW',         'View template versions'),
    ('audit.template_version',      'UPDATE',       'Update template version'),
    ('audit.template_version',      'DELETE',       'Delete template version'),
    ('audit.template_version',      'APPROVE_L2',   'Second level approval of template version'),
    -- Template sections
    ('audit.template_section',      'CREATE',       'Create template section'),
    ('audit.template_section',      'VIEW',         'View template sections'),
    ('audit.template_section',      'UPDATE',       'Update template section'),
    ('audit.template_section',      'DELETE',       'Delete template section'),
    -- Template items
    ('audit.template_item',         'CREATE',       'Create template item'),
    ('audit.template_item',         'VIEW',         'View template items'),
    ('audit.template_item',         'UPDATE',       'Update template item'),
    ('audit.template_item',         'DELETE',       'Delete template item'),
    -- Schedules
    ('audit.audit_schedule',        'CREATE',       'Create audit schedule'),
    ('audit.audit_schedule',        'VIEW',         'View audit schedules'),
    ('audit.audit_schedule',        'UPDATE',       'Update audit schedule'),
    ('audit.audit_schedule',        'DELETE',       'Delete audit schedule'),
    ('audit.audit_schedule',        'SUBMIT',       'Submit CAPAs for review (auditee action)'),
    ('audit.audit_schedule',        'APPROVE_L1',   'First level CAPA review approval (auditor action)'),
    ('audit.audit_schedule',        'APPROVE_L2',   'Second level approval of audit schedule'),

    -- Execution
    ('audit.audit_execution',       'CREATE',       'Create audit execution'),
    ('audit.audit_execution',       'VIEW',         'View audit executions'),
    ('audit.audit_execution',       'UPDATE',       'Update audit execution'),
    ('audit.audit_execution',       'CANCEL',       'Cancel an audit execution'),
    ('audit.audit_execution',       'APPROVE_L2',   'Approval for audit execution'),
    -- Responses
    ('audit.response',              'CREATE',       'Create audit response'),
    ('audit.response',              'VIEW',         'View audit responses'),
    ('audit.response',              'UPDATE',       'Update audit response'),
    -- CAPA
    ('audit.capa',                  'CREATE',       'Create CAPA'),
    ('audit.capa',                  'VIEW',         'View CAPAs'),
    ('audit.capa',                  'UPDATE',       'Update CAPA'),
    ('audit.capa',                  'DELETE',       'Delete CAPA'),
    ('audit.capa',                  'SUBMIT',       'Submit CAPA for closure review'),
    ('audit.capa', 					'REASSIGN', 	'Reassign CAPA to another user'),
    -- Attachments
    ('audit.attachment',         'CREATE',       'Add attachments'),
    ('audit.attachment',         'VIEW',         'View attachments'),
    ('audit.attachment',         'DELETE',       'Delete only own attachments'),
    -- Action history - comments and approvals/rejections
    ('audit.action_history',         'CREATE',       'Add comments or approve/reject'),
    ('audit.action_history',         'VIEW',         'View comments or approve/reject history'),
    ('audit.action_history',         'DELETE',       'Delete comments or approve/reject history'),
    
    -- ######################################################################################################
    -- approval (#################### This is only resource which is NOT actual database table. #############
    -- ######################################################################################################
     ('audit.approval',         'VIEW',       'To see the pending approvals for himself/herself')
) AS v(resource, action, description)
WHERE p.code = 'AUDIT'
ON CONFLICT DO NOTHING;

-- =========================================================
-- 3. ROLES — seeded for SYSTEM tenant as templates
--    When a new tenant is onboarded, copy these roles for
--    that tenant (tenant_id = new tenant's id)
-- =========================================================
INSERT INTO platform.role (tenant_id, product_id, code, name, description, created_by)
SELECT
    t.id,
    p.id,
    v.code,
    v.name,
    v.description,
    '00000000-0000-0000-0000-000000000000'
FROM platform.tenant t, platform.product p,
(VALUES
    ('PLATFORM', 'PLATFORM_ADMIN', 'Platform Administrator',
     'Full access to platform management. Manages tenants, subscriptions, products and reference data. No access to tenant business data.')
) AS v(product_code, code, name, description)
WHERE t.code = 'SYSTEM'
  AND p.code = v.product_code
ON CONFLICT DO NOTHING;

-- =========================================================
-- 4. ROLE_PERMISSION — map roles to permissions - PLATFORM product
-- =========================================================

-- ── PLATFORM_ADMIN ──────────────────────────────────────
INSERT INTO platform.role_permission (tenant_id, role_id, permission_id, created_by)
SELECT r.tenant_id, r.id, perm.id,
       '00000000-0000-0000-0000-000000000000'
FROM platform.role r
JOIN platform.tenant t ON t.id = r.tenant_id AND t.code = 'SYSTEM'
JOIN platform.product prod ON prod.id = r.product_id AND prod.code = 'PLATFORM'
JOIN platform.permission perm ON perm.product_id = prod.id
WHERE r.code = 'PLATFORM_ADMIN'
ON CONFLICT DO NOTHING;


-- =========================================================
-- 5. USER_ROLE — assign PLATFORM_ADMIN role to SYSTEM user
-- =========================================================
INSERT INTO platform.user_role (tenant_id, user_id, role_id, created_by, last_updated_by)
SELECT
    t.id,
    u.id,
    r.id,
    u.id,
    u.id
FROM platform.users u
JOIN platform.tenant t ON t.id = u.tenant_id AND t.code = 'SYSTEM'
JOIN platform.role r ON r.tenant_id = t.id AND r.code = 'PLATFORM_ADMIN'
WHERE u.email = 'admin@auditpro.in'
ON CONFLICT DO NOTHING;


-- =========================================================
-- END OF SCRIPT
-- =========================================================
-- NOTE:
-- Tenant-specific roles (AUDIT_ADMIN, QA_MANAGER, MANAGER,
-- AUDITOR, AUDITEE, VIEWER) are created during tenant
-- onboarding via 08_onboard_tenant.sql.
-- =========================================================
