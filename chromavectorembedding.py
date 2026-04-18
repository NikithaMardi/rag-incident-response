import chromadb
from chromadb.utils import embedding_functions

embedding_func = embedding_functions.SentenceTransformerEmbeddingFunction(model_name = "all-MiniLM-L6-v2")

client = chromadb.PersistentClient(path="./chroma_db")

collections = client.get_or_create_collection(
    name="k8s_runbooks",
    embedding_function = embedding_func
)

collections.add(
    documents = [
        "OOMKilled means the pod exceeded its memory limit. Increase the memory limit in the pod spec or optimize the application memory usage. Check if memory limit is set too low for the workload.",
        "CrashLoopBackOff means the container keeps crashing on startup. Check application logs with kubectl logs. Common causes are missing environment variables, failed database connections, or application bugs.",
        "ImagePullBackOff means Kubernetes cannot pull the container image. Check image name and tag are correct. Verify registry credentials if using a private registry.",
        "Pending pod means it cannot be scheduled. Check if nodes have enough CPU and memory resources. Check for node selector or affinity rules that might prevent scheduling.",
        "Pod evicted means the node ran out of resources and evicted the pod. Check node resource usage. Consider setting resource requests and limits on all pods.",
        "CrashLoopBackOff means the container keeps crashing on startup. Check application logs with kubectl logs"
    ],
    ids=["runbook_001", "runbook_002", "runbook_003", "runbook_004", "runbook_005","runbook_006"],
    metadatas=[
        {"type": "OOMKilled", "severity": "high"},
        {"type": "CrashLoopBackOff", "severity": "high"},
        {"type": "ImagePullBackOff", "severity": "medium"},
        {"type": "Pending", "severity": "low"},
        {"type": "Evicted", "severity": "medium"},
        {"type": "Evicted", "severity": "medium"},
    ]
)

print(collections.count())

results = collections.query(
    query_texts=["image cannot be pulled from registry"],
    n_results=2  # return top 2 most similar
)
