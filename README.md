# vault-v2
Multi-strategy vault base classes, meant to be ingested as a submodule in other repositories

Whenever spinning up a new strategy repo, vault code is often required. Instead of repeating this code in each repository, it would be much simpler to have a single repository/source of truth which is then used a submodule wherever required.

- Work in a feature branch on your local machine and make PRs to master.
- DO NOT IGNORE formatting errors!
- Once your PR is merged, navigate to the project that's consuming this repository, and update the submodule dependencies (following the workflow required for that specific project).
