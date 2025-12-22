#!/bin/bash

# Git Analytics Script for Ticket-Based Repositories
# Ticket format: ABC-123 (2+ capital letters, number 0-20000)

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Ticket pattern regex
TICKET_PATTERN='[A-Z]{2,}-[0-9]{1,5}'

# Global time filter variables
GLOBAL_SINCE=""
GLOBAL_UNTIL=""

# Build git log command with time filters
build_git_log_cmd() {
    local cmd="git log --no-merges"

    if [ -n "$GLOBAL_SINCE" ]; then
        cmd="$cmd --since=\"$GLOBAL_SINCE\""
    fi

    if [ -n "$GLOBAL_UNTIL" ]; then
        cmd="$cmd --until=\"$GLOBAL_UNTIL\""
    fi

    echo "$cmd"
}

print_header() {
    echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_subheader() {
    echo -e "\n${BOLD}${YELLOW}$1${NC}"
    echo -e "${YELLOW}───────────────────────────────────────────────────────────────${NC}"
}

# Function 1: Top contributors by time period
top_contributors() {
    local period=$1
    local limit=${2:-10}

    print_header "Top $limit Contributors - $period"

    local git_cmd=$(build_git_log_cmd)

    # If global flags are set, they override the period parameter
    if [ -z "$GLOBAL_SINCE" ] && [ -z "$GLOBAL_UNTIL" ]; then
        case $period in
            week)
                git_cmd="$git_cmd --since=\"1 week ago\""
                ;;
            month)
                git_cmd="$git_cmd --since=\"1 month ago\""
                ;;
            year)
                git_cmd="$git_cmd --since=\"1 year ago\""
                ;;
            all)
                # No additional time filter
                ;;
            *)
                echo "Usage: top_contributors [week|month|year|all] [limit]"
                return 1
                ;;
        esac
    fi

    eval "$git_cmd --format='%an'" | sort | uniq -c | sort -rn | head -n "$limit" | \
    awk '{printf "%s%-4d %s%-50s%s %s\n", "'"${GREEN}"'", $1, "'"${NC}"'", substr($0, index($0,$2)), "'"${NC}"'", "commits"}'
}

# Function 2: Commits per ticket
commits_per_ticket() {
    local limit=${1:-20}

    print_header "Top $limit Tickets by Commit Count"

    local git_cmd=$(build_git_log_cmd)
    eval "$git_cmd --format='%s'" | \
    grep -oE "$TICKET_PATTERN" | \
    sort | uniq -c | sort -rn | head -n "$limit" | \
    awk '{printf "%s%-4d commits%s  %s%s%s\n", "'"${GREEN}"'", $1, "'"${NC}"'", "'"${BOLD}"'", $2, "'"${NC}"'"}'
}

# Function 3: Contributors per ticket
contributors_per_ticket() {
    local ticket=$1

    if [ -z "$ticket" ]; then
        echo -e "${RED}Usage: contributors_per_ticket TICKET-NUMBER${NC}"
        return 1
    fi

    print_header "Contributors to $ticket"

    local git_cmd=$(build_git_log_cmd)

    echo -e "${BOLD}Commits by author:${NC}"
    eval "$git_cmd --format='%an' --grep=\"$ticket\"" | sort | uniq -c | sort -rn | \
    awk '{printf "  %s%-3d commits%s  %s\n", "'"${GREEN}"'", $1, "'"${NC}"'", substr($0, index($0,$2))}'

    echo -e "\n${BOLD}Timeline:${NC}"
    eval "$git_cmd --format='%ai | %an | %s' --grep=\"$ticket\"" | head -n 20 | \
    awk -F'|' '{printf "  %s%s%s | %s%s%s | %s\n", "'"${CYAN}"'", $1, "'"${NC}"'", "'"${YELLOW}"'", $2, "'"${NC}"'", $3}'
}

# Function 4: Tickets by author
tickets_by_author() {
    local author=$1
    local limit=${2:-20}

    if [ -z "$author" ]; then
        echo -e "${RED}Usage: tickets_by_author \"Author Name\" [limit]${NC}"
        return 1
    fi

    print_header "Tickets worked on by: $author"

    local git_cmd=$(build_git_log_cmd)

    eval "$git_cmd --author=\"$author\" --format='%s'" | \
    grep -oE "$TICKET_PATTERN" | \
    sort | uniq -c | sort -rn | head -n "$limit" | \
    awk '{printf "%s%-3d commits%s  %s%s%s\n", "'"${GREEN}"'", $1, "'"${NC}"'", "'"${BOLD}"'", $2, "'"${NC}"'"}'

    local total=$(eval "$git_cmd --author=\"$author\" --format='%s'" | grep -oE "$TICKET_PATTERN" | sort -u | wc -l | tr -d ' ')
    echo -e "\n${YELLOW}Total unique tickets: $total${NC}"
}

# Function 5: Activity timeline
activity_timeline() {
    local period=${1:-month}
    local limit=${2:-30}

    print_header "Activity Timeline - By $period"

    case $period in
        day)
            format="%Y-%m-%d"
            ;;
        week)
            format="%Y-W%W"
            ;;
        month)
            format="%Y-%m"
            ;;
        year)
            format="%Y"
            ;;
        *)
            echo "Usage: activity_timeline [day|week|month|year] [limit]"
            return 1
            ;;
    esac

    local term_width=$(tput cols 2>/dev/null || echo 80)
    local label_width=28  # Space for "2025-11-01  1234 commits "
    local bar_width=$((term_width - label_width))

    # Ensure minimum bar width
    if [ $bar_width -lt 20 ]; then
        bar_width=20
    fi

    local git_cmd=$(build_git_log_cmd)
    eval "$git_cmd --format=\"%ad\" --date=format:\"$format\"" | \
    sort | uniq -c | sort -rn | head -n "$limit" | \
    awk -v bar_width="$bar_width" '
    {
        count[NR]=$1;
        period[NR]=$2;
        if($1 > max) max=$1;
    }
    END {
        for(i=1; i<=NR; i++) {
            bar="";
            bar_len = int(count[i] * bar_width / max);
            if(count[i] > 0 && bar_len < 1) bar_len = 1;
            for(j=0; j<bar_len; j++) bar=bar"█";
            printf "%s%-12s%s %s%4d%s commits %s%s%s\n", "'"${CYAN}"'", period[i], "'"${NC}"'", "'"${GREEN}"'", count[i], "'"${NC}"'", "'"${BLUE}"'", bar, "'"${NC}"'"
        }
    }'
}

# Function 6: Recent ticket activity
recent_tickets() {
    local days=${1:-7}

    print_header "Tickets Active in Last $days Days"

    local git_cmd=$(build_git_log_cmd)

    # If global flags are set, they override the days parameter
    if [ -z "$GLOBAL_SINCE" ] && [ -z "$GLOBAL_UNTIL" ]; then
        git_cmd="$git_cmd --since=\"$days days ago\""
    fi

    eval "$git_cmd --format='%s'" | \
    grep -oE "$TICKET_PATTERN" | \
    sort | uniq -c | sort -rn | \
    awk '{printf "%s%-3d commits%s  %s%s%s\n", "'"${GREEN}"'", $1, "'"${NC}"'", "'"${BOLD}"'", $2, "'"${NC}"'"}'
}

# Function 7: Author activity by time period
author_timeline() {
    local author=$1
    local period=${2:-month}

    if [ -z "$author" ]; then
        echo -e "${RED}Usage: author_timeline \"Author Name\" [day|week|month|year]${NC}"
        return 1
    fi

    print_header "Activity Timeline for: $author"

    case $period in
        day)
            format="%Y-%m-%d"
            ;;
        week)
            format="%Y-W%W"
            ;;
        month)
            format="%Y-%m"
            ;;
        year)
            format="%Y"
            ;;
        *)
            echo "Usage: author_timeline \"Author Name\" [day|week|month|year]"
            return 1
            ;;
    esac

    local term_width=$(tput cols 2>/dev/null || echo 80)
    local label_width=28  # Space for "2025-11-01  1234 commits "
    local bar_width=$((term_width - label_width))

    # Ensure minimum bar width
    if [ $bar_width -lt 20 ]; then
        bar_width=20
    fi

    local git_cmd=$(build_git_log_cmd)
    eval "$git_cmd --author=\"$author\" --format=\"%ad\" --date=format:\"$format\"" | \
    sort | uniq -c | \
    awk -v bar_width="$bar_width" '
    {
        count[NR]=$1;
        period[NR]=$2;
        if($1 > max) max=$1;
    }
    END {
        for(i=1; i<=NR; i++) {
            bar="";
            bar_len = int(count[i] * bar_width / max);
            if(count[i] > 0 && bar_len < 1) bar_len = 1;
            for(j=0; j<bar_len; j++) bar=bar"█";
            printf "%s%-12s%s %s%4d%s commits %s%s%s\n", "'"${CYAN}"'", period[i], "'"${NC}"'", "'"${GREEN}"'", count[i], "'"${NC}"'", "'"${BLUE}"'", bar, "'"${NC}"'"
        }
    }'
}

# Function 8: Ticket completion rate (first commit to last commit)
ticket_duration() {
    local ticket=$1

    if [ -z "$ticket" ]; then
        echo -e "${RED}Usage: ticket_duration TICKET-NUMBER${NC}"
        return 1
    fi

    print_header "Timeline for $ticket"

    local git_cmd=$(build_git_log_cmd)
    local first_commit=$(eval "$git_cmd --format='%ai' --grep=\"$ticket\" --reverse" | head -n 1)
    local last_commit=$(eval "$git_cmd --format='%ai' --grep=\"$ticket\"" | head -n 1)
    local commit_count=$(eval "$git_cmd --format='%h' --grep=\"$ticket\"" | wc -l | tr -d ' ')
    local author_count=$(eval "$git_cmd --format='%an' --grep=\"$ticket\"" | sort -u | wc -l | tr -d ' ')

    if [ -z "$first_commit" ]; then
        echo -e "${RED}No commits found for ticket: $ticket${NC}"
        return 1
    fi

    echo -e "${BOLD}First commit:${NC}  ${CYAN}$first_commit${NC}"
    echo -e "${BOLD}Last commit:${NC}   ${CYAN}$last_commit${NC}"
    echo -e "${BOLD}Total commits:${NC} ${GREEN}$commit_count${NC}"
    echo -e "${BOLD}Contributors:${NC}  ${GREEN}$author_count${NC}"

    if [ "$first_commit" != "$last_commit" ]; then
        local first_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$first_commit" "+%s" 2>/dev/null || date -d "$first_commit" "+%s" 2>/dev/null)
        local last_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$last_commit" "+%s" 2>/dev/null || date -d "$last_commit" "+%s" 2>/dev/null)

        if [ ! -z "$first_epoch" ] && [ ! -z "$last_epoch" ]; then
            local duration=$((last_epoch - first_epoch))
            local days=$((duration / 86400))
            echo -e "${BOLD}Duration:${NC}      ${YELLOW}$days days${NC}"
        fi
    fi
}

# Function 9: All authors list
list_authors() {
    print_header "All Contributors (excluding merges)"

    local git_cmd=$(build_git_log_cmd)
    eval "$git_cmd --format='%an <%ae>'" | sort -u | \
    awk '{printf "  %s•%s %s\n", "'"${GREEN}"'", "'"${NC}"'", $0}'
}

# Function 10: Ticket prefix statistics
ticket_prefix_stats() {
    print_header "Statistics by Ticket Prefix"

    local git_cmd=$(build_git_log_cmd)
    eval "$git_cmd --format='%s'" | \
    grep -oE "$TICKET_PATTERN" | \
    sed 's/-[0-9]*//' | \
    sort | uniq -c | sort -rn | \
    awk '{printf "%s%-4d tickets%s  %s%s%s\n", "'"${GREEN}"'", $1, "'"${NC}"'", "'"${BOLD}"'", $2, "'"${NC}"'"}'
}

# Function 11: Co-authorship (who works on same tickets)
coauthorship() {
    local author=$1

    if [ -z "$author" ]; then
        echo -e "${RED}Usage: coauthorship \"Author Name\"${NC}"
        return 1
    fi

    print_header "Collaboration Analysis for: $author"

    local git_cmd=$(build_git_log_cmd)

    # Get tickets worked on by this author
    local tickets=$(eval "$git_cmd --author=\"$author\" --format='%s'" | grep -oE "$TICKET_PATTERN" | sort -u)

    # For each ticket, find other contributors
    echo -e "${BOLD}Frequent collaborators:${NC}\n"

    (
    for ticket in $tickets; do
        eval "$git_cmd --format='%an' --grep=\"$ticket\"" | grep -v "^$author$"
    done
    ) | sort | uniq -c | sort -rn | head -n 10 | \
    awk '{printf "  %s%-3d shared tickets%s  %s\n", "'"${GREEN}"'", $1, "'"${NC}"'", substr($0, index($0,$2))}'
}

# Function 12: Repository summary
repo_summary() {
    print_header "Repository Summary"

    local git_cmd=$(build_git_log_cmd)

    local total_commits=$(eval "$git_cmd --format='%h'" | wc -l | tr -d ' ')
    local total_authors=$(eval "$git_cmd --format='%an'" | sort -u | wc -l | tr -d ' ')
    local total_tickets=$(eval "$git_cmd --format='%s'" | grep -oE "$TICKET_PATTERN" | sort -u | wc -l | tr -d ' ')
    local first_commit=$(eval "$git_cmd --format='%ai' --reverse" | head -n 1 | cut -d' ' -f1)
    local last_commit=$(eval "$git_cmd --format='%ai'" | head -n 1 | cut -d' ' -f1)

    echo -e "${BOLD}Total commits:${NC}        ${GREEN}$total_commits${NC}"
    echo -e "${BOLD}Total contributors:${NC}   ${GREEN}$total_authors${NC}"
    echo -e "${BOLD}Unique tickets:${NC}       ${GREEN}$total_tickets${NC}"
    echo -e "${BOLD}First commit date:${NC}    ${CYAN}$first_commit${NC}"
    echo -e "${BOLD}Last commit date:${NC}     ${CYAN}$last_commit${NC}"

    print_subheader "Recent Activity (Last 30 days)"

    # Build separate git cmd for 30 day stats (respects global filters if set)
    local git_cmd_30d=$(build_git_log_cmd)
    if [ -z "$GLOBAL_SINCE" ] && [ -z "$GLOBAL_UNTIL" ]; then
        git_cmd_30d="$git_cmd_30d --since=\"30 days ago\""
    fi

    local commits_30d=$(eval "$git_cmd_30d --format='%h'" | wc -l | tr -d ' ')
    local authors_30d=$(eval "$git_cmd_30d --format='%an'" | sort -u | wc -l | tr -d ' ')
    local tickets_30d=$(eval "$git_cmd_30d --format='%s'" | grep -oE "$TICKET_PATTERN" | sort -u | wc -l | tr -d ' ')

    echo -e "${BOLD}Commits:${NC}       ${GREEN}$commits_30d${NC}"
    echo -e "${BOLD}Contributors:${NC}  ${GREEN}$authors_30d${NC}"
    echo -e "${BOLD}Tickets:${NC}       ${GREEN}$tickets_30d${NC}"
}

# Function 13: Commit distribution by time period
busiest_periods() {
    local period=${1:-day}
    local git_cmd=$(build_git_log_cmd)

    case $period in
        hour)
            print_header "Commits by Hour of Day"
            local term_width=$(tput cols 2>/dev/null || echo 80)
            local label_width=24
            local bar_width=$((term_width - label_width))
            if [ $bar_width -lt 20 ]; then bar_width=20; fi

            eval "$git_cmd --format='%ad' --date=format:'%H'" | \
            sort | uniq -c | sort -k2 -n | \
            awk -v bar_width="$bar_width" '
            {
                count[NR]=$1;
                hour[NR]=$2;
                if($1 > max) max=$1;
            }
            END {
                for(i=1; i<=NR; i++) {
                    bar="";
                    bar_len = int(count[i] * bar_width / max);
                    if(count[i] > 0 && bar_len < 1) bar_len = 1;
                    for(j=0; j<bar_len; j++) bar=bar"█";
                    printf "%s%02d:00%s %s%5d%s commits %s%s%s\n", "'"${CYAN}"'", hour[i], "'"${NC}"'", "'"${GREEN}"'", count[i], "'"${NC}"'", "'"${BLUE}"'", bar, "'"${NC}"'"
                }
            }'
            ;;
        day)
            print_header "Commits by Day of Week"
            local term_width=$(tput cols 2>/dev/null || echo 80)
            local label_width=30
            local bar_width=$((term_width - label_width))
            if [ $bar_width -lt 20 ]; then bar_width=20; fi

            eval "$git_cmd --format='%ad' --date=format:'%A'" | \
            sort | uniq -c | \
            awk '{
                days["Monday"]=1; days["Tuesday"]=2; days["Wednesday"]=3;
                days["Thursday"]=4; days["Friday"]=5; days["Saturday"]=6; days["Sunday"]=7;
                printf "%d\t%s\t%s\n", days[$2], $1, $2
            }' | sort -n | \
            awk -v bar_width="$bar_width" '
            {
                count[NR]=$2;
                day[NR]=$3;
                if($2 > max) max=$2;
            }
            END {
                for(i=1; i<=NR; i++) {
                    bar="";
                    bar_len = int(count[i] * bar_width / max);
                    if(count[i] > 0 && bar_len < 1) bar_len = 1;
                    for(j=0; j<bar_len; j++) bar=bar"█";
                    printf "%s%-10s%s %s%5d%s commits %s%s%s\n", "'"${CYAN}"'", day[i], "'"${NC}"'", "'"${GREEN}"'", count[i], "'"${NC}"'", "'"${BLUE}"'", bar, "'"${NC}"'"
                }
            }'
            ;;
        week)
            print_header "Commits by Week Number"
            local term_width=$(tput cols 2>/dev/null || echo 80)
            local label_width=24
            local bar_width=$((term_width - label_width))
            if [ $bar_width -lt 20 ]; then bar_width=20; fi

            eval "$git_cmd --format='%ad' --date=format:'Week %W'" | \
            sort | uniq -c | sort -k2 -n | \
            awk -v bar_width="$bar_width" '
            {
                count[NR]=$1;
                week[NR]=$2" "$3;
                if($1 > max) max=$1;
            }
            END {
                for(i=1; i<=NR; i++) {
                    bar="";
                    bar_len = int(count[i] * bar_width / max);
                    if(count[i] > 0 && bar_len < 1) bar_len = 1;
                    for(j=0; j<bar_len; j++) bar=bar"█";
                    printf "%s%-10s%s %s%5d%s commits %s%s%s\n", "'"${CYAN}"'", week[i], "'"${NC}"'", "'"${GREEN}"'", count[i], "'"${NC}"'", "'"${BLUE}"'", bar, "'"${NC}"'"
                }
            }'
            ;;
        month)
            print_header "Commits by Month"
            local term_width=$(tput cols 2>/dev/null || echo 80)
            local label_width=24
            local bar_width=$((term_width - label_width))
            if [ $bar_width -lt 20 ]; then bar_width=20; fi

            eval "$git_cmd --format='%ad' --date=format:'%B'" | \
            sort | uniq -c | \
            awk '{
                months["January"]=1; months["February"]=2; months["March"]=3;
                months["April"]=4; months["May"]=5; months["June"]=6;
                months["July"]=7; months["August"]=8; months["September"]=9;
                months["October"]=10; months["November"]=11; months["December"]=12;
                printf "%d\t%s\t%s\n", months[$2], $1, $2
            }' | sort -n | \
            awk -v bar_width="$bar_width" '
            {
                count[NR]=$2;
                month[NR]=$3;
                if($2 > max) max=$2;
            }
            END {
                for(i=1; i<=NR; i++) {
                    bar="";
                    bar_len = int(count[i] * bar_width / max);
                    if(count[i] > 0 && bar_len < 1) bar_len = 1;
                    for(j=0; j<bar_len; j++) bar=bar"█";
                    printf "%s%-10s%s %s%5d%s commits %s%s%s\n", "'"${CYAN}"'", month[i], "'"${NC}"'", "'"${GREEN}"'", count[i], "'"${NC}"'", "'"${BLUE}"'", bar, "'"${NC}"'"
                }
            }'
            ;;
        year)
            print_header "Commits by Year"
            local term_width=$(tput cols 2>/dev/null || echo 80)
            local label_width=24
            local bar_width=$((term_width - label_width))
            if [ $bar_width -lt 20 ]; then bar_width=20; fi

            eval "$git_cmd --format='%ad' --date=format:'%Y'" | \
            sort | uniq -c | \
            awk -v bar_width="$bar_width" '
            {
                count[NR]=$1;
                year[NR]=$2;
                if($1 > max) max=$1;
            }
            END {
                for(i=1; i<=NR; i++) {
                    bar="";
                    bar_len = int(count[i] * bar_width / max);
                    if(count[i] > 0 && bar_len < 1) bar_len = 1;
                    for(j=0; j<bar_len; j++) bar=bar"█";
                    printf "%s%-10s%s %s%5d%s commits %s%s%s\n", "'"${CYAN}"'", year[i], "'"${NC}"'", "'"${GREEN}"'", count[i], "'"${NC}"'", "'"${BLUE}"'", bar, "'"${NC}"'"
                }
            }'
            ;;
        *)
            echo -e "${RED}Usage: busiest_periods [hour|day|week|month|year]${NC}"
            return 1
            ;;
    esac
}

# Function 15: Find ticket by number
find_ticket() {
    local number=$1

    if [ -z "$number" ]; then
        echo -e "${RED}Usage: find_ticket <ticket_number>${NC}"
        echo -e "Example: find_ticket 13391"
        return 1
    fi

    print_header "Searching for tickets matching: $number"

    local git_cmd=$(build_git_log_cmd)
    eval "$git_cmd --format='%s'" | \
    grep -oE "$TICKET_PATTERN" | \
    grep "$number" | \
    sort -u | \
    awk '{printf "  %s•%s %s%s%s\n", "'"${GREEN}"'", "'"${NC}"'", "'"${BOLD}"'", $0, "'"${NC}"'"}'
}

# Function 16: List unique tickets by time period
unique_tickets() {
    local since=${1:-"1 year ago"}
    local until=$2

    local git_cmd=$(build_git_log_cmd)

    # Global flags override function parameters
    if [ -z "$GLOBAL_SINCE" ] && [ -z "$GLOBAL_UNTIL" ]; then
        # Use function parameters
        if [ -n "$until" ]; then
            git_cmd="$git_cmd --since=\"$since\" --until=\"$until\""
        else
            git_cmd="$git_cmd --since=\"$since\""
        fi
    fi

    eval "$git_cmd --format='%s'" | \
    grep -oE "$TICKET_PATTERN" | \
    sort -u
}

# Interactive menu
show_menu() {
    print_header "Git Analytics Menu"

    echo -e "${BOLD}Repository Analysis:${NC}"
    echo -e "  ${GREEN}1)${NC}  repo_summary               - Overall repository statistics"
    echo -e "  ${GREEN}2)${NC}  list_authors               - List all contributors"
    echo -e ""
    echo -e "${BOLD}Contributor Analysis:${NC}"
    echo -e "  ${GREEN}3)${NC}  top_contributors <period>  - Top contributors (week/month/year/all)"
    echo -e "  ${GREEN}4)${NC}  tickets_by_author <name>   - Tickets worked on by specific author"
    echo -e "  ${GREEN}5)${NC}  author_timeline <name> [period] - Activity timeline for author (day/week/month/year)"
    echo -e "  ${GREEN}6)${NC}  coauthorship <name>        - Find frequent collaborators"
    echo -e ""
    echo -e "${BOLD}Ticket Analysis:${NC}"
    echo -e "  ${GREEN}7)${NC}  commits_per_ticket         - Tickets with most commits"
    echo -e "  ${GREEN}8)${NC}  contributors_per_ticket    - Contributors to specific ticket"
    echo -e "  ${GREEN}9)${NC}  ticket_duration <ticket>   - Timeline and duration of ticket"
    echo -e "  ${GREEN}10)${NC} recent_tickets [days]      - Recently active tickets"
    echo -e "  ${GREEN}11)${NC} find_ticket <number>       - Find ticket by number"
    echo -e "  ${GREEN}12)${NC} ticket_prefix_stats        - Statistics by ticket prefix"
    echo -e "  ${GREEN}13)${NC} unique_tickets <since> [until] - List unique tickets by time period"
    echo -e "                                     (since/until: '1 year ago', '2024-01-01', etc.)"
    echo -e ""
    echo -e "${BOLD}Timeline Analysis:${NC}"
    echo -e "  ${GREEN}14)${NC} activity_timeline [period] - Overall activity over time (day/week/month/year)"
    echo -e "  ${GREEN}15)${NC} busiest_periods [period]   - Commit distribution (hour/day/week/month/year)"
    echo -e ""
    echo -e "${BOLD}Usage:${NC}"
    echo -e "  Run without arguments to see this menu"
    echo -e "  Or call functions directly: ${CYAN}./git-analytics.sh top_contributors month${NC}"
    echo -e ""
    echo -e "${BOLD}Global Time Filters:${NC}"
    echo -e "  ${CYAN}--since \"<date>\"${NC}  Filter commits since this date (e.g., '1 year ago', '2024-01-01')"
    echo -e "  ${CYAN}--until \"<date>\"${NC}  Filter commits until this date (e.g., '2024-12-31', '6 months ago')"
    echo -e ""
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  ${CYAN}./git-analytics.sh --since=\"2024-01-01\" repo_summary${NC}"
    echo -e "  ${CYAN}./git-analytics.sh --since=\"2024-01-01\" --until=\"2024-06-30\" unique_tickets${NC}"
    echo -e "  ${CYAN}./git-analytics.sh --since=\"1 year ago\" busiest_periods day${NC}"
    echo -e ""
}

# Main script logic
if [ $# -eq 0 ]; then
    show_menu
else
    # Parse global flags (sets GLOBAL_SINCE and GLOBAL_UNTIL)
    # and collect remaining args
    remaining_args=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --since=*)
                GLOBAL_SINCE="${1#*=}"
                shift
                ;;
            --since)
                GLOBAL_SINCE="$2"
                shift 2
                ;;
            --until=*)
                GLOBAL_UNTIL="${1#*=}"
                shift
                ;;
            --until)
                GLOBAL_UNTIL="$2"
                shift 2
                ;;
            *)
                remaining_args=("${remaining_args[@]}" "$1")
                shift
                ;;
        esac
    done

    # Call the function with remaining arguments
    if [ ${#remaining_args[@]} -gt 0 ]; then
        "${remaining_args[@]}"
    fi
fi
