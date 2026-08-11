USE university_fee_db;

-- QUERY 1: Overall financial KPI summary (dashboard card data)

SELECT
    COUNT(DISTINCT s.student_id)                            AS total_students,
    SUM(d.total_fee)                                        AS total_fees_expected,
    SUM(d.amount_paid)                                      AS total_fees_collected,
    SUM(d.balance)                                          AS total_outstanding,
    SUM(d.late_fine)                                        AS total_fines_charged,
    ROUND(SUM(d.amount_paid)/SUM(d.total_fee)*100, 2)       AS collection_rate_pct,
    SUM(COALESCE(sa.awarded_amount,0))                      AS total_scholarship_awarded,
    COUNT(CASE WHEN d.status='Paid'    THEN 1 END)          AS fully_paid_students,
    COUNT(CASE WHEN d.status='Partial' THEN 1 END)          AS partial_students,
    COUNT(CASE WHEN d.status IN ('Unpaid','Overdue') THEN 1 END) AS defaulters
FROM students s
LEFT JOIN dues d ON s.student_id = d.student_id
LEFT JOIN scholarship_applications sa ON s.student_id = sa.student_id AND sa.status = 'Approved';

-- QUERY 2: Department-wise fee collection report

SELECT * FROM vw_department_summary
ORDER BY collection_rate_pct DESC;

-- QUERY 3: Top 10 students with highest outstanding dues

SELECT
    s.reg_no,
    s.full_name,
    s.program,
    s.semester,
    d.balance           AS outstanding_balance,
    d.late_fine,
    (d.balance + d.late_fine) AS total_payable,
    d.due_date,
    DATEDIFF(CURRENT_DATE, d.due_date) AS days_overdue,
    RANK() OVER (ORDER BY d.balance DESC) AS defaulter_rank
FROM students s
JOIN dues d ON s.student_id = d.student_id
WHERE d.balance > 0
ORDER BY d.balance DESC
LIMIT 10;


-- ─────────────────────────────────────────────────────────────
-- QUERY 4: Scholarship eligibility — students NOT yet applied
-- ─────────────────────────────────────────────────────────────
SELECT
    s.student_id,
    s.reg_no,
    s.full_name,
    s.program,
    s.gpa,
    CASE
        WHEN s.gpa >= 3.80 THEN 'Eligible: VC Merit Award (100%)'
        WHEN s.gpa >= 3.50 THEN 'Eligible: Dean List (75%)'
        WHEN s.gpa >= 3.20 THEN 'Eligible: Academic Excellence (50%)'
        ELSE 'Not eligible for merit scholarships'
    END AS scholarship_eligibility
FROM students s
WHERE s.student_id NOT IN (
    SELECT DISTINCT student_id FROM scholarship_applications
)
  AND s.gpa >= 3.20
ORDER BY s.gpa DESC;


-- ─────────────────────────────────────────────────────────────
-- QUERY 5: Monthly payment trend (how much collected each month)
-- ─────────────────────────────────────────────────────────────
SELECT
    DATE_FORMAT(payment_date, '%Y-%m') AS payment_month,
    COUNT(*)                           AS total_transactions,
    SUM(amount_paid)                   AS total_collected,
    AVG(amount_paid)                   AS avg_payment,
    payment_method,
    COUNT(*) OVER (PARTITION BY payment_method) AS method_total_count
FROM payments
GROUP BY DATE_FORMAT(payment_date, '%Y-%m'), payment_method
ORDER BY payment_month, payment_method;


-- ─────────────────────────────────────────────────────────────
-- QUERY 6: Scholarship distribution by type
-- ─────────────────────────────────────────────────────────────
SELECT * FROM vw_scholarship_summary
ORDER BY total_awarded DESC;


-- ─────────────────────────────────────────────────────────────
-- QUERY 7: Students with both scholarship and pending dues
-- ─────────────────────────────────────────────────────────────
SELECT
    s.reg_no,
    s.full_name,
    s.program,
    sc.scholarship_name,
    sc.coverage_percent,
    sa.awarded_amount,
    d.balance           AS still_outstanding,
    d.status            AS payment_status
FROM students s
JOIN dues d ON s.student_id = d.student_id
JOIN scholarship_applications sa ON s.student_id = sa.student_id AND sa.status = 'Approved'
JOIN scholarships sc ON sa.scholarship_id = sc.scholarship_id
WHERE d.balance > 0
ORDER BY d.balance DESC;


-- ─────────────────────────────────────────────────────────────
-- QUERY 8: Fee collection rate by semester
-- ─────────────────────────────────────────────────────────────
SELECT
    s.semester,
    s.program,
    COUNT(DISTINCT s.student_id)                            AS students,
    SUM(d.total_fee)                                        AS expected,
    SUM(d.amount_paid)                                      AS collected,
    SUM(d.balance)                                          AS outstanding,
    ROUND(SUM(d.amount_paid)/SUM(d.total_fee)*100, 1)       AS collection_pct
FROM students s
JOIN dues d ON s.student_id = d.student_id
GROUP BY s.semester, s.program
ORDER BY s.program, s.semester;


-- ─────────────────────────────────────────────────────────────
-- QUERY 9: Payment method breakdown
-- ─────────────────────────────────────────────────────────────
SELECT
    payment_method,
    COUNT(*)                        AS total_transactions,
    SUM(amount_paid)                AS total_amount,
    ROUND(AVG(amount_paid), 0)      AS avg_amount,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM payments), 1) AS pct_of_total
FROM payments
GROUP BY payment_method
ORDER BY total_amount DESC;


-- ─────────────────────────────────────────────────────────────
-- QUERY 10: GPA brackets vs scholarship coverage
-- ─────────────────────────────────────────────────────────────
SELECT
    CASE
        WHEN s.gpa >= 3.80 THEN '3.80 - 4.00 (Outstanding)'
        WHEN s.gpa >= 3.50 THEN '3.50 - 3.79 (Excellent)'
        WHEN s.gpa >= 3.20 THEN '3.20 - 3.49 (Very Good)'
        WHEN s.gpa >= 2.80 THEN '2.80 - 3.19 (Good)'
        ELSE                    'Below 2.80'
    END AS gpa_bracket,
    COUNT(s.student_id)                         AS total_students,
    COUNT(sa.application_id)                    AS on_scholarship,
    ROUND(COUNT(sa.application_id)*100.0/COUNT(s.student_id), 1) AS scholarship_coverage_pct,
    ROUND(AVG(s.gpa), 2)                        AS avg_gpa
FROM students s
LEFT JOIN scholarship_applications sa ON s.student_id = sa.student_id AND sa.status = 'Approved'
GROUP BY gpa_bracket
ORDER BY avg_gpa DESC;


-- ─────────────────────────────────────────────────────────────
-- QUERY 11: Running total of payments by date (CTE)
-- ─────────────────────────────────────────────────────────────
WITH daily_payments AS (
    SELECT
        payment_date,
        SUM(amount_paid) AS daily_total
    FROM payments
    GROUP BY payment_date
)
SELECT
    payment_date,
    daily_total,
    SUM(daily_total) OVER (ORDER BY payment_date) AS running_total,
    ROUND(daily_total * 100.0 / SUM(daily_total) OVER (), 2) AS pct_of_all_payments
FROM daily_payments
ORDER BY payment_date;


-- ─────────────────────────────────────────────────────────────
-- QUERY 12: Students ranked by GPA within their program
-- ─────────────────────────────────────────────────────────────
SELECT
    s.program,
    s.full_name,
    s.reg_no,
    s.semester,
    s.gpa,
    RANK() OVER (PARTITION BY s.program ORDER BY s.gpa DESC)        AS program_rank,
    DENSE_RANK() OVER (ORDER BY s.gpa DESC)                         AS overall_rank,
    ROUND(AVG(s.gpa) OVER (PARTITION BY s.program), 2)              AS program_avg_gpa
FROM students s
ORDER BY s.program, s.gpa DESC;


-- ─────────────────────────────────────────────────────────────
-- QUERY 13: Overdue students detail (from view)
-- ─────────────────────────────────────────────────────────────
SELECT * FROM vw_overdue_students;


-- ─────────────────────────────────────────────────────────────
-- QUERY 14: Program-wise scholarship payout vs fee collected
-- ─────────────────────────────────────────────────────────────
SELECT
    s.program,
    SUM(d.total_fee)                            AS total_fee_billed,
    SUM(d.amount_paid)                          AS fee_collected,
    COALESCE(SUM(sa.awarded_amount), 0)         AS scholarship_awarded,
    SUM(d.total_fee) - COALESCE(SUM(sa.awarded_amount),0) AS net_revenue,
    ROUND(COALESCE(SUM(sa.awarded_amount),0)
          / SUM(d.total_fee) * 100, 2)          AS scholarship_pct_of_fees
FROM students s
JOIN dues d ON s.student_id = d.student_id
LEFT JOIN scholarship_applications sa ON s.student_id = sa.student_id AND sa.status = 'Approved'
GROUP BY s.program;


-- ─────────────────────────────────────────────────────────────
-- QUERY 15: Full student financial summary (from view)
-- ─────────────────────────────────────────────────────────────
SELECT * FROM vw_student_financial_summary
ORDER BY outstanding_balance DESC;
