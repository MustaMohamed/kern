-- up
CREATE TABLE invoices (id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, total NUMERIC NOT NULL, status TEXT NOT NULL, paid_at TIMESTAMP);
-- down
DROP TABLE invoices;
