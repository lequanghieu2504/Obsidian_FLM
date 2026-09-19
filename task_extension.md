You are implementing the FLM browser-extension crawler inside an existing monorepo.

IMPORTANT:
- Inspect the repository first.
- Follow the existing architecture and naming conventions.
- Do NOT restructure the repo unless necessary.
- Work only in `apps/extension/` unless a shared schema contract genuinely needs updating.
- Keep code clean, small, explicit, testable, and maintainable.
- Do not overengineer.
- Do not implement Flutter integration yet.

==================================================
GOAL
==================================================

Build the first working FLM curriculum crawler.

The crawl must be USER-INITIATED.

Expected flow:

1. User manually logs into:
   https://flm.fpt.edu.vn

2. User manually opens a curriculum page such as:
   https://flm.fpt.edu.vn/gui/role/student/CurriculumDetails?curid=3335

3. User opens the browser extension.

4. Extension detects:
   - this is a valid CurriculumDetails page
   - current curriculum ID

5. Extension shows a "Crawl" button.

6. Only after the user clicks "Crawl" does crawling start.

Do NOT auto-crawl on:
- login
- page load
- extension startup

==================================================
AUTH / SESSION
==================================================

Reuse the user's existing authenticated FLM browser session.

Confirmed working:

fetch(url, {
  credentials: "include"
})

Do NOT:
- manually read cookies
- export cookies
- store cookies
- read access tokens
- require cookie permission unless genuinely necessary

Prefer network requests from the extension background/service worker.

Content script / popup should mainly handle:
- current-page detection
- user interaction
- messaging

Background/service worker should coordinate crawling.

Detect authentication failure structurally:
- redirected to login
- password input exists
- actual login form exists
- expected FLM structure missing

Do NOT use broad checks such as:
/login|sign in/i

FLM pages may contain login-related strings while authenticated.

==================================================
CRAWL FLOW
==================================================

CurriculumDetails
    ↓
extract curriculum
    ↓
detect normal courses
    ↓
detect SE_COM placeholders
    ↓
ViewComBo
    ↓
ONLY keep SE_COM combos
    ↓
crawl each SE_COM detail
    ↓
extract real subject codes
    ↓
merge with normal curriculum subjects
    ↓
deduplicate subject codes
    ↓
SyllabusManagement search
    ↓
find active syllabus
    ↓
SyllabusDetails
    ↓
preserve raw HTML
    +
extract structured JSON
    ↓
export one import package

==================================================
1. CURRICULUM PAGE
==================================================

URL:

/gui/role/student/CurriculumDetails?curid=<id>

Confirmed structure currently contains 3 tables.

Curriculum metadata includes:
- CurriculumCode
- Name
- English Name
- Description
- Decision
- View PO
- View Combo
- View Elective

There is also:
- PLO table
- curriculum subjects table

Example normal rows:
CEA201
CSI106
OJT202
VNR202

Example combo placeholders:

PHE_COM*1
PHE_COM*2
PHE_COM*3

SE_COM*1
SE_COM*2
SE_COM*3
SE_COM*4_ELE

For this task:

ONLY resolve/crawl the SE_COM family.

Ignore PHE_COM combo resolution.

Still preserve the curriculum row if it exists.

Extract and preserve meaningful academic content:
- curriculum metadata
- complete description
- PLOs
- subject code
- subject name
- semester
- credits
- prerequisite/note
- combo placeholders

Do not discard meaningful FLM academic text.

Avoid relying only on fixed table indexes.
Prefer header/signature-based table detection with safe fallback.

==================================================
2. SE COMBO LIST
==================================================

URL:

/Compo/ViewComBo?cur_id=<curriculumId>

The page contains:
- curriculum metadata
- combo list

Combo list includes:
- Combo ID
- Combo Name
- real detail link

Example detail URL:

/Compo/Detail/340?curriculumID=3335

ONLY crawl combos belonging to the SE_COM family.

Examples:
SE_COM5.2
SE_COM7.1
SE_COM9
...

Do NOT crawl:
PHE_COM...
or unrelated combo families.

Prefer the actual href from FLM instead of reconstructing detail URLs manually.

==================================================
3. COMBO DETAIL
==================================================

Example:

/Compo/Detail/2566?curriculumID=3335

Confirmed combo metadata:
- Combo Name
- Note

Confirmed subject table headers:

ID
Subject Code
Subject Name
Semester
Note
<action column>

Example:

6661 | PRP201c | Python Programming_Lập trình Python | 5
6662 | DPL303m | Deep Learning_Học sâu              | 8
6668 | AIL304m | Machine Learning_Học máy           | 7
6669 | DBM301  | Data mining_Khai phá dữ liệu       | 7

Another combo:

JPD133 | semester 5
JPD316 | semester 7
JPD326 | semester 8

Important:

Subject codes in combo detail are plain text.
They are NOT clickable syllabus links.

Therefore resolve syllabus later using Subject Code.

Preserve original subject-code casing.

Do NOT invent mappings such as:

SE_COM*2 -> AIL304m
SE_COM*3 -> DBM301

unless FLM explicitly provides evidence.

The combo can simply preserve its actual subjects and semesters.

==================================================
4. SUBJECT COLLECTION
==================================================

Collect real subject codes from:

A. normal curriculum courses
B. all selected SE_COM combo details

Exclude placeholders such as:

SE_COM*1
SE_COM*2
SE_COM*4_ELE
PHE_COM*1

Deduplicate subject codes before syllabus crawling.

Comparison may be case-insensitive for deduplication,
but preserve original FLM casing in stored source data.

==================================================
5. SYLLABUS RESOLUTION
==================================================

Known search URL:

/gui/role/student/SyllabusManagement?searchOn=Code&keyword=<subjectCode>

For each unique real subject:

1. fetch SyllabusManagement search result
2. locate the syllabus result table by headers
3. parse rows
4. identify ACTIVE syllabus rows
5. fetch each active SyllabusDetails page

Known detail URL:

/gui/role/student/SyllabusDetails?sylID=<id>

IMPORTANT:

IsActive and IsApproved are checkbox inputs.

Example DOM:

<input type="checkbox" checked="" disabled="disabled">

Do NOT parse IsActive or IsApproved using innerText.

Use checkbox state:

input[type="checkbox"].checked

Only ACTIVE syllabus rows should be crawled.

Do NOT require IsApproved unless future requirements say so.

If multiple active syllabus versions exist:
preserve all active versions.

==================================================
6. SYLLABUS DETAIL
==================================================

Fetch the complete syllabus detail HTML.

Preserve:
- raw HTML
- meaningful academic extracted data

Do not fabricate missing fields.

Keep FLM-specific HTML parsing isolated inside syllabus extractors.

Do NOT generate Markdown yet.

==================================================
7. RAW + EXTRACTED DATA
==================================================

Keep both:

RAW HTML
and
EXTRACTED JSON

Reason:
if parsing logic changes later, raw HTML can be re-parsed without crawling FLM again.

Conceptual package:

manifest.json

raw/
├── curriculum.html
├── combo-list.html
├── combo-details/
│   └── <comboId>.html
└── syllabi/
    └── <syllabusId>.html

extracted/
├── curriculum.json
├── combos.json
├── combo-details/
│   └── <comboId>.json
└── syllabi/
    └── <syllabusId>.json

Do not include irrelevant:
- navigation
- footer
- menu text

inside extracted academic models.

Raw HTML may preserve the full source response.

==================================================
8. EXPORT
==================================================

The user should NOT have to import hundreds of files manually.

Export ONE package file.

Prefer:

curriculum-<curriculumId>.flmpkg

or:

curriculum-<curriculumId>.zip

Internally it may be a ZIP archive.

The package must contain:
- manifest
- raw source files
- extracted JSON

Design it so the Flutter desktop app can later support:

Import FLM Package
→ select one file
→ validate
→ import

Do NOT implement Flutter import in this task.

==================================================
9. EXTENSION ARCHITECTURE
==================================================

Respect the existing repo structure.

Prefer responsibilities similar to:

apps/extension/src/

background/
  crawl-orchestrator.ts

content/
  flm-content-script.ts

extractors/
  curriculum/
  combo/
  syllabus/

transport/
  package-builder.ts
  package-exporter.ts

types/
utils/

Adapt to existing files if equivalent modules already exist.
Do NOT create duplicate abstractions.

Rules:

- popup = UI only
- content script = current-page detection / communication
- background = network crawl orchestration
- extractors = HTML → structured source data
- transport = package creation/export

Do not put HTML parsing inside the crawl orchestrator.

Do not put crawling logic inside popup UI.

==================================================
10. CRAWL SAFETY
==================================================

Avoid aggressive requests.

For syllabus/detail crawling:
- concurrency = 1
- configurable conservative delay
- bounded retry count
- deduplicate requests
- cancellation support

Stop safely on:
- 401
- 403
- 429
- authentication lost
- repeated unexpected FLM structure

Never save a login page as curriculum/combo/syllabus data.

For MVP:
- avoid duplicate requests during the current crawl session
- maintain current progress
- support retrying failed items

Do NOT build a complex persistent resume system yet.

Persistent resume after browser restart can be added later.

==================================================
11. POPUP MVP
==================================================

When opened on a valid CurriculumDetails page, show:

- curriculum detected
- curriculum ID
- curriculum name/code when available
- SE combo count
- unique subject count
- crawl progress
- current subject
- completed count
- failed count

Actions:

[Crawl]
[Cancel]
[Retry Failed]
[Export Package]

If the current tab is not a valid CurriculumDetails page:

show a clear message such as:

"Open an FLM Curriculum Details page before crawling."

Do not build polished final UI yet.

==================================================
12. TESTS
==================================================

Add focused unit tests using small HTML fixtures.

Test at least:

- curriculum metadata extraction
- PLO extraction
- curriculum subject extraction
- SE_COM placeholder detection
- ignore PHE_COM for combo crawling
- combo list extraction
- SE_COM filtering
- combo detail extraction
- mixed-case subject codes
- subject deduplication
- SyllabusManagement result parsing
- IsActive checkbox parsing
- IsApproved checkbox parsing
- active syllabus filtering
- authentication failure detection
- missing/malformed table handling

Do not create meaningless tests for coverage.

==================================================
13. OUT OF SCOPE
==================================================

Do NOT implement:

- Flutter integration
- Markdown generation
- knowledge graph
- prerequisite graph
- RAG
- embeddings
- LLM
- study recommendation
- backend
- SQLite
- full persistent resume subsystem

This task is ONLY the browser-extension FLM crawler and export package.

==================================================
14. IMPLEMENTATION APPROACH
==================================================

Before coding:

1. inspect the current repo
2. inspect the current extension architecture
3. identify reusable files/modules
4. briefly state the implementation plan

Then implement incrementally.

Do not rewrite unrelated existing code.

==================================================
15. VALIDATION
==================================================

Run all relevant existing extension checks.

At minimum, if available:

npm test
npm run lint
npm run typecheck
npm run build

Fix errors caused by your implementation.

At the end report:

1. files created/changed
2. final crawler flow
3. package format
4. tests/build results
5. remaining assumptions
6. anything that still requires validation against a real FLM page