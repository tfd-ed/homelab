#!/usr/bin/env python3
"""
Homelab Architecture Diagram Generator
Generates infrastructure diagram with real technology logos
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.compute import Server
from diagrams.onprem.network import Traefik, Nginx
from diagrams.onprem.monitoring import Prometheus, Grafana
from diagrams.onprem.database import PostgreSQL, MySQL, MongoDB
from diagrams.onprem.workflow import Airflow
from diagrams.onprem.ci import GitlabCI, GithubActions
from diagrams.k8s.controlplane import APIServer, ControllerManager, Scheduler
from diagrams.k8s.compute import Pod
from diagrams.generic.network import Firewall, Router
from diagrams.generic.os import Ubuntu
from diagrams.saas.cdn import Cloudflare
from diagrams.programming.flowchart import MultipleDocuments
from diagrams.custom import Custom

# Configure diagram
graph_attr = {
    "fontsize": "12",
    "bgcolor": "transparent",
    "pad": "0.8",
    "nodesep": "1.0",
    "ranksep": "1.5",
    "splines": "ortho",
}

with Diagram(
    "Homelab Architecture - SSH & Service Access",
    filename="homelab-architecture-logos",
    show=False,
    direction="TB",
    graph_attr=graph_attr,
    outformat="png"
):
    
    # Remote User
    user = Ubuntu("Remote User")
    
    # Cloudflare Layer
    with Cluster("Cloudflare"):
        cf_ssh = Custom("SSH Tunnel", "./assets/cloudflare.png")
        cf_web = Custom("Web Tunnel", "./assets/cloudflare.png")
    
    # Homelab Network
    with Cluster("Homelab Network"):
        
        # Hypervisor Host
        with Cluster("Proxmox/ESXi Host"):
            hypervisor = Custom("Hypervisor\nJump Host", "./assets/proxmox.png")
        
        # Gateway VM
        with Cluster("Gateway VM"):
            gateway = Custom("app-gateway\n2C | 2GB\nReverse Proxy", "./assets/nginx.png")
        
        # Kubernetes Cluster
        with Cluster("Kubernetes Cluster"):
            k8s_master = Custom("k8s-master\n2C | 4GB\nControl Plane", "./assets/k8s.png")
            k8s_worker1 = Custom("k8s-worker-1\n6C | 10GB\nWorkloads", "./assets/k8s.png")
            k8s_worker2 = Custom("k8s-worker-2\n6C | 10GB\nWorkloads", "./assets/k8s.png")
        
        # Database VM
        with Cluster("Database Server"):
            database = Custom("database-vm\n4C | 6GB\nPostgreSQL, MySQL, MongoDB", "./assets/dbs.png")
        
        # Service VMs
        with Cluster("Service VMs"):
            monitoring = Custom("monitoring\n2C | 6GB\nPrometheus + Grafana", "./assets/prometheus-grafana.png")
            
            n8n = Custom("n8n\n2C | 4GB\nAutomation", "./assets/n9n.png")
            cicd = GithubActions("ci-cd\n4C | 8GB\nCI/CD")
            aivm = Server("ai-vm\n4C | 6GB\nOllama + TinyLlama")
    
    # SSH Access Flow (Blue - dotted)
    user >> Edge(label="SSH", color="blue", style="solid") >> cf_ssh
    cf_ssh >> Edge(label="Tunnel", color="blue", style="solid") >> hypervisor
    
    hypervisor >> Edge(label="ProxyJump", color="blue", style="dotted") >> k8s_master
    hypervisor >> Edge(label="ProxyJump", color="blue", style="dotted") >> k8s_worker1
    hypervisor >> Edge(label="ProxyJump", color="blue", style="dotted") >> k8s_worker2
    hypervisor >> Edge(label="ProxyJump", color="blue", style="dotted") >> database
    hypervisor >> Edge(label="ProxyJump", color="blue", style="dotted") >> gateway
    hypervisor >> Edge(label="ProxyJump", color="blue", style="dotted") >> monitoring
    hypervisor >> Edge(label="ProxyJump", color="blue", style="dotted") >> n8n
    hypervisor >> Edge(label="ProxyJump", color="blue", style="dotted") >> cicd
    hypervisor >> Edge(label="ProxyJump", color="blue", style="dotted") >> aivm
    
    # Web Service Access Flow (Purple - solid)
    user >> Edge(label="HTTPS", color="purple", style="solid") >> cf_web
    cf_web >> Edge(label="Tunnel", color="purple", style="solid") >> gateway
    
    gateway >> Edge(label="Proxy", color="purple", style="dashed") >> monitoring
    gateway >> Edge(label="Proxy", color="purple", style="dashed") >> n8n
    gateway >> Edge(label="Proxy", color="purple", style="dashed") >> k8s_worker1
    gateway >> Edge(label="Proxy", color="purple", style="dashed") >> k8s_worker2
    
    # Database Connections (Green - dashed)
    k8s_worker1 >> Edge(label="DB", color="green", style="dashed") >> database
    k8s_worker2 >> Edge(label="DB", color="green", style="dashed") >> database
    n8n >> Edge(label="DB", color="green", style="dashed") >> database
    monitoring >> Edge(label="DB", color="green", style="dashed") >> database
    n8n >> Edge(label="LLM API", color="orange", style="dashed") >> aivm

print("✅ Diagram generated: homelab-architecture-logos.png")
