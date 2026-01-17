# Shell & Docker Style Guide (GitLab Runner)

## Shell Scripting (Bash)
- Follow the **Google Shell Style Guide**.
- Use `#!/bin/bash` shebang.
- Enforce error checking with `set -e`.
- Use descriptive variable names for runner configuration (e.g., `CI_SERVER_URL`, `REGISTRATION_TOKEN`).

## Docker
- Optimize for build speed and small image size.
- Ensure all dependencies required for the executor are installed.
- Handle graceful shutdowns to prevent zombie jobs in GitLab.

## GitLab Runner Specifics
- Configure the `config.toml` structure correctly if generating it dynamically.
- Understand the difference between `shell` and `docker` executors in the context of this image.
- Ensure proper cleanup of the runner on container exit.
