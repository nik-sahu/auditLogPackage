public with sharing class AuditTrailAIHelper {

    // Using the Default Open AI Model provided by Salesforce (Generative AI)
    // Ensure "Einstein GPT" is enabled in Setup for this to work.
    private static final String MODEL_NAME = 'sfdc_ai__DefaultOpenAIGPT4OmniMini'; 

    /**
     * @description Calls the LLM to predict API names for a list of audit descriptions.
     * @param inputs List of Audit Trail "Display" strings (e.g., "Created custom field: MyField")
     * @return Map<String, String> Mapping of [Original Input] -> [Predicted API Name]
     */
    public static Map<String, String> predictApiNames(List<String> inputs) {
        Map<String, String> predictions = new Map<String, String>();
        
        if (inputs == null || inputs.isEmpty()) {
            return predictions;
        }

        try {
            // 1. Construct the Prompt
            // We batch the inputs into a single prompt to save tokens and reduce round-trips.
            String promptText = 'You are a Salesforce Metadata Expert. \n' +
                'Convert these Audit Trail entries into their correct API Names.\n' +
                'The input format is: "Section: [Section Name] | Display: [Display Text]"\n\n' +
                'Rules:\n' +
                '1. Use the "Section" to identify the parent Object (e.g., "Customize Accounts" means Object is "Account").\n' +
                '2. Use the "Display" text to identify the field or component name.\n' +
                '3. For Custom Fields, combine them as ObjectName.FieldName__c (e.g., Account.Verifiedacc__c).\n' +
                '4. Return ONLY a valid JSON object where keys are the exact input strings provided, and values are the API names.\n' +
                'Inputs:\n' + String.join(inputs, '\n');

            // 2. Configure the Models API Request
            // This uses the "aiplatform" namespace available in API v60.0+
            aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
            request.modelName = MODEL_NAME;
            
            aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
            requestBody.prompt = promptText;
            
            // Optional: Adjust parameters like temperature if needed
            // requestBody.temperature = 0.0; // Keep it deterministic
            
            request.body = requestBody;

            // 3. Execute the Callout
            aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
            aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(request);

            // 4. Extract Response
            String aiResponseText = '';
            if (response.Code200 != null && response.Code200.generation != null) {
                aiResponseText = response.Code200.generation.generatedText;
            }

            // 5. Sanitize and Parse JSON
            // LLMs often wrap JSON in markdown code blocks (```json ... ```), which breaks deserialization.
            aiResponseText = cleanJsonString(aiResponseText);
            
            // Deserialize into the expected Map structure
            predictions = (Map<String, String>) JSON.deserialize(aiResponseText, Map<String, String>.class);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Models API Error: ' + e.getMessage());
            // We throw a handled exception so the LWC can show a user-friendly toast message
            throw new AuraHandledException('AI Generation Failed: ' + e.getMessage());
        }
        
        return predictions;
    }

    /**
     * @description Helper to strip Markdown code blocks (```json ... ```) from LLM responses.
     */
    private static String cleanJsonString(String input) {
        if (String.isBlank(input)) return '';
        
        // Remove markdown backticks and language identifiers
        String clean = input.replaceAll('```json', '').replaceAll('```', '');
        
        // Robustness: Extract only the content between the first { and last }
        // This handles cases where the AI adds introductory text like "Here is your JSON:"
        Integer firstBrace = clean.indexOf('{');
        Integer lastBrace = clean.lastIndexOf('}');
        
        if (firstBrace != -1 && lastBrace != -1) {
            clean = clean.substring(firstBrace, lastBrace + 1);
        }
        
        return clean.trim();
    }
}