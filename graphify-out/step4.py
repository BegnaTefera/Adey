import json
from pathlib import Path
from graphify.build import build
from graphify.cluster import cluster
from graphify.export import to_json

ext_data = json.loads(Path('graphify-out/.graphify_extracted.json').read_text(encoding="utf-8"))
G = build([ext_data], directed=False)
communities = cluster(G)
to_json(G, communities, 'graphify-out/graph.json')

graph_data = json.loads(Path('graphify-out/graph.json').read_text(encoding="utf-8"))
edges_count = len(graph_data.get("links", graph_data.get("edges", [])))
print(f'Graph: {len(graph_data["nodes"])} nodes, {edges_count} edges, {len(communities)} communities')
