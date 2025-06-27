# Adoption Strategies

## Summary

There are two primary alerting methodologies: Notification and Automation. Notification leverages communication channels to inform users or groups about events or potential issues. In contrast, Automation alerts indicate that the system has completed a specific task on behalf of the user or group. This document outlines both methodologies and provides practical examples for implementation across enterprise environments.

## Notification

Notifications can range from basic to advanced, often incorporating automation for greater complexity.

### Basic Notification

A basic notification typically involves sending an email to an individual or group. In Keyfactor Command, this can be achieved through standard alert configurations. Alternatively, advanced workflows can deliver notifications via third-party applications, such as IT Service Management (ITSM) platforms or collaboration tools like Microsoft Teams.

Best practice recommends notifying groups rather than individuals—especially for issues or pending problems—to ensure visibility and accountability. An effective notification strategy should also include an escalation process to guarantee timely resolution if initial alerts go unacknowledged.

#### Escalating Alerts Methodology

An escalation methodology sends notifications at defined intervals to a group, requiring multiple alerts to be configured. ([Workflow Examples](/AdoptionStrategies/Workflows/))

##### Certificate Expiration Alerting and Escalation Strategy

When a certificate is set to expire within 90 days, it is critical to initiate timely communication with the responsible application team to prevent service interruptions.

1. **Initial Notification (90 Days Prior):**  
   An automated email is sent to the application team, notifying them of the upcoming certificate expiration and providing renewal instructions.

2. **Follow-Up Notification (60 Days Prior):**  
   If renewal is not completed within 30 days, a secondary alert reiterates the urgency and provides the same instructions.

3. **Escalated Notification (30 Days Prior):**  
   If the certificate remains unrenewed, a final alert is sent to both the application team and their management, emphasizing the criticality and potential business impact.

This progressive alerting model ensures accountability and visibility at appropriate organizational levels. To support this approach, an automated retirement mechanism should be implemented, allowing the application team to acknowledge task completion and suppress future alerts once the certificate has been renewed. (See [Retirement Methodology](#retirement-methodology) for details.)

#### Retirement Methodology

A Retirement Methodology defines the process for ceasing all notifications and automated actions related to a certificate once it has been renewed or decommissioned. In Keyfactor Command, this can be implemented by leveraging metadata to intelligently recognize certificates that no longer require monitoring. By tagging certificates as retired, the system can suppress further alerts and automate task closure, ensuring operational efficiency and preventing unnecessary communications.

Once implemented, metadata can be used to dynamically filter out retired certificates from ongoing alerts. For example, applying a condition such as `Retired -ne True` within the alert collection query ensures that retired certificates are excluded, streamlining workflows and reducing unnecessary notifications.

##### Retirement Methodology Implementation Steps

1. In Keyfactor Command, navigate to **Settings** and select **Certificate Metadata**.
2. Click **Add** to create new metadata for certificates.
3. Assign a meaningful name (e.g., Retired, Retired Certificate, Unmonitored).
4. Provide a brief description.
5. Under **Enrollment Options**, select **Hidden** to remove it from enrollment pages.
6. In **Hint**, add a warning such as "Stop all Automation and Notifications."
7. Choose **Boolean** as the data type.
8. Set the default value to **False** to ensure new certificates are not retired by default.
9. Save the metadata.
10. Update existing certificates with the appropriate value based on whether automation and notifications should be processed.

## Automating Alerts and Renewals

Automating alerts and certificate renewals can be accomplished using Keyfactor Command Alerts and Workflows. The following prerequisites must be met.  ([Workflow Examples](/AdoptionStrategies/Workflows/)).

- **Universal Orchestrator Deployment:**  
  Deploy a Universal Orchestrator with a Certificate Store Type capability matching the certificate store environment (e.g., IISU for IIS websites).

- **Certificate Store Registration:**  
  Add the relevant certificate store to Certificate Store Locations in Keyfactor Command and perform a full inventory scan.

- **Collection for Expiration Evaluation:**  
  Create a collection specifically for evaluating certificates nearing expiration. This collection should include only certificates with inventoried locations.

- **Alert Configuration with Workflow Integration:**  
  Define an alert that utilizes workflows based on a predefined threshold (e.g., days until expiration) to trigger automated actions.

- **Expiration Workflow:**  
  - Include a "Renew Expired Certificates" step to renew the certificate and schedule the Certificate Management job.
  - Add a "Send Email" step to notify the application team of the action.
  - Update metadata (if using the [Retirement Methodology](#retirement-methodology)) to stop further automation and notifications for the old certificate.

### Automating Alerts and Renewals Implementation Steps

Assuming the Orchestrator and certificate store inventory are complete:

#### Create the Collection

1. In Keyfactor Command, select the **Certificate Collections** tab.
2. Click **Advanced** to build your collection query.
3. From the **Field** dropdown, select `CertStoreFQDN`, choose **Is not null** from the comparison dropdown, and insert.
4. If using the [Retirement Methodology](#retirement-methodology), select `Retired` under Metadata, choose **Is not equal to**, select **True**, and insert.
5. Save the collection with a meaningful name.

#### Create the Alert

1. In Keyfactor Command, select the **Alerts** tab and choose **Expiration** from the dropdown list.
2. Select the "ADD" button to add a new alert.
3. Choose the collection the alert should evaluate for expiring certificates in the **Certificate Collection** field.
4. In the **Timeframe** field select the timeframe to evaluate the certificates in the collection.
5. In **Display Name**, give the Alert a meaningful name.
6. Make sure use workflows is selected.
7. Select Save. (this will take you into the workflow with the Alert display name as the name of the Workflow)

#### Create the Workflow

1. In the **Add Workflow Definition** give the workflow a meaningful description.
2. Select the "Plus" sign to add a workflow step.
3. Under "General" select the **Step Type** as **Renew Expired Certificate**
4. Give the step a **Display Name** ("Certificate Renewal")
5. Under the **Configuration Parameters** section, choose the template and Certificate Authority that you want to renew the certificate from. (if you want to use the existing CA you can use the expiring certificates information).
6. (Optional)  Next you can include other steps such as sending an email to a group and/or updating metadata such as "Retired".
7. Select SAVE WORKFLOW
8. Select Publish Workflow to have it active.

## References

- [Keyfactor Command Documentation](https://software.keyfactor.com)
- [Workflows Overview](https://software.keyfactor.com/Content/Workflow/Workflows.htm)

---

© Keyfactor. This document is provided as an example
