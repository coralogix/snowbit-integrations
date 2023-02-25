# Google Workspace integration to Coralogix via Terraform
This integration hold few steps in order to integrate Google Workspace audit logs to Coralogix.
1. Create a **Service Account** in an existing project (or provide a name for a new project if you wish terraform should create one) in GCP
2. Create a JSON format **Key** for the **Service Account**
3. Create an EC2 instance in AWS 
4. Copy the JSON Key (2) to the EC2 instance to authenticate to Google Workspace
5. installs Filebeat on the EC2 instance that uses the `google_workspace` module and sends its logs to the user's Coralogix Account
## Prerequisites
1. Make sure to have access to AWS to create EC2 instance and security group
2. Make sure to have access to GCP to create a new project (or use an existing project), service account and a key, and to enable API's required for the integration
3. For finalizing the integration, have Super Admin access to Google Workspace

## Deployment
1. Fill the required fields in the `values.auto.tf` file
2. For `coralogix_domain`, choose either **Europe**, **India** or **US**
3. Optional values are:
   1. For AWS: 
      1. `security_group_id` - When not provided, Terraform will create a new security group
      2. `SSHIpAddress` - the IP that will be able to SSH into the instance in the newly created security group. when no IP is provided, Terraform will put the user's external IP address
      3. `additional_tags` - additional tags to add to the 2 AWS resources in this document
   2. For GCP:
      1. `new_project_name` - if you wish to create a new project, add the desired name. (when a value is provided, the `existing_project_id` value is ignored)
      2. `new_project_organization` - for the new project
      3. `new_project_billing_account` - for the new project
#### Note: the `primary_google_workspace_admin_email_address` variable needs to be the primary admin account email address (and not a user with admin privilege). this user is visible in the Google Workspace console under `Account > Account Settings` 
### Finalizing - in Google Workspace
1. Navigate to `Security > Access and data control > API control`
2. In the `Domain wide delegation` dialog box, click on `MANAGE DOMAIN WIDE DELEGATION`
3. Add new
4. Paste the `Client ID` from the service account created by Terraform
5. Under `OAuth scoped`, copy and paste the following scopes
```text 
https://www.googleapis.com/auth/admin.directory.user,
https://www.googleapis.com/auth/admin.directory.customer.readonly,
https://www.googleapis.com/auth/admin.directory.rolemanagement.readonly,
https://www.googleapis.com/auth/userinfo.email,
https://www.googleapis.com/auth/migrate.deployment.interop,
https://www.googleapis.com/auth/admin.reports.audit.readonly
```