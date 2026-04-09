#!/bin/bash

# Epic Closure Analyzer
# Analyzes Jira epic completion patterns to predict team epic throughput

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  EPIC CLOSURE ANALYZER"
echo "  Analysis Date: $(date '+%Y-%m-%d')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Configuration - CUSTOMIZE THESE FOR YOUR PROJECT
PROJECT="${1:-YOUR_PROJECT}"  # Pass project key as first argument or edit default
LOOKBACK_MONTHS="${2:-12}"    # Pass lookback months as second argument or edit default
OUTPUT_FILE="${PROJECT}_epic_analysis_$(date '+%Y%m%d').json"

# Sprint configuration
SPRINT_LENGTH_WEEKS=2         # Adjust if your sprints are different length
SPRINT_VELOCITY=80            # Update with your team's average velocity

if [ "$PROJECT" = "YOUR_PROJECT" ]; then
    echo "Usage: $0 <PROJECT_KEY> [LOOKBACK_MONTHS]"
    echo ""
    echo "Example: $0 MYPROJ 6"
    echo "  Analyzes epics in MYPROJ from last 6 months"
    echo ""
    echo "Or edit the script to set your default PROJECT value"
    exit 1
fi

echo "📊 Querying Jira for epic data..."
echo "   Project: $PROJECT"
echo "   Analyzing: ALL completed epics (no date filter)"
echo ""

# Query 1: Get all closed epics (Resolution = Done, excluding duplicates/won't do)
echo "1️⃣  Fetching completed epics..."
CLOSED_EPICS_JQL="project = $PROJECT AND type = Epic AND status = Closed AND resolution = Done ORDER BY key DESC"

# Get epic list with details
EPICS_RAW=$(jira issue list --jql "$CLOSED_EPICS_JQL" --columns "key,summary,status,created,resolved" --plain 2>/dev/null || echo "")

if [ -z "$EPICS_RAW" ]; then
    echo "❌ No completed epics found"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   1. Check all epics: jira issue list --jql 'project = $PROJECT AND type = Epic' --plain"
    echo "   2. Check status values: jira issue list --jql 'project = $PROJECT AND type = Epic' --columns status,resolution --plain"
    echo "   3. Verify Jira CLI is configured: jira init"
    exit 0
fi

# Count epics
EPIC_COUNT=$(echo "$EPICS_RAW" | tail -n +2 | grep -c "^" || echo "0")
echo "   ✓ Found $EPIC_COUNT closed epics"
echo ""

# Query 2: For each epic, get child issue counts and story points
echo "2️⃣  Analyzing epic details..."
echo ""

# Create JSON output
cat > "$OUTPUT_FILE" <<EOF
{
  "analysis_date": "$(date '+%Y-%m-%d')",
  "project": "$PROJECT",
  "lookback_months": $LOOKBACK_MONTHS,
  "total_epics_closed": $EPIC_COUNT,
  "epics": [
EOF

EPIC_KEYS=$(echo "$EPICS_RAW" | tail -n +2 | awk '{print $1}')
FIRST=true
TOTAL_POINTS=0
TOTAL_STORIES=0
TOTAL_ITEMS=0

for EPIC_KEY in $EPIC_KEYS; do
    echo "   Analyzing $EPIC_KEY..."

    # Get child issues for this epic
    # Note: Adjust the field name if your Jira uses different epic link field
    CHILD_JQL="'Epic Link' = $EPIC_KEY OR parent = $EPIC_KEY"
    CHILDREN=$(jira issue list --jql "$CHILD_JQL" --plain 2>/dev/null | tail -n +2 || echo "")
    CHILD_COUNT=$(echo "$CHILDREN" | grep -c "^" || echo "0")

    # Get story point sum (if available)
    # Note: Update customfield_10016 to match your Jira's story point field
    # To find: jira issue view <KEY> --template '{{.}}' | grep -i "story\|point"
    POINTS=$(jira issue view "$EPIC_KEY" --template '{{.fields.customfield_10016}}' 2>/dev/null || echo "0")

    # If no points field, estimate based on items (optional: comment out if not needed)
    if [ "$POINTS" = "0" ] || [ -z "$POINTS" ]; then
        # Estimate: 3 points per item (adjust based on your team's average)
        POINTS=$((CHILD_COUNT * 3))
    fi

    # Count story vs task children
    STORY_COUNT=$(echo "$CHILDREN" | grep -i "story" | grep -c "^" || echo "0")

    # Add to JSON (skip comma for first item)
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    cat >> "$OUTPUT_FILE" <<EOF
    {
      "key": "$EPIC_KEY",
      "child_count": $CHILD_COUNT,
      "story_count": $STORY_COUNT,
      "points": $POINTS
    }
EOF

    # Add to totals
    TOTAL_POINTS=$((TOTAL_POINTS + POINTS))
    TOTAL_STORIES=$((TOTAL_STORIES + STORY_COUNT))
    TOTAL_ITEMS=$((TOTAL_ITEMS + CHILD_COUNT))
done

# Close JSON
cat >> "$OUTPUT_FILE" <<EOF

  ],
  "summary": {
    "total_items": $TOTAL_ITEMS,
    "total_points": $TOTAL_POINTS,
    "total_stories": $TOTAL_STORIES,
    "avg_items_per_epic": $(echo "scale=1; $TOTAL_ITEMS / $EPIC_COUNT" | bc),
    "avg_points_per_epic": $(echo "scale=1; $TOTAL_POINTS / $EPIC_COUNT" | bc),
    "avg_stories_per_epic": $(echo "scale=1; $TOTAL_STORIES / $EPIC_COUNT" | bc)
  }
}
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📈 EPIC CLOSURE ANALYSIS RESULTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Filter: Status = Closed, Resolution = Done"
echo "Total Epics Analyzed: $EPIC_COUNT"
echo "Total Items: $TOTAL_ITEMS"
echo "Total Story Points: $TOTAL_POINTS"
echo "Total Stories: $TOTAL_STORIES"
echo ""

if [ $EPIC_COUNT -gt 0 ]; then
    AVG_ITEMS=$(echo "scale=1; $TOTAL_ITEMS / $EPIC_COUNT" | bc)
    AVG_POINTS=$(echo "scale=1; $TOTAL_POINTS / $EPIC_COUNT" | bc)
    AVG_STORIES=$(echo "scale=1; $TOTAL_STORIES / $EPIC_COUNT" | bc)

    echo "Average Items per Epic: $AVG_ITEMS"
    echo "Average Points per Epic: $AVG_POINTS"
    echo "Average Stories per Epic: $AVG_STORIES"
    echo ""

    # Calculate epic closure rate
    MONTHS_IN_PERIOD=$LOOKBACK_MONTHS
    WEEKS_IN_PERIOD=$((MONTHS_IN_PERIOD * 4))
    SPRINTS_IN_PERIOD=$((WEEKS_IN_PERIOD / SPRINT_LENGTH_WEEKS))
    EPICS_PER_SPRINT=$(echo "scale=2; $EPIC_COUNT / $SPRINTS_IN_PERIOD" | bc)

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎯 EPIC CLOSURE PREDICTIONS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Historical Epic Closure Rate:"
    echo "   $EPICS_PER_SPRINT epics per sprint (based on $SPRINTS_IN_PERIOD sprints)"
    echo ""

    # Capacity-based prediction
    echo "Capacity-Based Prediction:"
    echo "   Team velocity: $SPRINT_VELOCITY points/sprint"
    echo "   Avg epic size: $AVG_POINTS points"

    if [ "$(echo "$AVG_POINTS > 0" | bc)" -eq 1 ]; then
        # Assume 85% of sprint goes to epic work (15% bugs/tech debt)
        CAPACITY_PREDICTION=$(echo "scale=1; $SPRINT_VELOCITY * 0.85 / $AVG_POINTS" | bc)
        echo "   Capacity rate: $CAPACITY_PREDICTION epics/sprint (assuming 85% epic-focused)"
    fi
    echo ""

    echo "Recommended Planning Assumptions:"
    CONSERVATIVE=$(echo "scale=1; $EPICS_PER_SPRINT * 0.9" | bc)
    OPTIMISTIC=$(echo "scale=1; $EPICS_PER_SPRINT * 1.1" | bc)
    echo "   📊 Conservative: $CONSERVATIVE epics/sprint"
    echo "   📊 Expected: $EPICS_PER_SPRINT epics/sprint"
    echo "   📊 Optimistic: $OPTIMISTIC epics/sprint"
    echo ""

    # Quarterly projection (assuming 6 sprints per quarter)
    QUARTERLY_CONSERVATIVE=$(echo "scale=0; $CONSERVATIVE * 6" | bc)
    QUARTERLY_EXPECTED=$(echo "scale=0; $EPICS_PER_SPRINT * 6" | bc)
    QUARTERLY_OPTIMISTIC=$(echo "scale=0; $OPTIMISTIC * 6" | bc)

    echo "Quarterly Projection (6 sprints):"
    echo "   📊 Conservative: $QUARTERLY_CONSERVATIVE epics/quarter"
    echo "   📊 Expected: $QUARTERLY_EXPECTED epics/quarter"
    echo "   📊 Optimistic: $QUARTERLY_OPTIMISTIC epics/quarter"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💾 Full analysis saved to: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Review epic sizes - are they well-scoped?"
echo "  2. Track epic closure for next 2-3 sprints to validate"
echo "  3. Update prediction model quarterly"
echo "  4. Adjust SPRINT_VELOCITY in script to match your team"
echo ""
