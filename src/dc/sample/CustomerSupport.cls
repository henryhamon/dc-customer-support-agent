Class dc.sample.CustomerSupport Extends %RegisteredObject
{

Parameter CollectionName = "CustomerSupport";

///  Ingest
ClassMethod Ingest() As %String [ Language = python ]
{
    import os
    import json
    import iris
    import pandas as pd
    from dotenv import load_dotenv
    from langchain_iris import IRISVector
    from langchain.docstore.document import Document
    from langchain_community.document_loaders import DataFrameLoader
    from langchain_text_splitters import RecursiveCharacterTextSplitter

    from langchain_openai import OpenAIEmbeddings
    load_dotenv()

    try:
        filePath = "/home/irisowner/dev/assets/customer_tickets.csv"
        df = pd.read_csv(filePath, on_bad_lines='warn')
        loader = DataFrameLoader(df, page_content_column="body")
        documents = loader.load()
        text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
        splits = text_splitter.split_documents(documents)

        vectorstore = IRISVector.from_documents(
            documents=splits,
            embedding=OpenAIEmbeddings(openai_api_key=os.getenv("API_KEY")),
            dimension=1536,
            collection_name=iris.cls(__name__)._GetParameter("CollectionName"),
        )

        return json.dumps({"status": True, "vector_size": len(vectorstore.get()['ids'])})
    except Exception as err:
        return json.dumps({"error": str(err)})
}

ClassMethod Retrieve(pEmailBody As %String) As %String [ Language = python ]
{
    import os
    import iris
    import json
    from dotenv import load_dotenv

    from langchain_openai import OpenAIEmbeddings
    from openai import OpenAI

    from langchain_iris import IRISVector

    load_dotenv()
    top_k = 10

    try:
        example_db = IRISVector (
            embedding_function = OpenAIEmbeddings(openai_api_key=os.getenv("API_KEY")),
            dimension =1536,
            collection_name=iris.cls(__name__)._GetParameter("CollectionName"),
        )
        docs_with_score = example_db.similarity_search_with_score(pEmailBody, k=top_k)
        return json.dumps([{"body": doc.page_content, "answer": doc.metadata["answer"], "score": score} for doc, score in docs_with_score], ensure_ascii=False)

    except Exception as err:
        return json.dumps({"error": str(err)}, ensure_ascii=False)
}

ClassMethod Agents(pInput As %String) [ Language = python ]
{
    import os
    from dotenv import load_dotenv
    load_dotenv()

    import iris
    from typing import TypedDict, Literal
    from langchain_core.tools import tool
    from langchain_openai import ChatOpenAI
    from langgraph.graph import StateGraph, START, END
    from langchain_core.prompts import ChatPromptTemplate

    # Define the state structure
    class TicketState(TypedDict):
        email_body: str
        priority: str
        topic: str
        rag_examples: str
        suggested_reply: str
        decision: str
        final_action: str


    @tool
    def classify_priority(email_body: str) -> str:
        """Classify the priority of an IT support ticket based on email content."""
        prompt = ChatPromptTemplate.from_template(
            """Analyze this IT support email and classify its priority as High, Medium, or Low.
            
            High: System outages, security breaches, critical business functions down
            Medium: Non-critical issues affecting productivity, software problems
            Low: General questions, requests, minor issues
            
            Email: {email}
            
            Respond with only: High, Medium, or Low"""
        )
        chain = prompt | llm
        response = chain.invoke({"email": email_body})
        return response.content.strip()

    @tool
    def identify_topic(email_body: str) -> str:
        """Identify the main topic/category of the IT support request."""
        prompt = ChatPromptTemplate.from_template(
            """Analyze this IT support email and identify the main topic category.
            
            Categories: password_reset, vpn, software_request, hardware, email, network, printer, other
            
            Email: {email}
            
            Respond with only the category name (lowercase with underscores)."""
        )
        chain = prompt | llm
        response = chain.invoke({"email": email_body})
        return response.content.strip()

    @tool
    def retrieve_examples(email_body: str) -> str:
        """Retrieve relevant examples from past responses based on email_body."""
        try:
            examples = iris.cls(__name__).Retrieve(email_body)
            return examples if examples else "No relevant examples found."
        except:
            return "No relevant examples found."


    @tool
    def generate_reply(email_body: str, topic: str, examples: str) -> str:
        """Generate a suggested reply based on the email, topic, and RAG examples."""
        prompt = ChatPromptTemplate.from_template(
            """Generate a professional IT support response based on:
            
            Original Email: {email}
            Topic Category: {topic}
            Example Response: {examples}
            
            Create a helpful, professional response that addresses the user's concern.
            Keep it concise and actionable."""
        )
        chain = prompt | llm
        response = chain.invoke({
            "email": email_body,
            "topic": topic,
            "examples": examples
        })
        return response.content.strip()

    @tool
    def make_escalation_decision(email_body: str, priority: str, topic: str) -> str:
        """Decide whether to auto-respond or escalate to IT team."""
        prompt = ChatPromptTemplate.from_template(
            """Based on this IT support ticket, decide whether to:
            - "auto_respond": Send automated response for simple/common or medium priority issues
            - "escalate": Escalate to IT team for complex/urgent issues
            
            Email: {email}
            Priority: {priority}
            Topic: {topic}
            
            Consider: High priority items usually need escalation, complex technical issues need human review.
            
            Respond with only: auto_respond or escalate"""
        )
        chain = prompt | llm
        response = chain.invoke({
            "email": email_body,
            "priority": priority,
            "topic": topic
        })
        return response.content.strip()

    # Define graph nodes
    def classify_priority_node(state: TicketState) -> TicketState:
        """Node to classify ticket priority."""
        priority = classify_priority.invoke({"email_body": state["email_body"]})
        return {"priority": priority}

    def identify_topic_node(state: TicketState) -> TicketState:
        """Node to identify ticket topic."""
        topic = identify_topic.invoke({"email_body": state["email_body"]})
        return {"topic": topic}

    def rag_node(state: TicketState) -> TicketState:
        """Node to retrieve relevant examples using RAG."""
        examples = retrieve_examples.invoke({"email_body": state["email_body"]})
        return {"rag_examples": examples}

    def generate_reply_node(state: TicketState) -> TicketState:
        """Node to generate suggested reply."""
        reply = generate_reply.invoke({
            "email_body": state["email_body"],
            "topic": state["topic"],
            "examples": state["rag_examples"]
        })
        return {"suggested_reply": reply}

    def decision_node(state: TicketState) -> TicketState:
        """Node to decide on escalation or auto-response."""
        decision = make_escalation_decision.invoke({
            "email_body": state["email_body"],
            "priority": state["priority"],
            "topic": state["topic"]
        })
        return {"decision": decision}

    def execute_action_node(state: TicketState) -> TicketState:
        """Node to execute final action based on decision."""
        if state["decision"] == "escalate":
            action = f"🚨 ESCALATED TO IT TEAM\nPriority: {state['priority']}\nTopic: {state['topic']}\nTicket created in system."
            print(f"[SYSTEM] Escalating ticket to IT team - Priority: {state['priority']}, Topic: {state['topic']}")
        else:
            action = f"✅ AUTO-RESPONSE SENT\nReply: {state['suggested_reply']}\nTicket logged for tracking."
            print(f"[SYSTEM] Auto-response sent to user - Topic: {state['topic']}")
        
        return {"final_action": action}

        
    email_body = pInput
        
    # Initialize state
    initial_state = TicketState(
        email_body=email_body,
        priority="",
        topic="",
        decision="",
        rag_examples="",
        suggested_reply="",
        final_action=""
    )

    # Initialize OpenAI LLM
    llm = ChatOpenAI(api_key=os.getenv("API_KEY"), temperature=0)
    """Initialize the workflow graph."""

    workflow = StateGraph(TicketState)
    
    # Add nodes
    workflow.add_node("classify_priority", classify_priority_node)
    workflow.add_node("identify_topic", identify_topic_node)

    workflow.add_node("make_decision", decision_node)
    workflow.add_node("rag", rag_node)
    workflow.add_node("generate_reply", generate_reply_node)
    workflow.add_node("execute_action", execute_action_node)
    
    # Set entry point - parallel processing of priority and topic
    workflow.add_edge(START, "classify_priority")
    workflow.add_edge(START, "identify_topic")
    
    # Both priority and topic must complete before making decision
    workflow.add_edge("identify_topic", "make_decision")
    workflow.add_edge("classify_priority", "make_decision")
    
    # Conditional routing based on decision
    workflow.add_conditional_edges(
        "make_decision",
        lambda x: x.get("decision"),
        {
            "auto_respond": "rag",
            "escalate": "execute_action"
        }
    )

    # For auto_respond path: RAG → generate_reply → execute_action
    workflow.add_edge("rag", "generate_reply")
    workflow.add_edge("generate_reply", "execute_action")
    
    # End after action execution
    workflow.add_edge("execute_action", END)
    
    graph = workflow.compile()
        
    #graph.get_graph().draw_mermaid_png(output_file_path="/home/irisowner/dev/assets/graph.png")
        
    """
    Process an IT support email and execute the complete workflow.
    
    Args:
        email_body (str): The body content of the support email
    """
    print("🎫 IT Support Ticket Processing Started")
    print("=" * 50)
    
    
    # Run the workflow
    final_state = graph.invoke(initial_state)
    
    # Print results
    print(f"📧 Original Email: {final_state['email_body'][:100]}...")
    print(f"🔥 Priority: {final_state['priority']}")
    print(f"📂 Topic: {final_state['topic']}")
    print(f"🤖 Decision: {final_state['decision']}")
    print(f"📝 Suggested Reply: {final_state['suggested_reply'][:100]}...")
    print(f"⚡ Final Action: {final_state['final_action']}")
    print("=" * 50)
    print("✅ Ticket Processing Complete")
}

ClassMethod Escalate()
{
    Write ..Agents("Our medical data security system is facing vulnerabilities, possibly due to outdated software without proper encryption. Despite attempts to secure the system by updating applications and implementing firewall rules, the issues continue. Urgent assistance is needed to resolve this issue as soon as possible.")
}

ClassMethod AutoRespond()
{
    Write ..Agents("Hello, I'm requesting Adobe Photoshop to be installed on my workstation. Please let me know the process.")
}

}
