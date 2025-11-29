public class AgentSetupResolver {
/*
    // Wrapper for your final desired output
    public class PackageXmlResult {
        public String names;   // ""
        public String members; // ""
    }

    /**
     * Invokes the Agent using the standard 'generateAiAgentResponse' action.
     * Includes a retry loop to force JSON correction.
     */
/*    public static PackageXmlResult resolveMetadataFromText(String auditLogText) {
        String agentApiName = 'Agent_for_Setup'; // <--- UPDATE THIS
        String sessionId = null; // Maintains conversation context
        
        // 1. Construct the Initial Prompt
        String currentPrompt = 
            'Analyze this setup action: "' + auditLogText + '". ' +
            'Identify the Metadata Type and the full API Name (Object.Field). ' +
            'Output valid JSON only. ' +
            'Format: { "names": "MetadataType", "members": "API_Name" }.';

        PackageXmlResult finalResult = null;
        Integer maxRetries = 3;
        Integer attempt = 0;

        while (attempt < maxRetries && finalResult == null) {
            try {
                attempt++;
                System.debug('--- Attempt ' + attempt + ' ---');

                // 2. Invoke the Agent via Invocable.Action
                // This replaces the ConnectApi call
                Invocable.Action action = Invocable.Action.createCustomAction('generateAiAgentResponse', agentApiName);
                
                action.setInvocationParameter('inputText', currentPrompt);
                
                // Pass session ID if we have one (to keep context for retries)
                if (sessionId != null) {
                    action.setInvocationParameter('sessionId', sessionId);
                }

                // Execute
                List<Invocable.Action.Result> results = action.invoke();
                
                // 3. Process Result
                if (results.size() > 0 && results[0].isSuccess()) {
                    Map<String, Object> outputs = results[0].getOutputParameters();
                    String agentResponseText = (String) outputs.get('outputText'); // Standard output key
                    sessionId = (String) outputs.get('sessionId'); // Capture session for next loop

                    System.debug('Agent Raw Response: ' + agentResponseText);

                    // 4. Sanitize and Parse
                    String cleanJson = cleanJsonString(agentResponseText);
                    finalResult = (PackageXmlResult) JSON.deserialize(cleanJson, PackageXmlResult.class);
                    
                    // Validation
                    if (String.isBlank(finalResult.names) || String.isBlank(finalResult.members)) {
                        throw new CalloutException('JSON missing required keys');
                    }
                    
                    return finalResult; // Success!
                } else {
                    System.debug('Action invocation failed: ' + results[0].getErrors());
                    break; // Stop if system error
                }

            } catch (Exception e) {
                System.debug('Parsing failed or Agent hallucinated: ' + e.getMessage());
                
                // 5. The Retry Prompt
                finalResult = null;
                currentPrompt = 'The previous output was incorrect internal data. ' + 
                                'Please purely output the final JSON object in this format: ' +
                                '{ "names": "CustomField", "members": "Account.Example__c" }. ' +
                                'Do not include any other text or markdown.';
            }
        }
        
        return null; // Failed after max retries
    }

    // Helper to strip Markdown backticks
    private static String cleanJsonString(String input) {
        if (String.isBlank(input)) return '';
        String clean = input.replaceAll('```json', '').replaceAll('```', '');
        Integer firstBrace = clean.indexOf('{');
        Integer lastBrace = clean.lastIndexOf('}');
        if (firstBrace != -1 && lastBrace != -1) {
            clean = clean.substring(firstBrace, lastBrace + 1);
        }
        return clean.trim();
    }  */
}