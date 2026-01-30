import os
import json
import shutil
import subprocess
import re

# 技能集合仓库列表
REPOS = [
    {"url": "https://github.com/openai/skills.git", "provider": "OpenAI"},
    {"url": "https://github.com/huggingface/skills.git", "provider": "HuggingFace"},
    {"url": "https://github.com/skillcreatorai/Ai-Agent-Skills.git", "provider": "SkillCreator.ai"},
    {"url": "https://github.com/karanb192/awesome-claude-skills.git", "provider": "Community"},
    {"url": "https://github.com/shajith003/awesome-claude-skills.git", "provider": "Community"},
    {"url": "https://github.com/GuDaStudio/skills.git", "provider": "GuDaStudio"},
    {"url": "https://github.com/DougTrajano/pydantic-ai-skills.git", "provider": "Pydantic AI"},
    {"url": "https://github.com/OmidZamani/dspy-skills.git", "provider": "DSPy"},
    {"url": "https://github.com/ponderous-dustiness314/awesome-claude-skills.git", "provider": "Community"},
    {"url": "https://github.com/hikanner/agent-skills.git", "provider": "Hikanner"},
    {"url": "https://github.com/gradion-ai/freeact-skills.git", "provider": "FreeAct"},
    {"url": "https://github.com/gotalab/skillport.git", "provider": "Gotalab"},
    {"url": "https://github.com/mhattingpete/claude-skills-marketplace.git", "provider": "Community"},
    {"url": "https://github.com/K-Dense-AI/claude-scientific-skills.git", "provider": "K-Dense-AI"},
    {"url": "https://github.com/sickn33/antigravity-awesome-skills.git", "provider": "Antigravity"},
    {"url": "https://github.com/SKE-Labs/agent-trading-skills.git", "provider": "SKE-Labs"}
]

TEMP_DIR = "temp_scan_repos"
INDEX_FILE = "skills_index.json"

def load_index():
    if os.path.exists(INDEX_FILE):
        with open(INDEX_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {"skills": []}

def save_index(data):
    with open(INDEX_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def parse_skill_md(file_path):
    """解析 SKILL.md 获取名称和描述"""
    name = None
    description = None
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
            # 尝试解析 YAML frontmatter
            yaml_match = re.search(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
            if yaml_match:
                yaml_content = yaml_match.group(1)
                name_match = re.search(r'name:\s*(.+)', yaml_content)
                desc_match = re.search(r'description:\s*(.+)', yaml_content)
                if name_match:
                    name = name_match.group(1).strip()
                if desc_match:
                    description = desc_match.group(1).strip()
            
            # 如果没有 YAML 或 缺少信息，尝试从标题获取
            if not name:
                # 假设文件夹名是 skill name，这里先不处理，由调用者提供默认
                pass
                
            if not description:
                # 尝试获取第一个非标题行作为描述
                lines = content.split('\n')
                for line in lines:
                    line = line.strip()
                    if line and not line.startswith('#') and not line.startswith('---'):
                        description = line
                        break
    except Exception as e:
        print(f"Error parsing {file_path}: {e}")
        
    return name, description

def scan_repo(repo_info, existing_names):
    repo_url = repo_info['url']
    provider = repo_info['provider']
    repo_name = f"{provider}_{repo_url.split('/')[-1].replace('.git', '')}".replace(' ', '_')
    clone_path = os.path.join(TEMP_DIR, repo_name)
    
    print(f"\nProcessing {repo_name}...")
    
    # 1. Clone
    if os.path.exists(clone_path):
        def on_rm_error(func, path, exc_info):
            try:
                os.chmod(path, 0o777)
                func(path)
            except Exception as e:
                print(f"Warning: Failed to remove {path}: {e}")

        try:
            shutil.rmtree(clone_path, onerror=on_rm_error)
        except Exception as e:
            print(f"Warning: Failed to clean up existing {clone_path}: {e}")
        
    try:
        subprocess.run(["git", "clone", "--depth", "1", repo_url, clone_path], check=True)
    except subprocess.CalledProcessError:
        print(f"Failed to clone {repo_url}, skipping.")
        return []

    found_skills = []
    
    # 2. Walk and find skills
    # 策略：寻找包含 SKILL.md 的目录
    for root, dirs, files in os.walk(clone_path):
        # 忽略 .git 目录
        if '.git' in root:
            continue
            
        if 'SKILL.md' in files:
            skill_md_path = os.path.join(root, 'SKILL.md')
            rel_path = os.path.relpath(root, clone_path)
            
            # 如果 SKILL.md 在根目录，且不是 skills 文件夹（有些 repo 根目录就是 skill）
            # 或者在子目录
            
            # 解析元数据
            name, description = parse_skill_md(skill_md_path)
            
            # 如果 YAML 中没有 name，使用文件夹名
            if not name:
                if rel_path == '.':
                    name = repo_name # 根目录技能
                else:
                    name = os.path.basename(root)
            
            # 清理 name (移除空格，转小写)
            name = name.lower().replace(' ', '-')
            
            if not description:
                description = f"Skill from {repo_name}"
            
            # 构造 entry
            # 注意：folder_path 需要是相对于 repo 根目录的路径
            folder_path = rel_path if rel_path != '.' else ''
            
            # 检查是否重复
            if name in existing_names:
                print(f"  Skipping duplicate: {name}")
                continue
            
            skill_entry = {
                "name": name,
                "category": "Community", # 暂时统称为 Community，后续可以优化
                "provider": provider,
                "description": description[:200] + "..." if len(description) > 200 else description,
                "type": "remote_folder",
                "repo_url": repo_url,
                "branch": "main", # 假设 main，如果不确定可能需要动态检测，但 depth 1 通常拉取默认分支
                "folder_path": folder_path.replace('\\', '/')
            }
            
            found_skills.append(skill_entry)
            existing_names.add(name)
            print(f"  Found: {name}")

    # Cleanup
    def on_rm_error(func, path, exc_info):
        try:
            os.chmod(path, 0o777)
            func(path)
        except Exception as e:
            print(f"Warning: Failed to remove {path}: {e}")

    try:
        shutil.rmtree(clone_path, onerror=on_rm_error)
    except Exception as e:
        print(f"Warning: Failed to clean up {clone_path}: {e}")
    
    return found_skills

def main():
    if not os.path.exists(TEMP_DIR):
        os.makedirs(TEMP_DIR)
        
    index_data = load_index()
    existing_names = {s['name'] for s in index_data['skills']}
    
    total_added = 0
    
    for repo in REPOS:
        new_skills = scan_repo(repo, existing_names)
        if new_skills:
            index_data['skills'].extend(new_skills)
            total_added += len(new_skills)
            # 实时保存，防止中断丢失
            save_index(index_data)
            
    print(f"\nDone. Total new skills added: {total_added}")
    
    # Final cleanup
    if os.path.exists(TEMP_DIR):
        def on_rm_error(func, path, exc_info):
            os.chmod(path, 0o777)
            func(path)
        shutil.rmtree(TEMP_DIR, onerror=on_rm_error)

if __name__ == "__main__":
    main()
