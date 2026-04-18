from fastapi import FastAPI
from pydantic import BaseModel
from langchain_groq import ChatGroq
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_huggingface import HuggingFaceEmbeddings
from dotenv import load_dotenv
from langchain_chroma import Chroma

import os

load_dotenv()

app = FastAPI()

# Initialize embedding model and vectorstore at startup
# Not inside the endpoint — you do not want to reload on every request
embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")

vectorstore = Chroma(
    collection_name="k8s_runbooks",
    embedding_function=embeddings,
    persist_directory=os.getenv("CHROMA_PATH", "./chroma_db")
    # reads from env variable so you can change path without code change
)

retriever = vectorstore.as_retriever(search_kwargs={"k": 2})
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

# Request body schema
class AlertRequest(BaseModel):
    alert_text: str

# Response schema
class AlertResponse(BaseModel):
    alert: str
    remediation: str
    status: str

# Health check endpoint — ALB uses this to verify container is alive
@app.get("/health")
def health_check():
    return {"status": "healthy"}

# Main RAG endpoint
@app.post("/analyze", response_model=AlertResponse)
def analyze_alert(request: AlertRequest):
    try:
        # Use similarity search with score instead of retriever
        results = vectorstore.similarity_search_with_score(
            request.alert_text, k=2
        )

        DISTANCE_THRESHOLD = 0.5

        # Filter out weak matches
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