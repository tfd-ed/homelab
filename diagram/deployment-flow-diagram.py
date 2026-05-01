#!/usr/bin/env python3
"""
Final CI/CD Deployment Flow Diagram (Numbered)
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.ci import GithubActions
from diagrams.onprem.container import Docker
from diagrams.k8s.compute import Deployment, Pod
from diagrams.k8s.network import Service
from diagrams.onprem.client import User
from diagrams.custom import Custom
from diagrams.onprem.vcs import Github

graph_attr = {
    "fontsize": "14",
    "bgcolor": "white",
    "pad": "0.8",
    "nodesep": "1.2",
    "ranksep": "1.5",
    "splines": "spline",
}

node_attr = {
    "fontsize": "11",
}

edge_attr = {
    "fontsize": "10",
    "fontcolor": "black",
}

with Diagram(
    "Homelab CI/CD Deployment Flow",
    filename="deployment-flow",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
    node_attr=node_attr,
    edge_attr=edge_attr,
):

    # Developer
    developer = User("Developer")

    # GitHub
    with Cluster("GitHub"):
        repo = Github("Repository")

    # CI/CD VM
    with Cluster("CI/CD VM (192.168.100.240)"):
        runner = GithubActions("Runner")
        docker_build = Docker("Build")
        registry = Docker("Registry\n:5000")

    # Kubernetes
    with Cluster("Kubernetes Cluster"):
        api = Custom("API Server", "./assets/k8s.png")
        deployment = Deployment("Deployment")

        with Cluster("Pods"):
            pod1 = Pod("Pod")
            pod2 = Pod("Pod")

        service = Service("Service")

        api >> Edge(color="red", label="6 apply") >> deployment
        deployment >> Edge(color="brown", label="8 rollout") >> pod1
        deployment >> pod2

        pod1 >> Edge(color="gray", style="dotted") >> service
        pod2 >> service

    # Main numbered flow
    developer >> Edge(color="blue", label="1 push") >> repo
    repo >> Edge(color="orange", label="2 trigger") >> runner
    runner >> Edge(color="green", label="3 build") >> docker_build
    docker_build >> Edge(color="purple", label="4 push") >> registry
    runner >> Edge(color="red", label="5 deploy") >> api

    # Image pull (important step)
    registry >> Edge(color="purple", style="dashed", label="7 pull") >> pod1
    registry >> pod2

print("✓ Deployment flow diagram generated: deployment-flow.png")