# auditLogPackage
xml creator based on audit log selection (beta)
Agentforce Audit Trail Package Generator

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)

Overview

This Salesforce solution allows administrators and developers to generate a package.xml manifest directly from the Setup Audit Trail. It solves the common pain point of identifying API names for recent metadata changes by using a "Smart Resolve" strategy:

Deterministic Resolution (Priority 1): Queries the Salesforce Tooling API to find exact matches based on the Audit Trail timestamp (CreatedDate) and the Metadata Name. It handles both "Created" and "Changed" events by checking CreatedDate and LastModifiedDate respectively.

Generative AI Fallback (Priority 2): Uses the Einstein Generative AI (aiplatform.ModelsAPI) with the GPT-4 Omni Mini model to infer API names for items that the Tooling API could not locate (e.g., complex configuration changes or unsupported metadata types).

Features

- Generates a package.xml manifest from Salesforce Setup Audit Trail.
- Smart Resolve strategy for API name inference.
- Integration with Einstein Generative AI for unresolved items.
- UI with Smart Resolve button and XML generation functionality.

Installation

1. Clone the repository:
   
   ```bash
   git clone https://github.com/username/auditLogPackage.git
   ```

2. Navigate into the project directory:
   
   ```bash
   cd auditLogPackage
   ```

3. Deploy the components to your Salesforce org.

Components

Apex Classes

- **AuditTrailController.cls**: The main entry point for the Lightning Web Component. Handles data fetching and orchestrates resolution logic.
- **AuditTrailService.cls**: Contains the business logic for parsing logs, inferring metadata types from display strings, and performing the "Smart Matching" algorithm against Tooling API results.
- **ToolingApiHelper.cls**: Handles HTTP callouts to the Salesforce Tooling API. Retrieves metadata (Custom Fields, Validation Rules, FlexiPages, etc.) within a specific time window.
- **AuditTrailAIHelper.cls**: Connects to the Einstein Models API to predict API names for unresolved items.
- **AuditTrailWrapper.cls**: A DTO (Data Transfer Object) class that shapes the data passed between Apex and LWC, including fields for actionType (Created/Updated) and resolution status.

Lightning Web Component

- **auditTrailGenerator**: A UI that displays audit logs in a datatable, which includes:
  - **Smart Resolve Button**: Triggers the two-step resolution process.
  - **Filter Switch**: Toggles between "All", "Created Only", and "Updated Only" views.
  - **XML Generation**: Compiles the resolved API names into a package.xml format for clipboard copying.

Configuration & Prerequisites

- **API Version**: This solution requires API v60.0+ to support the aiplatform namespace.
- **Einstein Generative AI**: Must be enabled in Setup. The user requires the Einstein GPT permission set.
- **Remote Site Settings (Optional)**: If URL.getOrgDomainUrl() callouts fail, add your org's domain to Remote Site Settings.
- **Session ID**: The ToolingApiHelper uses UserInfo.getSessionId(). In some Lightning contexts, this token may not have API access. If you encounter "Unauthorized" errors, configure a Named Credential (callout:MyOrgNC) and update the ToolingApiHelper code.

Current Limitations & Known Issues

1. **Tooling API Coverage**
   - **Limited Scope**: The ToolingApiHelper currently queries a fixed set of metadata types (CustomField, ValidationRule, Layout, FlexiPage, ApexClass, LightningComponentBundle). It does not yet cover every possible metadata type (e.g., Flows versions, Custom Permissions, Groups), meaning those will always fall back to AI or remain unresolved.
   - **Session Access**: As mentioned in prerequisites, accessing the Tooling API from Apex via UserInfo.getSessionId() is not always reliable in all security configurations (e.g., LWC exposed on Communities/Experience Cloud).

2. **Time Synchronization**
   - **Drift**: There is often a slight delay (seconds or minutes) between the actual metadata creation and the timestamp logged in Setup Audit Trail.
   - **Mitigation**: The code currently uses a hardcoded +/- 2 minute buffer (addMinutes(-2) / addMinutes(2)). If the drift exceeds this, the match will fail.

3. **AI Hallucinations**
   - **Accuracy**: While GPT-4 Omni Mini is powerful, it may occasionally "hallucinate" API names, especially for objects with non-standard naming conventions or package prefixes.
   - **Formatting**: The AI might return valid JSON that doesn't strictly match the expected Object.Field__c format if the prompt instructions are ambiguous for edge cases.

4. **Setup Audit Trail Limitations**
   - **Granularity**: The SetupAuditTrail object does not always expose the API name directly in the Display field. For complex changes (e.g., "Changed Page Layout"), the specific element changed on the layout is not always retrievable or deployable.

Future Improvements

- **Expanded Tooling Queries**: Add dynamic SOQL construction to query EntityDefinition or Tooling for a broader range of metadata types based on the detected Section.
- **Configurable Time Buffer**: Move the hardcoded 2-minute buffer to a Custom Metadata Type setting so admins can adjust sensitivity.
- **Named Credential Support**: Refactor ToolingApiHelper to strictly use Named Credentials for robust authentication.
- **Batch Processing**: Currently, resolveWithAI processes all selected rows in one request. For very large selections (50+ items), this might hit token limits or timeout. Implementing batching or chunking in the LWC would improve scalability.
- **Direct Deployment**: Integrate the Metadata API (MetadataService) to allow users to deploy the generated package directly to another org, rather than just copying the XML.

Contributing

We welcome contributions to the project! If you have suggestions, bug reports, or features you'd like to see added, please open an issue or submit a pull request.

