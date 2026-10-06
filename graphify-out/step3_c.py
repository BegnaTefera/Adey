import json
from pathlib import Path

ast_path = Path('graphify-out/.graphify_ast.json')
sem_path = Path('graphify-out/.graphify_semantic.json')

ast_data = json.loads(ast_path.read_text(encoding="utf-8")) if ast_path.exists() else {'nodes':[],'edges':[],'input_tokens':0,'output_tokens':0}
sem_data = json.loads(sem_path.read_text(encoding="utf-8")) if sem_path.exists() else {'nodes':[],'edges':[],'hyperedges':[],'input_tokens':0,'output_tokens':0}

nodes = ast_data.get('nodes', []) + sem_data.get('nodes', [])
edges = ast_data.get('edges', []) + sem_data.get('edges', [])
hyperedges = sem_data.get('hyperedges', [])

result = {
    'nodes': nodes,
    'edges': edges,
    'hyperedges': hyperedges,
    'input_tokens': ast_data.get('input_tokens', 0) + sem_data.get('input_tokens', 0),
    'output_tokens': ast_data.get('output_tokens', 0) + sem_data.get('output_tokens', 0),
}

code_files = set(json.loads(Path('graphify-out/.graphify_detect.json').read_text(encoding="utf-8")).get('files', {}).get('code', []))
filtered_nodes = [n for n in result['nodes'] if n.get('source_file') not in code_files or n.get('node_type') != 'File']
result['nodes'] = filtered_nodes

Path('graphify-out/.graphify_extracted.json').write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
print(f'Extracted: {len(result["nodes"])} nodes, {len(result["edges"])} edges ({len(result.get("hyperedges",[]))} hyperedges)')
