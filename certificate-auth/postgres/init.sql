-- Create schema and set up initial permissions
CREATE SCHEMA IF NOT EXISTS app;
GRANT ALL PRIVILEGES ON DATABASE "app-db" TO app;
GRANT ALL PRIVILEGES ON SCHEMA app TO app;

-- Create application roles
CREATE ROLE app_read WITH LOGIN PASSWORD 'app_read_password';
CREATE ROLE app_write WITH LOGIN PASSWORD 'app_write_password';

-- Create a test table
CREATE TABLE app.users (
                           id SERIAL PRIMARY KEY,
                           username VARCHAR(50) NOT NULL UNIQUE,
                           email VARCHAR(255) NOT NULL UNIQUE,
                           created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                           updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create a test table for orders
CREATE TABLE app.orders (
                            id SERIAL PRIMARY KEY,
                            user_id INTEGER REFERENCES app.users(id),
                            order_number VARCHAR(50) NOT NULL UNIQUE,
                            total_amount DECIMAL(10,2) NOT NULL,
                            status VARCHAR(20) NOT NULL,
                            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Grant permissions to roles
GRANT USAGE ON SCHEMA app TO app_read, app_write;

-- Read role permissions
GRANT SELECT ON ALL TABLES IN SCHEMA app TO app_read;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT ON TABLES TO app_read;

-- Write role permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO app_write;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO app_write;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_write;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT USAGE, SELECT ON SEQUENCES TO app_write;

-- Insert some test data
INSERT INTO app.users (username, email) VALUES
                                            ('testuser1', 'test1@example.com'),
                                            ('testuser2', 'test2@example.com');

INSERT INTO app.orders (user_id, order_number, total_amount, status) VALUES
                                                                         (1, 'ORD-001', 99.99, 'COMPLETED'),
                                                                         (1, 'ORD-002', 150.50, 'PENDING'),
                                                                         (2, 'ORD-003', 75.25, 'COMPLETED');
