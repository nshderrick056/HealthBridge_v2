# HealthBridge Rwanda — Design Brief

Oct 6, 2026 · @GATETE Derrick

Design for a tired CHW, outdoors, at night, with a worried family watching: every screen answers "what do I do next" and "did my data get through" without reading a paragraph. The base is the team's Mobile UI foundation (v1): a calm green system of eight components that every CHW screen is built from (Section 4).

## 1. Audience

- **Primary**: CHW, 25 to 55, Kinyarwanda first, basic smartphone use, often one-handed, in bright sun or by torchlight, on a low-end Android screen.
- **Secondary**: supervisor at a desk on a laptop, comfortable with DHIS2, scanning many cases at once.

## 2. Principles

1. **Tick, don't type.** Checkboxes, chips and steppers; free text is always optional.
2. **Status is never hidden.** Every record shows its sync state; the connection banner is always on Home.
3. **Urgent is calm.** Red only for the danger banner; one primary action; plain words, no error codes.
4. **Nothing is lost.** Autosave on every field; no destructive action without confirmation.
5. **Same word, same thing.** One term per concept across app, dashboard and documentation.

## 3. Status vocabulary (use exactly these)

| State | Label (EN) | Colour | Icon |
| --- | --- | --- | --- |
| Online | Online | Green | Wi-Fi |
| No internet | Offline, saving on phone | Grey | Wi-Fi off |
| Local only | Saved on phone | Grey | Phone |
| Queued | Waiting to sync | Amber | Clock |
| Done | Synced | Green | Check |
| Failed | Sync failed, tap to retry | Red outline | Retry |
| SMS sent | Sent by SMS | Blue | Message |
| Confirmed | Received by health centre | Green | Double check |
| Not confirmed | Not confirmed yet | Amber | Alert |
| Patient due | Follow-up due | Amber | Dot |
| Patient urgent | Urgent | Red | Dot |
| Patient stable | Stable | Green | Dot |

Kinyarwanda labels are written by a native speaker on the team and checked by a CHW; clinical terms are never machine-translated.

## 4. Component library (UI foundation v1)

These eight components come from the Mobile UI foundation in Figma. Every CHW screen is assembled from them; a new component is added only after a design review (Section 7 lists the ones still to design).

| Component | As designed in the foundation | Usage rules |
| --- | --- | --- |
| Header | Small green caps label above a large bold title and a grey subtitle, for example "Patients" and "26 people in your care" | One per screen; the subtitle always carries a live count or state; one line only |
| Primary button | Full-width, filled deep green, bold white label, leading plus icon | One per screen, directly under the content it acts on or at the bottom (Record new visit, Save, Send urgent alert); on the urgent screen it is the only filled button |
| Secondary button | Full-width, white with green outline and bold green label | The alternative action (Review details, Back to home); never two equal-weight secondaries side by side |
| Input field | Bold label above; rounded field with a leading icon and grey placeholder | The label is always visible, never placeholder-only; errors appear under the field in plain words; numeric fields open the numeric keypad |
| Status chip | Pill with a dot or icon plus a word: Online (green, Wi-Fi), Offline (grey, crossed circle), Follow-up due (amber), Urgent (red) | The word is mandatory, colour is never the only signal; chip labels and colours come only from the status vocabulary in Section 3; one chip per object |
| Summary card | Three equal tiles, each with a tinted icon square, a large number and a label: Visited, Due, Urgent | Tapping a tile opens the matching filtered list; the Urgent tile takes its red tint only when the count is above zero |
| Patient card | Bold name, age and sex, village with a person icon, last-visit day on the right, status chip at top right | The whole card is tappable; shows only what the CHW needs to pick the right person, no phone number or other details |
| Bottom navigation | Five items: Home, Patients, Record Visit (raised filled circle with a plus), Alerts, Profile; active item in green | On every CHW screen except login and while a visit form is open; Record is always one tap away |

## 5. Screen assembly

| Screen | Built from |
| --- | --- |
| Login | Header, two input fields, primary button |
| Home | Header, connection chip, three summary cards, sync card, recent patient cards, bottom navigation |
| Patients | Header with count, search input field, filter chips, patient cards, primary button (Register patient) |
| Patient profile | Header, patient card, status chip, visit history list, primary button (Record new visit), secondary button (View history) |
| Record visit | Header with step progress, input fields and checklist rows, primary button (Continue) |
| Urgent case | Urgent banner, ticked-sign list, one primary button, then status chips for each sending state |
| Alerts | Header, patient cards with Urgent or Follow-up due chips, delivery-state chips |

## 6. Changes to the foundation

The foundation covers the visual base. These points differ from the project requirements or are missing, and need a decision before the screens are built.

1. **Login field.** The foundation shows a Password field; the requirements specify a PIN. Keep the component, relabel it PIN, open the numeric keypad, and add a show/hide toggle.
2. **Chips for sync and SMS.** The foundation has Online, Offline, Follow-up due, Urgent and Stable only. Add Waiting to sync (amber, clock), Synced (green, check), Sync failed (red outline, retry), Sent by SMS (blue, message), Received by health centre (green, double check) and Not confirmed yet (amber, alert). The blue is a new colour token.
3. **Two meanings of green.** Stable (patient) and Synced (record) are both green. Patient chips appear only at the top right of a patient card; sync chips appear only under a record and always carry an icon. Give Stable a dot and Synced a check so they stay distinct.
4. **Bottom navigation label.** "Record Visit" is too long for five items on a 360 dp screen in Kinyarwanda at 14 sp. Shorten the label to "Record" and give Alerts a count badge for unread urgent updates.
5. **Contrast.** The pale chip fills, the grey Offline chip and the grey placeholder text look under 4.5:1 in the foundation image. Measure them against the AA target in Section 8 and darken the text, not the fills, where they fail, then re-check in sunlight on a real phone.
6. **Mobile only.** The foundation has no desktop components. The supervisor dashboard reuses chips and summary cards, and needs a sidebar in place of bottom navigation, an alert table row and a case detail panel.

## 7. Components still to design

| Component | Needed for |
| --- | --- |
| Connection banner | Strip under the header showing Online or Offline; tap opens the pending list |
| Sync card | Home: counts of waiting, synced and failed records |
| Checklist row | Danger signs and form checkboxes; full-width row, 48 dp high, large check box |
| Number stepper | Temperature, MUAC, gestational weeks, with the allowed range shown |
| Step progress bar | Record visit steps: type, form, danger signs, review |
| Urgent banner | Red-tinted strip on the urgent screen only |
| Confirmation dialog | Discard draft, resend alert; two buttons, the safe one first |
| Empty state | Empty patient list, no alerts, nothing waiting to sync |

## 8. Visual language

- **Colour**: keep the Figma deep green as primary; red only for danger signs and the urgent banner; amber for pending. All text meets WCAG AA contrast (4.5:1).
- **Type**: one sans family that covers Kinyarwanda (Noto Sans or Inter); body 16 sp minimum, labels 14 sp, headings 20 to 24 sp.
- **Touch targets**: 48 dp minimum; primary buttons full width at the bottom, in the thumb zone.
- **Icons**: always paired with a text label.
- **Spacing**: 8 dp grid; cards with 16 dp padding.

## 9. Screen design direction

| Screen | Design direction |
| --- | --- |
| Login | Foundation header, input fields (CHW ID or phone number; PIN with numeric keypad) and primary button; language switch at the bottom |
| Home | Connection chip, three summary cards (Visited, Due, Urgent), sync card, recent patient cards; Record is the raised centre button of the bottom navigation |
| Record visit | Steps with a progress bar: type, form, danger signs, review |
| Danger signs | Large checkbox list grouped by visit type, red only when ticked |
| Urgent case | Banner, ticked signs, one button; then the states Sending, Sent by SMS, Received, Not confirmed. Store build: after "No internet", the SMS app opens and a short hint says "Tap Send"; managed build: no hint, it just sends |
| Patient profile | Status chip, last visit, next follow-up, visit history |
| Supervisor inbox | Alert list first, channel badge, "Full record pending" tag |
| Case detail | Signs and vitals at the top, actions fixed at the bottom |
| Profile | Language, catchment area, a plain "Build: store" or "Build: managed" line, and Logout (blocked while records are unsynced) |

## 10. Accessibility

- Android font scaling to 130% without clipping.
- Colour is never the only signal: every state has an icon and a word.
- Layouts tested on a 5-inch, 720p, 2 GB Android phone.
- Dashboard fully usable by keyboard.
