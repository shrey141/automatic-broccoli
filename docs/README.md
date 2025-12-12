```mermaid
sequenceDiagram
    Dev->>GHA: Push to main
    GHA->>GHA: app-ci (test, lint, scan)
    GHA->>ECR: Build & push image
    GHA->>ECS: Deploy to Dev
    ECS->>ALB: Register target
    ALB->>ALB: Health check (/health)
    GHA->>GHA: Smoke test /health
    GHA->>GHA: Integration tests
    GHA->>GHA: Await approval
    Dev->>GHA: Approve Production
    GHA->>ECS: Deploy to Prod
    ECS->>CW: Emit metrics & logs
    CW->>CW: CloudWatch alarms
