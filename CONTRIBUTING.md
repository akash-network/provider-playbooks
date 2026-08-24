# Contributing to Akash Provider Ansible Playbooks

Before submitting changes, run:

```bash
bash -n scripts/setup_provider.sh scripts/lib/*.sh tests/*.sh
shellcheck -x scripts/setup_provider.sh scripts/lib/*.sh tests/*.sh
bash tests/test_installer.sh
.venv/bin/yamllint .
.venv/bin/ansible-playbook --syntax-check -i tests/inventory.ini playbooks.yml
.venv/bin/ansible-playbook -i tests/inventory.ini tests/render_provider.yml
```

Keep dependency pins in `versions.yml`, and update tests and documentation in
the same change. Never commit `.generated/`, `.venv/`, `.cache/`, wallet keys,
DNS credentials, or Tailscale auth keys.

Thank you for your interest in contributing to the Akash Provider Ansible Playbooks! This document provides guidelines and instructions for contributing to the project.

## Project Structure

The repository is organized as follows:

```
.
├── roles/                    # Component roles
│   ├── gpu/                  # NVIDIA GPU Operator
│   ├── k3s/                  # K3s and Calico
│   ├── provider/             # Akash provider stack
│   ├── rook-ceph/            # Persistent storage
│   └── tailscale/            # Optional private networking
├── scripts/                  # Interactive installer and helpers
├── tests/                    # Installer and template validation
├── playbooks.yml             # Main tagged plays
├── inventory_example.yml     # Non-secret inventory example
└── versions.yml              # Central compatibility pins
```

## Prerequisites

Before contributing, ensure you have:

- Python 3.12 and the dependencies from `requirements-dev.txt`
- Basic understanding of Ansible playbooks and roles
- Git installed and configured
- Access to a test environment for validating changes

## Development Workflow

1. **Fork the Repository**
   - Create a fork of the repository on GitHub
   - Clone your fork locally

2. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**
   - Follow the coding standards below
   - Test your changes thoroughly
   - Update documentation as needed

4. **Submit a Pull Request**
   - Push your changes to your fork
   - Create a pull request against the main branch
   - Provide a clear description of your changes

## Coding Standards

### Ansible Playbooks

- Use YAML syntax for all playbooks and roles
- Follow Ansible best practices and style guide
- Include proper documentation and comments
- Use meaningful variable names
- Implement idempotency in all tasks

### Role Structure

Each role should follow this structure:
```
role_name/
├── defaults/        # Default variables
├── handlers/        # Handlers
├── tasks/          # Main tasks
├── templates/      # Templates
└── vars/           # Role-specific variables
```

### Variables

- Use descriptive variable names
- Document all variables in the role's README
- Follow the naming convention: `role_name_variable_name`
- Use host_vars for host-specific configurations

### Testing

Before submitting changes:
1. Test your changes in a controlled environment
2. Verify idempotency (running the playbook multiple times)
3. Check for any syntax errors using `ansible-playbook --syntax-check`
4. Validate against the example inventory structure

## Documentation

- Update README.md for significant changes
- Document new variables and their purposes
- Include examples for new features
- Update inventory_example.yml if adding new host variables

## Commit Messages

Follow these commit message guidelines:
- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

## Review Process

1. All pull requests require at least one review
2. Address review comments promptly
3. Keep pull requests focused and manageable
4. Update your pull request based on feedback

## Getting Help

- Open an issue for bugs or feature requests
- Join the Akash Network community channels for discussions
- Check existing issues and pull requests for similar problems

## License

By contributing, you agree that your contributions will be licensed under the same terms as the project's license.

Thank you for contributing to the Akash Provider Ansible Playbooks!
