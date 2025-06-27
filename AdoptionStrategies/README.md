# Adoption Stratagies
## Summary
There are two primary alerting methodologies: Notification and Automation. The Notification method utilizes a communication channel to inform a user or group of users about an event or a potential issue. In contrast, an Automation alert indicates that the system has completed a specific task on behalf of the user or user group. This document outlines both methodologies and provides practical examples of how they can be implemented across any enterprise environment.

## Notification
Notification can be pretty basic, but can include some automation that can make them more complex.
### Basic Notification
A basic Notification typically consists of a simple email sent to an individual user or a group. In Keyfactor Command, this can be achieved through a standard alert configuration. Alternatively, a more advanced workflow can be implemented to deliver notifications to users via third-party applications, such as an IT Service Management (ITSM) platform or collaboration tools like Microsoft Teams.

Regardless of the chosen delivery method, it's considered best practice to notify a group rather than a single user—particularly when addressing issues or pending problems—to ensure visibility and accountability. An effective notification strategy should also incorporate an escalation methodology to ensure timely resolution when initial alerts go unacknowledged.
#### Escalating Alerts Methodology
An escalated alert methodology incorperates a stratagy to send out a notification alert at specific intervals to a group.  this requires multible alerts to be create. ([Workflow Examples](/AdoptionStrategies/Workflows/))
##### Certificate Expiration Alerting and Escalation Strategy
When a certificate is set to expire within 90 days, it is critical to initiate timely communication with the responsible application team to prevent service interruptions or potential outages.
1. Initial Notification (90 Days Prior to Expiry):
An automated email alert is sent to the application team, notifying them of the upcoming certificate expiration and providing instructions for renewal.
2. Follow-Up Notification (60 Days Prior):
If the renewal action is not completed within 30 days, a secondary alert is triggered. This message reiterates the urgency of the task and includes the same instructions to ensure visibility and continuity.
3.  Escalated Notification (30 Days Prior):
Should the certificate remain unrenewed, a final alert is sent. This communication is escalated to include not only the application team but also their management, emphasizing the criticality of the issue and potential business impact.

This progressive alerting model ensures accountability and visibility at appropriate organizational levels. To support this approach, an automated retirement mechanism should be implemented—allowing the application team to acknowledge task completion and suppress future alerts once the certificate has been successfully renewed. (See [Retirement Methodology](#retirement-methodology) for details.)
#### Retirement Methodology
A Retirement Methodology defines the process for ceasing all notifications and automated actions related to a certificate once it has been renewed or decommissioned. In Keyfactor Command, this can be implemented by leveraging metadata—allowing for intelligent recognition that the certificate no longer requires monitoring. By tagging or flagging certificates as retired through metadata, the system can suppress further alerts and automate the closure of related tasks, ensuring operational efficiency and preventing unnecessary communications.

Once the retirement methodology is implemented, metadata can be used to dynamically filter out retired certificates from ongoing alerts. In practice, this can be achieved by applying a condition such as "Retired -ne True" within the alert collection query. This ensures that certificates marked as retired are excluded from the alert collection, streamlining notification workflows and reducing unnecessary communications

##### How to Impliment
1. From the Keyfactor Command Platform go to the Settings gear and select "Certificate Metadata."
2. Select the "ADD" button to add a new Metadata to certificates.
3. Give the Metadata a meaningful name such as (Retired, Retired Certificate, Unmonitored, Unmoritored Certificate)
4. give a brief description of the field in the "Description" field.
5. under "Enrollment Options" choose the radio button "Hidden" which will remove it from the enrollment pages.
6. under "Hint" it is recomened to put a warning such as "Stop all Automation and Notifications."
7. Selet Boolean in the "Data Type" dropdown.
8. Set the "Default Value" to "False" to ensure that all new certificates have a not retired status. 
9. Select Save.
10. Update all current certificates with True or False based on if you want automation and\or Notifications to be processed.
## Automating Alerts and Renewals

# Importing Keyfactor Workflows

This guide explains how to import Keyfactor Workflows into your Keyfactor Command environment. Workflows automate certificate lifecycle processes such as enrollment, renewal, and revocation.

---

## Prerequisites

- Access to the Keyfactor Command Web UI with administrative privileges.
- Workflow definition files (typically in JSON format) exported from another environment or provided by Keyfactor.
- The appropriate permissions to manage workflows.

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
3. Review the workflow details shown in the preview.
4. Click **Import** to add the workflow to your environment.

### 4. Configure and Enable the Workflow

1. After import, locate your workflow in the list.
2. Click on the workflow name to review its configuration.
3. Make any necessary adjustments (e.g., assign collections, update notification settings).
4. Set the workflow status to **Enabled** if you want it to be active.

---

## Troubleshooting

- **Import Errors**: Ensure the workflow file is valid JSON and matches the schema expected by your Keyfactor version.
- **Permission Issues**: Verify your account has the required permissions to import and manage workflows.
- **Workflow Not Visible**: Refresh the page or check your filters.

---

## References

- [Keyfactor Command Documentation](https://software.keyfactor.com)
- [Workflows Overview](https://software.keyfactor.com/Content/Workflow/Workflows.htm)

---

© Keyfactor. This document is provided as an example and