-- =========================================================
-- create base data
-- =========================================================

-- insert products
INSERT INTO platform.product (code, name, description, created_by)
VALUES
('AUDIT','Audit Monitoring System', 'Audit planning, executing and reporting tool.', '00000000-0000-0000-0000-000000000000'),
('MES','Manufacturing Execution System', 'Manufacturing Execution System', '00000000-0000-0000-0000-000000000000')
ON CONFLICT DO NOTHING;

-- is there any need to insert one user?


INSERT INTO platform.audit_retention_policy (schema_name, table_name, retention_class, created_by)
VALUES
-- platform: compliance-critical tables
('platform', 'language',                'LEGAL_HOLD', '00000000-0000-0000-0000-000000000000'),
('platform', 'tenant',                  'LEGAL_HOLD', '00000000-0000-0000-0000-000000000000'),
('platform', 'product',                 'LEGAL_HOLD', '00000000-0000-0000-0000-000000000000'),
('platform', 'subscription',            'LEGAL_HOLD', '00000000-0000-0000-0000-000000000000'),
('platform', 'users',                   'LEGAL_HOLD', '00000000-0000-0000-0000-000000000000'),
('platform', 'user_password_history',   'LEGAL_HOLD', '00000000-0000-0000-0000-000000000000'),
('platform', 'audit_log',               'LEGAL_HOLD', '00000000-0000-0000-0000-000000000000'),
('platform', 'audit_retention_policy',  'LEGAL_HOLD', '00000000-0000-0000-0000-000000000000'),
-- platform: reference data
('platform', 'country',                 'STANDARD', '00000000-0000-0000-0000-000000000000'),
('platform', 'state',                   'STANDARD', '00000000-0000-0000-0000-000000000000'),
-- platform: operational / config
('platform', 'tenant_config',           'STANDARD', '00000000-0000-0000-0000-000000000000'),
('platform', 'site',                    'STANDARD', '00000000-0000-0000-0000-000000000000'),
('platform', 'department',              'STANDARD', '00000000-0000-0000-0000-000000000000'),
('platform', 'user_tokens',             'STANDARD', '00000000-0000-0000-0000-000000000000'),
-- platform: RBAC
('platform', 'role',                    'STANDARD', '00000000-0000-0000-0000-000000000000'),
('platform', 'permission',              'STANDARD', '00000000-0000-0000-0000-000000000000'),
('platform', 'permission_condition',    'STANDARD', '00000000-0000-0000-0000-000000000000'),
('platform', 'role_permission',         'STANDARD', '00000000-0000-0000-0000-000000000000'),
('platform', 'user_role',               'STANDARD', '00000000-0000-0000-0000-000000000000'),
-- audit schema
('audit', 'audit_type',                 'STANDARD', '00000000-0000-0000-0000-000000000000'),
('audit', 'audit_template',             'STANDARD', '00000000-0000-0000-0000-000000000000'),
('audit', 'template_version',           'STANDARD', '00000000-0000-0000-0000-000000000000'),
('audit', 'template_section',           'STANDARD', '00000000-0000-0000-0000-000000000000'),
('audit', 'template_item',              'STANDARD', '00000000-0000-0000-0000-000000000000'),
('audit', 'audit_schedule',             'STANDARD', '00000000-0000-0000-0000-000000000000'),
('audit', 'audit_schedule_draft',       'STANDARD', '00000000-0000-0000-0000-000000000000'),
('audit', 'audit_execution',            'STANDARD', '00000000-0000-0000-0000-000000000000'),
('audit', 'response',                   'STANDARD', '00000000-0000-0000-0000-000000000000'),
('audit', 'capa',                       'STANDARD', '00000000-0000-0000-0000-000000000000'),
('audit', 'action_history',             'STANDARD', '00000000-0000-0000-0000-000000000000'),
('audit', 'attachment',                 'STANDARD', '00000000-0000-0000-0000-000000000000'),
-- infra schema
('infra', 'failed_message',             'STANDARD', '00000000-0000-0000-0000-000000000000')
ON CONFLICT DO NOTHING;

--language inserts
--English is already inserted immediately after table creation for bootstraping the SYSTEM user


-- Country inserts

INSERT INTO platform.country (code, name, created_by) VALUES ('IND', 'India', '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.country (code, name, created_by) VALUES ('USA', 'United States of America', '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.country (code, name, created_by) VALUES ('CAN', 'Canada', '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.country (code, name, created_by) VALUES ('AUS', 'Australia', '00000000-0000-0000-0000-000000000000');

-- States for IND

INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('AN', 'Andaman and Nicobar Islands', (SELECT id FROM platform.country where code = 'IND'), '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('AP', 'Andhra Pradesh', (SELECT id FROM platform.country where code = 'IND'),   '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('AR', 'Arunachal Pradesh', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('AS', 'Assam', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('BR', 'Bihar', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('CH', 'Chandigarh', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('CT', 'Chhattisgarh', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('DN', 'Dadra and Nagar Haveli and Daman and Diu', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('DL', 'Delhi', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('GA', 'Goa', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('GJ', 'Gujarat', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('HR', 'Haryana', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('HP', 'Himachal Pradesh', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('JK', 'Jammu and Kashmir', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('JH', 'Jharkhand', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('KA', 'Karnataka', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('KL', 'Kerala', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('LA', 'Ladakh', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('LD', 'Lakshadweep', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('MP', 'Madhya Pradesh', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('MH', 'Maharashtra', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('MN', 'Manipur', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('ML', 'Meghalaya', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('MZ', 'Mizoram', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NL', 'Nagaland', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('OD', 'Odisha', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('PB', 'Punjab', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('RJ', 'Rajasthan', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('SK', 'Sikkim', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('TN', 'Tamil Nadu', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('TS', 'Telangana', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('TR', 'Tripura',  (SELECT id FROM platform.country where code = 'IND'), '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('UP', 'Uttar Pradesh', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('UK', 'Uttarakhand', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('WB', 'West Bengal', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('PY', 'Puducherry', (SELECT id FROM platform.country where code = 'IND'),  '00000000-0000-0000-0000-000000000000');

-- States for USA

INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('AL', 'Alabama', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('AK', 'Alaska', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('AZ', 'Arizona', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('AR', 'Arkansas', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('CA', 'California', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('CO', 'Colorado', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('CT', 'Connecticut', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('DE', 'Delaware', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('FL', 'Florida', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('GA', 'Georgia', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('HI', 'Hawaii', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('ID', 'Idaho', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('IL', 'Illinois', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('IN', 'Indiana', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('IA', 'Iowa', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('KS', 'Kansas', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('KY', 'Kentucky', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('LA', 'Louisiana', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('ME', 'Maine', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('MD', 'Maryland', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('MA', 'Massachusetts', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('MI', 'Michigan', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('MN', 'Minnesota', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('MS', 'Mississippi', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('MO', 'Missouri', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('MT', 'Montana', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NE', 'Nebraska', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NV', 'Nevada', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NH', 'New Hampshire', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NJ', 'New Jersey', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NM', 'New Mexico', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NY', 'New York', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NC', 'North Carolina', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('ND', 'North Dakota', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('OH', 'Ohio', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('OK', 'Oklahoma', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('OR', 'Oregon', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('PA', 'Pennsylvania', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('RI', 'Rhode Island', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('SC', 'South Carolina', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('SD', 'South Dakota', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('TN', 'Tennessee', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('TX', 'Texas', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('UT', 'Utah',  (SELECT id FROM platform.country where code = 'USA'), '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('VT', 'Vermont', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('VA', 'Virginia', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('WA', 'Washington', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('WV', 'West Virginia',  (SELECT id FROM platform.country where code = 'USA'), '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('WI', 'Wisconsin', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('WY', 'Wyoming', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('DC', 'District of Columbia', (SELECT id FROM platform.country where code = 'USA'),  '00000000-0000-0000-0000-000000000000');

-- States for CAN

INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('AB', 'Alberta', (SELECT id FROM platform.country where code = 'CAN'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('BC', 'British Columbia', (SELECT id FROM platform.country where code = 'CAN'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('MB', 'Manitoba', (SELECT id FROM platform.country where code = 'CAN'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NB', 'New Brunswick', (SELECT id FROM platform.country where code = 'CAN'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NL', 'Newfoundland and Labrador', (SELECT id FROM platform.country where code = 'CAN'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NS', 'Nova Scotia', (SELECT id FROM platform.country where code = 'CAN'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NT', 'Northwest Territories', (SELECT id FROM platform.country where code = 'CAN'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NU', 'Nunavut', (SELECT id FROM platform.country where code = 'CAN'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('ON', 'Ontario', (SELECT id FROM platform.country where code = 'CAN'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('PE', 'Prince Edward Island', (SELECT id FROM platform.country where code = 'CAN'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('QC', 'Quebec', (SELECT id FROM platform.country where code = 'CAN'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('SK', 'Saskatchewan', (SELECT id FROM platform.country where code = 'CAN'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('YT', 'Yukon', (SELECT id FROM platform.country where code = 'CAN'),  '00000000-0000-0000-0000-000000000000');

-- States for AUS

INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NSW', 'New South Wales', (SELECT id FROM platform.country where code = 'AUS'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('QLD', 'Queensland', (SELECT id FROM platform.country where code = 'AUS'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('SA', 'South Australia', (SELECT id FROM platform.country where code = 'AUS'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('TAS', 'Tasmania', (SELECT id FROM platform.country where code = 'AUS'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('VIC', 'Victoria', (SELECT id FROM platform.country where code = 'AUS'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('WA', 'Western Australia', (SELECT id FROM platform.country where code = 'AUS'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('ACT', 'Australian Capital Territory', (SELECT id FROM platform.country where code = 'AUS'),  '00000000-0000-0000-0000-000000000000');
INSERT INTO platform.state (code, name, country_id, created_by) VALUES ('NT', 'Northern Territory', (SELECT id FROM platform.country where code = 'AUS'),  '00000000-0000-0000-0000-000000000000');
