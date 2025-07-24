!/bin/bash

# Fixed Git History Tampering Detection Script
# Addresses the issues found in the previous analysis

OUTPUT_FILE="git_tampering_analysis_fixed.txt"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
INCIDENT_START="2024-07-13"
INCIDENT_END="2024-07-19"

echo "=== FIXED GIT HISTORY TAMPERING ANALYSIS ===" > "$OUTPUT_FILE"
echo "Repository: $(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown-repo")" >> "$OUTPUT_FILE"
echo "Analysis Date: $TIMESTAMP" >> "$OUTPUT_FILE"
echo "Incident Period: $INCIDENT_START to $INCIDENT_END" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Function to add section headers
add_section() {
    echo "" >> "$OUTPUT_FILE"
    echo "=====================================================" >> "$OUTPUT_FILE"
    echo "$1" >> "$OUTPUT_FILE"
    echo "=====================================================" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
}

# 1. CRITICAL TIMESTAMP ANALYSIS
add_section "1. CRITICAL TIMESTAMP ANALYSIS"

echo "🔍 DETAILED TIMESTAMP ANOMALY INVESTIGATION:" >> "$OUTPUT_FILE"
echo "Legend: Negative = Author time before Commit time (backdating)" >> "$OUTPUT_FILE"
echo "        Positive = Author time after Commit time (forward dating)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Get detailed timestamp analysis
git log --format='%H|%at|%ct|%an|%s' --since="$INCIDENT_START" --until="$INCIDENT_END" | \
while IFS='|' read -r hash author_time commit_time author subject; do
    diff=$((author_time - commit_time))
    
    # Convert to human readable
    if [ "$diff" -ne 0 ]; then
        hours=$((diff / 3600))
        if [ "$hours" -lt -1 ] || [ "$hours" -gt 1 ]; then
            printf "⚠️  %s: %+d hours (%s) - %s\n" "${hash:0:8}" "$hours" "$author" "${subject:0:60}" >> "$OUTPUT_FILE"
        fi
    fi
done

echo "" >> "$OUTPUT_FILE"

# 2. AUTHOR VS COMMITTER ANALYSIS
add_section "2. AUTHOR VS COMMITTER MISMATCH ANALYSIS"

echo "🔍 COMMITS WHERE AUTHOR ≠ COMMITTER:" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

mismatch_count=0
total_count=0

git log --format='%H|%an|%ae|%cn|%ce|%s' --since="$INCIDENT_START" --until="$INCIDENT_END" | \
while IFS='|' read -r hash author_name author_email committer_name committer_email subject; do
    total_count=$((total_count + 1))
    
    if [ "$author_name" != "$committer_name" ] || [ "$author_email" != "$committer_email" ]; then
        mismatch_count=$((mismatch_count + 1))
        printf "⚠️  %s: Author=%s <%s>, Committer=%s <%s>\n" \
               "${hash:0:8}" "$author_name" "$author_email" "$committer_name" "$committer_email" >> "$OUTPUT_FILE"
        printf "    Subject: %s\n\n" "${subject:0:80}" >> "$OUTPUT_FILE"
    fi
done

# 3. GPG SIGNATURE ANALYSIS (FIXED)
add_section "3. GPG SIGNATURE ANALYSIS"

if command -v gpg >/dev/null 2>&1 && git config --get user.signingkey >/dev/null 2>&1; then
    echo "🔍 GPG SIGNATURE STATUS:" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    git log --format='%H %G? %GS' --since="$INCIDENT_START" --until="$INCIDENT_END" | \
    while read hash status signer; do
        case "$status" in
            "G") echo "✅ ${hash:0:8}: Good signature from $signer" >> "$OUTPUT_FILE" ;;
            "B") echo "❌ ${hash:0:8}: Bad signature" >> "$OUTPUT_FILE" ;;
            "U") echo "⚠️  ${hash:0:8}: Unknown signature validity" >> "$OUTPUT_FILE" ;;
            "X") echo "❌ ${hash:0:8}: Expired signature" >> "$OUTPUT_FILE" ;;
            "Y") echo "❌ ${hash:0:8}: Expired key" >> "$OUTPUT_FILE" ;;
            "R") echo "❌ ${hash:0:8}: Revoked key" >> "$OUTPUT_FILE" ;;
            "E") echo "❌ ${hash:0:8}: Signature error" >> "$OUTPUT_FILE" ;;
            "N") echo "ℹ️  ${hash:0:8}: No signature" >> "$OUTPUT_FILE" ;;
            *) echo "?  ${hash:0:8}: Unknown status ($status)" >> "$OUTPUT_FILE" ;;
        esac
    done
else
    echo "ℹ️  GPG signatures not configured for this repository" >> "$OUTPUT_FILE"
    echo "   (This is normal - most repositories don't use GPG signing)" >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"

# 4. COMMIT FREQUENCY BY HOUR
add_section "4. COMMIT TIMING PATTERNS"

echo "🔍 COMMITS BY HOUR OF DAY (during incident period):" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

git log --format='%cd' --date=iso --since="$INCIDENT_START" --until="$INCIDENT_END" | \
sed 's/T/ /' | awk '{print $2}' | cut -d: -f1 | sort | uniq -c | \
while read count hour; do
	printf "%s:00 - %2d commits\n" "$hour" "$count"
done

echo "" >> "$OUTPUT_FILE"

# 5. EMERGENCY RESPONSE PATTERNS
add_section "5. EMERGENCY RESPONSE PATTERN ANALYSIS"

echo "🔍 COMMITS WITH EMERGENCY/CLEANUP KEYWORDS:" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

git log --format='%H|%cd|%s' --date=iso --since="$INCIDENT_START" --until="$INCIDENT_END" | \
grep -iE '(urgent|emergency|hotfix|revert|security|clean|remove|sanitiz|fix|patch)' | \
while IFS='|' read -r hash date subject; do
    printf "%s %s: %s\n" "${hash:0:8}" "$date" "$subject" >> "$OUTPUT_FILE"
done

# 6. FILE MODIFICATION PATTERNS
add_section "6. SUSPICIOUS FILE MODIFICATION PATTERNS"

echo "🔍 FILES MODIFIED MOST FREQUENTLY:" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

git log --name-only --format= --since="$INCIDENT_START" --until="$INCIDENT_END" | \
grep -v '^$' | sort | uniq -c | sort -nr | head -20 | \
while read count filename; do
    if [ "$count" -gt 3 ]; then
        printf "⚠️  %s: modified %d times\n" "$filename" "$count" >> "$OUTPUT_FILE"
    else
        printf "   %s: modified %d times\n" "$filename" "$count" >> "$OUTPUT_FILE"
    fi
done

echo "" >> "$OUTPUT_FILE"

# 7. STATISTICAL SUMMARY
add_section "7. STATISTICAL EVIDENCE SUMMARY"

# Calculate statistics properly
total_commits=$(git log --oneline --since="$INCIDENT_START" --until="$INCIDENT_END" | wc -l | tr -d ' ')
baseline_commits=$(git log --oneline --since="2024-06-13" --until="2024-07-12" | wc -l | tr -d ' ')

timestamp_anomalies=$(git log --format='%at %ct' --since="$INCIDENT_START" --until="$INCIDENT_END" | \
awk '$1-$2 > 3600 || $1-$2 < -3600' | wc -l | tr -d ' ')

author_mismatches=$(git log --format='%an|%cn' --since="$INCIDENT_START" --until="$INCIDENT_END" | \
awk -F'|' '$1!=$2' | wc -l | tr -d ' ')

emergency_commits=$(git log --format='%s' --since="$INCIDENT_START" --until="$INCIDENT_END" | \
grep -icE '(urgent|emergency|hotfix|revert|security|clean|remove|sanitiz)' | tr -d ' ')

echo "📊 KEY STATISTICS:" >> "$OUTPUT_FILE"
echo "==================" >> "$OUTPUT_FILE"
echo "Total commits in incident period: $total_commits" >> "$OUTPUT_FILE"
echo "Baseline commits (30 days prior): $baseline_commits" >> "$OUTPUT_FILE"
echo "Timestamp anomalies (>1hr diff): $timestamp_anomalies" >> "$OUTPUT_FILE"
echo "Author≠Committer mismatches: $author_mismatches" >> "$OUTPUT_FILE"
echo "Emergency-style commits: $emergency_commits" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Calculate suspicion score
suspicious_score=0
max_score=4

if [ "$timestamp_anomalies" -gt 5 ]; then
    suspicious_score=$((suspicious_score + 1))
    echo "❌ SUSPICIOUS: $timestamp_anomalies timestamp anomalies (>5)" >> "$OUTPUT_FILE"
else
    echo "✅ NORMAL: $timestamp_anomalies timestamp anomalies" >> "$OUTPUT_FILE"
fi

if [ "$author_mismatches" -gt $((total_commits / 2)) ]; then
    suspicious_score=$((suspicious_score + 1))
    echo "❌ SUSPICIOUS: $author_mismatches author/committer mismatches (>50%)" >> "$OUTPUT_FILE"
else
    echo "✅ NORMAL: $author_mismatches author/committer mismatches" >> "$OUTPUT_FILE"
fi

if [ "$emergency_commits" -gt 5 ]; then
    suspicious_score=$((suspicious_score + 1))
    echo "❌ SUSPICIOUS: $emergency_commits emergency commits (>5)" >> "$OUTPUT_FILE"
else
    echo "✅ NORMAL: $emergency_commits emergency commits" >> "$OUTPUT_FILE"
fi

# Repository integrity check
integrity_issues=$(git fsck 2>&1 | grep -v '^Checking' | wc -l | tr -d ' ')
if [ "$integrity_issues" -gt 0 ]; then
    suspicious_score=$((suspicious_score + 1))
    echo "❌ SUSPICIOUS: $integrity_issues repository integrity issues" >> "$OUTPUT_FILE"
else
    echo "✅ NORMAL: Repository integrity clean" >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "🎯 FINAL ASSESSMENT:" >> "$OUTPUT_FILE"
echo "===================" >> "$OUTPUT_FILE"
echo "SUSPICION SCORE: $suspicious_score/$max_score" >> "$OUTPUT_FILE"

if [ "$suspicious_score" -ge 3 ]; then
    echo "🚨 HIGH LIKELIHOOD OF TAMPERING" >> "$OUTPUT_FILE"
    echo "   Multiple indicators suggest Git history has been manipulated" >> "$OUTPUT_FILE"
elif [ "$suspicious_score" -ge 2 ]; then
    echo "⚠️  MODERATE SUSPICION OF TAMPERING" >> "$OUTPUT_FILE"
    echo "   Some indicators warrant further investigation" >> "$OUTPUT_FILE"
elif [ "$suspicious_score" -ge 1 ]; then
    echo "❓ LOW-MODERATE SUSPICION" >> "$OUTPUT_FILE"
    echo "   Minor indicators present, likely normal but worth noting" >> "$OUTPUT_FILE"
else
    echo "✅ LOW LIKELIHOOD OF TAMPERING" >> "$OUTPUT_FILE"
    echo "   Repository appears to have intact, unmanipulated history" >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "=== END OF FIXED ANALYSIS ===" >> "$OUTPUT_FILE"

echo "✅ Fixed analysis complete!" >&2
echo "📄 Results: $OUTPUT_FILE" >&2
echo "🎯 Suspicion score: $suspicious_score/$max_score" >&2
