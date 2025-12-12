```mermaid
sequenceDiagram
    PR->>GHA: Open/Update PR (terraform changes)
    GHA->>GHA: validate (fmt/init/validate per env)
    GHA->>Checkov: Run Checkov scan
    Checkov-->>GHA: Upload report + comment
    GHA->>TF: terraform plan per env, upload artifacts
    TF-->>GHA: Plan outputs (artifacts)
    GHA->>Summary: Aggregate results, post summary/comment