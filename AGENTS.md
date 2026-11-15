# LocalioBC project rules

## Fixed visual design requirements

These requirements come from the owner's explicit instructions on 15 November 2026. Preserve them in every future change. Change the visual design only when the owner explicitly requests that design change; adding a feature or fixing a bug does not authorize a redesign.

- Keep the native editor clean and restrained. Use alignment, whitespace and typography to group controls.
- Do not add decorative separator lines, outlined section frames, nested cards, shadows, or darker/tinted section backgrounds. In particular, Export, video format, compression, estimates, progress/results and the export action must not acquire separate visual wrappers.
- Use simple logical groups on one continuous adaptive surface. The primary export action may use the existing blue accent; selected options use a checkmark and text emphasis. Keep focus, disabled and selection states accessible.
- All editing/export controls must be visible without scrolling when the application opens and at the supported minimum window size. Do not reintroduce a vertical ScrollView around the export controls. Do not hide controls, truncate validation messages, or shrink text to solve overflow.
- Preserve the supported default window size (1180 × 760) and minimum editor content size (1040 × 680) unless the owner explicitly requests a change. Account for the title bar and toolbar when checking available space.
- Before completing any layout change, build and inspect the actual native app in Czech and English, light and dark appearance, and default/minimum sizes. Check merged/separate export, quality/target-size/lossless modes, pending-crop validation, progress and completion. Controls and the full export button must stay visible; a screenshot of only the default state is insufficient.
- Keep changes local to the affected view. Do not alter shared panel/button styles across the app as a side effect of an unrelated fix.

## Release integrity

- Published release assets and builds already submitted to Apple are immutable. Local design changes require a new build before distribution; never overwrite the existing 1.2.0 (6) artifacts or claim that a local preview is the submitted app.
- Keep `AppStore/STATUS.md` and submission metadata accurate about the distinction between the submitted build and later source changes.
- Never commit private review contacts, account screenshots, signing material, local JSON files, or unrelated temporary files.

## Product website

- Offer only the current release for download on the English and Czech website. Historical release news may stay, but remove direct download links for earlier versions when publishing a new release.
- Optional support links stay below the free download, in Czech and English. Contributions do not unlock app features.
- Use owner-supplied screenshots as instructed. The screenshot supplied on 15 November 2026 already includes the macOS frame; preserve the full image without cropping, retouching or adding duplicate window chrome.
- “Videos for website headers” describes a use case for the app, especially for developers. The owner explicitly rejected adding video to the website on 15 November 2026; do not embed a video player or autoplay header video without a new explicit request.
- Keep Czech and English SEO aligned with the actual free direct edition: video crop/trim, file-size reduction, audio removal, open source and no ads. Keep metadata and sitemap current when adding public pages; never invent ratings or reviews for structured data.
- Describe editing in Czech as “v macOS” and in English as “on macOS” throughout website copy and SEO. Write the origin story in the team's first-person plural in both languages, including its teaser and metadata. Preserve the proper product name Mac App Store and accurate hardware descriptions.
