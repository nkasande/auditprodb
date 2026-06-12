
-- =========================================================
-- 02_audit_schema.sql
-- Audit Business Schema + RBAC
-- =========================================================

CREATE SCHEMA IF NOT EXISTS audit AUTHORIZATION platform_owner;

-- audit type table

CREATE TABLE IF NOT EXISTS audit.audit_type (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id) ON DELETE CASCADE,

    code        VARCHAR(20) NOT NULL, -- TODO should code have only upto 6 chars?
    name        VARCHAR(100) NOT NULL,

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

CREATE UNIQUE INDEX IF NOT EXISTS ux_audit_type_code
ON audit.audit_type (tenant_id, code) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_audit_type_tenant ON audit.audit_type (tenant_id);

--audit template (definition) table

CREATE TABLE IF NOT EXISTS audit.audit_template (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),

    code	    VARCHAR(20) NOT NULL,	
    name            VARCHAR(100) NOT NULL,
    description     VARCHAR(255),
    audit_type_id   UUID NOT NULL REFERENCES audit.audit_type(id),
    
    is_scoring_enabled 	BOOLEAN NOT NULL DEFAULT true,
    enable_weightage 	BOOLEAN NOT NULL DEFAULT true,
    
    score_type VARCHAR(20) NOT NULL DEFAULT 'NUMERIC'
    		CHECK (score_type IN ('NUMERIC', 'ALPHABETIC')),
    
    max_score 	INTEGER, -- filled in only if score_type is 'NUMERIC'
    
	schedule_approval_required  BOOLEAN NOT NULL DEFAULT false,
	execution_approval_required BOOLEAN NOT NULL DEFAULT false,
	closure_approval_required   BOOLEAN NOT NULL DEFAULT false,
    
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

CREATE UNIQUE INDEX IF NOT EXISTS ux_audit_template_code
ON audit.audit_template (tenant_id, code) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_audit_template_tenant ON audit.audit_template (tenant_id);

CREATE INDEX IF NOT EXISTS idx_audit_template_type ON audit.audit_template (audit_type_id);

-- audit template versions

CREATE TABLE IF NOT EXISTS audit.template_version (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),

    audit_template_id UUID NOT NULL  REFERENCES audit.audit_template(id),
    version         INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL
    	CONSTRAINT chk_template_version_status
    	CHECK (status IN ('DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'ARCHIVED'))
    	DEFAULT 'DRAFT',
    
    -- not null if tenant level config IS_TEMPLATE_VERSION_APPROVAL_REQUIRED = true
    approver_id UUID REFERENCES platform.users(id),

    -- edit lock: set while user is actively editing; NULL = unlocked
    locked_for_edit_by UUID REFERENCES platform.users(id),
    locked_at          TIMESTAMPTZ, -- when the lock was acquired; used for stale-lock expiry

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

CREATE UNIQUE INDEX IF NOT EXISTS ux_template_version
ON audit.template_version (tenant_id, audit_template_id, version) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_template_version_tenant ON audit.template_version (tenant_id);

CREATE INDEX IF NOT EXISTS idx_tv_template_version_lookup 
ON audit.template_version (tenant_id, audit_template_id, version);

--Trigger to set appropriate template version
CREATE OR REPLACE FUNCTION audit.set_template_version()
RETURNS TRIGGER AS $$
DECLARE
    next_version INTEGER;
BEGIN
    -- Lock per (tenant_id + template_id)
	PERFORM pg_advisory_xact_lock(
	    hashtext(NEW.tenant_id::text),
	    hashtext(NEW.audit_template_id::text)
	);
	
	SELECT COALESCE(MAX(version), 0) + 1
	INTO next_version
	FROM audit.template_version
	WHERE tenant_id = NEW.tenant_id
	  AND audit_template_id = NEW.audit_template_id
	  AND is_deleted = false;

    NEW.version := next_version;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--attach the trigger to the table before insert
CREATE TRIGGER trg_set_template_version
BEFORE INSERT ON audit.template_version
FOR EACH ROW
WHEN (NEW.version IS NULL)
EXECUTE FUNCTION audit.set_template_version();


CREATE TABLE IF NOT EXISTS audit.template_section (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),

    template_version_id UUID NOT NULL  REFERENCES audit.template_version(id),

    parent_section_id UUID REFERENCES audit.template_section(id),
    level             INTEGER NOT NULL DEFAULT 0,

    number	INT NOT NULL,
    name	VARCHAR(100) NOT NULL,	
    
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

CREATE UNIQUE INDEX ux_section_number_per_parent
ON audit.template_section (template_version_id, number, COALESCE(parent_section_id, '00000000-0000-0000-0000-000000000000'::uuid))
WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_template_section_tenant ON audit.template_section (tenant_id);

CREATE INDEX IF NOT EXISTS idx_template_section_version ON audit.template_section (template_version_id);

CREATE INDEX IF NOT EXISTS idx_template_section_parent ON audit.template_section(parent_section_id)
 WHERE parent_section_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_template_section_version_level ON audit.template_section(template_version_id, level);

--audit template item (each question in the template - i.e. particular version of audit definition)

CREATE TABLE IF NOT EXISTS audit.template_item (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),

    section_id	    UUID NOT NULL REFERENCES audit.template_section(id),
    sequence_no     INTEGER NOT NULL,

    question_text   VARCHAR(255) NOT NULL,  -- user should be able to upload attachments also
    weightage	    INTEGER, 		
    is_mandatory    BOOLEAN DEFAULT FALSE,

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

CREATE INDEX IF NOT EXISTS idx_template_item_tenant ON audit.template_item (tenant_id);

CREATE INDEX IF NOT EXISTS idx_template_item_section ON audit.template_item (section_id);

-- audit schedule (planning layer)
-- do we really need status column here too? Are people going to approve the schedule also?

CREATE TABLE IF NOT EXISTS audit.audit_schedule (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),

    audit_template_id   UUID NOT NULL  REFERENCES audit.audit_template(id),
    scheduled_date      DATE NOT NULL,

    name				VARCHAR(50), -- name of audit instance being planned
    status              VARCHAR(20) NOT NULL DEFAULT 'PENDING_APPROVAL', 
	cancellation_status VARCHAR(20), 
	edit_status			VARCHAR(20),
	
	site_id       UUID REFERENCES platform.site(id),
    department_id UUID REFERENCES platform.department(id),

    -- assignments
    auditor_id  UUID REFERENCES platform.users(id),
    auditee_id  UUID REFERENCES platform.users(id),
    
    schedule_approver	UUID REFERENCES platform.users(id),
	execution_approver	UUID REFERENCES platform.users(id),
	closure_approver	UUID REFERENCES platform.users(id),


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
    
    CONSTRAINT schedule_status_chk
        CHECK (status IN ('DRAFT', 'PENDING_APPROVAL','PLANNED', 'IN_PROGRESS', 'EXECUTION_REVIEW',
        	'ACTION_REQUIRED', 'CAPA_REVIEW', 'FINAL_APPROVAL', 'CLOSED',  'CANCELLED')),
    
    -- -----------------------------
    -- Cancellation constraint
    -- Only REQUESTED or NULL
    -- -----------------------------
    CONSTRAINT schedule_cancellation_chk
    CHECK (
        cancellation_status IS NULL
        OR (status = 'PLANNED' AND cancellation_status = 'REQUESTED')
    ),
    
        -- -----------------------------
    -- Edit workflow constraint
    -- -----------------------------
    CONSTRAINT schedule_edit_chk
    CHECK (
        edit_status IS NULL
        OR (status = 'PLANNED' AND edit_status = 'REQUESTED')
	),
	
	    -- -----------------------------
    -- Prevent simultaneous workflows
    -- -----------------------------
    CONSTRAINT schedule_single_workflow_chk
    CHECK (
        NOT (
            cancellation_status = 'REQUESTED'
            AND edit_status = 'REQUESTED'
        )
    ),
	
	CONSTRAINT chk_scope_site_department
    CHECK (
        site_id IS NOT NULL
        OR department_id IS NULL
    )
);

CREATE INDEX IF NOT EXISTS idx_schedule_tenant ON audit.audit_schedule (tenant_id);

CREATE INDEX IF NOT EXISTS idx_schedule_template_date ON audit.audit_schedule (audit_template_id, scheduled_date);

CREATE INDEX IF NOT EXISTS idx_schedule_date ON audit.audit_schedule (scheduled_date);

CREATE INDEX IF NOT EXISTS idx_schedule_site ON audit.audit_schedule (site_id) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_schedule_department ON audit.audit_schedule (department_id) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_schedule_auditor ON audit.audit_schedule (auditor_id) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_schedule_auditee ON audit.audit_schedule (auditee_id) WHERE is_deleted = false;

-- unique index for global scope (no site, no department) 
CREATE UNIQUE INDEX ux_schedule_global_scope
ON audit.audit_schedule (audit_template_id, scheduled_date)
WHERE site_id IS NULL
  AND department_id IS NULL
  AND is_deleted = false;

-- unique index for site scope (if site is defined and department is null, scope is for full site. 
-- In that case we cannot have two records with same site)
CREATE UNIQUE INDEX ux_schedule_site_scope
ON audit.audit_schedule (audit_template_id, scheduled_date, site_id)
WHERE site_id IS NOT NULL
  AND department_id IS NULL
  AND is_deleted = false;
  
-- unique index for site + department scope  
CREATE UNIQUE INDEX ux_schedule_site_dept_scope
ON audit.audit_schedule (audit_template_id, scheduled_date, site_id, department_id)
WHERE site_id IS NOT NULL
  AND department_id IS NOT NULL
  AND is_deleted = false;
  
  
  
CREATE TABLE IF NOT EXISTS audit.audit_schedule_draft (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),

    schedule_id UUID NOT NULL REFERENCES audit.audit_schedule(id),

    -- proposed changes (same structure as main table)
    audit_template_id   UUID NOT NULL  REFERENCES audit.audit_template(id),
    scheduled_date      DATE NOT NULL,
    
    name  VARCHAR(50), -- name of audit instance being planned
	
	site_id       UUID REFERENCES platform.site(id),
    department_id UUID REFERENCES platform.department(id),

    -- assignments
    auditor_id  UUID REFERENCES platform.users(id),
    auditee_id  UUID REFERENCES platform.users(id),

	schedule_approver	UUID REFERENCES platform.users(id),
	execution_approver	UUID REFERENCES platform.users(id),
	closure_approver	UUID REFERENCES platform.users(id),
	    
    -- this field is needed since in some scenarios created by is not the same as requested_by
    -- for example, one person (system admin) doing updates on behalf of manager (future scenario)
    -- migration script - created by system. Requested by some actual user.
    requested_by UUID NOT NULL REFERENCES platform.users(id),

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

    CONSTRAINT chk_draft_scope_site_department
    CHECK (
        site_id IS NOT NULL
        OR department_id IS NULL
    )
);    
  
CREATE UNIQUE INDEX ux_schedule_draft_active ON audit.audit_schedule_draft (schedule_id)
WHERE is_deleted = false;

CREATE INDEX idx_schedule_draft_tenant ON audit.audit_schedule_draft (tenant_id);


-- audit execution (actual run)

CREATE TABLE IF NOT EXISTS audit.audit_execution (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),

    audit_schedule_id   UUID NOT NULL REFERENCES audit.audit_schedule(id),
    template_version_id UUID NOT NULL REFERENCES audit.template_version(id), -- locked at execution start

    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    capa_due_date	DATE, -- auditor will enter this date when he submits the audit
    
    total_weighted_score	INTEGER, 
    percentage_score 		NUMERIC(5,2),
    
    status  VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS', -- record will be created in this table when audit starts
    
    -- columns needed for offline audit
    sync_id 			UUID,   -- stores client sync session id for idempotency
    checked_out_at 		timestamptz, 
    checked_out_by 		UUID REFERENCES platform.users(id),
    synced_at 			timestamptz,
    

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
    CONSTRAINT execution_status_chk
        CHECK (status IN ('IN_PROGRESS', 'CHECKED_OUT', 'COMPLETED'))
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_execution_per_schedule
ON audit.audit_execution (tenant_id, audit_schedule_id) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_audit_execution_tenant ON audit.audit_execution (tenant_id);

CREATE INDEX IF NOT EXISTS idx_audit_execution_schedule ON audit.audit_execution (audit_schedule_id);

CREATE INDEX IF NOT EXISTS idx_audit_execution_status ON audit.audit_execution (status);

-- audit_execution: partial unique on sync_id, skips NULLs (most rows never synced).
--    Pure data-integrity guard; no ON CONFLICT needed here.
CREATE UNIQUE INDEX IF NOT EXISTS uq_audit_execution_sync_id
    ON audit.audit_execution (sync_id)
    WHERE sync_id IS NOT NULL;

-- audit response per question (response of each item in the execution)

CREATE TABLE IF NOT EXISTS audit.response (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),

    execution_id        UUID NOT NULL  REFERENCES audit.audit_execution(id),
    template_item_id    UUID NOT NULL  REFERENCES audit.template_item(id),
    
    answer_boolean	BOOLEAN,
    requires_action BOOLEAN default false,
    needs_improvement BOOLEAN default false,
    
	score INTEGER,
    weighted_score	INTEGER,
    severity    VARCHAR(20),
    CHECK (severity IS NULL OR severity IN ('MAJOR', 'MINOR')),
	
    observation VARCHAR(4000),
    
    -- columns needed for offline audit
    client_created_at	timestamptz,   -- when did the auditor enter the response offline?

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

CREATE UNIQUE INDEX IF NOT EXISTS ux_response_per_item
ON audit.response (tenant_id, execution_id, template_item_id) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_response_tenant ON audit.response (tenant_id);

CREATE INDEX IF NOT EXISTS idx_response_execution ON audit.response (execution_id);

CREATE INDEX IF NOT EXISTS idx_response_template_item ON audit.response (template_item_id);

-- findings per non-compliance (CAPA foundation) CAPA = corrective action and preventive action
-- one entry in this table for each capa item created by auditor or auditee
-- multiple capa items can be created for a single response by various people at various stages

CREATE TABLE IF NOT EXISTS audit.capa (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),
    
    title				VARCHAR(50) NOT NULL,
    response_id         UUID NOT NULL REFERENCES audit.response(id),
    execution_id        UUID NOT NULL, -- added to ensure title is unique across execution

    root_cause			VARCHAR(4000),
    additional_notes    VARCHAR(4000),
    corrective_action   VARCHAR(4000),
    preventive_action   VARCHAR(4000),
    
    responsible_user_id UUID REFERENCES platform.users(id),
    reassignment_due_date DATE, --auditee will enter this if he reassigns CAPA. Not tracking of this for now.
    
    status              VARCHAR(30) NOT NULL DEFAULT 'OPEN',

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
	-- TODO check values of severity and status below with Mayur
    CONSTRAINT capa_status_chk
        CHECK (status IN ('OPEN', 'REASSIGNED', 'PENDING_AUDITEE_APPROVAL', 'SUBMITTED')),
        
    CONSTRAINT fk_capa_execution 
    	FOREIGN KEY (execution_id) REFERENCES audit.audit_execution(id)
);

CREATE INDEX IF NOT EXISTS idx_capa_tenant ON audit.capa (tenant_id);

CREATE INDEX IF NOT EXISTS idx_capa_response ON audit.capa (response_id);

CREATE INDEX IF NOT EXISTS idx_capa_responsible_user ON audit.capa (responsible_user_id);

CREATE INDEX IF NOT EXISTS idx_capa_status ON audit.capa (status);

CREATE INDEX IF NOT EXISTS idx_capa_execution ON audit.capa (execution_id);

-- below index esnures case-insensitive unique title per execution
CREATE UNIQUE INDEX IF NOT EXISTS ux_capa_title_per_execution
ON audit.capa (tenant_id, execution_id, LOWER(title))
WHERE is_deleted = false;

-- stores comments and approval/rejection actions on various entities
CREATE TABLE IF NOT EXISTS audit.action_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES platform.tenant(id),

    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,

    action_type VARCHAR(50) NOT NULL,

    comments TEXT,

    is_deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid NOT NULL REFERENCES platform.users(id),
    last_updated_at timestamptz NOT NULL DEFAULT now(),
    last_updated_by uuid REFERENCES platform.users(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES platform.users(id),
    
    CONSTRAINT chk_delete_metadata CHECK (
        (is_deleted = false AND deleted_at IS NULL AND deleted_by IS NULL)
        OR
        (is_deleted = true AND deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
    ),

    CONSTRAINT chk_entity_type CHECK (
        entity_type IN (
            'audit.audit_schedule',
            'audit.template_version',
            'audit.audit_execution',
            'audit.response',
            'audit.capa'
        )
    ),

    CONSTRAINT chk_action_type CHECK (
        action_type IN ('SUBMITTED', 'APPROVED', 'REJECTED', 'COMMENTED',
        'CANCELLATION_SUBMITTED', 'CANCELLATIONAPPROVED', 'CANCELLATIONREJECTED',
        'EDIT_SUBMITTED', 'EDITAPPROVED', 'EDITREJECTED', 
        'EXECUTION_SUBMITTED', 'EXECUTIONAPPROVED', 'EXECUTIONREJECTED',
        'CAPA_SUBMITTED', 'CAPA_APPROVED', 'CAPA_REJECTED',
        'FINAL_APPROVAL_CAPA_REJECTED',
        'CAPA_REVIEW_SUBMITTED', 'CAPA_REVIEW_APPROVED', 'CAPA_REVIEW_REJECTED',
        'CLOSURE_APPROVED', 'CLOSURE_REJECTED')
    ),

    CONSTRAINT chk_comment_rule CHECK (
        action_type IN ('APPROVED', 'CANCELLATIONAPPROVED', 'EDITAPPROVED', 'EXECUTIONAPPROVED', 'CLOSUREAPPROVED', 'CAPA_APPROVED', 'CAPA_REVIEW_APPROVED')
        OR comments IS NOT NULL
    )
);

CREATE INDEX IF NOT EXISTS idx_action_history_entity
    ON audit.action_history (tenant_id, entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_action_history_created_at
    ON audit.action_history (created_at DESC);
    

CREATE TABLE IF NOT EXISTS audit.attachment (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES platform.tenant(id),

    entity_type VARCHAR(100) NOT NULL, -- e.g. 'audit.capa', 'audit.response'
    entity_id   UUID NOT NULL,         -- ID of the parent entity

    file_key    VARCHAR(500) NOT NULL, -- storage key used to generate download URL
    file_name   VARCHAR(255) NOT NULL, -- original file name shown to user
    
    
    -- columns needed for offline audit
    client_ref_id		UUID,		 -- client generated idempotency key per attachment
    client_created_at	timestamptz, -- when was attachment created offline?

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
    
    CONSTRAINT chk_entity_type CHECK (
        entity_type IN (
            'audit.template_version',
            'audit.template_section',
            'audit.template_item',
            'audit.response',
            'audit.capa'
        )
    )

);

CREATE INDEX IF NOT EXISTS idx_attachment_tenant
    ON audit.attachment (tenant_id);

CREATE INDEX IF NOT EXISTS idx_attachment_entity
    ON audit.attachment (entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_attachment_created_by
    ON audit.attachment (created_by);

--  attachment: partial unique on client_ref_id, skips NULLs (regular attachments)
--    and soft-deleted rows so a physical re-insert after soft-delete is possible.
CREATE UNIQUE INDEX IF NOT EXISTS uq_attachment_client_ref_id
    ON audit.attachment (client_ref_id)
    WHERE client_ref_id IS NOT NULL
      AND is_deleted = false;
      
-- =========================================================
-- function and trigger to maintain proper state transition in audit.template_version table.
-- allowed transitions are DRAFT -> PENDING_APPROVAL, PENDING_APPROVAL -> 'APPROVED', 'DRAFT'
-- APPROVED -> ARCHIVED
-- =========================================================
CREATE OR REPLACE FUNCTION enforce_template_version_transition()
RETURNS trigger AS $$
BEGIN
    -- Only check if status changes
    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;

    -- Allowed transitions
    IF OLD.status = 'DRAFT' AND NEW.status IN ('PENDING_APPROVAL', 'APPROVED') THEN
        NULL;
    ELSIF OLD.status = 'PENDING_APPROVAL' AND NEW.status IN ('APPROVED', 'DRAFT') THEN
        NULL;
    ELSIF OLD.status = 'APPROVED' AND NEW.status = 'ARCHIVED' THEN
        NULL;
    ELSE
        RAISE EXCEPTION
            'Invalid status transition from % to %',
            OLD.status, NEW.status;
    END IF;
    
    -- if new status is approved, update the status of earlier approved version to archived
    IF NEW.status = 'APPROVED' THEN
    UPDATE audit.template_version
    SET status = 'ARCHIVED'
    WHERE audit_template_id = NEW.audit_template_id
      AND status = 'APPROVED'
      AND id <> NEW.id;
    END IF;

    RETURN NEW;     

END;
$$ LANGUAGE plpgsql;


-- attach trigger to this function

CREATE TRIGGER trg_enforce_template_version_transition
BEFORE UPDATE ON audit.template_version
FOR EACH ROW
EXECUTE FUNCTION enforce_template_version_transition();

-- ensure only one approved version per template

CREATE UNIQUE INDEX IF NOT EXISTS ux_one_approved_per_template
ON audit.template_version(audit_template_id)
WHERE status = 'APPROVED'
  AND deleted_at IS NULL;

-- following index will make the queries to get template_versions with specific status fast.
CREATE INDEX IF NOT EXISTS idx_template_status_lookup ON audit.template_version(audit_template_id, status);
