Class dc.sample.CustomerSupport Extends %RegisteredObject
{

///  Ingest
ClassMethod Ingest() As %String [ Language = python ]
{
    import os
    import json
    from dotenv import load_dotenv
    from langchain_iris import IRISVector
    from langchain_community.document_loaders.csv_loader import CSVLoader
    from langchain_text_splitters import RecursiveCharacterTextSplitter

    from langchain_openai import OpenAIEmbeddings

    load_dotenv()

    filePath = "/home/irisowner/dev/assets/customer_tickets.csv"

    try:
        loader = CSVLoader(file_path=filePath)
        docs = loader.load()

        text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
        splits = text_splitter.split_documents(docs)

        vectorstore = IRISVector.from_documents(
            documents=splits,
            embedding=OpenAIEmbeddings(openai_api_key=os.getenv("API_KEY")),
            dimension=1536,
            collection_name="customerSupport",
        )

        # retriever = vectorstore.as_retriever()

        return json.dumps({"status": True})
    except Exception as err:
        return json.dumps({"error": str(err)})
}

ClassMethod Setup()
{
}

}
