public class SlackAlertService { 

    @future(callout=true) 
    public static void sendMessage() { 
        try { 
            // Step 1 — Get counts
            ClaimAlertQueryService.ClaimCounts counts =
                ClaimAlertQueryService.getPendingClaimCounts();

            // Step 2 — Build message
            String message = ClaimAlertFormatter.buildMessage(counts);
            // Create a map to hold the Slack message 
            Map<String, Object> payloadData = new Map<String, Object>(); 
            payloadData.put('text', message); 
            
            // Serialize to JSON 
            String payload = JSON.serialize(payloadData); 
            
            HttpRequest req = new HttpRequest(); 
           
            
            Http http = new Http(); 
            HttpResponse res = http.send(req); 
            
            System.debug('Slack Response: ' + res.getBody()); 
        } catch (Exception ex) { 
            System.debug('Slack Error: ' + ex.getMessage()); 
        } 
    } 
}