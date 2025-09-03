-- Table: app_infos
CREATE TABLE app_infos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    default_name VARCHAR NOT NULL,
    package_name VARCHAR NOT NULL,
    main_activity VARCHAR NOT NULL,
    created_at TIMESTAMP,
    count INTEGER NOT NULL DEFAULT 0
);
