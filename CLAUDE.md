# Dinko — Pickleball Skill Tracker

## Project Overview
Dinko is a native iOS pickleball skill tracker that helps players monitor and improve their game. Users can track skills with customizable progress checkers, rate their proficiency (0-100%), view historical trends via charts, and earn achievements.

## Tech Stack
- **UI**: SwiftUI (iOS 17+)
- **Architecture**: MVVM with Repository pattern
- **Persistence**: CoreData (local-only; Supabase deferred to future phase)
- **Concurrency**: Combine + async/await
- **Charts**: Swift Charts
- **Observation**: `@Observable` macro (iOS 17+)
- **Navigation**: NavigationStack with NavigationLink(value:)

## Architecture

### MVVM + Repository Pattern
- **Views** — SwiftUI views, no business logic
- **ViewModels** — `@Observable` classes, own business logic, call repositories
- **Models** — Plain Swift structs (domain models), never `NSManagedObject` in views/VMs
- **Repositories** — Protocol-based async CRUD; CoreData implementations behind protocols

### Dependency Injection
- `DependencyContainer` holds all repository instances
- Injected via SwiftUI `.environment()` from `DinkoApp`

## Folder Structure
```
Dinko/
  DinkoApp.swift              — App entry point, DI setup
  App/
    ContentView.swift          — Root navigation
  Core/
    DesignSystem/
      Colors.swift             — Color tokens (cream, teal, coral, etc.)
      Typography.swift         — Rounded system fonts, size scale
      Spacing.swift            — 4/8/12/16/20/24/32 spacing scale
    Components/
      SkillCard.swift          — Full skill card (icon, name, trend, progress, rating, sparkline)
      ProgressBar.swift        — Teal capsule progress bar
      RatingBadge.swift        — Circular percentage badge
      SparklineChart.swift     — Mini Swift Charts line
      CheckerItem.swift        — Toggleable checklist row
      AchievementBadge.swift   — Locked/unlocked achievement
      MotivationalBanner.swift — "X skills improving!" banner
      PreviewData.swift        — Static sample data for previews
    Extensions/
      Color+Hex.swift          — Hex color initializer
    Utilities/
      Constants.swift          — App-wide constants
  Data/
    CoreData/
      Dinko.xcdatamodeld       — CoreData model
      Persistence.swift        — NSPersistentContainer setup
      SkillEntity+Ext.swift    — toDomain() / update(from:)
      ProgressCheckerEntity+Ext.swift
      SkillRatingEntity+Ext.swift
      SessionEntity+Ext.swift
    Repositories/
      SkillRepository.swift          — Protocol
      SkillRepositoryImpl.swift      — CoreData implementation
      ProgressCheckerRepository.swift
      ProgressCheckerRepositoryImpl.swift
      SkillRatingRepository.swift
      SkillRatingRepositoryImpl.swift
      SessionRepository.swift
      SessionRepositoryImpl.swift
      DependencyContainer.swift
  Models/
    Skill.swift
    ProgressChecker.swift
    SkillRating.swift
    Session.swift
    SkillCategory.swift
    SkillStatus.swift
  Features/
    SkillList/    — View + ViewModel
    SkillDetail/  — View + ViewModel
    AddEditSkill/ — View + ViewModel
DinkoTests/
DinkoUITests/
```

## Data Models

### Skill
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| name | String | Skill name |
| parentSkillId | UUID? | For sub-skill hierarchy |
| hierarchyLevel | Int | 0 = top-level |
| category | SkillCategory | Offense, Defense, Strategy, Movement, General |
| description | String | Optional description |
| createdDate | Date | |
| updatedAt | Date | |
| status | SkillStatus | .active / .archived |
| archivedDate | Date? | |
| displayOrder | Int | For manual reordering |
| autoCalculateRating | Bool | If true, rating = avg of children |
| iconName | String | SF Symbol or emoji name |

### ProgressChecker
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| skillId | UUID | Parent skill |
| name | String | Checker description |
| isCompleted | Bool | |
| completedDate | Date? | |
| displayOrder | Int | |
| updatedAt | Date | |

### SkillRating
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| skillId | UUID | Parent skill |
| rating | Int | 0-100, displayed as "75%" |
| date | Date | When rating was recorded |
| notes | String? | Optional context |
| updatedAt | Date | |

### Session
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| date | Date | |
| duration | Int | Minutes |
| notes | String? | |
| updatedAt | Date | |

### Enums
- `SkillCategory`: offense, defense, strategy, movement, general
- `SkillStatus`: active, archived

## UI Reference

### Skill List View ("My Skills")
- Cream background (#FFF8F0), white cards with rounded corners (16pt)
- Motivational banner at top: "X skills improving!" with teal background
- Each card: skill icon, name, trend arrow (+/- change), "X/Y checkers", teal progress bar, rating badge (percentage in teal circle), coral sparkline, chevron

### Skill Detail View
- Rating hero: centered icon + large rating + "out of 100%"
- Rating history: coral line chart (Swift Charts) with date x-axis
- Skill checkers: toggleable checklist (green checks, gray unchecked)
- Achievements: horizontal scroll of badges (unlocked = colored, locked = gray)
- Archive skill button at bottom

### Design Tokens
- **Background**: Cream #FFF8F0
- **Cards**: White, 16pt corner radius
- **Accent**: Teal #2AA6A0
- **Trends/Charts**: Coral #E8756A
- **Success**: Green #34C759
- **Typography**: Rounded system fonts
- **Spacing**: 4 / 8 / 12 / 16 / 20 / 24 / 32

## Coding Conventions
- **Naming**: Swift API Design Guidelines — camelCase properties, PascalCase types
- **Views**: Small, composable; extract components > 30 lines
- **ViewModels**: `@Observable` classes, suffix `ViewModel`
- **Repositories**: Protocol + `Impl` suffix for implementations
- **Domain models**: Plain structs, `Identifiable`, `Hashable`
- **CoreData**: Never expose `NSManagedObject` outside Data layer; always convert via `toDomain()`
- **Error handling**: Do/catch at repository level, surface user-friendly errors in VM
- **No force unwraps** in production code

## Build & Run
```bash
# Build
xcodebuild -project Dinko.xcodeproj -scheme Dinko -sdk iphonesimulator build

# Run tests
xcodebuild -project Dinko.xcodeproj -scheme Dinko -sdk iphonesimulator test

# Or simply open in Xcode and Cmd+R
open Dinko.xcodeproj
```

## Testing Strategy
- **Unit tests**: Repository CRUD, ViewModel logic, model transformations
- **UI tests**: App launch, basic navigation flows
- **Previews**: Every reusable component has a `#Preview` with sample data
- Use in-memory CoreData store for test isolation

## Future: Supabase Integration
Planned but deferred. When added:
- `syncStatus` field already on CoreData entities (pending/synced/conflict)
- Repository protocol stays the same; add `SupabaseRepositoryImpl` alongside CoreData
- Conflict resolution: last-write-wins with timestamp comparison
- Auth: Supabase Auth with Apple Sign-In
