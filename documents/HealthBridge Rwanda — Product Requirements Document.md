# HealthBridge Rwanda — Product Requirements Document

Oct 6, 2026 · @GATETE Derrick

HealthBridge Rwanda lets a Community Health Worker record a visit with no data connection and get an urgent case to the health centre over 2G SMS within minutes, while routine records sync later. It complements cEMR; it does not replace it.

## 1. Problem

CEMR moves CHWs from paper to smartphones, but it needs 3G/4G to submit. In villages without data, CHWs fall back to paper, walk to find signal, or phone the supervisor. Urgent maternal and child cases wait, and supervisors receive routine data up to 30 days late.

## 2. Users

| User | Context | Primary need |
| --- | --- | --- |
| CHW (ASM or binôme member) | Rural village, Android smartphone, basic literacy, Kinyarwanda first | Record fast, never lose data, know an urgent alert got through |
| Health centre supervisor / data manager | Health centre, laptop, intermittent internet, DHIS2 user | See urgent cases now, see what each CHW reported, close the loop |
| System admin | Office | Register CHWs and devices, manage keys |

## 3. Goals and success metrics

| Goal | Metric | MVP target |
| --- | --- | --- |
| Urgent cases reach the supervisor fast | Time from CHW tapping Send to alert on dashboard, no-data condition | Under 15 min in 95% of test runs |
| Routine data stops waiting for month end | Time from visit saved to record on server | Under 48 h |
| No data loss offline | Records lost across forced kills, reboots, 7 days offline | 0 |
| Simple enough for low digital literacy | Time to record a routine visit unaided | Under 3 min |
| Supervisor closes the loop | Urgent alerts acknowledged back to the CHW | 100% of test alerts |

## 4. Scope

**In scope (MVP)**

1. CHW login (phone number + PIN), works offline after first login.
2. Register and search patients in the CHW's own catchment.
3. Record a visit: four visit types (maternal, child health, malaria, nutrition), checkbox-first forms.
4. Danger-sign checklist that flags a visit as urgent; the CHW confirms.
5. Offline storage and background sync with visible status per record.
6. SMS fallback for urgent cases when data is unavailable, with delivery acknowledgement: automatic in the managed build, one tap in the store build.
7. Supervisor web dashboard: urgent alert inbox, case detail, mark reviewed / escalate / request follow-up, CHW list with last-sync time.
8. English and Kinyarwanda.

**Out of scope (future)**

- Ambulance dispatch, pharmacy stock, disease trend analytics.
- Chronic disease (hypertension, diabetes) forms.
- Integration with cEMR or DHIS2.
- iOS app.

## 5. Functional requirements

| ID | Requirement | Priority |
| --- | --- | --- |
| FR-01 | CHW logs in with phone + PIN; session cached so the app opens offline | Must |
| FR-02 | CHW registers a patient with name, sex, date of birth or age, village, phone (optional), consent | Must |
| FR-03 | CHW searches patients by name or village offline | Must |
| FR-04 | CHW records a visit of type maternal, child, malaria or nutrition | Must |
| FR-05 | Forms validate on entry (ranges for temperature, MUAC, gestational weeks) | Must |
| FR-06 | Any ticked danger sign marks the visit urgent and opens the urgent screen | Must |
| FR-07 | Every save writes locally first, then queues for sync | Must |
| FR-08 | Sync runs automatically when data returns, with retry and back-off | Must |
| FR-09 | Urgent visit: try HTTPS first (10 s timeout); on failure, prepare the encoded SMS | Must |
| FR-10 | Server parses inbound SMS, verifies, decrypts, creates the alert | Must |
| FR-11 | Server sends an acknowledgement SMS; app shows "Received by health centre" | Should |
| FR-12 | Dashboard lists urgent alerts newest first, with channel (internet / SMS) | Must |
| FR-13 | Supervisor marks an alert reviewed, escalated, follow-up requested or resolved | Must |
| FR-14 | A full record arriving later merges into the same case (no duplicate) | Must |
| FR-15 | Dashboard shows each CHW's last sync and pending count | Should |
| FR-16 | Patient profile shows visit history and next follow-up date | Should |
| FR-17 | UI available in English and Kinyarwanda | Must |

## 6. Non-functional requirements

- Runs on Android 8+ with 2 GB RAM; APK under 30 MB.
- Cold start under 3 s; saving a visit under 1 s offline.
- Personal data encrypted on device and in transit; access by role only.
- Follows Rwanda Law No. 058/2021 on personal data protection: consent recorded at registration.
- Synthetic data only during development and demo.

## 7. Assumptions and open questions

- CHWs use Android phones, either issued by the health programme (managed build, an APK the programme installs by sideload or MDM, sends SMS automatically) or their own (store build from Google Play, one tap to send); the team has at least one real test device with a SIM.
- The danger-sign list needs review by a clinician before any field use.
- Course deadline determines how many sprints the implementation plan uses.
