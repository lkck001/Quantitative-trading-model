import urllib.request
import json
import re

SKILLS = [
    'algorithmic-art', 'brand-guidelines', 'canvas-design', 'doc-coauthoring', 
    'docx', 'frontend-design', 'internal-comms', 'mcp-builder', 'pdf', 'pptx', 
    'skill-creator', 'slack-gif-creator', 'theme-factory', 'web-artifacts-builder', 
    'webapp-testing', 'xlsx'
]

CATEGORY_MAP = {
    'docx': 'Office', 'xlsx': 'Office', 'pptx': 'Office', 'pdf': 'Office',
    'algorithmic-art': 'Creative', 'slack-gif-creator': 'Creative',
    'brand-guidelines': 'Design', 'canvas-design': 'Design', 'theme-factory': 'Design',
    'frontend-design': 'Development', 'web-artifacts-builder': 'Development', 
    'webapp-testing': 'Development', 'mcp-builder': 'Development', 'skill-creator': 'Development',
    'internal-comms': 'Productivity', 'doc-coauthoring': 'Productivity'
}

BASE_URL = "https://raw.githubusercontent.com/anthropics/skills/main/skills"

def fetch_description(skill_name):
    url = f"{BASE_URL}/{skill_name}/SKILL.md"
    try:
        with urllib.request.urlopen(url) as response:
            content = response.read().decode('utf-8')
            
            # Try to find description in YAML frontmatter
            desc_match = re.search(r'description:\s*"(.*?)"', content, re.IGNORECASE)
            if desc_match:
                return desc_match.group(1)
            
            desc_match_simple = re.search(r'description:\s*(.+)', content, re.IGNORECASE)
            if desc_match_simple:
                return desc_match_simple.group(1).strip()
                
            # Fallback: First paragraph after title
            # Remove YAML
            content_no_yaml = re.sub(r'^---\n.*?---\n', '', content, flags=re.DOTALL)
            lines = content_no_yaml.strip().split('\n')
            for line in lines:
                if line.strip() and not line.startswith('#'):
                    return line.strip()[:200] # Limit length
                    
            return f"Official Anthropic skill for {skill_name}"
            
    except Exception as e:
        print(f"Failed to fetch {skill_name}: {e}")
        return f"Official Anthropic skill for {skill_name}"

def generate_index():
    skills_list = []
    
    print("Fetching metadata...")
    for skill in SKILLS:
        print(f" - Processing {skill}...")
        desc = fetch_description(skill)
        
        entry = {
            "name": skill,
            "category": CATEGORY_MAP.get(skill, "General"),
            "provider": "Anthropic",
            "description": desc,
            "type": "remote_folder",
            "repo_url": "https://github.com/anthropics/skills.git",
            "branch": "main",
            "folder_path": f"skills/{skill}"
        }
        skills_list.append(entry)
        
    # Add our local bookmark-manager
    skills_list.append({
      "name": "bookmark-manager",
      "category": "Utility",
      "provider": "Local",
      "description": "Organizes and classifies browser bookmarks. Helps users restructure chaotic favorites into a logical hierarchy.",
      "source_url": "local://.trae/skills/bookmark-manager/SKILL.md",
      "type": "local"
    })
    
    final_json = {"skills": skills_list}
    
    print("\nSaving to skills_index.json...")
    with open('skills_index.json', 'w', encoding='utf-8') as f:
        json.dump(final_json, f, indent=2)
    print("Done!")

if __name__ == "__main__":
    generate_index()
