#!/bin/bash

# git-init-repo.sh
# A script to initialize a git repository with proper .gitignore and GitHub setup

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

mode="init"
is_modify=false

if [[ "$1" == "-m" || "$1" == "--modify" ]]; then
    mode="modify"
    is_modify=true
    shift
fi

handle_github_pages() {
    local repo_name="$1"
    local repo_owner="$2"
    local repo_url="$3"

    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}GitHub CLI (gh) is not installed. Skipping GitHub Pages setup.${NC}"
        return
    fi

    if ! gh auth status &> /dev/null; then
        echo -e "${YELLOW}GitHub CLI not authenticated. Run 'gh auth login' to enable GitHub Pages automation.${NC}"
        return
    fi

    echo -e "${BLUE}=== GitHub Pages & Hosting Guidance ===${NC}\n"
    echo -e "${BLUE}Detecting project type...${NC}\n"

    local has_backend=false
    local backend_type=""
    local hosting_suggestions=""

    # Check for Python backends
    if [ -f "requirements.txt" ]; then
        if grep -qiE "(flask|django|fastapi|gradio|streamlit|uvicorn)" requirements.txt; then
            has_backend=true
            backend_type="Python backend app"
            hosting_suggestions="Render.com (free), Railway.app, or Hugging Face Spaces (for Gradio/ML apps)"
        fi
    fi

    # Check for Python server files
    if ls *.py >/dev/null 2>&1; then
        if grep -qiE "(flask|Flask|fastapi|FastAPI|gradio|Gradio|streamlit|Streamlit)" *.py 2>/dev/null; then
            has_backend=true
            backend_type="Python backend app"
            hosting_suggestions="Render.com (free), Railway.app, or Hugging Face Spaces (for Gradio/ML apps)"
        fi
    fi

    # Check for Node.js backends
    if [ -f "package.json" ]; then
        if grep -qiE "(express|koa|fastify|nest|\"start\".*node|server\.js)" package.json; then
            has_backend=true
            backend_type="Node.js backend app"
            hosting_suggestions="Render.com (free), Railway.app, Heroku, or Vercel (for Next.js)"
        fi
    fi

    local is_static=false
    if [ -f "index.html" ] || [ -f "index.htm" ]; then
        is_static=true
    fi

    local enable_pages="n"

    if [ "$has_backend" = true ]; then
        echo -e "${YELLOW}⚠️  Detected: ${backend_type}${NC}"
        echo -e "${YELLOW}GitHub Pages only works for static HTML/CSS/JS sites.${NC}"
        echo -e "${YELLOW}This project requires a server to run.${NC}\n"

        if grep -qiE "(local|Local|localhost)" README.md 2>/dev/null || grep -qiE "(local|Local)" *.py 2>/dev/null; then
            echo -e "${BLUE}Note: This appears to be designed for LOCAL use only.${NC}"
            echo -e "${BLUE}Consider if hosting it publicly is necessary/desired.${NC}\n"
        fi

        echo -e "${GREEN}If you want to host this online, consider:${NC}"
        echo -e "  • ${hosting_suggestions}\n"
        read -p "Do you still want to try enabling GitHub Pages? (not recommended) (y/n): " enable_pages
    elif [ "$is_static" = true ]; then
        echo -e "${GREEN}✓ Detected: Static website (HTML/CSS/JS)${NC}"
        echo -e "${GREEN}This project is perfect for GitHub Pages!${NC}\n"
        read -p "Do you want to enable GitHub Pages? (y/n): " enable_pages
    else
        echo -e "${YELLOW}Could not detect clear project type.${NC}"
        read -p "Do you want to enable GitHub Pages? (y/n): " enable_pages
    fi

    if [[ $enable_pages =~ ^[Yy]$ ]]; then
        echo -e "\n${BLUE}Setting up GitHub Pages...${NC}"

        if [ -f "index.html" ] || [ -f "index.htm" ]; then
            echo -e "${GREEN}Found index.html - setting up GitHub Pages...${NC}"
        else
            echo -e "${YELLOW}No index.html found. GitHub Pages may not work properly.${NC}"
        fi

        local default_branch
        default_branch=$(git branch --show-current)

        if gh api -X POST "repos/${repo_owner}/${repo_name}/pages" \
            -f source[branch]="${default_branch}" \
            -f source[path]="/" &>/dev/null; then

            local pages_url="https://${repo_owner}.github.io/${repo_name}"
            echo -e "${GREEN}GitHub Pages enabled!${NC}"
            echo -e "${BLUE}Your site will be available at: ${pages_url}${NC}"
            echo -e "${YELLOW}Note: It may take a few minutes for the site to be published.${NC}\n"

            if [ -f "README.md" ]; then
                if ! grep -q "Live Demo" README.md && ! grep -q "$pages_url" README.md; then
                    local temp_readme
                    temp_readme=$(mktemp)
                    awk -v url="$pages_url" '
                        NR==1 {print; next}
                        NR==2 && /^$/ {
                            print ""
                            print "🚀 **[Live Demo](" url ")** 🚀"
                            print ""
                            next
                        }
                        NR==2 && !/^$/ {
                            print ""
                            print "🚀 **[Live Demo](" url ")** 🚀"
                            print ""
                            print
                            next
                        }
                        {print}
                    ' README.md > "$temp_readme"
                    mv "$temp_readme" README.md

                    git add README.md
                    git commit -m "Add GitHub Pages link to README"
                    git push

                    echo -e "${GREEN}Updated README.md with GitHub Pages link${NC}\n"
                fi
            fi
        else
            echo -e "${YELLOW}Could not enable GitHub Pages automatically.${NC}"
            echo "You can enable it manually in your repo settings:"
            echo "  ${repo_url}/settings/pages"
            echo ""
        fi
    fi
}

escape_json_string() {
    local input="$1"
    input=${input//\\/\\\\}
    input=${input//\"/\\\"}
    input=${input//$'\n'/\\n}
    input=${input//$'\t'/\\t}
    echo "$input"
}

list_to_json_array() {
    local input="$1"
    local result="["
    local first=true
    IFS=',' read -ra items <<< "$input"
    for item in "${items[@]}"; do
        local trimmed
        trimmed=$(echo "$item" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [ -z "$trimmed" ]; then
            continue
        fi
        trimmed=$(escape_json_string "$trimmed")
        if [ "$first" = true ]; then
            result+="\"${trimmed}\""
            first=false
        else
            result+=", \"${trimmed}\""
        fi
    done
    result+="]"
    echo "$result"
}

title_case() {
    echo "$1" | sed -E 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) } print}'
}

derive_default_demo_url() {
    local repo_name_local="$1"
    local origin_url
    origin_url=$(git config --get remote.origin.url 2>/dev/null || printf "")
    local default_url=""

    if [[ "$origin_url" == git@github.com:* ]]; then
        local path="${origin_url#git@github.com:}"
        path=${path%.git}
        default_url="https://github.com/${path}"
    elif [[ "$origin_url" == https://github.com/* ]]; then
        default_url=${origin_url%.git}
    fi

    if [ -z "$default_url" ]; then
        local gh_user=""
        if command -v gh &> /dev/null; then
            gh_user=$(gh api user -q .login 2>/dev/null || printf "")
        fi
        if [ -n "$gh_user" ]; then
            default_url="https://github.com/${gh_user}/${repo_name_local}"
        else
            default_url="https://github.com/${repo_name_local}"
        fi
    fi

    echo "$default_url"
}

derive_repo_slug() {
    local repo_name_local="$1"
    local origin_url
    origin_url=$(git config --get remote.origin.url 2>/dev/null || printf "")
    local slug=""

    if [ -n "$origin_url" ]; then
        local path=""
        if [[ "$origin_url" =~ github\.com[:/](.+)$ ]]; then
            path="${BASH_REMATCH[1]}"
        fi
        path=${path%.git}
        path=${path#/}
        if [[ "$path" == */* ]]; then
            slug="$path"
        fi
    fi

    if [ -z "$slug" ] && command -v gh &> /dev/null; then
        local gh_user
        gh_user=$(gh api user -q .login 2>/dev/null || printf "")
        if [ -n "$gh_user" ] && [ -n "$repo_name_local" ]; then
            slug="${gh_user}/${repo_name_local}"
        fi
    fi

    echo "$slug"
}

derive_default_branch_name() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || printf "")
    if [ -z "$branch" ]; then
        branch="main"
    fi
    echo "$branch"
}

derive_raw_file_url() {
    local repo_name_local="$1"
    local file_path="$2"
    local slug
    slug=$(derive_repo_slug "$repo_name_local")
    if [ -z "$slug" ]; then
        echo ""
        return
    fi

    local branch
    branch=$(derive_default_branch_name)
    local sanitized="${file_path#./}"
    sanitized=${sanitized#/}
    if [ -z "$sanitized" ]; then
        sanitized="screenshot.png"
    fi

    echo "https://raw.githubusercontent.com/${slug}/${branch}/${sanitized}"
}

generate_catalogue_ai_defaults() {
    if [ -z "$OPENAI_API_KEY" ]; then
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${YELLOW}python3 is required for AI-assisted catalogue defaults.${NC}" >&2
        return 1
    fi

    local repo_name_local="$1"
    local screenshot_hint="$2"
    local model="${OPENAI_MODEL:-gpt-4o-mini}"
    local guide_file="$HOME/gitBash/catalogue_metadata.md"
    local guide_content=""
    if [ -f "$guide_file" ]; then
        guide_content=$(cat "$guide_file")
    fi

    local log_dir="$HOME/gitBash/logs"
    mkdir -p "$log_dir"
    local ai_log_file="${log_dir}/catalogue_ai_response.log"

    local ai_output=""
    if ! ai_output=$(CATALOGUE_GUIDE_CONTENT="$guide_content" REPO_NAME_INPUT="$repo_name_local" SCREENSHOT_HINT_INPUT="$screenshot_hint" OPENAI_MODEL_CHOICE="$model" AI_RESPONSE_LOG="$ai_log_file" python3 - <<'PY'
import os, sys, json, pathlib, textwrap, urllib.request, urllib.error, re

api_key = os.environ.get("OPENAI_API_KEY")
if not api_key:
    sys.exit(1)

repo_name = os.environ.get("REPO_NAME_INPUT", "")
screenshot_hint = os.environ.get("SCREENSHOT_HINT_INPUT", "")
model = os.environ.get("OPENAI_MODEL_CHOICE", "gpt-4o-mini")
guide = os.environ.get("CATALOGUE_GUIDE_CONTENT", "")
log_path = os.environ.get("AI_RESPONSE_LOG", "")

def write_log(text):
    if not log_path:
        return
    try:
        with open(log_path, "w", encoding="utf-8") as logf:
            logf.write(text)
    except Exception:
        pass

root = pathlib.Path(".")

def read_text(path: pathlib.Path, limit: int) -> str:
    try:
        data = path.read_text(encoding="utf-8")
    except Exception:
        return ""
    if len(data) > limit:
        data = data[:limit]
    return data.strip()

context_sections = []

readme_text = read_text(root / "README.md", 6000)
if readme_text:
    context_sections.append(f"# README.md\n{readme_text}")

index_text = read_text(root / "index.html", 4000)
if index_text:
    context_sections.append(f"# index.html\n{index_text}")

requirements_text = read_text(root / "requirements.txt", 2000)
if requirements_text:
    context_sections.append(f"# requirements.txt\n{requirements_text}")

package_text = read_text(root / "package.json", 2000)
if package_text:
    context_sections.append(f"# package.json\n{package_text}")

automation_notes = read_text(root / "AUTOMATION_SETUP.md", 2000)
if automation_notes:
    context_sections.append(f"# AUTOMATION_SETUP.md\n{automation_notes}")

context = "\n\n".join(context_sections)

user_prompt = f"""
You're helping populate catalogue.json entries for a portfolio site.

Catalogue instructions:
{guide}

Repository name: {repo_name or root.name}
Screenshot hint: {screenshot_hint or 'Not provided'}

Source materials:
{context}

Respond with strictly valid JSON only (no markdown fences, comments, or prose). Include keys:
id, title, oneLiner, demoUrl, screenshot, kind, tags (array), status.
NOTE: tags are used for categorization/filtering (formerly split between categories and tags, now unified).
Use best guesses from the materials; leave fields blank only if absolutely unknown.
"""

payload = {
    "model": model,
    "temperature": 0.2,
    "messages": [
        {"role": "system", "content": "You generate concise JSON metadata for project catalogues following given instructions."},
        {"role": "user", "content": user_prompt}
    ]
}

data = json.dumps(payload).encode("utf-8")
req = urllib.request.Request(
    "https://api.openai.com/v1/chat/completions",
    data=data,
    headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    },
    method="POST"
)

response_text = ""

try:
    with urllib.request.urlopen(req) as resp:
        body = resp.read()
        response_text = body.decode("utf-8", errors="ignore")
except urllib.error.HTTPError as exc:
    status = getattr(exc, "code", None)
    msg = exc.read().decode("utf-8", errors="ignore") if hasattr(exc, "read") else str(exc)
    if status == 429:
        print("OpenAI request hit rate limits (HTTP 429). Try again later or lower usage.", file=sys.stderr)
    else:
        print(f"OpenAI HTTP error {status}: {msg}", file=sys.stderr)
    sys.exit(1)
except urllib.error.URLError as exc:
    print(f"OpenAI request failed: {exc}", file=sys.stderr)
    sys.exit(1)

if not response_text.strip():
    write_log("<<empty response>>")
    print("OpenAI returned an empty response", file=sys.stderr)
    sys.exit(1)

write_log(response_text)

response = json.loads(response_text)
content = response["choices"][0]["message"]["content"].strip()

if content.startswith("```"):
    parts = content.split("```")
    for part in parts:
        part = part.strip()
        if part.startswith("{"):
            content = part
            break

def attempt_parse(text):
    try:
        return json.loads(text.strip())
    except json.JSONDecodeError:
        cleaned = re.sub(r'(?m)(?<!:)//.*$', '', text)
        cleaned = cleaned.replace('```json', '').replace('```', '').strip()
        if cleaned != text:
            try:
                return json.loads(cleaned)
            except json.JSONDecodeError:
                pass
        raise

try:
    parsed = attempt_parse(content)
except json.JSONDecodeError:
    write_log(f"{response_text}\n\n--- Parsed Segment ---\n{content}")
    print("Failed to parse AI response as JSON", file=sys.stderr)
    sys.exit(1)

def ensure_list(key):
    value = parsed.get(key, [])
    if isinstance(value, list):
        parsed[key] = value
    elif value in ("", None):
        parsed[key] = []
    else:
        parsed[key] = [value]

# Merge categories and tags for backwards compatibility
categories = parsed.get("categories", [])
tags = parsed.get("tags", [])
if isinstance(categories, str):
    categories = [categories] if categories else []
if isinstance(tags, str):
    tags = [tags] if tags else []

# Combine both and deduplicate
merged = list(dict.fromkeys(categories + tags))
parsed["tags"] = merged

write_log(content)

print(json.dumps(parsed))
PY
    ); then
        echo -e "${YELLOW}AI prefill unavailable. Check ${ai_log_file} for details.${NC}" >&2
        return 1
    fi

    printf "%s" "$ai_output"
}
create_catalogue_metadata() {
    local repo_name_local="$1"
    local screenshot_hint="$2"
    local catalogue_file="catalogue.json"
    local prompt_label="Create catalogue.json for homepage catalogue? (Y/n): "

    if [ -f "$catalogue_file" ]; then
        prompt_label="catalogue.json already exists. Update it now? (Y/n): "
    fi

    read -p "$prompt_label" catalogue_choice
    catalogue_choice=${catalogue_choice:-y}
    if [[ ! $catalogue_choice =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Skipping catalogue metadata generation.${NC}\n"
        return
    fi

    local default_id="$repo_name_local"
    local default_title
    default_title=$(title_case "$repo_name_local")
    [ -z "$default_title" ] && default_title="$repo_name_local"

    local default_demo_url
    default_demo_url=$(derive_default_demo_url "$repo_name_local")

    local screenshot_relative="screenshot.png"
    if [ -n "$screenshot_hint" ]; then
        screenshot_relative="${screenshot_hint#./}"
    fi
    screenshot_relative=${screenshot_relative#/}

    local default_screenshot=""
    local guessed_raw=""
    guessed_raw=$(derive_raw_file_url "$repo_name_local" "$screenshot_relative")
    if [ -n "$guessed_raw" ]; then
        default_screenshot="$guessed_raw"
    else
        default_screenshot="./${screenshot_relative}"
    fi

    local default_oneliner=""
    local default_kind="project"
    local default_tags=""
    local default_status="published"

    local ai_prefill=""
    if [ -n "$OPENAI_API_KEY" ] && command -v python3 >/dev/null 2>&1; then
        read -p "Use OpenAI to prefill catalogue metadata? (Y/n): " use_ai_prefill
        use_ai_prefill=${use_ai_prefill:-y}
        if [[ $use_ai_prefill =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Requesting AI-generated catalogue suggestions...${NC}"
            if ai_prefill=$(generate_catalogue_ai_defaults "$repo_name_local" "$screenshot_hint"); then
                if [ -n "$ai_prefill" ]; then
                    echo -e "${GREEN}AI suggestions received. You can edit them below.${NC}"
                    ai_values=$(
                        AI_PREFILL_JSON="$ai_prefill" python3 - <<'PY'
import os, json
text = os.environ.get("AI_PREFILL_JSON", "")
if not text.strip():
    raise SystemExit(0)
try:
    data = json.loads(text)
except json.JSONDecodeError:
    raise SystemExit(0)
def fmt(value):
    if isinstance(value, list):
        return ", ".join(str(v) for v in value)
    return value or ""
fields = ["id","title","oneLiner","demoUrl","screenshot","kind","tags","status"]
for key in fields:
    print(fmt(data.get(key, "")))
PY
                    )
                    if [ -z "$ai_values" ]; then
                        echo -e "${YELLOW}AI returned empty data; continuing with defaults.${NC}"
                    else
                        IFS=$'\n' read -r ai_id ai_title ai_oneliner ai_demo ai_screenshot ai_kind ai_tags ai_status <<EOF
$ai_values
EOF
                        [ -n "$ai_id" ] && default_id="$ai_id"
                        [ -n "$ai_title" ] && default_title="$ai_title"
                        [ -n "$ai_oneliner" ] && default_oneliner="$ai_oneliner"
                        [ -n "$ai_demo" ] && default_demo_url="$ai_demo"
                        [ -n "$ai_screenshot" ] && default_screenshot="$ai_screenshot"
                        [ -n "$ai_kind" ] && default_kind="$ai_kind"
                        [ -n "$ai_tags" ] && default_tags="$ai_tags"
                        [ -n "$ai_status" ] && default_status="$ai_status"
                    fi
                else
                    echo -e "${YELLOW}AI returned no data; continuing with manual input.${NC}"
                fi
            else
                echo -e "${YELLOW}AI prefill unavailable (check $HOME/gitBash/logs for details). Continuing manually.${NC}"
            fi
        fi
    elif [ -z "$OPENAI_API_KEY" ]; then
        echo -e "${YELLOW}Set OPENAI_API_KEY to enable AI-assisted catalogue defaults.${NC}"
    fi

    echo -e "${BLUE}=== Catalogue Metadata ===${NC}"
    read -p "Catalogue ID (default: ${default_id}): " catalogue_id
    catalogue_id=${catalogue_id:-$default_id}

    read -p "Catalogue title (default: ${default_title}): " catalogue_title
    catalogue_title=${catalogue_title:-$default_title}

    read -p "One-liner description (default: ${default_oneliner}): " catalogue_oneliner
    catalogue_oneliner=${catalogue_oneliner:-$default_oneliner}

    read -p "Demo URL (default: ${default_demo_url}): " catalogue_demo_url
    catalogue_demo_url=${catalogue_demo_url:-$default_demo_url}

    read -p "Screenshot path (default: ${default_screenshot}): " catalogue_screenshot
    catalogue_screenshot=${catalogue_screenshot:-$default_screenshot}

    read -p "Kind (project/longform/page) [default: ${default_kind}]: " catalogue_kind
    catalogue_kind=${catalogue_kind:-$default_kind}

    read -p "Tags (comma-separated, e.g., simulation, physics, p5.js) [default: ${default_tags}]: " tags_input
    tags_input=${tags_input:-$default_tags}

    read -p "Status (default: ${default_status}): " catalogue_status
    catalogue_status=${catalogue_status:-$default_status}

    local tags_json
    tags_json=$(list_to_json_array "$tags_input")

    local escaped_id
    escaped_id=$(escape_json_string "$catalogue_id")
    local escaped_title
    escaped_title=$(escape_json_string "$catalogue_title")
    local escaped_oneliner
    escaped_oneliner=$(escape_json_string "$catalogue_oneliner")
    local escaped_demo
    escaped_demo=$(escape_json_string "$catalogue_demo_url")
    local escaped_screenshot
    escaped_screenshot=$(escape_json_string "$catalogue_screenshot")
    local escaped_kind
    escaped_kind=$(escape_json_string "$catalogue_kind")
    local escaped_status
    escaped_status=$(escape_json_string "$catalogue_status")

    cat > "$catalogue_file" <<EOF
{
  "id": "${escaped_id}",
  "title": "${escaped_title}",
  "oneLiner": "${escaped_oneliner}",
  "demoUrl": "${escaped_demo}",
  "screenshot": "${escaped_screenshot}",
  "kind": "${escaped_kind}",
  "categories": ${tags_json},
  "tags": ${tags_json},
  "status": "${escaped_status}"
}
EOF

    echo -e "${GREEN}catalogue.json created/updated for homepage automation.${NC}\n"
}

if [ "$is_modify" = true ]; then
    echo -e "${BLUE}=== Git Repository Enhancer (Modify Mode) ===${NC}\n"
else
    echo -e "${BLUE}=== Git Repository Initializer ===${NC}\n"
fi

default_commit_msg="init commit"
if [ "$is_modify" = true ]; then
    default_commit_msg="chore: repo retrofit"
fi
made_commit=false

# Initialize git repository (init mode only)
if [ "$is_modify" = false ]; then
    if [ -d ".git" ]; then
        echo -e "${YELLOW}Git repository already initialized in this directory.${NC}"
        read -p "Do you want to continue anyway? (y/n): " continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            echo "Exiting..."
            exit 0
        fi
    else
        echo -e "${GREEN}Initializing git repository...${NC}"
        git init
        echo ""
    fi
else
    if [ ! -d ".git" ]; then
        echo -e "${RED}Modify mode requires running inside an existing git repository.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Running in modify mode on existing repository.${NC}\n"
fi

# Check for .gitignore and create if needed
if [ ! -f ".gitignore" ]; then
    echo -e "${YELLOW}.gitignore not found. Creating one...${NC}"
    cat > .gitignore << 'EOF'
# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor files
.vscode/
.idea/
*.swp
*.swo
*~

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
.venv
pip-log.txt
pip-delete-this-directory.txt

# Node
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Logs
*.log
logs/

EOF
    echo -e "${GREEN}Created basic .gitignore${NC}\n"
else
    echo -e "${GREEN}.gitignore already exists.${NC}\n"
fi

# Scan for potential files that should be ignored
echo -e "${BLUE}Scanning for files that might need to be ignored...${NC}\n"

# Array to hold files to potentially ignore
declare -a files_to_check=()

# Check for secrets files
while IFS= read -r -d '' file; do
    files_to_check+=("$file")
done < <(find . -maxdepth 3 -type f \( -name "*secret*" -o -name "*password*" -o -name "*credentials*" -o -name "*.pem" -o -name "*.key" -o -name ".env" -o -name ".env.*" \) -not -path "./.git/*" -print0 2>/dev/null)

# Check for .yaml and .json files
while IFS= read -r -d '' file; do
    files_to_check+=("$file")
done < <(find . -maxdepth 2 -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) -not -path "./.git/*" -not -name "package.json" -not -name "package-lock.json" -not -name "tsconfig.json" -print0 2>/dev/null)

# Check for large files (>10MB)
while IFS= read -r -d '' file; do
    files_to_check+=("$file")
done < <(find . -maxdepth 3 -type f -size +10M -not -path "./.git/*" -print0 2>/dev/null)

# Remove duplicates
files_to_check=($(printf "%s\n" "${files_to_check[@]}" | sort -u))

# Ask user about each file
if [ ${#files_to_check[@]} -gt 0 ]; then
    echo -e "${YELLOW}Found ${#files_to_check[@]} file(s) that might need attention:${NC}\n"
    
    declare -a files_to_ignore=()
    
    for file in "${files_to_check[@]}"; do
        # Get file size
        if [[ "$OSTYPE" == "darwin"* ]]; then
            file_size=$(stat -f%z "$file" 2>/dev/null || echo "0")
        else
            file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        fi
        
        # Convert to human readable
        if [ $file_size -gt 1048576 ]; then
            size_display="$(( file_size / 1048576 ))MB"
        elif [ $file_size -gt 1024 ]; then
            size_display="$(( file_size / 1024 ))KB"
        else
            size_display="${file_size}B"
        fi
        
        echo -e "${BLUE}File: ${file} (${size_display})${NC}"
        
        # Check if already in .gitignore
        if grep -qF "${file#./}" .gitignore 2>/dev/null; then
            echo -e "${GREEN}  Already in .gitignore${NC}\n"
            continue
        fi
        
        read -p "  Should this be IGNORED (not tracked in git)? (y/n/q to quit): " response
        
        if [[ $response =~ ^[Qq]$ ]]; then
            break
        elif [[ $response =~ ^[Yy]$ ]]; then
            files_to_ignore+=("${file#./}")
            echo -e "${GREEN}  Will add to .gitignore${NC}\n"
        else
            echo -e "${YELLOW}  Will be tracked in git${NC}\n"
        fi
    done
    
    # Add files to .gitignore
    if [ ${#files_to_ignore[@]} -gt 0 ]; then
        echo -e "\n${GREEN}Adding files to .gitignore...${NC}"
        echo -e "\n# Files added by git-init-repo script" >> .gitignore
        for file in "${files_to_ignore[@]}"; do
            echo "$file" >> .gitignore
            echo "  Added: $file"
        done
        echo ""
    fi
else
    echo -e "${GREEN}No suspicious files found.${NC}\n"
fi

# Check for README.md
if [ ! -f "README.md" ]; then
    echo -e "${YELLOW}README.md not found.${NC}"
    read -p "Enter repository name: " repo_name
    read -p "Enter a brief description: " repo_description
    
    cat > README.md << EOF
# ${repo_name}

${repo_description}

## Getting Started

### Prerequisites

List any prerequisites here.

### Installation

\`\`\`bash
# Add installation instructions
\`\`\`

### Usage

\`\`\`bash
# Add usage examples
\`\`\`

## License

Add license information here.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
EOF
    
    echo -e "${GREEN}Created README.md${NC}\n"
else
    echo -e "${GREEN}README.md already exists.${NC}\n"
    repo_name=$(basename "$(pwd)")
fi

# Detect screenshot first
detected_screenshot_path=""
declare -a screenshot_candidates=("screenshot.png" "screenshot.jpg" "screenshot.jpeg" "Screenshot.png" "Screenshot.jpg" "Screenshot.jpeg")
screenshot_file=""

for candidate in "${screenshot_candidates[@]}"; do
    if [ -f "$candidate" ]; then
        screenshot_file="$candidate"
        break
    fi
done

if [ -n "$screenshot_file" ]; then
    screenshot_relative="${screenshot_file#./}"
    detected_screenshot_path="./${screenshot_relative#./}"
fi

# For MODIFY mode: handle GitHub Pages FIRST (before README/catalogue edits)
if [ "$is_modify" = true ]; then
    echo -e "${BLUE}=== GitHub Enhancements (Modify Mode) ===${NC}\n"
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        repo_url=$(gh repo view --json url -q .url 2>/dev/null || printf "")
        repo_owner=$(gh repo view --json owner -q .owner.login 2>/dev/null || printf "")
        repo_name_remote=$(gh repo view --json name -q .name 2>/dev/null || printf "")

        if [ -n "$repo_url" ] && [ -n "$repo_owner" ] && [ -n "$repo_name_remote" ]; then
            handle_github_pages "$repo_name_remote" "$repo_owner" "$repo_url"
        else
            echo -e "${YELLOW}Unable to determine GitHub repo information. Ensure 'origin' remote exists.${NC}\n"
        fi
    else
        echo -e "${YELLOW}GitHub CLI not available or not authenticated. Skipping GitHub Pages guidance.${NC}\n"
    fi
fi

# Embed screenshot in README (after Pages setup in modify mode, so demo link is there)
if [ -n "$screenshot_file" ] && [ -f "README.md" ]; then
    if ! grep -q "$screenshot_relative" README.md; then
        echo -e "${BLUE}Adding project screenshot (${screenshot_relative}) to README...${NC}"
        cat <<EOF >> README.md

## Preview

<p align="center">
  <img src="${screenshot_relative}" alt="Project screenshot" width="720" />
</p>

EOF
        echo -e "${GREEN}Screenshot embedded in README.${NC}\n"
    else
        echo -e "${GREEN}Screenshot already referenced in README.${NC}\n"
    fi
fi

# Create catalogue metadata (after Pages and screenshot in modify mode)
create_catalogue_metadata "$repo_name" "$detected_screenshot_path"

# Stage all files
echo -e "${BLUE}Staging files...${NC}"
git add .
echo -e "${GREEN}Files staged.${NC}\n"

# Commit (only if there are staged changes)
if git diff --cached --quiet; then
    echo -e "${YELLOW}No changes to commit. Skipping commit step.${NC}\n"
else
    echo -e "${BLUE}Creating commit...${NC}"
    read -p "Enter commit message (default: ${default_commit_msg}): " commit_message
    commit_message=${commit_message:-$default_commit_msg}
    git commit -m "$commit_message"
    echo -e "${GREEN}Commit created with message: '${commit_message}'.${NC}\n"
    made_commit=true
fi

# For INIT mode: handle GitHub setup AFTER commit (needs commits to push)
if [ "$is_modify" = false ]; then
    echo -e "${BLUE}=== GitHub Repository Setup ===${NC}\n"

    if ! command -v gh &> /dev/null; then
        echo -e "${RED}GitHub CLI (gh) is not installed.${NC}"
        echo "Please install it from: https://cli.github.com/"
        echo "Run: brew install gh"
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        echo -e "${YELLOW}GitHub CLI not authenticated.${NC}"
        echo "Please run: gh auth login"
        exit 1
    fi

    echo "Will this repository be:"
    echo "1) Private"
    echo "2) Public"
    read -p "Enter choice (1 or 2): " visibility_choice

    if [ "$visibility_choice" = "1" ]; then
        visibility="--private"
        visibility_text="private"
    else
        visibility="--public"
        visibility_text="public"
    fi

    if [ -z "$repo_name" ]; then
        repo_name=$(basename "$(pwd)")
        read -p "Enter repository name (default: ${repo_name}): " input_repo_name
        if [ ! -z "$input_repo_name" ]; then
            repo_name="$input_repo_name"
        fi
    fi

    echo -e "\n${BLUE}Creating ${visibility_text} GitHub repository: ${repo_name}${NC}"
    read -p "Press Enter to continue or Ctrl+C to cancel..."

    if gh repo create "$repo_name" $visibility --source=. --push; then
        echo -e "\n${GREEN}========================================${NC}"
        echo -e "${GREEN}Success! Repository created and pushed!${NC}"
        echo -e "${GREEN}========================================${NC}\n"

        repo_url=$(gh repo view --json url -q .url)
        repo_owner=$(gh repo view --json owner -q .owner.login)
        echo -e "${BLUE}Repository URL: ${repo_url}${NC}\n"

        handle_github_pages "$repo_name" "$repo_owner" "$repo_url"
    else
        echo -e "\n${RED}Failed to create GitHub repository.${NC}"
        echo "You can manually create it and push with:"
        echo "  gh repo create $repo_name $visibility --source=. --push"
        exit 1
    fi
fi

# Push changes if in modify mode and commit was made
if [ "$is_modify" = true ] && [ "$made_commit" = true ]; then
    read -p "Do you want to push the new commit to origin? (y/n): " push_choice
    if [[ $push_choice =~ ^[Yy]$ ]]; then
        git push
        echo -e "${GREEN}Changes pushed to origin.${NC}\n"
    else
        echo -e "${YELLOW}Remember to push your changes later.${NC}\n"
    fi
fi

echo -e "${GREEN}All done! 🎉${NC}\n"

if [ "$is_modify" = false ]; then
    # Ask about cleanup (only for init mode)
    current_dir=$(pwd)
    folder_name=$(basename "$current_dir")
    parent_dir=$(dirname "$current_dir")

    echo -e "${BLUE}=== Cleanup ===${NC}"
    echo -e "${YELLOW}The repository has been successfully pushed to GitHub.${NC}"
    echo -e "Current folder: ${BLUE}${current_dir}${NC}"
    read -p "Do you want to delete this local folder to clean up your computer? (y/n): " cleanup_choice

    if [[ $cleanup_choice =~ ^[Yy]$ ]]; then
        echo -e "\n${YELLOW}This will:${NC}"
        echo -e "  1. Navigate to: ${parent_dir}"
        echo -e "  2. Delete: ${folder_name}/"
        echo -e "${RED}WARNING: This cannot be undone!${NC}"
        read -p "Are you absolutely sure? Type 'DELETE' to confirm: " confirm_delete

        if [ "$confirm_delete" = "DELETE" ]; then
            cd "$parent_dir"
            rm -rf "$folder_name"
            echo -e "${GREEN}✓ Folder deleted and moved to parent directory${NC}"
            echo -e "${BLUE}Current location: $(pwd)${NC}"
        else
            echo -e "${YELLOW}Cleanup cancelled. Folder kept.${NC}"
        fi
    else
        echo -e "${YELLOW}Keeping local folder.${NC}"
    fi
fi

