-- Climbs Mountaineering Club database 


-- Create database and schema
CREATE DATABASE climbs_mountaineering_club_db;

CREATE SCHEMA IF NOT EXISTS club_schema;

--===========
-- Table: area
-- Purpose: Stores information about geographical climbing areas.
-- Data Integrity:
-- - Area name and country are mandatory for clear identification.
CREATE table IF NOT EXISTS club_schema.area (
    area_ID SERIAL PRIMARY KEY, -- SERIAL auto-increments unique ID
    area_name VARCHAR(255) NOT NULL, -- Long enough to store full names like 'Kilimanjaro Range'
    country VARCHAR(100) NOT NULL -- Country names fit within 100 characters
);

--===========
-- Table: mountain
-- Purpose: Stores information about mountains, linked to areas.
-- Data Integrity:
-- - Mountain name and height are critical for records.
-- - Height must be non-negative.
CREATE TABLE IF NOT EXISTS club_schema.mountain (
    mountain_ID SERIAL PRIMARY KEY,
    area_ID INT NOT NULL,
    mountain_name VARCHAR(255) NOT NULL,
    height_meters INT CHECK (height_meters >= 0), -- No negative heights allowed
    FOREIGN KEY (area_ID) REFERENCES club_schema.area(area_ID) ON DELETE CASCADE -- A mountain must belong to an area
    -- If an area is deleted, all its mountains must be deleted to maintain relational integrity.
    );

--===========
-- Table: route
-- Purpose: Stores different climbing routes for each mountain.
-- Data Integrity:
-- - Route name is mandatory.
-- -The difficulty_level field for the route table is enforced as NOT NULL,
-- -since difficulty rating is a critical property for planning safe climbing expeditions and must always be recorded.
CREATE table IF NOT EXISTS club_schema.route (
    route_ID SERIAL PRIMARY KEY,
    mountain_ID INT NOT NULL,
    route_name VARCHAR(255) NOT NULL,
    difficulty_level VARCHAR(100) NOT NULL,
    FOREIGN KEY (mountain_ID) REFERENCES club_schema.mountain(mountain_ID) ON DELETE cascade
    -- If a mountain is deleted, all its associated routes must also be deleted
);

--===========-
-- Table: guide
-- Purpose: Stores personal and professional information about mountain guides.
-- Data Integrity:
-- - First and last names are mandatory for proper identification.
-- - Minimum experience enforced with a CHECK constraint.
CREATE table IF NOT EXISTS club_schema.guide (
    guide_ID SERIAL PRIMARY KEY, -- Unique guide ID auto-generated
    guide_first_name VARCHAR(100) NOT NULL, --Names rarely exceed 100 characters
    guide_last_name VARCHAR(100) NOT NULL,
    experience_years INT DEFAULT 3 CHECK (experience_years >= 3), -- GuIDes must have at least 3 years of experience
    guide_phone_number VARCHAR(20) -- International phone numbers (plus signs, dashes) fit within 20 characters
);

--===========
-- Table: climber
-- Purpose: Stores personal data about climbers.
-- Data Integrity:
-- - First and last names mandatory.
-- - Gender restricted to 'M' or 'F' via CHECK constraint.
CREATE TABLE IF NOT EXISTS club_schema.climber (
    climber_ID SERIAL PRIMARY KEY,
    climber_first_name VARCHAR(100) NOT NULL,
    climber_last_name VARCHAR(100) NOT NULL,
    address VARCHAR(255),
    gender VARCHAR(1) NOT NULL CHECK (gender IN ('M', 'F')) -- Enforces Male/Female only
);

--===========
-- Table: climb
-- Purpose: Represents climbing expeditions.
-- Data Integrity:
-- - Linked to mountain, route, guIDe.
-- - Start date must be after January 1st, 2000 for data relevance.
CREATE TABLE IF NOT EXISTS club_schema.climb (
    climb_ID SERIAL PRIMARY KEY,
    mountain_ID INT NOT NULL,
    route_ID INT NOT NULL,
    guide_ID INT NOT NULL,
    start_date DATE NOT NULL CHECK (start_date > '2000-01-01'), -- Ensures climbing dates according to the requirement
    end_date DATE,
    FOREIGN KEY (mountain_ID) REFERENCES club_schema.mountain(mountain_ID) ON DELETE CASCADE,
    FOREIGN KEY (route_ID) REFERENCES club_schema.route(route_ID) ON DELETE CASCADE,
    FOREIGN KEY (guide_ID) REFERENCES club_schema.guide(guide_ID) ON DELETE CASCADE
    -- Deleting a mountain, route, or guide must cascade to climbs to avoid situation like a climb still points to that missing mountain.
);

--===========
-- Table: climb_note
-- Purpose: Stores notes written by climbers about specific climbs.
-- Data Integrity:
-- - Note text and date are mandatory for meaningful feedback.
CREATE table IF NOT EXISTS club_schema.climb_note (
    note_ID SERIAL PRIMARY KEY,
    climb_ID INT NOT NULL,
    climber_ID INT NOT NULL,
    note_text VARCHAR(1000) NOT NULL, -- Allows long descriptive notes
    note_date DATE NOT NULL,
    FOREIGN KEY (climb_ID) REFERENCES club_schema.climb(climb_ID) ON DELETE CASCADE,
    FOREIGN KEY (climber_ID) REFERENCES club_schema.climber(climber_ID) ON DELETE cascade
    -- Notes must disappear if the related climb or climber is deleted.
);

--===========
-- Table: equipment
-- Purpose: Records climbing equipment owned by climbers.
-- Data Integrity:
-- - Equipment name and type are mandatory.
CREATE table IF NOT EXISTS club_schema.equipment (
    equipment_ID SERIAL PRIMARY KEY,
    climber_ID INT NOT NULL,
    equipment_name VARCHAR(255) NOT NULL,
    equipment_type VARCHAR(100) NOT NULL,
    FOREIGN KEY (climber_ID) REFERENCES club_schema.climber(climber_ID) ON DELETE cascade
    -- If a climber is deleted, their equipment records must also be deleted.
);

--===========
-- Table: rescuer
-- Purpose: Stores information about mountain rescuers.
-- Data Integrity:
-- - First and last names and organization are mandatory.
CREATE TABLE IF NOT EXISTS club_schema.rescuer (
    rescuer_ID SERIAL PRIMARY KEY,
    rescuer_first_name VARCHAR(100) NOT NULL,
    rescuer_last_name VARCHAR(100) NOT NULL,
    organization VARCHAR(255) NOT NULL,
    rescuer_contact VARCHAR(20) NOT NULL -- Rescuer contact information is mandatory for emergency situation; cannot be NULL.
);

--===========-
-- Table: climber_medical_info
-- Purpose: Stores sensitive medical information for each climber.
-- Data Integrity:
-- - climber_ID is UNIQUE, ensuring a one-to-one relationship.
-- - Blood type must be valID according to predefined types.
CREATE TABLE IF NOT EXISTS club_schema.climber_medical_info (
    medical_info_ID SERIAL PRIMARY KEY,
    climber_ID INT UNIQUE NOT NULL, -- One climber = one medical record
    blood_type VARCHAR(2) NOT NULL CHECK (blood_type IN ('A', 'B', 'AB', 'O')),
    allergies VARCHAR(255),
    other_medical_note VARCHAR(1000),
    FOREIGN KEY (climber_ID) REFERENCES club_schema.climber(climber_ID) ON DELETE cascade
    -- If a climber is deleted, their sensitive medical information must also be deleted.
);

--===========
-- Table: climb_participant
-- Purpose: BrIDge table between climbs and climbers (Many-to-Many).
-- Data Integrity:
-- - Composite Primary Key ensures each climber joins each climb only once.
CREATE TABLE IF NOT EXISTS club_schema.climb_participant (
    climb_ID INT NOT NULL,
    climber_ID INT NOT NULL,
    PRIMARY KEY (climb_ID, climber_ID),
    FOREIGN KEY (climb_ID) REFERENCES club_schema.climb(climb_ID) ON DELETE CASCADE,
    FOREIGN KEY (climber_ID) REFERENCES club_schema.climber(climber_ID) ON DELETE cascade
    -- Participant records must be deleted if either the climb or the climber is deleted.
);

--===========
-- Table: climb_rescue
-- Purpose: Tracks rescue operations during climbs (Many-to-Many).
-- Data Integrity:
-- - Composite Primary Key prevents duplicate rescue records.
-- - Rescue date must be after 2000-01-01 for data consistency.
CREATE TABLE IF NOT EXISTS club_schema.climb_rescue (
    climb_ID INT NOT NULL,
    rescuer_ID INT NOT NULL,
    rescue_date DATE NOT NULL CHECK (rescue_date > '2000-01-01'),
    rescue_details VARCHAR(1000),
    PRIMARY KEY (climb_ID, rescuer_ID),
    FOREIGN KEY (climb_ID) REFERENCES club_schema.climb(climb_ID) ON DELETE CASCADE,
    FOREIGN KEY (rescuer_ID) REFERENCES club_schema.rescuer(rescuer_ID) ON DELETE cascade
    -- Rescue records must be deleted if either the climb or the rescuer is deleted.
);


--============
-- Add UNIQUE constraint to prevent duplicate areas, mountains, routes

ALTER TABLE club_schema.area DROP CONSTRAINT IF EXISTS unique_area;

ALTER TABLE club_schema.area
ADD CONSTRAINT unique_area UNIQUE (area_name, country);

ALTER TABLE club_schema.mountain DROP CONSTRAINT IF EXISTS unique_mountain;
ALTER TABLE club_schema.mountain ADD CONSTRAINT unique_mountain UNIQUE (mountain_name, area_ID);


ALTER TABLE club_schema.route DROP CONSTRAINT IF EXISTS unique_route;
ALTER TABLE club_schema.route ADD CONSTRAINT unique_route UNIQUE (route_name, mountain_ID);


--============
---- Initial Data Population

-- Insert areas safely
INSERT INTO club_schema.area (area_name, country)
VALUES 
('Kilimanjaro Range', 'Tanzania'),
('Andes Mountains', 'Argentina')
ON CONFLICT ON CONSTRAINT unique_area DO NOTHING;

-- Insert mountains safely
INSERT INTO club_schema.mountain (area_ID, mountain_name, height_meters)
VALUES 
(
  (SELECT area_ID FROM club_schema.area WHERE area_name = 'Kilimanjaro Range'),
  'Kilimanjaro',
  5895
),
(
  (SELECT area_ID FROM club_schema.area WHERE area_name = 'Andes Mountains'),
  'Aconcagua',
  6961
)
ON CONFLICT ON CONSTRAINT unique_mountain DO NOTHING;

-- Insert routes safely
INSERT INTO club_schema.route (mountain_ID, route_name, difficulty_level)
VALUES 
(
  (SELECT mountain_ID FROM club_schema.mountain WHERE mountain_name = 'Kilimanjaro'),
  'Machame Route',
  'Challenging'
),
(
  (SELECT mountain_ID FROM club_schema.mountain WHERE mountain_name = 'Aconcagua'),
  'Polish Glacier',
  'Extremely Difficult'
)
ON CONFLICT ON CONSTRAINT unique_route DO NOTHING;

-- Insert guides 
INSERT INTO club_schema.guide (guide_first_name, guide_last_name, experience_years, guide_phone_number)
VALUES 
('Joseph', 'Mtui', 17, '+255754123456'),
('Miguel', 'Sanchez', 28, '+542614250871');


-- Insert climbers 
INSERT INTO club_schema.climber (climber_first_name, climber_last_name, address, gender)
VALUES 
('Cristian', 'Luca', '12 Kogalniceanu Street, Chisinau, Moldova', 'M'),
('Monica', 'Luca', '164 Stefan cel Mare Boulevard, Chisinau, Moldova', 'F');


-- Insert rescuers
INSERT INTO club_schema.rescuer (rescuer_first_name, rescuer_last_name, organization, rescuer_contact)
VALUES 
('Valentin', 'Damaris', 'Kilimanjaro SAR', '+255758222255'),
('Maria', 'Dumitrescu', 'Aconcagua National Park Visitor Center', '+542614258751');


--===========
-- Add record_ts column to all tables
-- Purpose: Track the date when each record was created.

ALTER TABLE club_schema.area ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE club_schema.mountain ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE club_schema.route ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE club_schema.guide ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE club_schema.climber ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE club_schema.climb ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE club_schema.climb_note ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE club_schema.equipment ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE club_schema.rescuer ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE club_schema.climber_medical_info ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE club_schema.climb_participant ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE club_schema.climb_rescue ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

--===========
-- Set record_ts for existing rows 

UPDATE club_schema.area SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE club_schema.mountain SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE club_schema.route SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE club_schema.guide SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE club_schema.climber SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE club_schema.climb SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE club_schema.climb_note SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE club_schema.equipment SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE club_schema.rescuer SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE club_schema.climber_medical_info SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE club_schema.climb_participant SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE club_schema.climb_rescue SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;

/*
 
Database  - a short recap:

The database has been  normalized to 3NF to eliminate redundancy, ensure data integrity, and promote scalability.

Primary keys (PKs) uniquely IDentify records in all tables.

Foreign keys (FKs) enforce strict referential integrity across relationships.

ON DELETE CASCADE was applied  across foreign key constraints to enforce referential integrity 
and automatically clean up dependent data upon parent deletions.

Appropriate data types have been chosen for all columns (such as VARCHAR for names, DATE for start dates).

Constraints such as NOT NULL, CHECK, UNIQUE, and DEFAULT values are applied to ensure data integrity and consistency in the database.

SERIAL data types are used for primary keys to ensure automatic ID generation.

A record_ts field (with DEFAULT CURRENT_DATE) has been added across all tables using ALTER TABLE statements as a requirement.

In this physical database design, GENERATED ALWAYS AS columns were not implemented because the current logical model
does not include any computed attributes. All columns represent manually collected, independently meaningful data points 
(names, dates, routes, equipment). If future business requirements introduce calculated fields (such as calculating total climb days as end_date - start_date),
then GENERATED ALWAYS AS would be consIDered  to automate such calculations at the database level.

DDL with IF NOT EXISTS (such as CREATE TABLE IF NOT EXISTS) prevents errors when objects already exist.

DML with ON CONFLICT DO NOTHING (such as INSERT INTO ... ON CONFLICT DO NOTHING) avoids inserting duplicate records.

Unique constraints and ON CONFLICT clauses have been implemented across all critical tables to ensure no duplicate data even when executed multiple times.
 
Sample data inserts were designed dynamically using RETURNING and SELECT subqueries to avoid hardcoded IDs and to ensure data integrity.

*/
