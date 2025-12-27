<p align="center">
  <img src="https://svg-banners.vercel.app/api?type=origin&text1=UNI%20Exam&width=900&height=250&color=blue" />
</p>

<h1 align="center" style="color:#3498DB;">
      University Exam Management System
</h1>
## Advanced Database Project (PL/SQL)

---

## 📌 Project Description
This project implements a **University Exam Management System** using **Advanced Database concepts**
and **PL/SQL**.  
The system automates exam scheduling, student registration validation, grade processing,
auditing, and reporting in a secure and consistent database environment.

It is designed to demonstrate practical usage of **procedures, functions, triggers,
cursors, and transactions** in a real-world academic scenario.

---

## 🎯 Project Objectives
- Automate exam and registration management
- Enforce data integrity and consistency
- Apply advanced PL/SQL programming techniques
- Track database changes using audit trails
- Generate analytical and performance reports

---

## 🛠 Technologies Used
- Oracle SQL
- PL/SQL
- Stored Procedures
- Functions
- Triggers
- Cursors
- Transactions

---

## 🗄 Database Tables
The system includes the following main tables:
- **Courses**
- **Professors**
- **Students**
- **Register**
- **Exams**
- **ExamResults**
- **Warnings**
- **AuditTrail**

These tables model course registration, exam scheduling, grading,
warnings, and auditing operations.

---

## 🔐 Features Implemented

### 1️⃣ User Management & Privileges
- Manager user creation
- Controlled creation of database users
- Automatic logging of user creation using PL/SQL procedures

---

### 2️⃣ Exam Eligibility Validation
- Trigger-based prerequisite checking
- Prevents students from registering for courses without completing prerequisites

---

### 3️⃣ Grade Calculation Function
- PL/SQL function calculates grades based on exam scores
- Automatically updates grades in the `ExamResults` table

---

### 4️⃣ Automated Warning Issuance
- Procedure detects students with multiple failing grades
- Automatically inserts warning records into the `Warnings` table

---

### 5️⃣ Audit Trail for Registration
- BEFORE INSERT and BEFORE DELETE triggers on the `Register` table
- Logs all registration and deregistration actions with timestamps

---

### 6️⃣ Course Performance Report
- Cursor-based report generation
- Displays student grades and pass/fail statistics per course

---

### 7️⃣ Exam Schedule Management
- PL/SQL block retrieves and displays exam schedules
- Handles cases where no exams are scheduled

---

### 8️⃣ Multi-Exam Grade Update (Transactions)
- Processes multiple grade updates in a single transaction
- Ensures rollback in case of any errors to maintain consistency

---

### 9️⃣ Student Suspension Based on Warnings
- Procedure identifies students with three or more warnings
- Updates academic status to **Suspended**
- Logs updates in the `AuditTrail` table

---

### 🔟 Advanced Grade Management & Data Integrity
- GPA calculation function using course credit hours
- Trigger prevents unauthorized grade updates
- Enforces role-based grade modification

---

## 🧪 Bonus Features

### 1️⃣ Blocker–Waiting Scenario
- Demonstrates table locking using two concurrent transactions
- Simulates real-world database contention

### 2️⃣ Session Identification
- Identifies blocking and waiting sessions using **SID** and **SERIAL#**
- Displays resolution details


This project demonstrates the application of **advanced database concepts**
and **PL/SQL programming** in a structured and realistic university system.
