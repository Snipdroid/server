-- Table: app_localized_names
CREATE TABLE app_localized_names (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    app_info_id UUID REFERENCES app_infos(id),
    language_code VARCHAR NOT NULL,
    name VARCHAR NOT NULL,
    is_primary BOOLEAN NOT NULL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
