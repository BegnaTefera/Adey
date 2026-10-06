import json
from pathlib import Path
from graphify.build import build
from graphify.cluster import cluster, score_all
from graphify.analyze import god_nodes, surprising_connections, suggest_questions
from graphify.report import generate

graph_data = json.loads(Path('graphify-out/graph.json').read_text(encoding="utf-8"))
ext_data = json.loads(Path('graphify-out/.graphify_extracted.json').read_text(encoding="utf-8"))
detect_data = json.loads(Path('graphify-out/.graphify_detect.json').read_text(encoding="utf-8"))

G = build([ext_data], directed=False)
communities = cluster(G)
cohesion_scores = score_all(G, communities)

labels = {cid: f"Community {cid}" for cid in communities}
gods = god_nodes(G, top_n=10)
surprises = surprising_connections(G, communities, top_n=10)
questions = suggest_questions(G, communities, labels)

token_cost = {
    'input_tokens': ext_data.get('input_tokens', 0),
    'output_tokens': ext_data.get('output_tokens', 0),
}

report_md = generate(
    G=G,
    communities=communities,
    cohesion_scores=cohesion_scores,
    community_labels=labels,
    god_node_list=gods,
    surprise_list=surprises,
    detection_result=detect_data,
    token_cost=token_cost,
    root='.',
    suggested_questions=questions
)

Path('graphify-out/GRAPH_REPORT.md').write_text(report_md, encoding='utf-8')
print("GRAPH_REPORT.md generated!")
