# Risks

- Cleanup remains explicit/user-triggered and age-gated; this proposal does not delete an export immediately after sharing.
- Matching uses exact app-generated prefixes plus expected suffixes; picker imports additionally require a UUID-shaped name. Broad `VeilLink-*` deletion is prohibited.
- Only direct children of the app temporary directory pass the existing root boundary check.
- Symlinks remain excluded and their targets are never traversed or deleted.
- Player learning databases, chat attachments, SQLite data, identity material and backup exports are outside this category.
