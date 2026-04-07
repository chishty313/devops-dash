# **DevOps Engineer Practical Task**

## **Objective**

Design and deploy a small production style system demonstrating **containerization, CI/CD automation, traffic management, and basic observability**.

The system should expose **one GET API and one POST API** and demonstrate how the system could handle **\~100 requests/sec** while supporting **zero-downtime deployment**.

# **Core Task (Required)**

## **1\. Build a Simple API**

Create a small service with:

* **GET endpoint** (example: /status)  
* **POST endpoint** (example: /data)

The service can be written in any language (Node.js / Python / Go / etc.).

Explain briefly in the README how the system can handle **\~100 requests/sec** (scaling strategy or configuration).

## **2\. Containerize the Application**

Package the application into a container.

Example tool: **Docker**

Requirements:

* Production-ready **Dockerfile**  
* Environment variable configuration  
* Application should run via container

## **3\. Reverse Proxy Setup**

Deploy the application behind a reverse proxy.

Example tool: **Nginx**

Responsibilities:

* Route traffic to the application container  
* Basic load-balancing configuration

## **4\. CI/CD Pipeline**

Create an automated pipeline that:

1. Builds the application  
2. Runs basic tests  
3. Builds the container image  
4. Deploys the updated application

Example tools:

* GitHub Actions  
* GitLab CI/CD  
* Jenkins

Explain how deployment happens **without interrupting users**.

## **5\. Basic Monitoring & Logs**

Add a basic way to observe the system.

Examples:

* Application logs  
* Request logs  
* Basic service health monitoring

Possible tools:

* Prometheus  
* Grafana  
* Container logs

### **Cloud Deployment**

Deploy the system on a cloud provider.

Example:

* Amazon Web Services  
* Google Cloud Platform  
* DigitalOcean

# **Bonus (Optional)**

### **Container Orchestration**

Deploy using a container orchestrator.

Example: Kubernetes

Possible features:

* Deployment manifests  
* Rolling updates  
* Horizontal scaling

## **Infrastructure as Code**

Provision infrastructure using IaC tools.

Examples:

* OpenTofu  
* Terraform

Example use cases:

* Provision cloud instances  
* Configure networking  
* Automate infrastructure deployment

### **Secrets & Security Management**

Demonstrate secure handling of secrets.

Example tools:

* HashiCorp Vault  
* AWS Secrets Manager

Security practices may include:

* No hardcoded credentials  
* Secure environment variables  
* Non-root containers 

# **Submission Instructions**

Submit a **Git repository** containing:

* Application source code  
* Dockerfile  
* Proxy configuration  
* CI/CD configuration  
* Deployment setup

### **README should explain:**

* System architecture  
* Containerization approach  
* Deployment process  
* How zero-downtime deployment works  
* Logging / monitoring setup  
* How the system can handle \~100 requests/sec

### **Deadline:** ASAP.