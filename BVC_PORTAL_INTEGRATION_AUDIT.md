# BVC Student Portal Integration Audit & Feasibility Report

**Target College Portal:** `https://www.bvcecautonomous.com/` & `https://bvcec.edu.in/`  
**System Name:** SBCMS (Smart Brainy Campus Management System / Examination Section)  
**Document Status:** Pre-Implementation Security & Architecture Audit  
**Date:** September 2026  

---

## 1. Executive Summary

This audit assesses the technical feasibility, security architecture, privacy constraints, and integration pathways for connecting official student academic records from BVC Engineering College (`bvcecautonomous.com` / `bvcec.edu.in`) into Nexora.

### Key Audit Findings
1. **Underlying Technology:** The student portal (`www.bvcecautonomous.com`) is built on a legacy **Microsoft ASP.NET WebForms architecture (.NET Framework)** utilizing server-side view state encryption (`__VIEWSTATE`, `__EVENTVALIDATION`, `__VIEWSTATEGENERATOR`) and HTTP-only session cookies (`ASP.NET_SessionId`).
2. **Official API Availability:** **No official public REST API, GraphQL endpoint, Swagger/OpenAPI definition, or OAuth2/OIDC authorization server exists.**
3. **Authentication Mechanism:** Authentication is form-based via `SBLogin.aspx`, requiring a Student Username (`txtUserName` — the student's BVC Roll Number, e.g. `25221A0568`) and Password (`txtPassword`), submitted via HTTP POST with active page viewstate tokens.
4. **Data Isolation & Privacy:** Student academic data (attendance, marks, SGPA/CGPA, fee dues) is strictly private. Under no circumstances may student data be ingested into the global RAG database, shared Vectorize indices, or public GraphRAG structures.
5. **Existing Auth Invariance:** Nexora's existing Firebase Email/Password authentication is untouched and remains the sole identity provider. The BVC Roll Number and academic profile attach to the student's existing `firebase_uid` as an external data link.

---

## 2. BVC Portal Architecture & Discovery

### 2.1 Domain & Hosting Topology
- **Main Institutional Portal:** `https://bvcec.edu.in/` (WordPress on Apache/Linux, public notices, circulars, syllabus, regulations).
- **Autonomous Examination & Student Portal:** `https://www.bvcecautonomous.com/` (Microsoft IIS, ASP.NET WebForms).
- **Exam Application Gateway:** `http://123.108.201.163/examapplications2021/pg_exam_app.html` (Static IP portal for semester examination registration and fee payment).

### 2.2 Entry Points & ASP.NET Pages
Live inspection of `https://www.bvcecautonomous.com/` revealed the following key pages:
- `/` (Default Homepage): Contains institutional notices, exam notifications, revaluation circulars, and the student navigation trigger.
- `lnkStudent` PostBack: Invokes `javascript:NavigateReport()`, which launches `SBLogin.aspx`.
- `SBLogin.aspx`: The primary student and staff authentication portal ("BVC Group of Institutions SBCMS — Complete Campus Automation").
  - Form ID: `form1`
  - Action: `./SBLogin.aspx`
  - Input field 1: `txtUserName` (type="text", placeholder="Username", e.g., Roll Number)
  - Input field 2: `txtPassword` (type="password", placeholder="Password")
  - Submit button: `btnSubmit` (value="Login")
  - Recovery link: `linkPwd` ("Forgot Password?")
- `OnlineResultReport.aspx`: Semester-wise grade sheets, marks, and SGPA/CGPA report generator. Requires an authenticated `ASP.NET_SessionId` session; direct unauthenticated GET requests return HTTP 500 (`NullReferenceException` in server-side session lookup).
- `ViewHomepage.aspx`: Student home dashboard containing personal academic summary, profile, branch, section, and semester status.
- `StaffNotifications.aspx`: Internal academic circulars and faculty circulars.

---

## 3. Student Academic Information Inventory

Once authenticated, the following fields are maintained within the SBCMS portal:

| Category | Available Fields | Sensitivity Level | Destination in Nexora |
| :--- | :--- | :--- | :--- |
| **Profile** | Full Name, Roll Number, Student ID, College Email, Course, Branch, Section, Academic Year, Semester, Regulation (e.g. BR23, BR20) | High (PII) | Private Student D1 Table (`student_profile`) |
| **Subjects** | Subject Code, Subject Title, Credits, Faculty Name, Lab vs Theory | Low (Academic) | Private Student D1 Table (`student_subjects`) |
| **Attendance** | Total Classes Conducted, Classes Attended, Attendance Percentage, Subject-wise Breakdown, Shortage Warning Flag | High (Personal) | Private Student D1 Table (`student_attendance`) |
| **Results** | Internal Marks, External Marks, Total Marks, Grade, Grade Points, Credits Earned, SGPA, CGPA, Backlog Status | Critical (Academic Record) | Private Student D1 Table (`student_results`) |
| **Timetable** | Day, Period, Subject Code, Room/Lab Location, Time Slot | Medium (Schedule) | Private Student D1 Table (`student_timetable`) |
| **Fees** | Tuition Fee, Exam Fee, Bus/Hostel Fee, Amount Paid, Due Date, Payment Status | Critical (Financial) | Private Student D1 Table (`student_fees`) |
| **Exams** | Hall Ticket Number, Examination Schedule, Room Allocation, Timetable | High (Academic) | Private Student D1 Table (`student_exams`) |

> [!CAUTION]
> **Zero Guessed Data Principle:**
> Nexora will NEVER infer, calculate, or guess:
> - Branch, Section, or Regulation from the Roll Number pattern.
> - Current Semester from the calendar date.
> - Attendance numbers or SGPA/CGPA.
> If BVC does not supply a field, it remains `null`/`unavailable`.

---

## 4. Roll Number Normalization Specification

The student's BVC Roll Number is the primary college key. Nexora enforces strict normalization on both the client (Flutter) and backend (Cloudflare Worker):

1. **Trimming:** Strip all leading, trailing, and embedded whitespace (`" 25221a0568 "` $\rightarrow$ `"25221a0568"`).
2. **Casing:** Convert strictly to uppercase ASCII (`"25221a0568"` $\rightarrow$ `"25221A0568"`).
3. **Format Validation (BVC Pattern):** Matches `^[0-9]{2}[0-9A-Z]{2}[0-9A-Z][0-9A-Z0-9]{4,5}$` (e.g., `25221A0568`, `21221A0501`, `22225A0402` for Lateral Entry).
4. **Storage:** Stored in normalized uppercase across all database indexes and audit logs.

---

## 5. Potential Integration Methods Comparison

```
+-------------------------------------------------------------------------+
|                    BVC INTEGRATION METHODS MATRIX                       |
+-------------------------------------------------------------------------+
| Option | Method                | Feasibility | Security | Sustainability|
+--------+-----------------------+-------------+----------+---------------+
| 1      | Official BVC REST API | Ideal       | High     | High          |
|        | (Requires BVC Approval)                                        |
| 2      | Authorized Session    | Feasible    | High     | Medium        |
|        | Token Connector       |             |          |               |
| 3      | Direct Student Creds  | Conditional | Medium   | Low           |
|        | Web Scraping (ASP.NET)|             |          |               |
| 4      | Verified Document     | Immediate   | Maximum  | Maximum       |
|        | Sync (Grade Card/PDF) |             |          |               |
+-------------------------------------------------------------------------+
```

### Option 1: Official BVC Partner API / Webhook (Recommended Target)
- **Mechanism:** College IT administration provides a secured API endpoint (Bearer Token / API Key) querying the backend SBCMS database directly for a verified student roll number.
- **Pros:** Fast, zero scraping fragility, no password handling, institutional compliance.
- **Cons:** Requires explicit MoU / administrative approval from BVC College Principal & Autonomous Examination Cell.

### Option 2: Authorized Student-Initiated Session Connector
- **Mechanism:** Nexora provides a secure web authentication bridge where the student authenticates directly against `www.bvcecautonomous.com/SBLogin.aspx`. The session token (`ASP.NET_SessionId`) is temporarily held in encrypted memory for one-shot extraction of the student's dashboard and result pages.
- **Pros:** No persistent storage of BVC passwords; student explicitly authorizes every synchronization.
- **Cons:** Fragile if SBCMS updates its HTML markup or ASP.NET viewstate encryption keys.

### Option 3: Verified Academic Document / Grade Sheet Upload (Fallback Zero-Risk Method)
- **Mechanism:** Student downloads their official grade card or result PDF directly from the autonomous portal and uploads it to Nexora. Nexora's deterministic parser extracts the exact marks, SGPA, CGPA, subjects, and regulation without ever needing the student's college password.
- **Pros:** 100% compliant with all IT privacy policies; works immediately with zero college infrastructure dependency.

---

## 6. Recommended Implementation Roadmap

1. **Phase 1 (Immediate Architecture & Security Isolation):**
   - Create private D1 tables for student profile, subjects, attendance, and results, segregated by `firebase_uid`.
   - Build the backend normalization and mapping layers ([`src/bvc/`](file:///c:/Users/Admin/Desktop/final%20nexora/workers/nexora-bvc-api-2026/src/bvc)).
   - Implement Firebase UID token verification on all `/student/*` endpoints.
2. **Phase 2 (Dual Connector: Direct Sync + Document Verification):**
   - Implement the modular `BVCClient` interface with pluggable drivers (`BVC_API_DRIVER` and `BVC_SCRAPER_DRIVER`).
   - Add graceful fallback handling when SBCMS is offline or returns unexpected viewstate errors.
3. **Phase 3 (Institutional Partnership & Official Access Request):**
   - Submit the formal BVC API Access Request to the BVC Autonomous Examination Cell to obtain official API access.

---

## 7. What Requires Approval from BVC College Administration

To transition from an authorized client-session scraper to an official institutional API:
1. **API Gateway Whitelisting:** Permission for Nexora's Cloudflare Worker IPs to access SBCMS backend queries without firewall throttling.
2. **Service Account / Shared Secret:** A secure institutional token allowing verified student data lookups by roll number.
3. **Data Protection Agreement:** Formal alignment with BVC's autonomous examination confidentiality guidelines.

---

*Report prepared by Nexora Engineering for BVC Engineering College.*
