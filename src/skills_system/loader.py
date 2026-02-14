import json
import os
import sys
import urllib.request
import urllib.parse
import subprocess
import shutil
import time

# Configuration
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
INDEX_FILE = os.path.join(PROJECT_ROOT, "skills_index.json")

# Public Cache Directory (Remote skills)
SKILLS_REMOTE_CACHE_DIR = os.path.join(PROJECT_ROOT, "skills_remote_cache")

# Local Skills Directory (User maintained)
SKILLS_LOCAL_CACHE_DIR = os.path.join(PROJECT_ROOT, "skills_local_cache")

# System Skills Directory (Meta-skills)
SKILLS_SYSTEM_DIR = os.path.join(PROJECT_ROOT, ".trae", "skills")
METADATA_FILE = os.path.join(SKILLS_SYSTEM_DIR, "cache_metadata.json")

# SkillsMP API Key
SKILLSMP_API_KEY = "sk_live_skillsmp_GFztu37eDea7Op0f6f42N9j8xxDsGDAtBpFX8xeHlOM"

# 5GB Cache Limit
CACHE_LIMIT_BYTES = 5 * 1024 * 1024 * 1024 

def load_index():
    """Load the skills index JSON file."""
    if not os.path.exists(INDEX_FILE):
        return []
    with open(INDEX_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)
        return data.get("skills", [])

def get_dir_size(path):
    """Calculate the total size of a directory in bytes."""
    total_size = 0
    if not os.path.exists(path):
        return 0
    for dirpath, dirnames, filenames in os.walk(path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            if not os.path.islink(fp):
                total_size += os.path.getsize(fp)
    return total_size

def load_metadata():
    """Load cache metadata."""
    if not os.path.exists(METADATA_FILE):
        return {}
    try:
        with open(METADATA_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {}

def save_metadata(metadata):
    """Save cache metadata."""
    if not os.path.exists(SKILLS_SYSTEM_DIR):
        os.makedirs(SKILLS_SYSTEM_DIR)
    with open(METADATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2)

def update_usage_stats(skill_name, size_bytes=0):
    """Update usage statistics for a skill."""
    metadata = load_metadata()
    now = time.time()
    
    if skill_name not in metadata:
        metadata[skill_name] = {
            "access_count": 0,
            "last_used": 0,
            "size_bytes": 0
        }
    
    metadata[skill_name]["access_count"] += 1
    metadata[skill_name]["last_used"] = now
    if size_bytes > 0:
        metadata[skill_name]["size_bytes"] = size_bytes
        
    save_metadata(metadata)

def enforce_cache_limit():
    """Check cache size and evict least frequently used skills if over limit."""
    metadata = load_metadata()
    total_size = sum(info.get("size_bytes", 0) for info in metadata.values())
        
    if total_size <= CACHE_LIMIT_BYTES:
        return

    print("Cache limit exceeded. Starting eviction...")
    
    # Sort by access_count (ascending), then last_used (ascending)
    sorted_skills = sorted(
        metadata.items(),
        key=lambda item: (item[1].get("access_count", 0), item[1].get("last_used", 0))
    )
    
    for skill_name, info in sorted_skills:
        if total_size <= CACHE_LIMIT_BYTES:
            break
            
        print(f"Evicting skill: {skill_name} (Size: {info.get('size_bytes',0)/1024:.2f} KB, Uses: {info.get('access_count',0)})")
        
        skill_dir = os.path.join(SKILLS_REMOTE_CACHE_DIR, skill_name)
        if os.path.exists(skill_dir):
            try:
                shutil.rmtree(skill_dir, ignore_errors=True)
                total_size -= info.get("size_bytes", 0)
                del metadata[skill_name]
            except Exception as e:
                print(f"Error deleting {skill_name}: {e}")
        else:
            total_size -= info.get("size_bytes", 0)
            del metadata[skill_name]
            
    save_metadata(metadata)
    print(f"Eviction complete. New Cache Usage: {total_size / (1024*1024):.2f} MB")

def search_skills_remote(query, limit=10):
    """Search skills using SkillsMP API."""
    base_url = "https://skillsmp.com/api/v1/skills/search"
    params = {"q": query, "limit": limit}
    url = f"{base_url}?{urllib.parse.urlencode(params)}"
    
    try:
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'Mozilla/5.0')
        req.add_header('Authorization', f'Bearer {SKILLSMP_API_KEY}')
        
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode('utf-8'))
            
            # Handle API response structure
            results = []
            if isinstance(data, list):
                results = data
            elif isinstance(data, dict):
                # Try common API patterns
                if 'skills' in data: results = data['skills']
                elif 'data' in data: 
                    inner = data['data']
                    results = inner if isinstance(inner, list) else inner.get('skills', [])
                elif 'results' in data: results = data['results']
                else: results = []
            
            # Normalize to standard format
            normalized = []
            for item in results:
                normalized.append({
                    "name": item.get('name'),
                    "description": item.get('description', ''),
                    "stars": item.get('stars', 0),
                    "repo_url": item.get('githubUrl'),
                    "source": "REMOTE"
                })
            return normalized
            
    except Exception as e:
        print(f"Remote search failed: {e}")
        return []

def search_skills_local(query):
    """Search skills in local index."""
    skills = load_index()
    results = []
    query_terms = query.lower().split()
    
    for skill in skills:
        name = skill.get('name', '').lower()
        desc = skill.get('description', '').lower()
        category = skill.get('category', '').lower()
        
        # Simple scoring for filtering
        score = 0
        for term in query_terms:
            if term in name: score += 10
            if term in category: score += 5
            if term in desc: score += 3
                
        if score > 0:
            results.append({
                "name": skill['name'],
                "description": skill.get('description', ''),
                "stars": 0, # Local index has no stars
                "repo_url": skill.get('repo_url'),
                "source": "LOCAL",
                "score": score
            })
            
    # Sort local results by score
    results.sort(key=lambda x: x['score'], reverse=True)
    return results[:10] # Top 10 local

def search_skills(query):
    """Hybrid search: Remote + Local."""
    print(f"Searching for '{query}'...")
    
    # Parallel-ish search (sequential for now)
    remote_results = search_skills_remote(query)
    local_results = search_skills_local(query)
    
    # Merge and Deduplicate (Prioritize Remote)
    merged = {}
    
    # Add Remote first (Higher priority source)
    for item in remote_results:
        merged[item['name']] = item
        
    # Add Local if not exists
    for item in local_results:
        if item['name'] not in merged:
            merged[item['name']] = item
        else:
            # Mark as existing in both
            merged[item['name']]['source'] = "LOCAL+REMOTE"

    # Convert to list
    final_list = list(merged.values())
    
    # Sort logic: Remote items usually come sorted by API rank, keep that order roughly
    # But put highly relevant local items in mix?
    # For "Wide In", we just return them all, maybe sort by source then name
    # Let's simple sort: Stars desc (if available), then Source priority
    
    print(f"\nFound {len(final_list)} candidates (Top 10 shown):")
    print("=" * 80)
    
    for i, skill in enumerate(final_list[:10]):
        print(f"[{i+1}] {skill['name']} ({skill['source']}) | Stars: {skill['stars']}")
        print(f"    Repo: {skill.get('repo_url', 'N/A')}")
        print(f"    Desc: {skill['description'][:200]}...") # Show longer desc
        print("-" * 80)
        
    print("\n[INSTRUCTION] Please READ the descriptions above carefully.")
    print("Select the most appropriate skill and run 'python src/skills_system/loader.py fetch <name> <repo_url>'")
    print("Note: You MUST provide the repo_url for fetching if it's not in local index.")

def list_skills():
    """List installed skills."""
    metadata = load_metadata()
    print(f"Installed Skills ({len(metadata)}):")
    print("-" * 60)
    for name, info in metadata.items():
        size_mb = info.get('size_bytes', 0) / (1024*1024)
        print(f"{name:<30} | {size_mb:.2f} MB | Uses: {info.get('access_count', 0)}")
    print("-" * 60)

def remove_skill(skill_name):
    """Remove a skill from cache."""
    metadata = load_metadata()
    if skill_name not in metadata:
        print(f"Skill '{skill_name}' is not installed.")
        return
        
    skill_dir = os.path.join(SKILLS_REMOTE_CACHE_DIR, skill_name)
    if os.path.exists(skill_dir):
        try:
            shutil.rmtree(skill_dir, ignore_errors=True)
            print(f"Successfully removed skill '{skill_name}'")
            del metadata[skill_name]
            save_metadata(metadata)
        except Exception as e:
            print(f"Error removing skill: {e}")
    else:
        # Just clean metadata
        del metadata[skill_name]
        save_metadata(metadata)
        print(f"Cleaned metadata for '{skill_name}' (files were missing)")

def fetch_skill(skill_name, repo_url=None):
    """Fetch a skill. If repo_url is provided, use it directly."""
    
    # 1. Resolve URL
    target_url = repo_url
    folder_path = "" # Default to root if using direct URL
    
    if not target_url:
        # Try local index lookup
        skills = load_index()
        target = next((s for s in skills if s["name"] == skill_name), None)
        if target:
            target_url = target.get('repo_url')
            folder_path = target.get('folder_path', '')
        else:
            print(f"Error: Skill '{skill_name}' not found in index and no URL provided.")
            return

    # 2. Check Cache
    target_dir = os.path.join(SKILLS_REMOTE_CACHE_DIR, skill_name)
    if os.path.exists(target_dir):
        print(f"Skill '{skill_name}' is already installed.")
    else:
        # 3. Clone
        print(f"Fetching '{skill_name}' from {target_url}...")
        temp_dir = os.path.join(SKILLS_SYSTEM_DIR, f"temp_{int(time.time())}")
        
        try:
            # We use partial clone/sparse checkout if folder_path is known, 
            # otherwise full clone (depth 1) if it's a root repo
            if folder_path:
                 # Complex sparse checkout logic (omitted for brevity in this tool call, simplified to full clone for now to ensure robustness)
                 # Re-implementing simplified clone for robustness
                 subprocess.run(["git", "clone", "--depth", "1", "--filter=blob:none", "--sparse", target_url, temp_dir], check=True, capture_output=True)
                 subprocess.run(["git", "sparse-checkout", "set", folder_path], cwd=temp_dir, check=True, capture_output=True)
                 
                 source_path = os.path.join(temp_dir, folder_path)
            else:
                 subprocess.run(["git", "clone", "--depth", "1", target_url, temp_dir], check=True, capture_output=True)
                 source_path = temp_dir

            # Move to cache
            if os.path.exists(target_dir): shutil.rmtree(target_dir, ignore_errors=True)
            shutil.copytree(source_path, target_dir)
            
            # Update stats
            update_usage_stats(skill_name, get_dir_size(target_dir))
            enforce_cache_limit()
            
        except Exception as e:
            print(f"Git Clone Error: {e}")
            if os.path.exists(temp_dir): shutil.rmtree(temp_dir, ignore_errors=True)
            return
        finally:
            if os.path.exists(temp_dir): shutil.rmtree(temp_dir, ignore_errors=True)

    # 4. REVIEW (The "Strict Out" Phase)
    print("\n" + "="*30 + " SKILL INSTALLED " + "="*30)
    print(f"Skill '{skill_name}' has been downloaded to: {target_dir}")
    
    # Only show description from SKILL.md/README.md if possible, or just the file path
    readme_candidates = ["SKILL.md", "README.md", "instruction.md"]
    
    for doc in readme_candidates:
        doc_path = os.path.join(target_dir, doc)
        if os.path.exists(doc_path):
            print(f"\n[INFO] Documentation file: {doc_path}")
            print("To see details, please read this file.")
            break
            
    # 5. DEPENDENCY CHECK (Mechanical)
    req_file = os.path.join(target_dir, "requirements.txt")
    if os.path.exists(req_file):
        print(f"\n[WARNING] Dependency file found: {req_file}")
        print("Please check its content before running the skill code.")
        
    print("="*80)

def install_skill(skill_name):
    """Permanently install a skill from cache to src/skills_system/installed/."""
    # Source: Cache dir
    src_dir = os.path.join(SKILLS_REMOTE_CACHE_DIR, skill_name)
    if not os.path.exists(src_dir):
        print(f"Error: Skill '{skill_name}' is not in cache. Run 'fetch' first.")
        return
        
    # Destination: src/skills_system/installed/
    dest_base = os.path.join(PROJECT_ROOT, "src", "skills_system", "installed")
    if not os.path.exists(dest_base):
        os.makedirs(dest_base)
        
    # Ensure parent package has __init__.py
    init_file = os.path.join(dest_base, "__init__.py")
    if not os.path.exists(init_file):
        with open(init_file, 'w') as f:
            f.write(f"# Auto-generated by skill_loader at {time.ctime()}\n")
        
    dest_dir = os.path.join(dest_base, skill_name)
    
    if os.path.exists(dest_dir):
        print(f"Error: Skill '{skill_name}' is already installed at {dest_dir}")
        return
        
    try:
        shutil.copytree(src_dir, dest_dir)
        
        # Ensure skill itself is a package
        skill_init = os.path.join(dest_dir, "__init__.py")
        if not os.path.exists(skill_init):
             with open(skill_init, 'w') as f:
                f.write(f"# Auto-generated by skill_loader at {time.ctime()}\n")
                
        print(f"Successfully installed skill to: {dest_dir}")
        print(f"Package structure initialized. You can import it via: src.skills_system.installed.{skill_name}")
        print("This skill is now permanent and safe from cache eviction.")
    except Exception as e:
        print(f"Error installing skill: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python src/skills_system/loader.py [search|fetch|list|remove|install] ...")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "search":
        query = " ".join(sys.argv[2:])
        search_skills(query)
    elif cmd == "fetch":
        name = sys.argv[2]
        url = sys.argv[3] if len(sys.argv) > 3 else None
        fetch_skill(name, url)
    elif cmd == "list":
        list_skills()
    elif cmd == "remove":
        remove_skill(sys.argv[2])
    elif cmd == "install":
        install_skill(sys.argv[2])
    else:
        print(f"Unknown command: {cmd}")
