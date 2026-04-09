# Epic Closure Analyzer

A Jira CLI tool that analyzes epic completion patterns to predict team epic throughput for quarterly planning.

## Why This Tool?

When planning quarterly releases, teams need to know: **"How many epics can we realistically deliver?"**

This tool analyzes your historical epic data to give you data-driven predictions based on:
- Average epic size (items, stories, story points)
- Historical epic closure rate
- Team velocity and capacity

## Quick Start

```bash
# 1. Make executable
chmod +x epic-analyzer.sh

# 2. Run for your project
./epic-analyzer.sh YOUR_PROJECT_KEY

# 3. Analyze last 6 months
./epic-analyzer.sh MYPROJECT 6
```

## Example Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 EPIC CLOSURE ANALYSIS RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total Epics Analyzed: 18
Average Items per Epic: 8.7
Average Points per Epic: 25.0
Average Stories per Epic: 7.4

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 EPIC CLOSURE PREDICTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Historical Epic Closure Rate:
   1.5 epics per sprint (based on 12 sprints)

Capacity-Based Prediction:
   Team velocity: 80 points/sprint
   Avg epic size: 25.0 points
   Capacity rate: 2.7 epics/sprint (85% epic-focused)

Recommended Planning Assumptions:
   📊 Conservative: 1.4 epics/sprint
   📊 Expected: 1.5 epics/sprint
   📊 Optimistic: 1.7 epics/sprint

Quarterly Projection (6 sprints):
   📊 Conservative: 8 epics/quarter
   📊 Expected: 9 epics/quarter
   📊 Optimistic: 10 epics/quarter
```

## What It Does

1. **Queries Jira** for all completed epics (Status = Closed, Resolution = Done)
2. **Analyzes each epic:**
   - Child issue count (stories, tasks, bugs)
   - Story points (if configured)
   - Story count
3. **Calculates averages** across all epics
4. **Generates predictions:**
   - Historical rate (actual epic closures / sprints)
   - Capacity-based rate (velocity / avg epic size)
   - Conservative/Expected/Optimistic scenarios
5. **Exports JSON** with detailed data for further analysis

## Prerequisites

- **[Jira CLI](https://github.com/ankitpokhrel/jira-cli)** installed and configured
- **bc** (basic calculator) - pre-installed on macOS/Linux
- Access to Jira project with Epic issue type

### Install Jira CLI

```bash
# macOS
brew install ankitpokhrel/jira-cli/jira-cli

# Linux
# See: https://github.com/ankitpokhrel/jira-cli#installation

# Configure
jira init
```

## Configuration

### Basic Settings

Edit these variables in the script (lines 15-21):

```bash
PROJECT="${1:-YOUR_PROJECT}"  # Your default project key
LOOKBACK_MONTHS="${2:-12}"    # How far back to analyze

SPRINT_LENGTH_WEEKS=2         # Your sprint length
SPRINT_VELOCITY=80            # Your team's average velocity
```

### Story Point Field

If story points show as 0, you need to configure the custom field:

```bash
# Line 92: Update to your story point field ID
POINTS=$(jira issue view "$EPIC_KEY" --template '{{.fields.customfield_XXXXX}}' ...)
```

**To find your field ID:**
```bash
jira issue view EPIC-123 --template '{{.}}' | grep -i "story\|point"
```

Common field IDs:
- `customfield_10016` - Jira Cloud default
- `customfield_10002` - Some Jira Server instances

### Epic Link Field

If your Jira uses a different epic link field name (line 85):

```bash
CHILD_JQL="'Your Epic Link Field' = $EPIC_KEY OR parent = $EPIC_KEY"
```

## Output Files

### Console Output
Human-readable summary with predictions (see example above)

### JSON Export
`{PROJECT}_epic_analysis_YYYYMMDD.json`

```json
{
  "analysis_date": "2026-04-09",
  "project": "MYPROJECT",
  "total_epics_closed": 18,
  "epics": [
    {
      "key": "PROJ-123",
      "child_count": 8,
      "story_count": 6,
      "points": 24
    }
  ],
  "summary": {
    "total_items": 156,
    "total_points": 450,
    "total_stories": 132,
    "avg_items_per_epic": 8.7,
    "avg_points_per_epic": 25.0,
    "avg_stories_per_epic": 7.3
  }
}
```

## Use Cases

### 1. Quarterly Planning
**Question:** "How many epics can we commit to in Q2?"

Run analysis before quarterly planning:
```bash
./epic-analyzer.sh MYPROJ 6
```

Use **Conservative** prediction for committed deliverables, **Expected** for roadmap planning.

### 2. Epic Scoping
**Question:** "Are our epics too large?"

**Guideline:**
- **Small epic:** 5-8 items, 15-25 points (1-2 sprints)
- **Medium epic:** 8-15 items, 25-45 points (2-4 sprints)
- **Large epic:** >15 items → Consider splitting

If your average is >10 items, your epics may be over-scoped.

### 3. Trend Analysis
**Question:** "Is our epic throughput improving?"

Run monthly and compare results:
```bash
./epic-analyzer.sh MYPROJ 3 > results_$(date +%Y%m).txt
```

### 4. Stakeholder Communication
Use data-driven delivery predictions:

> "Based on our last 6 months of data, we close an average of 2.5 epics per sprint. For Q2 (6 sprints), we can commit to **12 epics** (conservative) with a stretch goal of **15 epics** (expected)."

## Best Practices

### When to Run
- **Before quarterly planning** (6-12 month lookback)
- **Monthly** to track trends (3 month lookback)
- **After major changes** (epic scoping, team size, process changes)

### Right-Sizing Epics

**Signs your epics are over-scoped:**
- Average >10 items per epic
- Epics in progress for >4 sprints
- Historical closure rate < capacity prediction

**How to fix:**
1. Scope epics to ONLY committed work
2. Move lower-priority work to separate epics
3. Target: 5-8 items, 15-25 points per epic

### Interpreting Results

**If Historical < Capacity:**
- Epics may be over-scoped
- **Action:** Scope epics tighter, focus on completing 2-3 per sprint

**If Historical ≈ Capacity:**
- Good alignment! Use historical rate for planning

**If Historical > Capacity:**
- Epics may be under-scoped, or velocity assumption too low
- **Action:** Review velocity setting in script

## Troubleshooting

### No epics found

```bash
# Check epics exist
jira issue list --jql 'project = MYPROJ AND type = Epic' --plain

# Check status and resolution values
jira issue list --jql 'project = MYPROJ AND type = Epic' --columns status,resolution --plain
```

Update JQL on line 40 to match your workflow.

### Authentication errors

```bash
# Re-initialize Jira CLI
jira init
```

### Story points show as 0

See [Configuration](#story-point-field) section to update custom field.

## Contributing

Suggestions and improvements welcome! Open an issue or pull request.

## License

MIT License - Free to use and modify

## Related Tools

By [@dramseur](https://github.com/dramseur):
- [Sprint Health Analyzer](https://github.com/dramseur/sprint-health-analyzer) - Track sprint metrics
- [Backlog Analyzer](https://github.com/dramseur/backlog-analyzer) - Analyze backlog health

Together, these tools provide complete visibility into agile team performance.
