import urllib.request
import json
import urllib.parse
import sys

API_KEY = "sk_live_skillsmp_GFztu37eDea7Op0f6f42N9j8xxDsGDAtBpFX8xeHlOM"

def test_api(endpoint_type, query):
    if endpoint_type == "ai":
        base_url = "https://skillsmp.com/api/v1/skills/ai-search"
        params = {"q": query}
        print(f"\n[AI Search] Query: '{query}'")
    else:
        base_url = "https://skillsmp.com/api/v1/skills/search"
        params = {"q": query, "limit": 3}
        print(f"\n[Keyword Search] Query: '{query}'")
    
    url = f"{base_url}?{urllib.parse.urlencode(params)}"
    
    try:
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'Mozilla/5.0')
        req.add_header('Authorization', f'Bearer {API_KEY}')
        
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode('utf-8'))
            
            print(f"DEBUG: Data keys: {data.keys() if isinstance(data, dict) else 'Not a dict'}")
            
            # Handle different response structures if any
            if isinstance(data, list):
                results = data
            elif isinstance(data, dict):
                # Try common API patterns
                if 'skills' in data: results = data['skills']
                elif 'data' in data: 
                    # Sometimes data is a list, sometimes a dict wrapper
                    inner_data = data['data']
                    if isinstance(inner_data, list):
                        results = inner_data
                    elif isinstance(inner_data, dict) and 'skills' in inner_data:
                        results = inner_data['skills']
                    else:
                        print(f"DEBUG: Unexpected data structure inside 'data': {type(inner_data)}")
                        results = []
                elif 'results' in data: results = data['results']
                elif 'items' in data: results = data['items']
                else: 
                    # Maybe the dict itself is the result if it has name/desc?
                    print("DEBUG: No list wrapper found, checking content...")
                    results = [] 
            else:
                results = []
                
            print(f"DEBUG: Results type: {type(results)}")
            print(f"DEBUG: First item: {results[0] if results else 'Empty'}")
            
            print(f"Found {len(results)} results:")
            print("-" * 60)
            
            # Safe slicing
            max_show = 3
            display_items = results[:max_show] if isinstance(results, list) else []
            
            for i, item in enumerate(display_items):
                name = item.get('name', 'N/A')
                desc = item.get('description', 'N/A')
                print(f"{i+1}. {name}")
                print(f"   Desc: {desc[:100]}...")
            print("-" * 60)
            return results
                
    except urllib.error.HTTPError as e:
        print(f"Error ({e.code}): {e.read().decode('utf-8')}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    # Test Case 1: Complex Intent (Natural Language)
    nl_query = "help me extract tables from pdf files and save to csv"
    
    # Test Case 2: Keyword Decomposition (Manually extracted)
    kw_query = "pdf table extract csv"
    
    print("=== COMPARING SEARCH METHODS ===")
    
    # 1. Test AI Search with Natural Language
    test_api("ai", nl_query)
    
    # 2. Test Keyword Search with Keywords
    test_api("keyword", kw_query)

