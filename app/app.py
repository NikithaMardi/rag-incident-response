from contextlib import asynccontextmanager
from fastapi import FastAPI
from pydantic import BaseModel
from langchain_groq import ChatGroq
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_chroma import Chroma
from dotenv import load_dotenv
import os

load_dotenv()

CHROMA_PATH = os.getenv("CHROMA_PATH", "./chroma_db")

embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")

vectorstore = Chroma(
    collection_name="k8s_runbooks",
    embedding_function=embeddings,
    persist_directory=CHROMA_PATH
)

llm = ChatGroq(model="llama-3.3-70b-versatile", temperature=0.1)

prompt = ChatPromptTemplate.from_messages([
    ("system", """You are a Kubernetes SRE expert.
Use the following runbook context to analyze the alert.
If context is not relevant say so clearly.
Runbook Context:
{context}"""),
    ("user", "Alert: {alert}")
])

parser = StrOutputParser()

def populate_runbooks():
    vectorstore.add_texts(
        texts=[
            "OOMKilled means the pod exceeded its memory limit. Increase the memory limit in the pod spec or optimize the application memory usage.",
            "CrashLoopBackOff means the container keeps crashing on startup. Check application logs with kubectl logs. Common causes are missing environment variables or application bugs.",
            "ImagePullBackOff means Kubernetes cannot pull the container image. Check image name and tag are correct. Verify registry credentials if using a private registry.",
            "Pending pod means it cannot be scheduled. Check if nodes have enough CPU and memory resources.",
            "Pod evicted means the node ran out of resources. Consider setting resource requests and limits on all pods.",
        ],
        metadatas=[
            {"type": "OOMKilled", "severity": "high"},
            {"type": "CrashLoopBackOff", "severity": "high"},
            {"type": "ImagePullBackOff", "severity": "medium"},
            {"type": "Pending", "severity": "low"},
            {"type": "Evicted", "severity": "medium"},
        ],
        ids=["runbook_001", "runbook_002", "runbook_003", "runbook_004", "runbook_005"]
    )
    print("Runbooks populated successfully")

@asynccontextmanager
async def lifespan(app: FastAPI):
    collection = vectorstore.get()
    if len(collection['ids']) == 0:
        print("ChromaDB is empty — populating runbooks")
        populate_runbooks()
    else:
        print(f"ChromaDB already has {len(collection['ids'])} documents — skipping ingestion")
    yield

app = FastAPI(lifespan=lifespan)

class AlertRequest(BaseModel):
    alert_text: str

class AlertResponse(BaseModel):
    alert: str
    remediation: str
    status: str

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.post("/analyze", response_model=AlertResponse)
def analyze_alert(request: AlertRequest):
    try:
        results = vectorstore.similarity_search_with_score(
            request.alert_text, k=2
        )
        DISTANCE_THRESHOLD = 0.8
        good_docs = [
            doc for doc, score in results
            if score < DISTANCE_THRESHOLD
        ]
        if not good_docs:
            return AlertResponse(
                alert=request.alert_text,
                remediation="No relevant runbook found for this alert. Please escalate to on-call engineer.",
                status="no_match"
            )
        context = "\n\n".join([doc.page_content for doc in good_docs])
        chain = prompt | llm | parser
        remediation = chain.invoke({
            "alert": request.alert_text,
            "context": context
        })
        return AlertResponse(
            alert=request.alert_text,
            remediation=remediation,
            status="success"
        )
    except Exception as e:
        return AlertResponse(
            alert=request.alert_text,
            remediation=f"Analysis failed: {str(e)}",
            status="error"
        )