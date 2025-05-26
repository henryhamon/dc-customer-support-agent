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

}
