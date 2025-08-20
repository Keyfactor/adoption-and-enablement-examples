# Importing Keyfactor Workflows

This guide explains how to import Keyfactor Workflows into your Keyfactor Command environment. Workflows automate certificate lifecycle processes such as enrollment, renewal, and revocation.

---

## Prerequisites

- Access to the Keyfactor Command Web UI with administrative privileges.
- Workflow definition files (typically in JSON format) exported from another environment or provided by Keyfactor.
- Appropriate permissions to manage workflows.
- Command v25.1 or higher

---

## Steps to Import a Workflow

### 1. Log in to Keyfactor Command

1. Open your browser and navigate to your Keyfactor Command instance.
2. Log in with an account that has administrative rights.

### 2. Navigate to Workflow Management

1. In the left navigation pane, go to **Platform Administration**.
2. Click on **Workflows**.

### 3. Import the Workflow

1. Click the **Import** button (usually at the top right of the Workflows page).
2. In the dialog, click **Browse** and select your workflow JSON file.
3. Review the workflow details in the preview.
4. Click **Import** to add the workflow to your environment.

### 4. Configure and Enable the Workflow

1. After import, locate your workflow in the list.
2. Click on the workflow name to review its configuration.
3. Make any necessary adjustments (e.g., assign collections, update notification settings).
4. Set the workflow status to **Enabled** if you want it to be active.

---

## Troubleshooting

- **Import Errors:** Ensure the workflow file is valid JSON and matches the schema expected by your Keyfactor version.
- **Permission Issues:** Verify your account has the required permissions to import and manage workflows.
- **Workflow Not Visible:** Refresh the page or check your filters.

---

## References

- [Keyfactor Command Documentation](https://software.keyfactor.com)
- [Workflows Overview](https://software.keyfactor.com/Content/Workflow/Workflows.htm)

---

© Keyfactor. This document is provided as an example
