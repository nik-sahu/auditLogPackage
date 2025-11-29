public with sharing class AuditTrailController {

    // ------------------------------------------------------------------------
    // METHOD 1: STANDARD FETCH (Used on Load)
    // ------------------------------------------------------------------------
    
    /**
     * @description Fetches the recent changes from Setup Audit Trail.
     * Uses the Service layer for standard Regex parsing.
     * @return List<AuditTrailWrapper>
     */
    @AuraEnabled(cacheable=true)
    public static List<AuditTrailWrapper> getRecentChanges() {
        try {
            // Fetch logs (Limit 1000 is standard safe limit for this object)
            List<SetupAuditTrail> logs = [
                SELECT Id, Action, Section, Display, CreatedBy.Name, CreatedDate 
                FROM SetupAuditTrail 
                ORDER BY CreatedDate DESC 
                LIMIT 30
            ];
            
            // Delegate to Service Layer for initial processing
            return AuditTrailService.processLogs(logs);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error fetching logs: ' + e.getMessage());
            throw new AuraHandledException('Error loading logs: ' + e.getMessage());
        }
    }

    // ------------------------------------------------------------------------
    // METHOD 2: TOOLING API RESOLUTION (Deterministic - Priority 1)
    // ------------------------------------------------------------------------

    /**
     * @description Resolve API names using Tooling API (Deterministic/Time-based)
     * @param logs List of AuditTrailWrapper objects (passed from LWC)
     * @return List<AuditTrailWrapper> Updated list with resolved names
     */
    @AuraEnabled
    public static List<AuditTrailWrapper> resolveWithTooling(List<AuditTrailWrapper> logs) {
        try {
            // Delegate to Service Layer which handles the smart matching logic
            return AuditTrailService.matchMetadataToLogs(logs);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Tooling Resolution Failed: ' + e.getMessage());
            throw new AuraHandledException('Tooling API Error: ' + e.getMessage());
        }
    }

    // ------------------------------------------------------------------------
    // METHOD 3: AI RESOLUTION (Generative Fallback - Priority 2)
    // ------------------------------------------------------------------------

    /**
     * @description Calls the AI Helper to resolve API names using the Models API.
     * Used for items that the Tooling API could not identify.
     * @param displayStrings List of "Display" text from the UI
     * @return Map<String, String> Map of [Original Text] -> [AI Predicted API Name]
     */
    @AuraEnabled
    public static Map<String, String> resolveWithAI(List<String> displayStrings) {
        try {
            // Input validation
            if (displayStrings == null || displayStrings.isEmpty()) {
                return new Map<String, String>();
            }

            // Delegate to the AI Helper which uses aiplatform.ModelsAPI
            return AuditTrailAIHelper.predictApiNames(displayStrings);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AI Controller Error: ' + e.getMessage());
            
            String msg = e.getMessage();
            if (msg.contains('Unauthorized') || msg.contains('Permission')) {
                throw new AuraHandledException('Permission Error: Ensure "Einstein GPT" permission set is assigned.');
            }
            throw new AuraHandledException('AI Processing Failed: ' + msg);
        }
    }
}