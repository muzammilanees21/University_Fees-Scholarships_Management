USE university_fee_db;

-- View 1: Full student financial summary
CREATE OR REPLACE VIEW vw_student_financial_summary AS
SELECT
    s.student_id,
    s.reg_no,
    s.full_name,
    s.program,
    s.department,
    s.semester,
    s.gpa,
    fs.total_fee        AS semester_fee,
    d.amount_paid,
    d.balance           AS outstanding_balance,
    d.late_fine,
    d.status            AS payment_status,
    COALESCE(sa.awarded_amount, 0)  AS scholarship_amount,
    sc.scholarship_type
FROM students s
LEFT JOIN dues d              ON s.student_id = d.student_id
LEFT JOIN fee_structure fs    ON d.fee_id = fs.fee_id
LEFT JOIN scholarship_applications sa ON s.student_id = sa.student_id AND sa.status = 'Approved'
LEFT JOIN scholarships sc     ON sa.scholarship_id = sc.scholarship_id;

-- View 2: Department-wise fee collection summary
CREATE OR REPLACE VIEW vw_department_summary AS
SELECT
    s.department,
    COUNT(DISTINCT s.student_id)                            AS total_students,
    SUM(d.total_fee)                                        AS total_expected,
    SUM(d.amount_paid)                                      AS total_collected,
    SUM(d.balance)                                          AS total_outstanding,
    ROUND(SUM(d.amount_paid) / SUM(d.total_fee) * 100, 2)  AS collection_rate_pct,
    SUM(d.late_fine)                                        AS total_fines,
    SUM(CASE WHEN d.status = 'Paid'    THEN 1 ELSE 0 END)  AS paid_count,
    SUM(CASE WHEN d.status = 'Partial' THEN 1 ELSE 0 END)  AS partial_count,
    SUM(CASE WHEN d.status IN ('Unpaid','Overdue') THEN 1 ELSE 0 END) AS unpaid_count
FROM students s
JOIN dues d ON s.student_id = d.student_id
GROUP BY s.department;

-- View 3: Scholarship distribution summary
CREATE OR REPLACE VIEW vw_scholarship_summary AS
SELECT
    sc.scholarship_name,
    sc.scholarship_type,
    sc.coverage_percent,
    COUNT(sa.application_id)                                AS total_applications,
    SUM(CASE WHEN sa.status='Approved' THEN 1 ELSE 0 END)  AS approved,
    SUM(CASE WHEN sa.status='Pending'  THEN 1 ELSE 0 END)  AS pending,
    SUM(CASE WHEN sa.status='Rejected' THEN 1 ELSE 0 END)  AS rejected,
    COALESCE(SUM(sa.awarded_amount), 0)                     AS total_awarded
FROM scholarships sc
LEFT JOIN scholarship_applications sa ON sc.scholarship_id = sa.scholarship_id
GROUP BY sc.scholarship_id;

-- View 4: Overdue students alert view
CREATE OR REPLACE VIEW vw_overdue_students AS
SELECT
    s.student_id,
    s.reg_no,
    s.full_name,
    s.program,
    s.semester,
    s.phone,
    s.email,
    d.balance           AS amount_due,
    d.late_fine,
    (d.balance + d.late_fine) AS total_payable,
    d.due_date,
    DATEDIFF(CURRENT_DATE, d.due_date) AS days_overdue
FROM students s
JOIN dues d ON s.student_id = d.student_id
WHERE d.status IN ('Overdue', 'Partial')
ORDER BY d.balance DESC;


-- ============================================================
-- SECTION B: STORED PROCEDURES
-- ============================================================

DELIMITER //

-- Procedure 1: Record a student payment
CREATE PROCEDURE sp_record_payment(
    IN  p_student_id   INT,
    IN  p_fee_id       INT,
    IN  p_amount       DECIMAL(10,2),
    IN  p_method       VARCHAR(20),
    IN  p_receipt_no   VARCHAR(30),
    OUT p_message      VARCHAR(200)
)
BEGIN
    DECLARE v_balance     DECIMAL(10,2);
    DECLARE v_total_fee   DECIMAL(10,2);
    DECLARE v_paid        DECIMAL(10,2);

    SELECT total_fee, amount_paid, balance
    INTO   v_total_fee, v_paid, v_balance
    FROM   dues
    WHERE  student_id = p_student_id AND fee_id = p_fee_id;

    IF v_balance IS NULL THEN
        SET p_message = 'ERROR: No due record found for this student/fee combination.';
    ELSEIF p_amount > v_balance THEN
        SET p_message = 'ERROR: Payment amount exceeds outstanding balance.';
    ELSE
        INSERT INTO payments(student_id, fee_id, amount_paid, payment_date, payment_method, receipt_no)
        VALUES (p_student_id, p_fee_id, p_amount, CURRENT_DATE, p_method, p_receipt_no);

        UPDATE dues
        SET    amount_paid = amount_paid + p_amount,
               status = CASE
                   WHEN (amount_paid + p_amount) >= total_fee THEN 'Paid'
                   ELSE 'Partial'
               END
        WHERE  student_id = p_student_id AND fee_id = p_fee_id;

        SET p_message = CONCAT('SUCCESS: Payment of Rs. ', p_amount, ' recorded for student ID ', p_student_id);
    END IF;
END //

-- Procedure 2: Apply late fines to all overdue students
CREATE PROCEDURE sp_apply_late_fines(
    IN  p_fine_per_day  DECIMAL(10,2),
    OUT p_updated_count INT
)
BEGIN
    UPDATE dues
    SET    late_fine = DATEDIFF(CURRENT_DATE, due_date) * p_fine_per_day,
           status = 'Overdue'
    WHERE  status IN ('Unpaid', 'Partial')
      AND  CURRENT_DATE > due_date;

    SET p_updated_count = ROW_COUNT();
END //

-- Procedure 3: Get complete student fee report
CREATE PROCEDURE sp_student_report(IN p_student_id INT)
BEGIN
    SELECT
        s.reg_no, s.full_name, s.program, s.semester, s.gpa,
        d.total_fee, d.amount_paid, d.balance, d.late_fine, d.status,
        COALESCE(sa.awarded_amount, 0) AS scholarship_awarded,
        sc.scholarship_name, sc.scholarship_type
    FROM   students s
    LEFT JOIN dues d              ON s.student_id = d.student_id
    LEFT JOIN scholarship_applications sa ON s.student_id = sa.student_id AND sa.status = 'Approved'
    LEFT JOIN scholarships sc     ON sa.scholarship_id = sc.scholarship_id
    WHERE  s.student_id = p_student_id;

    SELECT payment_id, amount_paid, payment_date, payment_method, receipt_no
    FROM   payments
    WHERE  student_id = p_student_id
    ORDER  BY payment_date DESC;
END //

-- Procedure 4: Enroll student scholarship
CREATE PROCEDURE sp_apply_scholarship(
    IN  p_student_id      INT,
    IN  p_scholarship_id  INT,
    OUT p_message         VARCHAR(300)
)
BEGIN
    DECLARE v_gpa          DECIMAL(3,2);
    DECLARE v_min_gpa      DECIMAL(3,2);
    DECLARE v_coverage     DECIMAL(5,2);
    DECLARE v_semester_fee DECIMAL(10,2);
    DECLARE v_award        DECIMAL(10,2);
    DECLARE v_name         VARCHAR(100);

    SELECT s.gpa INTO v_gpa FROM students s WHERE student_id = p_student_id;
    SELECT min_gpa_required, coverage_percent, scholarship_name
    INTO   v_min_gpa, v_coverage, v_name
    FROM   scholarships WHERE scholarship_id = p_scholarship_id;

    IF v_gpa < v_min_gpa THEN
        SET p_message = CONCAT('REJECTED: Student GPA (', v_gpa, ') is below minimum required (', v_min_gpa, ') for ', v_name);
    ELSE
        SELECT d.total_fee INTO v_semester_fee
        FROM dues d WHERE student_id = p_student_id LIMIT 1;

        SET v_award = v_semester_fee * (v_coverage / 100);

        INSERT INTO scholarship_applications
            (student_id, scholarship_id, applied_date, status, approved_date, awarded_amount)
        VALUES
            (p_student_id, p_scholarship_id, CURRENT_DATE, 'Approved', CURRENT_DATE, v_award)
        ON DUPLICATE KEY UPDATE
            status = 'Approved', approved_date = CURRENT_DATE, awarded_amount = v_award;

        SET p_message = CONCAT('APPROVED: Rs. ', v_award, ' awarded via ', v_name);
    END IF;
END //

DELIMITER ;


-- ============================================================
-- SECTION C: TRIGGERS
-- ============================================================

DELIMITER //

-- Trigger 1: Auto-update due status after payment inserted
CREATE TRIGGER trg_after_payment_insert
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_paid  DECIMAL(10,2);

    SELECT total_fee, amount_paid INTO v_total, v_paid
    FROM dues WHERE student_id = NEW.student_id AND fee_id = NEW.fee_id;

    IF v_paid >= v_total THEN
        UPDATE dues SET status = 'Paid', late_fine = 0
        WHERE student_id = NEW.student_id AND fee_id = NEW.fee_id;
    ELSEIF v_paid > 0 THEN
        UPDATE dues SET status = 'Partial'
        WHERE student_id = NEW.student_id AND fee_id = NEW.fee_id;
    END IF;
END //

-- Trigger 2: Log when a due becomes overdue (status update)
CREATE TRIGGER trg_before_due_update
BEFORE UPDATE ON dues
FOR EACH ROW
BEGIN
    IF NEW.status = 'Overdue' AND OLD.status != 'Overdue' THEN
        SET NEW.late_fine = GREATEST(OLD.late_fine, DATEDIFF(CURRENT_DATE, OLD.due_date) * 100);
    END IF;
END //

DELIMITER ;

SELECT 'Procedures, Triggers, and Views created successfully!' AS message;


SELECT * FROM dues;