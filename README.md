# 📘 Jet AI On-Device Demo Suite

### **A Complete Exploration of iOS 26 On-Device Foundation Models, Tool Calling, Generable, Transcript & Real-World Data Integration**

This repository contains a collection of **real, production-grade demo implementations** showcasing Apple’s **iOS 26 Foundation Models (on-device LLM)**.
It is designed as a comprehensive playground for experimenting with:

* On-device language models
* Generable (structured generation)
* Tool (agent-style function calling)
* Transcript (AI workflow timeline)
* HealthKit & EventKit real-world data integration
* Fax / Scan / PDF intelligent automation
* Dynamic schemas & configurable workflows

This project demonstrates **how to build real products with Apple’s on-device AI**—not just chatbots.

---

# 🌟 Features Overview

## 🧠 **1. Foundation Models (On-Device LLM)**

Demonstrates Apple's on-device LLM capabilities introduced in iOS 26:

* Low latency (<100ms local inference)
* Fully private (no data leaves the device)
* Native integration with app-level workflows
* Built-in guardrails for safety

Includes demos for:

* Prompting
* Instruction design
* Safety boundaries
* Streaming generation
* Chat session orchestration

---

## 🏗 **2. Generable – Strongly Typed Structured Output**

Generable lets developers build **strong schema-driven models**:

* Define Swift structs that the model must fill
* Replace “LLM hallucinated JSON” with **strict, type-safe** results
* Perfect for UI forms, workflows, automation logic

Included demos:

* `GenerableWorkflow Demo`
* `DynamicGenerationSchemaDemoView`
* `DynamicFaxPlanSelection Demo`
* `DynamicOCRLanguageSelection Demo`
* `DynamicPDFCompression Demo`
* `DynamicContactSelection Demo`
* `DynamicScanPreset Demo`
* `DynamicWorkflowSchema Demo`

---

## 🛠 **3. Tool Calling – Real Agents with Real Abilities**

This project demonstrates how to turn Swift services into callable LLM tools.

Examples:

### Fax Tools

* `SearchContactTool`
* `SendFaxTool`
* `AddCoverPageTool`
* `SearchFaxTool`
* `SaveFaxDraftTool`
* `CropFaxTool`

### Dream & Wellness Tools

* `CorrelateWithRealWorldDataTool` → Calls **real HealthKit + EventKit**


  * Reads sleep data
  * Reads heart rate
  * Reads calendar events
  * Correlates real-world stressors with user dream emotions

**All tool calls are automatically shown in the Transcript UI.**

---

## 📜 **4. Transcript – Visualized AI Workflow Timeline**

Transcript is one of the most important parts of iOS 26’s Foundation Models.

We provide **two production-ready implementations**:

### ✓ AIHubDemo View

ChatGPT-style UI with:

* User bubbles
* AI response bubbles
* Tool call bubbles (with tool badges)
* Tool output bubbles
* Streaming responses
* Auto-scroll
* Message grouping

### ✓ JetFaxDiagnostic View

Developer-facing console to debug:

* Tool sequence
* Argument correctness
* Output inspection
* Model decision steps

Transcript entries include:

* `.instructions`
* `.prompt`
* `.toolCalls`
* `.toolOutput`
* `.response`

---

## 🩺 **5. Real-World Data Integration (HealthKit + Calendar)**

We include a **real production-ready version** of HealthKit + EventKit integration:

### HealthKitManager (real)

* Requests authorization
* Reads sleep analysis
* Reads heart rate
* Computes pressure nights
* Fully async/await

### CalendarManager (real)

* Reads real calendar events for “last week”
* Extracts meaningful stress-related events

### RealWorldContext (Generable)



Used in the dream-context emotional analysis Demo.

---

## 😴 **6. Dream Context Analyzer**

A complete end-to-end example:

* User asks: “Why were my dreams so anxious last week?”
* AI is required (via Instructions) to call:
  `correlateWithRealWorldData`
* Tool fetches HealthKit + Calendar real data
* Returns structured `RealWorldContext`
* Model generates empathetic wellness insights based on actual user life events
* Perfect example of combining:

  * LLM reasoning
  * Real Sensor Data
  * Structured output
  * Tool chaining

UI file:


---

## 📂 **7. AIHub Engine – Centralized Model Controller**

`AIHubEngine` acts as the central orchestrator:

* Manages session lifecycle
* Registers all tools
* Handles streaming
* Publishes Transcript entries
* Exposes UI-friendly state
* Builds multi-module AI workflows (Fax, Contacts, Dream, PDF, Scan)

This is the “brain” of the entire system.

---

# 🧩 Project Structure

```
Root
 ├── AIHub/
 │    ├── AIHubEngine.swift
 │    ├── Tool/
 │    ├── Services/
 │    ├── TranscriptUI/
 │    └── ChatUI/
 │
 ├── Demos/
 │    ├── FoundationModel Demo
 │    ├── Prompt Demo
 │    ├── Safety Demo
 │    ├── ToolFaxScan Demo
 │    ├── WorkflowToolTranscript Demo
 │    ├── Dynamic Workflow Demos (Generable)
 │    └── DreamContextAnalyzerView.swift
 │
 ├── HealthKit/
 │    ├── HealthKitManager.swift
 │    ├── CalendarManager.swift
 │    ├── RealWorldContext.swift
 │
 ├── FaxServices/
 │    ├── FaxService.swift
 │    ├── ContactsService.swift
 │    ├── CoverPageService.swift
 │    └── Tools/*.swift
 │
 └── README.md  ← (this file)
```

---

# 🚀 Quick Start

### Requirements

* Xcode 16+
* iOS 26+ device (HealthKit not supported in Simulator)
* Enable in Signing & Capabilities:

  * HealthKit
  * iCloud (optional)
  * Contacts (if you plug deeper)
  * Calendars

### Permissions

Ensure the following keys exist in **Info.plist**:

```xml
<key>NSHealthShareUsageDescription</key>
<string>App uses your health data to build local AI insights.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>App uses health data to improve dream & wellness insights.</string>

<key>NSCalendarsUsageDescription</key>
<string>App reads calendar events to correlate real-world stress factors.</string>
```

### Run

1. Install to a real iPhone (Simulator won't support HealthKit)
2. Launch the app
3. Navigate through the Demos from the main menu
4. Try:

   * Generating structured output
   * Calling tools
   * Observing Transcript
   * Running Dream Context Analyzer
   * Fax AI workflow demo

---

# 🧪 Highlights for Developers

### ✔ Example of auto-toolchain:

```
User → “Help me send this fax to my accountant”
Model → Plans workflow:
         1) searchContact
         2) addCoverPage
         3) sendFax
         4) saveFaxDraft (fallback)
```

### ✔ Example of dynamic schema:

```
DynamicFaxPlanSelection
 → Changes fields based on country/user context
 → Schema passed to model
 → Model outputs strict Generable struct
```

### ✔ Example of real-world context correlation

```
Tool: correlateWithRealWorldData(period: "last_week")
 → Reads sleep analysis
 → Reads heart rate
 → Reads calendar events
 → Returns RealWorldContext summary
 → Model produces emotional explanation
```

---

# 🗺 Roadmap / Future Extensions

* PDF semantic segmentation (on-device)
* On-device OCR auto-language selection
* Tool router for multi-domain AI orchestration
* Local RAG (device-only embeddings)
* AI-powered scanning skills (cropping, enhancement)
* Fax analytics + workflow optimization
* Jet AI Hub: unified AI control center for all Jet apps

---

# 📄 License

This project is for **research, demonstration, and education**.
Commercial usage should ensure compliance with Apple policies, HIPAA/PII rules, and local regulations.