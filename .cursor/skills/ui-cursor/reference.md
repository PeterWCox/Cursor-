# CursorTheme token reference

Quick lookup for **Theme/CursorTheme.swift**. Use these in views instead of hardcoded values.

## Spacing (CGFloat)

| Token | Value | Use for |
|-------|--------|--------|
| `spaceXXS` | 2 | Inline gaps, tiny padding |
| `spaceXS` | 4 | Badge padding, tight grouping |
| `spaceS` | 8 | Between related elements |
| `spaceM` | 12 | Card padding, inner spacing |
| `spaceL` | 16 | Headers, screen padding |
| `spaceXL` | 24 | Section separation, modals |
| `spaceXXL` | 32 | Major sections, empty states |
| `gapSectionTitleToContent` | 16 | Below section title (e.g. "Backlog") |
| `gapBetweenSections` | 20 | Between Todo / Backlog / Completed |
| `paddingCard` | 12 | Inside cards (task row, chip) |
| `paddingPanel` | 12 | Scroll content, panel insets |
| `paddingHeaderHorizontal` | 16 | Header horizontal |
| `paddingHeaderVertical` | 12 | Header vertical |
| `paddingBadgeHorizontal` | 5 | Badge/tag horizontal |
| `paddingBadgeVertical` | 2 | Badge/tag vertical |
| `spacingListItems` | 8 | Vertical spacing between list items |
| `radiusCard` | 12 | Corner radius for cards |

## Typography (font size CGFloat)

| Token | Value | Use for |
|-------|--------|--------|
| `fontTiny` | 9 | Badges, metadata |
| `fontCaption` | 10 | Small labels, compact UI |
| `fontSmall` | 11 | Buttons, tertiary text |
| `fontSecondary` | 12 | Labels, filters |
| `fontBodySmall` | 13 | Dense content |
| `fontBody` | 14 | Main content, task text |
| `fontBodyEmphasis` | 15 | Emphasised body |
| `fontSubtitle` | 16 | Card titles, subtitles |
| `fontTitleSmall` | 17 | Modal/settings titles |
| `fontTitle` | 18 | Panel headers, section titles |
| `fontTitleLarge` | 20 | Prominent headings |
| `fontDisplaySmall` | 22 | Splash headings |
| `fontDisplay` | 24 | Sheet/modal main title |
| `fontIconList` | 18 | List bullet/checkbox icon size |

## Colors (use with colorScheme where applicable)

- **Text:** `textPrimary(for:)`, `textSecondary(for:)`, `textTertiary(for:)`
- **Surfaces:** `chrome(for:)`, `panel(for:)`, `surface(for:)`, `surfaceRaised(for:)`, `surfaceMuted(for:)`, `editor(for:)`
- **Borders:** `border(for:)`, `borderStrong(for:)`
- **Semantic:** `brandBlue`, `semanticError`, `semanticSuccess`, `spinnerBlue`, `semanticErrorTint`
- **Brand:** `brandPurple`, `premiumGold`, `metroBlue`, `metroRed`, etc.
