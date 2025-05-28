# dc-customer-support-agent

## 📖 Overview

Welcome to the **dc-customer-support-agent** project! This practical example accompanies an article about AI agents powered by LangGraph in InterSystems IRIS. 

The project demonstrates an AI-based customer support agent capable of analyzing incoming email requests, determining their priority, and categorizing them appropriately.

## 🛠️ How It Works

The **Customer Support AI Agent** is designed to automate the initial handling of customer support emails. Its workflow is as follows:

1. **Read Incoming Support Emails**: 
   - The agent accesses emails requiring assistance.
   
2. **Classify Priority**:
   - Emails are analyzed to determine their priority level: High, Medium, or Low.

3. **Identify Topic**:
   - The agent detects the topic or category of the request, such as password reset, VPN issues, printer problems, etc.

4. **Decision Making**:
   - The agent decides whether to auto-respond to the email or escalate it to human support for further attention.

5. **Auto-Responding**: 
   - If auto-responding is the chosen course of action, the agent retrieves past examples (RAG) and crafts a personalized reply.

## 📋 Prerequisites

Before you begin, ensure you have the following:

- Docker and Docker Compose installed on your system.
- An `.env` file set up with necessary environment variables. You can use the `env_sample` file available at the repository's root directory as a template.

## 🛠️ Installation

Follow these steps to set up the project:

1. Clone the repository:
   ```
   git clone https://github.com/henryhamon/dc-customer-support-agent
   ```

2. Navigate to the project directory:
   ```
   cd dc-customer-support-agent
   ```

3. Configure environment variables:
   - Copy the `env_sample` file to a new file named `.env` and fill in the required details.

4. Build the Docker container:
   ```
   docker-compose build --no-cache --progress=plain
   ```

## 💡 How to Use

To start and manage the **Customer Support AI Agent**, use Docker Compose:

1. **Start the Application**:
   - Run the following command to start the application in detached mode:
     ```
     docker-compose up -d
     ```

2. **Stop and Remove Containers**:
   - To stop the application and remove containers along with their images, use:
     ```
     docker-compose down --rmi all
     ```