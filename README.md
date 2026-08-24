<div align="center">

# 🏥 HealthVerse
### AI-Powered Ophthalmology Platform

*A full-stack intelligent healthcare system connecting patients and eye-care specialists through AI triage, real-time consultations, digital prescriptions, and smart medication tracking.*

</div>

---

## 📋 Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Complete User Flow](#complete-user-flow)
- [Components](#components)
  - [1. Backend API (.NET ASP.NET Core)](#1-backend-api-net-aspnet-core)
  - [2. Flutter Patient App](#2-flutter-patient-app)
  - [3. BlazorUI Doctor Dashboard](#3-blazorui-doctor-dashboard)
  - [4. Patient AI Agent (HealthVerse-agent_with_mcp)](#4-patient-ai-agent-healthverse-agent_with_mcp)
  - [5. Doctor AI Agent (HealthVerse-doctor-agents)](#5-doctor-ai-agent-healthverse-doctor-agents)
  - [6. Admin Dashboard](#6-admin-dashboard)
- [Tech Stack](#tech-stack)
- [Database Schema](#database-schema)
- [Setup & Running](#setup--running)
- [Environment Variables](#environment-variables)

---

## Overview

HealthVerse is a specialized AI-assisted ophthalmology platform for Pakistan. It bridges patients and eye-care specialists by:

1. **AI pre-triage** — A conversational AI agent collects patient symptoms in Urdu, English, Roman Urdu, or via voice, asks targeted MCQ follow-up questions, and recommends the right specialist.
2. **Smart appointment booking** — Patient books with the recommended doctor; all triage data is persisted to their record.
3. **Doctor AI assistant** — On appointment day, the doctor's AI agent loads the patient's full history and triage summary to guide clinical decision-making.
4. **Digital prescriptions** — Doctor generates a structured prescription, which is delivered to the patient via push notification and email.
5. **Medication tracking** — Patient tracks daily medication adherence, sees graphical progress, and gets reminders.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                                  │
│                                                                     │
│  Flutter App (Patient)          BlazorUI (Doctor Dashboard)         │
│  Android / iOS / Web            Web (Blazor Server)                 │
└──────────────────┬──────────────────────────┬───────────────────────┘
                   │                          │
                   ▼                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│              first_api  —  .NET ASP.NET Core REST API               │
│                     + SignalR Real-time Hub                         │
│                                                                     │
│  Controllers:  Auth · Patient · Doctor · Appointment · Chat         │
│                Prescription · MedicationTracking · Notification     │
│                Stripe · Referral · Voice · DoctorVerification        │
│                                                                     │
│  Services:  NotificationScheduler · AppointmentConfirmation         │
│             DoctorAgentAssignment · Stripe · Cloudinary             │
└───────┬──────────────────────────────────────┬───────────────────────┘
        │                                      │
        ▼                                      ▼
┌───────────────────┐              ┌────────────────────────┐
│  Patient AI Agent │              │   Doctor AI Agents     │
│  FastAPI + LangGraph              │   FastAPI + LangGraph  │
│  Port :8000       │              │   Port :8001           │
│                   │              │                        │
│  Ophthalmology    │              │  Ophthalmologist       │
│  Triage Agent     │              │  Optometrist           │
│  + RAG (Qdrant)   │              │  Optician              │
│  + MCP Tools      │              │  Ocularist             │
└───────────────────┘              └────────────────────────┘
        │                                      │
        ▼                                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       DATA LAYER                                    │
│  MongoDB Atlas           Qdrant Cloud          Cloudinary           │
│  (primary store)         (vector RAG)          (media/PDFs)         │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   EXTERNAL SERVICES                                 │
│  Firebase FCM (push)  ·  Stripe (payments)  ·  Gemini AI           │
│  PMDC API (doctor verification)  ·  Speechnotes (voice→text)       │
│  SMTP Gmail (email)                                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Complete User Flow

### 🧑‍🤝‍🧑 Patient Journey

```
1. ONBOARDING
   Patient opens Flutter app → Liquid-swipe onboarding → Register/Login (JWT)
   ↓
2. SYMPTOM INTAKE  (multilingual + voice)
   Patient describes symptoms in:
   ├── English: "My eye hurts and vision is blurry"
   ├── Urdu: "میری آنکھ میں درد ہے اور نظر دھندلی ہے"
   ├── Roman Urdu: "meri ankh mein dard hai"
   └── Voice: Tap mic → Speechnotes API transcribes → saved as InitialConditions
   ↓
3. AI TRIAGE (Patient Agent · port 8000)
   LangGraph ReAct agent receives symptoms
   ├── Queries Qdrant vector DB for similar ophthalmology cases (RAG)
   ├── Generates targeted MCQ follow-up questions (up to 6 rounds)
   │   e.g., "How severe is the pain? (1-3 mild / 4-6 moderate / 7-10 severe)"
   │   e.g., "Do you have sensitivity to light?"
   │   e.g., "Is the vision loss sudden or gradual?"
   ├── Accepts free-text ("Other") answers in any language
   └── Determines recommended specialist with confidence ≥ 85%
       → Ophthalmologist / Optometrist / Optician / Ocularist
   ↓
4. APPOINTMENT BOOKING
   Patient views recommended doctors (filtered by specialty)
   ├── Views doctor profile, qualifications, fee
   ├── Selects date & time slot
   ├── Pays consultation fee via Stripe (PKR)
   └── Appointment confirmed → SignalR real-time notification to doctor
   ↓
5. APPOINTMENT DAY
   Patient attends appointment
   Doctor reviews AI-generated patient summary in BlazorUI
   ↓
6. PRESCRIPTION RECEIVED
   Doctor generates prescription →
   ├── FCM push notification to patient: "Your prescription is ready"
   ├── Email sent with prescription PDF (Cloudinary URL)
   └── Prescription visible in Flutter app (Prescriptions tab)
   ↓
7. MEDICATION TRACKING
   Patient marks daily medication doses as taken
   ├── Visual adherence tracker per medicine
   ├── Fl_chart graphs showing weekly/monthly adherence
   ├── Medication history linked to prescriptions
   └── Next appointment reminder notifications
```

### 👨‍⚕️ Doctor Journey

```
1. REGISTRATION & VERIFICATION
   Doctor registers → uploads PMDC license number + documents
   ├── PMDC API called automatically to verify license
   ├── Admin reviews documents in Admin Dashboard
   └── Admin approves/rejects → Doctor notified
   ↓
2. SUBSCRIPTION
   Verified doctor subscribes via Stripe (PKR 2,000/month)
   └── Access granted to AI Agent + Patient management
   ↓
3. RECEIVING APPOINTMENTS
   Real-time SignalR notification when patient books
   └── Appointment appears in BlazorUI dashboard
   ↓
4. APPOINTMENT DAY — AI-ASSISTED CONSULTATION
   Doctor opens patient record in BlazorUI
   ├── Sees: patient vitals, triage session, MCQ answers, voice transcript
   ├── Chats with Doctor AI Agent (port 8001)
   │   AI loads full patient history + triage summary automatically
   │   Agent: ophthalmologist | optometrist | optician | ocularist
   │   Tools: detect_red_flags(), classify_message_intent()
   │   Model: GPT-OSS-120B via Groq
   └── AI flags emergency red flags immediately
       e.g., "Sudden painless vision loss — vascular emergency (CRAO/CRVO)"
   ↓
5. PRESCRIPTION GENERATION
   Doctor fills prescription form in BlazorUI:
   ├── Diagnosis, medicines, dosage, duration, instructions
   ├── Gemini AI generates prescription summary
   ├── PDF generated → uploaded to Cloudinary
   ├── Patient notified via FCM + Email
   └── Prescription stored in MongoDB, linked to appointment
   ↓
6. REFERRAL (optional)
   Doctor creates referral to another specialist
   └── Patient receives push notification: "Referred to Retina Specialist"
```

### 🛡️ Admin Journey

```
Admin logs into Admin Dashboard (Blazor)
├── Reviews pending doctor verifications (documents, PMDC)
├── Approves or rejects with notes
├── Monitors platform finance (Stripe revenue, subscriptions)
├── Views AI agent logs and conversations
├── Manages all platform users
└── Monitors notification delivery logs
```

---

## Components

---

### 1. Backend API (.NET ASP.NET Core)

**Location:** [`first_api/`](file:///d:/Fyp%20freshhhhh/fyp1/first_api)  
**Runtime:** .NET 8 · MongoDB Atlas · SignalR · JWT Auth

#### Features & Controllers

| Controller | Features |
|---|---|
| **AuthController** | Register, Login, Refresh JWT token, Password reset via email OTP, Forgot password, Role-based auth (patient/doctor) |
| **PatientController** | Patient profile CRUD, Medical history, Initial conditions (from voice/triage), Vitals logging, Patient search |
| **DoctorController** | Doctor profile CRUD, Specialization & qualifications, Availability schedule, Fee management, Doctor search/filter |
| **DoctorVerificationController** | PMDC license verification via external API, Document upload (Cloudinary), Verification status tracking, AI agent access control gating |
| **AppointmentController** | Create/view/update appointments, Date-time slot management, Appointment confirmation workflow, Real-time SignalR notifications to doctor |
| **ChatController** | Doctor-AI conversation persistence, Multi-turn chat with doctor AI agents, Specialist agent routing (ophthalmologist/optometrist/optician/ocularist), Access control (subscription check) |
| **PrescriptionController** | Create structured prescriptions, Gemini AI summary generation, PDF upload to Cloudinary, Patient FCM + email notification on ready, Prescription history, Active/inactive status |
| **MedicationTrackingController** | Active medications list per patient, Daily dose tracking (taken/missed), Medication adherence history, Next appointment date per doctor |
| **NotificationController** | FCM device token registration, Notification history, Mark as read, Notification preferences |
| **NotificationPreferencesController** | Per-user notification preferences (medication reminders, appointment alerts) |
| **StripeController** | Doctor subscription checkout session, Payment intent creation, Stripe webhook handling, Admin finance reports |
| **ReferralController** | Create specialist referral, View active referrals per patient, Patient push notification on referral |
| **VoiceController** | Audio file transcription via Speechnotes API, Webhook receiver for async transcription results, Saves transcript as patient's InitialConditions |
| **ChatBotController** | Basic chatbot endpoint (Gemini) |
| **DoctorBasicInfoController** | Doctor basic info endpoints |
| **UserController** | Generic user profile endpoints |

#### Services

| Service | Purpose |
|---|---|
| `NotificationScheduler` | Background `IHostedService` — polls pending FCM notifications, delivers via Firebase Admin SDK |
| `AppointmentConfirmationService` | Background service — sends appointment reminder notifications |
| `DoctorAgentAssignmentService` | Evaluates doctor's AI agent access (subscription + verification status), manages MongoDB indexes |
| `StripeService` | Stripe subscription management, checkout sessions, webhook verification |
| `CloudinaryService` | Image/PDF upload to Cloudinary CDN |
| `GeminiService` | Calls Google Gemini API (multiple keys with rate-limit rotation) for prescription summaries |
| `PmdcVerificationService` | HTTP client to PMDC external API for doctor license lookup |
| `AIAgentService` | Proxies doctor-AI conversation to Python doctor agents service (port 8001) |

#### Real-time (SignalR)
- `AppointmentHub` at `/hubs/appointment` — pushes instant notification to doctor when patient books

#### Auth & Security
- JWT Bearer tokens (15-min access + 3600-min refresh)
- Cookie-based token fallback (`hv_access`)
- Role-based `[Authorize]` on all endpoints
- Request logging middleware

---

### 2. Flutter Patient App

**Location:** [`fyp/`](file:///d:/Fyp%20freshhhhh/fyp1/fyp)  
**Platforms:** Android, iOS, Web  
**State Management:** Riverpod

#### Screens & Features

| Screen | Features |
|---|---|
| **Splash** | Animated splash, auth state check |
| **Onboarding** | Liquid-swipe multi-page onboarding |
| **Registration / Login** | Email/password auth, phone number input (intl_phone_field), JWT storage (flutter_secure_storage) |
| **Reset / Recovery Password** | OTP-based email password reset flow |
| **Home Screen** | Dashboard overview, doctor listings, upcoming appointments, quick actions |
| **Appointment — Symptom Input** | Free-text symptom entry in any language (English/Urdu/Roman Urdu), Voice recording via `flutter_sound` + `speech_to_text`, Sends to backend Speechnotes API for transcription |
| **Appointment — MCQ Triage** | Displays AI-generated MCQ questions from Patient Agent, Patient selects answers or types free text ("Other"), Progress indicator (questions answered / total), Session-based with session ID |
| **Appointment — Doctor View** | Doctor profile, specialization, fee, availability |
| **Appointment — Date/Time** | Calendar date picker, time slot selection |
| **Appointment — Payment** | Stripe payment integration (`flutter_stripe`), Checkout flow in PKR |
| **Prescriptions Screen** | View all prescriptions, Active/past status, PDF viewer (WebView), Medicine list with dosage details |
| **Medication Tracking** | Daily dose checklist per medicine, Mark taken/missed, Adherence percentage |
| **Vital Signs** | Log vitals (blood pressure, temperature, etc.), Vitals history with `fl_chart` graphs |
| **Profile Screen** | Edit personal info, Medical history, Profile picture upload |
| **Notifications** | Push notifications via Firebase FCM, In-app notification history |

#### Key Packages

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management |
| `flutter_stripe` | Stripe payments |
| `speech_to_text` | Voice-to-text (on-device) |
| `flutter_sound` | Audio recording |
| `firebase_messaging` | FCM push notifications |
| `flutter_local_notifications` | Local notification display |
| `fl_chart` | Medication adherence charts |
| `webview_flutter` | Prescription PDF viewer |
| `flutter_secure_storage` | Secure JWT storage |
| `liquid_swipe` | Onboarding swipe animation |
| `dio` / `http` | API calls |
| `shared_preferences` | Local preferences |

#### Multilingual Support
- Custom **Urdu font** (NotoNastaliqUrdu) bundled in assets
- Accepts input in English, Urdu, Roman Urdu, or voice

---

### 3. BlazorUI Doctor Dashboard

**Location:** [`BlazorUI/`](file:///d:/Fyp%20freshhhhh/fyp1/BlazorUI)  
**Runtime:** Blazor Server (.NET 8)

#### Pages & Features

| Page | Features |
|---|---|
| **Auth (Login)** | Doctor login with JWT, secure cookie session |
| **Home** | Doctor's main dashboard — upcoming appointments, patient list, quick stats |
| **Dashboard** | Metrics, today's appointments |
| **Appointments** | Full appointment management — view, confirm, reschedule, filter by status/date |
| **Patient Details** | Full patient profile view including: Initial symptom description (voice transcript), Triage MCQ session & answers, Medical history & vitals, All prescriptions, Active referrals |
| **AI Agent Chat** | Real-time chat with specialist doctor AI, Automatic patient context injection (history + triage loaded at session start), Multi-turn conversation persistence, Red flag alerts prominently displayed |
| **Profile** | Doctor profile management, PMDC verification status display, Subscription management (Stripe) |

#### Services (BlazorUI)
- `AuthService` — JWT login, cookie management
- API service layer to `first_api` backend

---

### 4. Patient AI Agent (HealthVerse-agent_with_mcp)

**Location:** [`HealthVerse-agent_with_mcp/`](file:///d:/Fyp%20freshhhhh/fyp1/HealthVerse-agent_with_mcp)  
**Runtime:** Python 3.13 · FastAPI · LangGraph · Groq · Qdrant  
**Port:** 8000

#### What It Does

The patient-facing triage AI. When a patient describes their eye symptoms, this agent:

1. **Accepts** the initial symptom description (any language/format)
2. **Searches** Qdrant vector DB for clinically similar ophthalmology cases (RAG)
3. **Generates** context-aware MCQ follow-up questions using LangGraph + Groq LLM
4. **Continues** asking questions (up to 6 rounds, configurable) until confidence ≥ 85%
5. **Recommends** the appropriate eye-care specialist
6. **Returns** session history for import into the doctor's AI

#### Architecture

```
FastAPI App
  └── /health-assessment/start     POST  — start session, return Q1
  └── /health-assessment/answer    POST  — submit answer, return next Q
  └── /health-assessment/session/{id}       GET — current session state
  └── /health-assessment/session/{id}/history  GET — full Q&A history
  └── /health-assessment/history   POST  — update medical history in session

LangGraph Agent (OphthalmologyAgent)
  ├── State: OphthalmologyState (symptoms, history, Q&A, confidence, specialist)
  ├── Node: query_qdrant → find similar cases
  ├── Node: generate_followup_question → LLM generates next MCQ
  ├── Node: identify_doctor → evaluate confidence, pick specialist
  └── Node: generate_doctor_summary → structured clinical summary

MCP Tools (ophthalmology_tools.py)
  ├── generate_followup_question()  — LLM-powered question generation
  ├── identify_doctor()             — specialist determination logic
  ├── query_qdrant()                — vector similarity search
  └── generate_doctor_summary()    — clinical summary for doctor

RAG (Qdrant)
  ├── Collection: healthverse_cases
  ├── Embedding model: qwen/qwen3-embedding-8b (via OpenRouter, 4096-dim)
  └── Data: healthverse_cases.json — curated ophthalmology case library
```

#### Specialist Recommendations

| Specialist | When Recommended |
|---|---|
| **Ophthalmologist** | Eye diseases, glaucoma, retina, surgical conditions, emergencies |
| **Optometrist** | Vision problems, glasses, contact lenses, routine exams |
| **Ocular Surgeon** | Cataracts, corneal surgery, surgical need |
| **Optician** | Glasses fitting, basic vision aids |

#### Configuration
- `MAX_ITERATIONS=6` — max follow-up questions
- `CONFIDENCE_THRESHOLD=0.85` — minimum confidence to stop questioning
- `TOP_K_SEARCH=5` — Qdrant results per query
- `MCQS_PER_ITERATION=1` — questions per round

---

### 5. Doctor AI Agent (HealthVerse-doctor-agents)

**Location:** [`HealthVerse-doctor-agents/`](file:///d:/Fyp freshhhhh/fyp1/HealthVerse-doctor-agents)  
**Runtime:** Python · FastAPI · LangGraph ReAct · Groq GPT-OSS-120B  
**Port:** 8001

#### What It Does

The clinical decision-support AI for **doctors** in the BlazorUI dashboard. When the doctor opens a patient's chat:

1. **Loads** full patient history, triage MCQ answers, and initial symptom description automatically
2. **Engages** in multi-turn clinical conversation with the doctor
3. **Detects red flags** in real time and escalates immediately
4. **Classifies intent** to tailor response format (symptom report vs. treatment question vs. examination guide)
5. **Assists** with differential diagnosis, examination planning, management decisions
6. **Stays in scope** — routes non-domain questions to the appropriate specialist

#### Specialist Agents

| Specialist | Route | Clinical Domain |
|---|---|---|
| **Ophthalmologist** | `POST /chat/ophthalmologist` | Eye diseases, anterior/posterior segment, glaucoma, uveitis, neuro-ophthalmology, pediatric, oculoplastics, emergencies |
| **Optometrist** | `POST /chat/optometrist` | Refraction, visual acuity, binocular vision, contact lens assessment |
| **Optician** | `POST /chat/optician` | Spectacles dispensing, frames, lens coatings, optical troubleshooting |
| **Ocularist** | `POST /chat/ocularist` | Prosthetic eyes, socket assessment, anophthalmic socket rehabilitation |

#### Tools (LangChain)

| Tool | Purpose |
|---|---|
| `detect_red_flags(text)` | Regex-based scan for 16 ophthalmic emergencies (sudden vision loss, retinal detachment, chemical injury, acute angle closure, elevated IOP, hyphaema, etc.) |
| `classify_message_intent(text)` | Classifies message as: symptom_report / examination_question / diagnosis_question / treatment_question / follow_up / general_knowledge / out_of_domain |

#### Red Flags Detected Automatically

- Sudden painless vision loss → vascular emergency (CRAO/CRVO/AION)
- Curtain/shadow over vision → retinal detachment
- Flashes + floaters → retinal tear
- Severe eye pain + nausea → acute angle closure
- Chemical eye injury → EMERGENCY
- IOP ≥ 30 mmHg → glaucoma emergency
- Ocular trauma (penetrating)
- Post-operative complications
- Diplopia, visual field defects, acute lid changes, hyphaema

#### Request Format (from .NET AIAgentService)

```json
POST /chat/ophthalmologist
{
  "messages": [
    { "role": "user", "content": "Patient: 65M, sudden painless vision loss right eye, 2h ago" },
    { "role": "assistant", "content": "Sudden painless vision loss in a 65-year-old..." },
    { "role": "user", "content": "IOP is 14 OU, RAPD present right eye" }
  ],
  "patient_id": "patient-mongo-id",
  "conversation_id": "conv-id"
}
```

---

### 6. Admin Dashboard

**Location:** [`AdminDashboard/`](file:///d:/Fyp%20freshhhhh/fyp1/AdminDashboard)  
**Runtime:** Blazor Server (.NET 8)

#### Pages & Features

| Page | Features |
|---|---|
| **Login** | Admin authentication |
| **Home** | Platform overview statistics |
| **Users** | All patients and doctors, user management |
| **Verification** | Doctor verification queue — view uploaded documents, PMDC results, approve/reject with notes |
| **Finance** | Stripe revenue dashboard, doctor subscription status, payment history |
| **AI Agent** | Monitor AI agent conversations and logs |
| **Logs** | System-wide request and notification logs |

---

## Tech Stack

### Backend (.NET)

| Technology | Usage |
|---|---|
| ASP.NET Core 8 | REST API framework |
| MongoDB Atlas | Primary database |
| SignalR | Real-time appointment notifications |
| JWT Bearer | Authentication & authorization |
| Stripe .NET SDK | Subscription payments |
| FluentEmail + SMTP | Email delivery (Gmail) |
| Cloudinary .NET | Media & PDF storage |
| Firebase Admin SDK | FCM push notifications |
| Swagger/OpenAPI | API documentation |
| Docker | Containerized deployment |

### Patient App (Flutter)

| Technology | Usage |
|---|---|
| Flutter 3.x / Dart | Cross-platform mobile/web |
| Riverpod | State management |
| Firebase FCM | Push notifications |
| Stripe Flutter | In-app payments |
| speech_to_text | Voice input |
| flutter_sound | Audio recording |
| fl_chart | Charts & graphs |
| WebView | Prescription PDF viewer |
| NotoNastaliqUrdu font | Urdu text rendering |

### AI Agents (Python)

| Technology | Usage |
|---|---|
| FastAPI | Agent REST APIs |
| LangGraph | ReAct agent workflow orchestration |
| LangChain | Tool definitions, LLM wrappers |
| Groq API | LLM inference (Llama 4 Scout + GPT-OSS-120B) |
| OpenRouter | Embedding model (Qwen3-embedding-8b) |
| Qdrant Cloud | Vector database for RAG |
| MCP (Model Context Protocol) | Tool server architecture |

### Doctor Dashboard & Admin (Blazor)

| Technology | Usage |
|---|---|
| Blazor Server (.NET 8) | Web UI framework |
| Razor Components | UI components |
| Bootstrap/CSS | Styling |

---

## Database Schema

### MongoDB Collections

| Collection | Description |
|---|---|
| `users` | Base user records (email, password hash, role, FCM tokens) |
| `patient` | Patient profiles (personal info, medical history, initial conditions from voice/triage) |
| `doctor` | Doctor profiles (specialization, qualifications, PMDC, fee, availability, verification status, subscription) |
| `appointments` | Appointment records (patient, doctor, date/time, status, triage session ID) |
| `appointment_confirmations` | Appointment confirmation workflow state |
| `chats` | Doctor-AI conversation history (per patient, per doctor) |
| `prescriptions` | Structured prescriptions (medicines, dosage, duration, Cloudinary PDF URL, summary) |
| `medication_tracking` | Daily medication dose tracking records per patient |
| `notification_logs` | Queued & delivered FCM notifications (type, status, retry count) |
| `device_tokens` | FCM device tokens per user per platform |
| `referrals` | Doctor-to-specialist referrals (patient, referring doctor, target specialty, status) |

---

## Setup & Running

### Prerequisites

- .NET 8 SDK
- Flutter SDK 3.x
- Python 3.13+
- MongoDB Atlas account
- Qdrant Cloud account
- Groq API key
- OpenRouter API key
- Stripe account
- Firebase project (FCM)
- Cloudinary account

### 1. Backend API

```bash
cd first_api
dotnet restore
dotnet run
# Runs on https://localhost:5166 (or configured port)
# Swagger: https://localhost:5166/swagger
```

### 2. Patient AI Agent

```bash
cd HealthVerse-agent_with_mcp
pip install -r requirements.txt

# Load ophthalmology cases into Qdrant (first time only)
python load_data.py

# Run the agent API
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 3. Doctor AI Agent

```bash
cd HealthVerse-doctor-agents
pip install -r requirements.txt
python main.py
# Runs on http://localhost:8001
```

### 4. Flutter App

```bash
cd fyp
flutter pub get
flutter run
```

### 5. BlazorUI Doctor Dashboard

```bash
cd BlazorUI
dotnet restore
dotnet run
# Runs on http://localhost:5257
```

### 6. Admin Dashboard

```bash
cd AdminDashboard
dotnet restore
dotnet run
```

### 7. Run All (Windows)

```bat
run.bat
```

---

## Environment Variables

### first_api (appsettings.json)

| Key | Description |
|---|---|
| `ConnectionStrings:DbConnection` | MongoDB Atlas connection string |
| `Gemini:ApiKeys` | Google Gemini API keys (rotated on rate limit) |
| `JwtSettings:SecretKey` | JWT signing key |
| `Stripe:SecretKey` | Stripe secret key |
| `Stripe:DoctorMonthlyFee` | Monthly fee in PKR (default: 2000) |
| `Email:*` | SMTP Gmail config for email delivery |
| `CloudinarySettings:*` | Cloudinary credentials |
| `Firebase:ServiceAccountJson` | Firebase Admin SDK credentials (FCM) |
| `Speechnotes:ApiKey` | Speechnotes voice transcription API key |

### HealthVerse-agent_with_mcp (.env)

| Key | Description |
|---|---|
| `GROQ_API_KEY` | Groq API key |
| `GROQ_MODEL` | LLM model (default: `meta-llama/llama-4-scout-17b-16e-instruct`) |
| `OPENROUTER_API_KEY` | OpenRouter key for embeddings |
| `OPENROUTER_EMBEDDING_MODEL` | Embedding model (default: `qwen/qwen3-embedding-8b`) |
| `QDRANT_ENDPOINT` | Qdrant cluster URL |
| `QDRANT_CLUSTER_KEY` | Qdrant API key |
| `QDRANT_COLLECTION_NAME` | Vector collection name (default: `healthverse_cases`) |
| `CONFIDENCE_THRESHOLD` | Triage confidence threshold (default: `0.85`) |
| `MAX_ITERATIONS` | Max MCQ follow-up questions (default: `6`) |

### HealthVerse-doctor-agents (.env)

| Key | Description |
|---|---|
| `GROQ_API_KEY` | Groq API key |
| `GROQ_MODEL` | LLM model (default: `openai/gpt-oss-120b`) |
| `MAX_CONTEXT_TURNS` | Max conversation turns in context (default: `10`) |
| `ALLOWED_ORIGINS` | CORS allowed origins |

---

## Key Feature Highlights

### 🎙️ Multilingual Voice-to-Text Triage
Patient can speak in Urdu, English, or Roman Urdu. Audio is recorded in-app, uploaded, and transcribed asynchronously via Speechnotes API webhook. The transcript becomes the patient's `InitialConditions` which is visible to the doctor.

### 🤖 RAG-Powered MCQ Generation
The patient agent retrieves the top 5 similar ophthalmology cases from Qdrant, uses them as clinical context, and generates highly relevant MCQ questions tailored to the patient's specific symptoms — not generic questionnaires.

### 🚨 Real-time Red Flag Detection
The doctor AI agent automatically scans every message for 16 ophthalmic emergencies using pattern matching + LLM reasoning, flags them prominently, and suggests immediate escalation actions.

### 💊 Prescription-to-Reminder Pipeline
Prescription → Gemini summary → PDF (Cloudinary) → FCM notification → Email → Patient app view → Medication tracking → Daily reminders → Adherence charts.

### 🔐 PMDC Verification + Subscription Gate
Doctors cannot access AI features until: (1) PMDC license verified, (2) documents approved by admin, (3) monthly subscription paid. The `DoctorAgentAssignmentService` enforces this gate on every chat request.

---

## Project Structure

```
fyp1/
├── first_api/                     # .NET ASP.NET Core Backend API
│   ├── Controllers/               # 16 REST controllers
│   ├── Entities/                  # MongoDB document models
│   ├── Services/                  # Background & business services
│   ├── Hubs/                      # SignalR appointment hub
│   ├── Middleware/                # Request logging
│   └── Data/                      # MongodbService, AI agent proxy
│
├── fyp/                           # Flutter Patient App
│   └── lib/
│       ├── views/                 # UI screens (appointment, home, prescriptions, vitals, profile)
│       ├── models/                # Data models
│       ├── services/              # API service layer
│       ├── provider/              # Riverpod providers
│       └── view_models/           # ViewModel layer
│
├── BlazorUI/                      # Doctor Dashboard (Blazor Server)
│   └── Components/Pages/          # Auth, Home, Appointments, PatientDetails, Profile
│
├── AdminDashboard/                # Admin Dashboard (Blazor Server)
│   └── Components/Pages/          # Login, Users, Verification, Finance, AI Agent, Logs
│
├── HealthVerse-agent_with_mcp/   # Patient Triage AI Agent (FastAPI + LangGraph)
│   ├── agents/ophthalmology/      # LangGraph triage agent
│   ├── mcp_server/tools/          # MCP ophthalmology tools
│   ├── rag/                       # Qdrant RAG data loader
│   └── app/                       # FastAPI app + endpoints
│
└── HealthVerse-doctor-agents/    # Doctor AI Agents (FastAPI + LangGraph)
    ├── agents/specialists/        # ophthalmologist, optometrist, optician, ocularist
    ├── tools/                     # detect_red_flags, classify_message_intent
    └── api/                       # FastAPI chat routes
```

---

## Contributors

*HealthVerse — Final Year Project (FYP)*

---

## License

Private / Academic Project
