
SYS AS SYSDBA
7530159

ALTER SESSION SET CONTAINER = XEPDB1;


CREATE USER MANAGER IDENTIFIED BY "123"; 
GRANT CREATE SESSION, CREATE USER, ALTER USER, DROP USER TO MANAGER;
ALTER USER MANAGER QUOTA UNLIMITED ON USERS;

--fix privilege issue
GRANT GRANT ANY PRIVILEGE TO MANAGER;
--==============================================

sqlplus MANAGER/"123"@localhost:1521/XEPDB1


CREATE USER USER1 IDENTIFIED BY "u1";
CREATE USER USER2 IDENTIFIED BY "u2";

GRANT CREATE SESSION TO USER1;
GRANT CREATE SESSION TO USER2;

GRANT CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER TO USER1;

ALTER USER USER1 QUOTA UNLIMITED ON USERS;
ALTER USER USER2 QUOTA UNLIMITED ON USERS;

--fix grants issue

--1.create tables
sqlplus USER1/"u1"@localhost:1521/XEPDB1

CREATE TABLE Professors (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    department VARCHAR2(100) NOT NULL
);

CREATE TABLE Courses (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    professor_id NUMBER NOT NULL,
    credit_hours NUMBER CHECK (credit_hours > 0),
    prerequisite_course_id NUMBER,
    CONSTRAINT fk_course_professor
        FOREIGN KEY (professor_id) REFERENCES Professors(id),
    CONSTRAINT fk_course_prerequisite
        FOREIGN KEY (prerequisite_course_id) REFERENCES Courses(id)
);

CREATE TABLE Students (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    academic_status VARCHAR2(20)
        CHECK (academic_status IN ('Active','Suspended')),
    total_credits NUMBER DEFAULT 0 CHECK (total_credits >= 0)
);

CREATE TABLE Register (
    id NUMBER PRIMARY KEY,
    student_id NUMBER NOT NULL,
    course_id NUMBER NOT NULL,
    CONSTRAINT fk_register_student
        FOREIGN KEY (student_id) REFERENCES Students(id),
    CONSTRAINT fk_register_course
        FOREIGN KEY (course_id) REFERENCES Courses(id),
    CONSTRAINT uq_student_course
        UNIQUE (student_id, course_id)
);

CREATE TABLE Exams (
    id NUMBER PRIMARY KEY,
    course_id NUMBER NOT NULL,
    exam_date DATE NOT NULL,
    exam_type VARCHAR2(20)
        CHECK (exam_type IN ('Midterm','Final')),
    CONSTRAINT fk_exam_course
        FOREIGN KEY (course_id) REFERENCES Courses(id)
);

CREATE TABLE ExamResults (
    id NUMBER PRIMARY KEY,
    registration_id NUMBER NOT NULL,
    score NUMBER CHECK (score BETWEEN 0 AND 100),
    grade VARCHAR2(2),
    status VARCHAR2(10)
        CHECK (status IN ('Pass','Fail')),
    CONSTRAINT fk_examresults_registration
        FOREIGN KEY (registration_id) REFERENCES Register(id)
);

CREATE TABLE AuditTrail (
    id NUMBER PRIMARY KEY,
    table_name VARCHAR2(50),
    operation VARCHAR2(20),
    old_data CLOB,
    new_data CLOB,
    log_date TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE TABLE Warnings (
    id NUMBER PRIMARY KEY,
    student_id NUMBER NOT NULL,
    warning_reason VARCHAR2(200),
    warning_date DATE DEFAULT SYSDATE,
    CONSTRAINT fk_warning_student
        FOREIGN KEY (student_id) REFERENCES Students(id)
);

CREATE TABLE DBUserCreationLog (
    id NUMBER PRIMARY KEY,
    username VARCHAR2(50),
    created_by VARCHAR2(50),
    created_at TIMESTAMP DEFAULT SYSTIMESTAMP
);

--2.grant privileges to MANAGER
sqlplus / as sysdba
ALTER SESSION SET CONTAINER = XEPDB1;
GRANT GRANT ANY OBJECT PRIVILEGE TO MANAGER;
GRANT GRANT ANY PRIVILEGE TO MANAGER;

--==============================================

GRANT INSERT, SELECT ON USER1.STUDENTS TO USER2;
GRANT INSERT, SELECT ON USER1.COURSES TO USER2;
GRANT INSERT, SELECT ON USER1.REGISTER TO USER2;


GRANT SELECT, INSERT ON USER1.PROFESSORS TO USER2;


sqlplus USER2/"u2"@localhost:1521/XEPDB1


INSERT INTO USER1.PROFESSORS (id, name, department) VALUES (1, 'Dr. Ahmed', 'DS'); 
INSERT INTO USER1.PROFESSORS (id, name, department) VALUES (2, 'Dr. Elsayed',  'RSE'); 

INSERT INTO USER1.COURSES (id, name, professor_id, credit_hours, prerequisite_course_id)
VALUES (101, 'Databases', 1, 3, NULL);

INSERT INTO USER1.COURSES (id, name, professor_id, credit_hours, prerequisite_course_id)
VALUES (102, 'Adv Databases', 1, 3, 101); 

INSERT INTO USER1.COURSES (id, name, professor_id, credit_hours, prerequisite_course_id)
VALUES (103, 'AI For Beginners', 2, 3, NULL); 

INSERT INTO USER1.STUDENTS (id, name, academic_status, total_credits)
VALUES (1, 'Amr',   'Active', 0);

INSERT INTO USER1.STUDENTS (id, name, academic_status, total_credits)
VALUES (2, 'Doha',  'Active', 0);

INSERT INTO USER1.STUDENTS (id, name, academic_status, total_credits)
VALUES (3, 'Kareem',  'Active', 0);

INSERT INTO USER1.STUDENTS (id, name, academic_status, total_credits)
VALUES (4, 'Abdallah',  'Active', 0);

INSERT INTO USER1.STUDENTS (id, name, academic_status, total_credits)
VALUES (5, 'Youssef',  'Active', 0);



INSERT INTO USER1.REGISTER (id, student_id, course_id) VALUES (1, 1, 101);
INSERT INTO USER1.REGISTER (id, student_id, course_id) VALUES (2, 2, 101);
INSERT INTO USER1.REGISTER (id, student_id, course_id) VALUES (3, 3, 103);
INSERT INTO USER1.REGISTER (id, student_id, course_id) VALUES (4, 4, 101);
INSERT INTO USER1.REGISTER (id, student_id, course_id) VALUES (5, 5, 103);

COMMIT;

SELECT COUNT(*) FROM USER1.STUDENTS;
SELECT COUNT(*) FROM USER1.REGISTER;

sqlplus USER1/"u1"@localhost:1521/XEPDB1

CREATE SEQUENCE AUDITTRAIL_SEQ START WITH 1 INCREMENT BY 1;


CREATE OR REPLACE TRIGGER TRG_CHECK_PREREQ
BEFORE INSERT ON REGISTER
FOR EACH ROW
DECLARE
    v_prereq_id  COURSES.PREREQUISITE_COURSE_ID%TYPE;
    v_count      NUMBER;
BEGIN
    SELECT prerequisite_course_id
    INTO v_prereq_id
    FROM courses
    WHERE id = :NEW.course_id;

    IF v_prereq_id IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_count
        FROM register r
        JOIN examresults er
          ON er.registration_id = r.id
        WHERE r.student_id = :NEW.student_id
          AND r.course_id  = v_prereq_id
          AND er.status    = 'Pass';

        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Registration blocked: prerequisite course not completed.'
            );
        END IF;
    END IF;
END;
/



CREATE OR REPLACE TRIGGER TRG_REGISTER_AUDIT_INS
BEFORE INSERT ON REGISTER
FOR EACH ROW
BEGIN
    INSERT INTO audittrail (id, table_name, operation, old_data, new_data, log_date)
    VALUES (
        AUDITTRAIL_SEQ.NEXTVAL,
        'REGISTER',
        'INSERT',
        NULL,
        TO_CLOB('id=' || :NEW.id || '; student_id=' || :NEW.student_id || '; course_id=' || :NEW.course_id),
        SYSTIMESTAMP
    );
END;
/


CREATE OR REPLACE TRIGGER TRG_REGISTER_AUDIT_DEL
BEFORE DELETE ON REGISTER
FOR EACH ROW
BEGIN
    INSERT INTO audittrail (id, table_name, operation, old_data, new_data, log_date)
    VALUES (
        AUDITTRAIL_SEQ.NEXTVAL,
        'REGISTER',
        'DELETE',
        TO_CLOB('id=' || :OLD.id || '; student_id=' || :OLD.student_id || '; course_id=' || :OLD.course_id),
        NULL,
        SYSTIMESTAMP
    );
END;
/


--test triggers
SELECT trigger_name, status
FROM user_triggers
WHERE trigger_name IN ('TRG_CHECK_PREREQ','TRG_REGISTER_AUDIT_INS','TRG_REGISTER_AUDIT_DEL');



CREATE OR REPLACE FUNCTION FN_CALC_GRADE (p_examresult_id IN NUMBER)
RETURN VARCHAR2
IS
    v_score NUMBER;
    v_grade VARCHAR2(2);
    v_status VARCHAR2(10);
BEGIN
    SELECT score
    INTO v_score
    FROM examresults
    WHERE id = p_examresult_id
    FOR UPDATE;

    IF v_score BETWEEN 90 AND 100 THEN
        v_grade := 'A';
    ELSIF v_score BETWEEN 80 AND 89 THEN
        v_grade := 'B';
    ELSIF v_score BETWEEN 70 AND 79 THEN
        v_grade := 'C';
    ELSIF v_score BETWEEN 60 AND 69 THEN
        v_grade := 'D';
    ELSE
        v_grade := 'F';
    END IF;

    IF v_grade = 'F' THEN
        v_status := 'Fail';
    ELSE
        v_status := 'Pass';
    END IF;

    UPDATE examresults
    SET grade = v_grade,
        status = v_status
    WHERE id = p_examresult_id;

    RETURN v_grade;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20010, 'ExamResults ID not found.');
END;
/


--test function
SELECT id, score, grade, status FROM examresults;

INSERT INTO examresults (id, registration_id, score, grade, status)
VALUES (1, 1, 85, NULL, NULL);
COMMIT;

SET SERVEROUTPUT ON;

DECLARE
  v_g VARCHAR2(2);
BEGIN
  v_g := FN_CALC_GRADE(1);
  DBMS_OUTPUT.PUT_LINE('Calculated Grade = ' || v_g);
END;
/



--(4) Automated Warning Issuance:

CREATE SEQUENCE WARNINGS_SEQ START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PROCEDURE PR_ISSUE_WARNINGS
IS
BEGIN
  FOR rec IN (
      SELECT r.student_id
      FROM register r
      JOIN examresults er
        ON er.registration_id = r.id
      WHERE er.status = 'Fail'
      GROUP BY r.student_id
      HAVING COUNT(*) >= 2
  ) LOOP
      INSERT INTO warnings (id, student_id, warning_reason, warning_date)
      VALUES (
          WARNINGS_SEQ.NEXTVAL,
          rec.student_id,
          'Failing in two or more courses',
          SYSDATE
      );
  END LOOP;

  COMMIT;
END;
/


BEGIN
  PR_ISSUE_WARNINGS;
END;
/


SELECT * FROM warnings ORDER BY id;


--test fail case
SELECT * FROM register WHERE student_id = 1;

INSERT INTO register (id, student_id, course_id) VALUES (1001, 1, 101);
INSERT INTO register (id, student_id, course_id) VALUES (1002, 1, 103);
COMMIT;


INSERT INTO examresults (id, registration_id, score, grade, status)
VALUES (201, 1001, 40, 'F', 'Fail');

INSERT INTO examresults (id, registration_id, score, grade, status)
VALUES (202, 1002, 50, 'F', 'Fail');

COMMIT;


BEGIN
  PR_ISSUE_WARNINGS;
END;
/

SELECT * FROM warnings;

--==============================================


CREATE OR REPLACE PROCEDURE PR_COURSE_PERFORMANCE_REPORT (p_course_id IN NUMBER)
IS
    CURSOR c_report IS
        SELECT s.id   AS student_id,
               s.name AS student_name,
               r.id   AS registration_id,
               er.score,
               er.grade,
               er.status
        FROM register r
        JOIN students s
          ON s.id = r.student_id
        LEFT JOIN examresults er
          ON er.registration_id = r.id
        WHERE r.course_id = p_course_id
        ORDER BY s.id;

    v_course_name courses.name%TYPE;
    v_pass NUMBER := 0;
    v_fail NUMBER := 0;
    v_total NUMBER := 0;
BEGIN
    SELECT name INTO v_course_name
    FROM courses
    WHERE id = p_course_id;

    DBMS_OUTPUT.PUT_LINE('Course Report: ' || v_course_name || ' (Course ID=' || p_course_id || ')');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');

    FOR rec IN c_report LOOP
        v_total := v_total + 1;

        IF rec.status = 'Pass' THEN
            v_pass := v_pass + 1;
        ELSIF rec.status = 'Fail' THEN
            v_fail := v_fail + 1;
        END IF;

        DBMS_OUTPUT.PUT_LINE(
            'StudentID=' || rec.student_id ||
            ', Name=' || rec.student_name ||
            ', RegID=' || rec.registration_id ||
            ', Score=' || NVL(TO_CHAR(rec.score), 'N/A') ||
            ', Grade=' || NVL(rec.grade, 'N/A') ||
            ', Status=' || NVL(rec.status, 'NoResult')
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Total Students: ' || v_total);
    DBMS_OUTPUT.PUT_LINE('Passed: ' || v_pass);
    DBMS_OUTPUT.PUT_LINE('Failed: ' || v_fail);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No such course found for Course ID=' || p_course_id);
END;
/


SET SERVEROUTPUT ON;

BEGIN
  PR_COURSE_PERFORMANCE_REPORT(101);
END;
/



INSERT INTO exams (id, course_id, exam_date, exam_type)
VALUES (1, 101, TO_DATE('2025-12-20','YYYY-MM-DD'), 'Midterm');

INSERT INTO exams (id, course_id, exam_date, exam_type)
VALUES (2, 101, TO_DATE('2026-01-10','YYYY-MM-DD'), 'Final');

COMMIT;



SET SERVEROUTPUT ON;

DECLARE
  v_course_name courses.name%TYPE;
  v_count NUMBER;
BEGIN
  SELECT name INTO v_course_name
  FROM courses
  WHERE id = 101;

  SELECT COUNT(*) INTO v_count
  FROM exams
  WHERE course_id = 101;

  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('No exams scheduled for course: ' || v_course_name);
  ELSE
    DBMS_OUTPUT.PUT_LINE('Exam Schedule for course: ' || v_course_name);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');

    FOR rec IN (
      SELECT exam_date, exam_type
      FROM exams
      WHERE course_id = 101
      ORDER BY exam_date
    ) LOOP
      DBMS_OUTPUT.PUT_LINE(
        TO_CHAR(rec.exam_date, 'YYYY-MM-DD') || ' - ' || rec.exam_type
      );
    END LOOP;
  END IF;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Course not found.');
END;
/






SELECT id, registration_id, score, grade, status
FROM examresults
ORDER BY id;

SET SERVEROUTPUT ON;

DECLARE
  TYPE t_reg_list IS TABLE OF NUMBER;
  v_regs   t_reg_list := t_reg_list(1, 2, 1002); -- registration IDs
  v_scores t_reg_list := t_reg_list(92, 55, 80);  

  v_er_id  NUMBER;
  v_grade  VARCHAR2(2);
BEGIN
  FOR i IN 1 .. v_regs.COUNT LOOP
    BEGIN
      SELECT id
      INTO v_er_id
      FROM examresults
      WHERE registration_id = v_regs(i);

      UPDATE examresults
      SET score = v_scores(i)
      WHERE id = v_er_id;

      v_grade := FN_CALC_GRADE(v_er_id);

      DBMS_OUTPUT.PUT_LINE('Updated reg_id=' || v_regs(i) ||
                           ' => score=' || v_scores(i) ||
                           ', grade=' || v_grade);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20100, 'Registration_id not found in ExamResults: ' || v_regs(i));
    END;
  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Transaction COMMIT completed successfully.');

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('All changes rolled back.');
END;
/
-- or thiss 

SELECT registration_id, COUNT(*)
FROM examresults
GROUP BY registration_id
HAVING COUNT(*) > 1;

DELETE FROM examresults
WHERE id = 9002;

COMMIT;

ALTER TABLE examresults
ADD CONSTRAINT uq_examresults_reg UNIQUE (registration_id);

SET SERVEROUTPUT ON;

DECLARE
  TYPE t_list IS TABLE OF NUMBER;

  v_regs   t_list := t_list(1, 1002);
  v_scores t_list := t_list(95, 40);

  v_er_id  NUMBER;
  v_grade  VARCHAR2(2);
BEGIN
  FOR i IN 1 .. v_regs.COUNT LOOP
    SELECT id INTO v_er_id
    FROM examresults
    WHERE registration_id = v_regs(i);

    UPDATE examresults
    SET score = v_scores(i)
    WHERE id = v_er_id;

    v_grade := FN_CALC_GRADE(v_er_id);

    DBMS_OUTPUT.PUT_LINE('Updated reg_id=' || v_regs(i) ||
                         ' => score=' || v_scores(i) ||
                         ', grade=' || v_grade);
  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Transaction COMMIT completed successfully.');

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('All changes rolled back.');
END;
/

SELECT id, registration_id, score, grade, status
FROM examresults
ORDER BY id;
--or this
SET SERVEROUTPUT ON;

DECLARE
  TYPE t_list IS TABLE OF NUMBER;

  v_regs   t_list := t_list(1, 1002);
  v_scores t_list := t_list(95, 40);

  v_er_id  NUMBER;
  v_grade  VARCHAR2(2);
BEGIN
  FOR i IN 1 .. v_regs.COUNT LOOP
    SELECT MAX(id)
    INTO v_er_id
    FROM examresults
    WHERE registration_id = v_regs(i);

    IF v_er_id IS NULL THEN
      RAISE_APPLICATION_ERROR(-20100, 'Registration_id not found: ' || v_regs(i));
    END IF;

    UPDATE examresults
    SET score = v_scores(i)
    WHERE id = v_er_id;

    v_grade := FN_CALC_GRADE(v_er_id);

    DBMS_OUTPUT.PUT_LINE('Updated reg_id=' || v_regs(i) ||
                         ' => score=' || v_scores(i) ||
                         ', grade=' || v_grade);
  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Transaction COMMIT completed successfully.');

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('All changes rolled back.');
END;
/
--==============================================

CREATE OR REPLACE PROCEDURE PR_SUSPEND_STUDENTS
IS
BEGIN
  FOR rec IN (
      SELECT student_id
      FROM warnings
      GROUP BY student_id
      HAVING COUNT(*) >= 3
  ) LOOP

      INSERT INTO audittrail (id, table_name, operation, old_data, new_data, log_date)
      VALUES (
          AUDITTRAIL_SEQ.NEXTVAL,
          'STUDENTS',
          'UPDATE',
          'student_id=' || rec.student_id || ', academic_status=Active',
          'student_id=' || rec.student_id || ', academic_status=Suspended',
          SYSTIMESTAMP
      );

      UPDATE students
      SET academic_status = 'Suspended'
      WHERE id = rec.student_id;

  END LOOP;

  COMMIT;
END;
/


BEGIN
  PR_SUSPEND_STUDENTS;
END;
/

SELECT id, name, academic_status
FROM students
ORDER BY id;




CREATE OR REPLACE FUNCTION FN_CALC_GPA (p_student_id IN NUMBER)
RETURN NUMBER
IS
  v_total_points NUMBER := 0;
  v_total_credits NUMBER := 0;
  v_gpa NUMBER := 0;
BEGIN
  FOR rec IN (
    SELECT c.credit_hours,
           er.grade
    FROM students s
    JOIN register r   ON r.student_id = s.id
    JOIN courses  c   ON c.id = r.course_id
    JOIN examresults er ON er.registration_id = r.id
    WHERE s.id = p_student_id
      AND er.grade IS NOT NULL
  ) LOOP
    v_total_credits := v_total_credits + rec.credit_hours;

    v_total_points := v_total_points +
      (CASE rec.grade
         WHEN 'A' THEN 4
         WHEN 'B' THEN 3
         WHEN 'C' THEN 2
         WHEN 'D' THEN 1
         WHEN 'F' THEN 0
         ELSE 0
       END) * rec.credit_hours;
  END LOOP;

  IF v_total_credits = 0 THEN
    RETURN NULL; 
  END IF;

  v_gpa := v_total_points / v_total_credits;
  RETURN ROUND(v_gpa, 2);
END;
/


SELECT FN_CALC_GPA(1) AS GPA FROM dual;

--==============================================
--==============================================
--BONUS PART
--==============================================
--==============================================
---FIX TESTING ISSUE
sqlplus MANAGER/"123"@localhost:1521/XEPDB1
GRANT UPDATE ON USER1.STUDENTS TO USER2;

--==============================================
--11
sqlplus USER1/"u1"@localhost:1521/XEPDB1

SET SERVEROUTPUT ON;

UPDATE students
SET academic_status = 'Active'
WHERE id = 1;


sqlplus USER2/"u2"@localhost:1521/XEPDB1

UPDATE USER1.STUDENTS
SET academic_status = 'Suspended'
WHERE id = 1;
--12
sqlplus / as sysdba

ALTER SESSION SET CONTAINER = XEPDB1;

SELECT sid, serial#, username, status, blocking_session, event, seconds_in_wait
FROM v$session
WHERE username IN ('USER1','USER2')
ORDER BY username;

SELECT
  s.sid AS waiting_sid,
  s.serial# AS waiting_serial,
  s.username AS waiting_user,
  s.blocking_session AS blocker_sid,
  bs.serial# AS blocker_serial,
  bs.username AS blocker_user,
  s.event,
  s.seconds_in_wait
FROM v$session s
LEFT JOIN v$session bs
  ON bs.sid = s.blocking_session
WHERE s.username = 'USER2';
--Back to USER1 
COMMIT;
--or
ROLLBACK;
--==============================================