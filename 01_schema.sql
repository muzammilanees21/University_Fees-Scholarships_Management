DROP DATABASE IF EXISTS university_fee_db;
CREATE DATABASE university_fee_db;
USE university_fee_db;

-- TABLE 1: students

CREATE TABLE students (
    student_id      INT AUTO_INCREMENT PRIMARY KEY,
    reg_no          VARCHAR(20)  NOT NULL UNIQUE,        -- e.g. BS-DS-2022-001
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,
    phone           VARCHAR(15),
    program         ENUM('BS Data Science','BS Computer Science',
                         'BS Software Engineering','BS IT') NOT NULL,
    department      ENUM('Data Science','Computer Science',
                         'Software Engineering','Information Technology') NOT NULL,
    semester        TINYINT NOT NULL CHECK (semester BETWEEN 1 AND 8),
    gpa             DECIMAL(3,2) DEFAULT 0.00 CHECK (gpa BETWEEN 0.00 AND 4.00),
    gender          ENUM('Male','Female') NOT NULL,
    admission_year  YEAR NOT NULL,
    status          ENUM('Active','Graduated','Suspended','Dropped') DEFAULT 'Active',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ────────────────────────────────────────────────────────────
-- TABLE 2: fee_structure
-- ────────────────────────────────────────────────────────────
CREATE TABLE fee_structure (
    fee_id          INT AUTO_INCREMENT PRIMARY KEY,
    program         ENUM('BS Data Science','BS Computer Science',
                         'BS Software Engineering','BS IT') NOT NULL,
    semester        TINYINT NOT NULL CHECK (semester BETWEEN 1 AND 8),
    tuition_fee     DECIMAL(10,2) NOT NULL,
    lab_fee         DECIMAL(10,2) DEFAULT 0.00,
    library_fee     DECIMAL(10,2) DEFAULT 500.00,
    exam_fee        DECIMAL(10,2) DEFAULT 1500.00,
    total_fee       DECIMAL(10,2) GENERATED ALWAYS AS
                    (tuition_fee + lab_fee + library_fee + exam_fee) STORED,
    academic_year   VARCHAR(10) NOT NULL,                -- e.g. 2023-24
    UNIQUE KEY uq_program_sem_year (program, semester, academic_year)
);

-- ────────────────────────────────────────────────────────────
-- TABLE 3: payments
-- ────────────────────────────────────────────────────────────
CREATE TABLE payments (
    payment_id      INT AUTO_INCREMENT PRIMARY KEY,
    student_id      INT NOT NULL,
    fee_id          INT NOT NULL,
    amount_paid     DECIMAL(10,2) NOT NULL CHECK (amount_paid > 0),
    payment_date    DATE NOT NULL,
    payment_method  ENUM('Cash','Bank Transfer','Online','Cheque') NOT NULL,
    receipt_no      VARCHAR(30) NOT NULL UNIQUE,
    remarks         VARCHAR(200),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    FOREIGN KEY (fee_id)     REFERENCES fee_structure(fee_id)
);

-- ────────────────────────────────────────────────────────────
-- TABLE 4: scholarships
-- ────────────────────────────────────────────────────────────
CREATE TABLE scholarships (
    scholarship_id      INT AUTO_INCREMENT PRIMARY KEY,
    scholarship_name    VARCHAR(100) NOT NULL,
    scholarship_type    ENUM('Merit','Need-Based','Sports','Hafiz-e-Quran',
                             'Disability','Government') NOT NULL,
    coverage_percent    DECIMAL(5,2) NOT NULL CHECK (coverage_percent BETWEEN 1 AND 100),
    min_gpa_required    DECIMAL(3,2) DEFAULT 0.00,
    max_family_income   DECIMAL(12,2) DEFAULT NULL,      -- NULL = no income limit
    description         VARCHAR(300),
    is_active           BOOLEAN DEFAULT TRUE
);

-- ────────────────────────────────────────────────────────────
-- TABLE 5: scholarship_applications
-- ────────────────────────────────────────────────────────────
CREATE TABLE scholarship_applications (
    application_id      INT AUTO_INCREMENT PRIMARY KEY,
    student_id          INT NOT NULL,
    scholarship_id      INT NOT NULL,
    applied_date        DATE NOT NULL,
    status              ENUM('Pending','Approved','Rejected') DEFAULT 'Pending',
    approved_date       DATE DEFAULT NULL,
    awarded_amount      DECIMAL(10,2) DEFAULT 0.00,
    reviewed_by         VARCHAR(100),
    remarks             VARCHAR(300),
    FOREIGN KEY (student_id)     REFERENCES students(student_id) ON DELETE CASCADE,
    FOREIGN KEY (scholarship_id) REFERENCES scholarships(scholarship_id),
    UNIQUE KEY uq_student_scholarship (student_id, scholarship_id)
);

-- ────────────────────────────────────────────────────────────
-- TABLE 6: dues
-- ────────────────────────────────────────────────────────────
CREATE TABLE dues (
    due_id          INT AUTO_INCREMENT PRIMARY KEY,
    student_id      INT NOT NULL,
    fee_id          INT NOT NULL,
    total_fee       DECIMAL(10,2) NOT NULL,
    amount_paid     DECIMAL(10,2) DEFAULT 0.00,
    balance         DECIMAL(10,2) GENERATED ALWAYS AS (total_fee - amount_paid) STORED,
    due_date        DATE NOT NULL,
    late_fine       DECIMAL(10,2) DEFAULT 0.00,
    status          ENUM('Paid','Partial','Unpaid','Overdue') DEFAULT 'Unpaid',
    last_updated    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    FOREIGN KEY (fee_id)     REFERENCES fee_structure(fee_id)
);

SELECT 'Schema created successfully!' AS message;
