# University Fee & Scholarship Management System

A full-stack Database Management System (DBMS) project that models, manages, and analyzes university fee collection and scholarship allocation. Built with **MySQL** for the relational backend, **Python** for analytics, and **Power BI** for interactive visualization.

---

## 📌 Project Overview

This project simulates a real-world university environment where student fee records and scholarship allocations need to be tracked, validated, and analyzed. It covers the complete database lifecycle — from schema design to automated business logic (stored procedures & triggers) — and extends into data analytics and dashboarding.

---

## 🎯 Objectives

- Design a normalized relational database schema for students, fees, and scholarships
- Automate fee/scholarship business rules using stored procedures and triggers
- Provide quick data access through SQL views
- Perform exploratory data analysis using Python
- Build an interactive Power BI dashboard for decision-making insights

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Database | MySQL |
| Backend Logic | Stored Procedures, Triggers, Views |
| Data Analytics | Python (Pandas, NumPy) in Jupyter Notebook |
| Visualization | Power BI |

---

## 🗄️ Database Design

- **Schema:** Fully normalized relational schema covering students, fee structures, payments, scholarships, and eligibility criteria
- **Stored Procedures:** Automate repetitive operations such as fee calculation, scholarship allocation, and record updates
- **Triggers:** Enforce business rules automatically (e.g., updating balance on payment insert, validating scholarship eligibility)
- **Views:** Simplified, pre-joined views for quick reporting and analytics access

---

## 📊 Python Analytics

A Jupyter Notebook connects to the MySQL database to:
- Extract and clean data using Pandas
- Perform exploratory data analysis (EDA) on fee payment trends and scholarship distribution
- Generate summary statistics and visualizations to support reporting

---

## 📈 Power BI Dashboard

An interactive dashboard built on top of the database/analytics layer, providing:
- Fee collection overview (paid vs. pending)
- Scholarship distribution by category/criteria
- Student-wise and department-wise breakdowns
- Visual trends for administrative decision-making

---

## 📂 Project Structure

```
University-Fee-Scholarship-Management/
│
├── database/
│   ├── schema.sql              # Table definitions
│   ├── stored_procedures.sql   # Stored procedures
│   ├── triggers.sql            # Triggers
│   └── views.sql                # Views
│
├── analytics/
│   └── analysis.ipynb          # Python/Jupyter analysis notebook
│
├── dashboard/
│   └── dashboard.pbix          # Power BI dashboard file
│
└── README.md
```

---

## 🚀 How to Run

1. **Set up the database**
   - Import `schema.sql` into MySQL
   - Run `stored_procedures.sql`, `triggers.sql`, and `views.sql`
2. **Run the analytics notebook**
   - Open `analysis.ipynb` in Jupyter
   - Update DB connection credentials
   - Run all cells to generate insights
3. **Open the dashboard**
   - Open `dashboard.pbix` in Power BI Desktop
   - Refresh data source connection to your local MySQL instance

---

## 👤 Author

**Muzammil Anees**
BS Data Science, Sir Syed University of Engineering & Technology
GitHub: [github.com/muzammilanees21](https://github.com/muzammilanees21)

---

## 📄 License

This project is for academic purposes as part of university coursework.
