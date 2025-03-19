# Contributing to Akash Provider Ansible Playbooks

Thank you for your interest in contributing to the Akash Provider Ansible Playbooks! This document provides guidelines and instructions for contributing to the project.

## Project Structure

The repository is organized as follows:

```
.
├── roles/                    # Ansible roles for different components
│   ├── tailscale/           # Tailscale networking setup
│   ├── provider/            # Provider-specific configurations
│   ├── op/                  # 1Password integration
│   ├── gpu/                 # GPU driver and runtime setup
│   └── os/                  # sysctl, cron job configurations
├── host_vars/               # Host-specific variables
├── playbooks.yml           # Main playbook definitions
├── inventory.yml           # Inventory configuration
└── inventory_example.yml   # Example inventory structure
```

## Prerequisites

Before contributing, ensure you have:

- Ansible installed (version 2.9 or higher)
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