CREATE SCHEMA IF NOT EXISTS infra AUTHORIZATION platform_owner;;

CREATE TABLE IF NOT EXISTS infra.failed_message (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES platform.tenant(id),

    message_type VARCHAR(50) NOT NULL
    CONSTRAINT chk_failed_message_type
    	CHECK (message_type IN ('EMAIL', 'SMS')),
 
    payload JSONB NOT NULL,

    status VARCHAR(20) NOT NULL
    CONSTRAINT chk_failed_message_status
    	CHECK (status IN ('FAILED', 'RETRYING', 'SUCCESS', 'REQUIRES_ATTENTION' ,'PERMANENT_FAILURE'))
    	DEFAULT 'FAILED',

    retry_count INT DEFAULT 0,
    max_retries INT DEFAULT 3,
    next_retry_at TIMESTAMPTZ DEFAULT now(),

    error_message TEXT,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);